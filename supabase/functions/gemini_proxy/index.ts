// supabase/edge_functions/gemini_proxy/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Gemini AI Proxy — Edge Function
// The Gemini API key NEVER leaves the server. Client sends authenticated
// requests; this function validates the JWT, checks rate limits, then
// calls Gemini and returns the result.
// ─────────────────────────────────────────────────────────────────────────────

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent";

// Rate limits
const AI_MAX_REQUESTS_PER_HOUR = 20;
const AI_WINDOW_MINUTES = 60;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RecipeRequest {
  type: "recipe_suggest" | "recipe_detail" | "meal_plan";
  pantryItems?: Array<{ name: string; expiry_date?: string; quantity: number; unit: string }>;
  dietaryPrefs?: string[];
  allergens?: string[];
  servings?: number;
  recipeName?: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 1. Authenticate the request via Supabase JWT ─────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const token = authHeader.replace("Bearer ", "");

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 2. Rate Limit Check ───────────────────────────────────────────────────
  const { data: rateLimitOk, error: rlError } = await supabase.rpc("check_rate_limit", {
    p_user_id: user.id,
    p_action: "ai_recipe_generate",
    p_max_requests: AI_MAX_REQUESTS_PER_HOUR,
    p_window_minutes: AI_WINDOW_MINUTES,
  });

  if (rlError || !rateLimitOk) {
    return new Response(
      JSON.stringify({
        error: "Rate limit exceeded. Please wait before making more AI requests.",
        retry_after_minutes: AI_WINDOW_MINUTES,
      }),
      {
        status: 429,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Retry-After": String(AI_WINDOW_MINUTES * 60),
        },
      }
    );
  }

  // ── 3. Parse & Validate Request Body ─────────────────────────────────────
  let body: RecipeRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!body.type) {
    return new Response(JSON.stringify({ error: "Missing 'type' field" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 4. Build Gemini Prompt ────────────────────────────────────────────────
  let prompt = "";

  if (body.type === "recipe_suggest") {
    const itemsList = (body.pantryItems || [])
      .map((i) => {
        const expStr = i.expiry_date
          ? ` (expires ${i.expiry_date})`
          : "";
        return `- ${i.name}: ${i.quantity} ${i.unit}${expStr}`;
      })
      .join("\n");

    const dietStr =
      body.dietaryPrefs?.length ? `Dietary preferences: ${body.dietaryPrefs.join(", ")}.` : "";
    const allergenStr =
      body.allergens?.length ? `Allergens to AVOID: ${body.allergens.join(", ")}.` : "";

    prompt = `You are a smart meal planning assistant. Given the following pantry inventory, suggest 5 recipes that prioritize items expiring soonest to minimize food waste.

PANTRY INVENTORY:
${itemsList || "No items listed."}

${dietStr}
${allergenStr}
Target servings: ${body.servings || 2}

Respond with ONLY valid JSON in this exact format (no markdown, no backticks):
{
  "recipes": [
    {
      "title": "Recipe Name",
      "description": "Brief description (1-2 sentences)",
      "prep_time_mins": 15,
      "cook_time_mins": 25,
      "difficulty": "easy|medium|hard",
      "cuisine": "Italian",
      "tags": ["quick", "healthy"],
      "used_pantry_items": ["item1", "item2"],
      "waste_saved_note": "Uses 3 items expiring in 2 days"
    }
  ]
}`;
  } else if (body.type === "recipe_detail") {
    if (!body.recipeName) {
      return new Response(JSON.stringify({ error: "recipeName required for recipe_detail" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const pantryContext = body.pantryItems?.length
      ? `Available pantry items: ${body.pantryItems.map((i) => i.name).join(", ")}.`
      : "";

    prompt = `Generate a detailed recipe for "${body.recipeName}".
${pantryContext}
Servings: ${body.servings || 2}.
${body.allergens?.length ? `Avoid allergens: ${body.allergens.join(", ")}.` : ""}

Respond with ONLY valid JSON (no markdown, no backticks):
{
  "title": "Full Recipe Name",
  "description": "Detailed description",
  "ingredients": [
    {"name": "ingredient", "quantity": 2, "unit": "cups", "notes": "optional note"}
  ],
  "instructions": [
    "Step 1 instructions...",
    "Step 2 instructions..."
  ],
  "prep_time_mins": 15,
  "cook_time_mins": 30,
  "servings": 2,
  "difficulty": "easy|medium|hard",
  "cuisine": "Cuisine type",
  "tags": ["tag1", "tag2"],
  "nutrition_info": {
    "calories_per_serving": 350,
    "protein_g": 25,
    "carbs_g": 40,
    "fat_g": 12,
    "fiber_g": 5
  },
  "tips": "Optional chef tips"
}`;
  } else if (body.type === "meal_plan") {
    const itemsList = (body.pantryItems || [])
      .map((i) => `${i.name} (${i.quantity} ${i.unit})`)
      .join(", ");

    prompt = `Create a 7-day meal plan for ${body.servings || 2} people using available pantry items: ${itemsList || "general items"}.
${body.dietaryPrefs?.length ? `Dietary preferences: ${body.dietaryPrefs.join(", ")}.` : ""}
${body.allergens?.length ? `Avoid: ${body.allergens.join(", ")}.` : ""}

Respond with ONLY valid JSON:
{
  "meal_plan": {
    "monday": {"breakfast": "Meal name", "lunch": "Meal name", "dinner": "Meal name"},
    "tuesday": {"breakfast": "...", "lunch": "...", "dinner": "..."},
    "wednesday": {"breakfast": "...", "lunch": "...", "dinner": "..."},
    "thursday": {"breakfast": "...", "lunch": "...", "dinner": "..."},
    "friday": {"breakfast": "...", "lunch": "...", "dinner": "..."},
    "saturday": {"breakfast": "...", "lunch": "...", "dinner": "..."},
    "sunday": {"breakfast": "...", "lunch": "...", "dinner": "..."}
  },
  "shopping_needed": ["item1", "item2"]
}`;
  }

  // ── 5. Call Gemini API ────────────────────────────────────────────────────
  const geminiResponse = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 4096,
        responseMimeType: "application/json",
      },
      safetySettings: [
        { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
      ],
    }),
  });

  if (!geminiResponse.ok) {
    const errText = await geminiResponse.text();
    console.error("Gemini API error:", errText);
    return new Response(
      JSON.stringify({ error: "AI service temporarily unavailable. Please try again." }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  const geminiData = await geminiResponse.json();
  const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

  // Parse and validate the Gemini JSON response
  let parsedResult: Record<string, unknown>;
  try {
    parsedResult = JSON.parse(rawText);
  } catch {
    return new Response(JSON.stringify({ error: "AI returned invalid response. Please retry." }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ data: parsedResult }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
