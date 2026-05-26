-- =============================================================================
-- FreshPlan — Supabase Database Schema + Row Level Security (RLS)
-- Migration: 001_initial_schema.sql
-- =============================================================================
-- Run this in your Supabase SQL editor or via `supabase db push`
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TYPE food_category AS ENUM (
  'produce', 'dairy', 'meat', 'seafood', 'grains', 'canned',
  'frozen', 'beverages', 'condiments', 'snacks', 'bakery',
  'herbs_spices', 'other'
);

CREATE TYPE storage_location AS ENUM (
  'fridge', 'freezer', 'pantry', 'counter'
);

CREATE TYPE expiry_status AS ENUM (
  'fresh', 'expiring_soon', 'expired'
);

CREATE TYPE meal_slot AS ENUM (
  'breakfast', 'lunch', 'dinner', 'snack'
);

CREATE TYPE shopping_item_status AS ENUM (
  'pending', 'in_cart', 'purchased', 'skipped'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: user_profiles
-- (extends Supabase auth.users — one row per user)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.user_profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name      TEXT,
  avatar_url        TEXT,
  household_size    SMALLINT DEFAULT 2 CHECK (household_size BETWEEN 1 AND 20),
  dietary_prefs     TEXT[]   DEFAULT '{}',       -- e.g. ['vegetarian','gluten-free']
  allergens         TEXT[]   DEFAULT '{}',
  notification_prefs JSONB   DEFAULT '{"expiry_alerts":true,"weekly_plan":true}'::jsonb,
  sustainability_score INTEGER DEFAULT 0,
  total_waste_saved_g  INTEGER DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
  ON public.user_profiles FOR DELETE
  USING (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: pantry_items
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.pantry_items (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  category         food_category NOT NULL DEFAULT 'other',
  storage_location storage_location NOT NULL DEFAULT 'pantry',
  quantity         NUMERIC(10,2) NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  unit             TEXT NOT NULL DEFAULT 'pcs' CHECK (char_length(unit) <= 50),
  expiry_date      DATE,
  purchase_date    DATE DEFAULT CURRENT_DATE,
  brand            TEXT CHECK (char_length(brand) <= 200),
  notes            TEXT CHECK (char_length(notes) <= 1000),
  barcode          TEXT CHECK (char_length(barcode) <= 100),
  image_url        TEXT,
  is_staple        BOOLEAN DEFAULT false,
  calories_per_100g NUMERIC(6,1),
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.pantry_items ENABLE ROW LEVEL SECURITY;

-- Users can ONLY access their own pantry items
CREATE POLICY "pantry_select_own"
  ON public.pantry_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "pantry_insert_own"
  ON public.pantry_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "pantry_update_own"
  ON public.pantry_items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "pantry_delete_own"
  ON public.pantry_items FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_pantry_user_id ON public.pantry_items(user_id);
CREATE INDEX idx_pantry_expiry_date ON public.pantry_items(expiry_date);
CREATE INDEX idx_pantry_category ON public.pantry_items(category);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: recipes (AI-generated, cached per user)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.recipes (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title            TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 300),
  description      TEXT,
  ingredients      JSONB NOT NULL DEFAULT '[]'::jsonb,
  instructions     TEXT[] NOT NULL DEFAULT '{}',
  prep_time_mins   SMALLINT CHECK (prep_time_mins >= 0),
  cook_time_mins   SMALLINT CHECK (cook_time_mins >= 0),
  servings         SMALLINT DEFAULT 2 CHECK (servings BETWEEN 1 AND 50),
  cuisine          TEXT,
  difficulty       TEXT CHECK (difficulty IN ('easy','medium','hard')),
  tags             TEXT[] DEFAULT '{}',
  nutrition_info   JSONB DEFAULT '{}'::jsonb,
  image_url        TEXT,
  ai_generated     BOOLEAN DEFAULT true,
  is_favourite     BOOLEAN DEFAULT false,
  pantry_items_used UUID[] DEFAULT '{}',
  waste_saved_g    INTEGER DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipes_select_own"
  ON public.recipes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "recipes_insert_own"
  ON public.recipes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "recipes_update_own"
  ON public.recipes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "recipes_delete_own"
  ON public.recipes FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_recipes_user_id ON public.recipes(user_id);
CREATE INDEX idx_recipes_favourite ON public.recipes(user_id, is_favourite);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: meal_plans
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.meal_plans (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_date        DATE NOT NULL,
  meal_slot        meal_slot NOT NULL,
  recipe_id        UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
  custom_meal_name TEXT CHECK (char_length(custom_meal_name) <= 300),
  notes            TEXT CHECK (char_length(notes) <= 500),
  is_completed     BOOLEAN DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, plan_date, meal_slot)
);

ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_plans_select_own"
  ON public.meal_plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "meal_plans_insert_own"
  ON public.meal_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meal_plans_update_own"
  ON public.meal_plans FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meal_plans_delete_own"
  ON public.meal_plans FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_meal_plans_user_date ON public.meal_plans(user_id, plan_date);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: shopping_lists
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.shopping_lists (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL DEFAULT 'My Shopping List' CHECK (char_length(name) <= 200),
  is_active        BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.shopping_lists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shopping_lists_own"
  ON public.shopping_lists FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.shopping_items (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  list_id          UUID NOT NULL REFERENCES public.shopping_lists(id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  quantity         NUMERIC(10,2) DEFAULT 1 CHECK (quantity > 0),
  unit             TEXT DEFAULT 'pcs',
  category         food_category DEFAULT 'other',
  estimated_price  NUMERIC(8,2),
  status           shopping_item_status DEFAULT 'pending',
  notes            TEXT CHECK (char_length(notes) <= 500),
  added_from_recipe UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
  sort_order       INTEGER DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.shopping_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shopping_items_own"
  ON public.shopping_items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_shopping_items_list ON public.shopping_items(list_id);
CREATE INDEX idx_shopping_items_user ON public.shopping_items(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: waste_logs (for sustainability tracking)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.waste_logs (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pantry_item_id   UUID REFERENCES public.pantry_items(id) ON DELETE SET NULL,
  item_name        TEXT NOT NULL,
  quantity_wasted_g INTEGER NOT NULL CHECK (quantity_wasted_g >= 0),
  reason           TEXT CHECK (reason IN ('expired','spoiled','overcooked','disliked','other')),
  logged_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.waste_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "waste_logs_own"
  ON public.waste_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_waste_logs_user ON public.waste_logs(user_id);
CREATE INDEX idx_waste_logs_date ON public.waste_logs(user_id, logged_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: rate_limit_log (server-side rate limiting via DB)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.rate_limit_log (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action           TEXT NOT NULL,           -- e.g. 'ai_recipe_generate'
  request_count    INTEGER DEFAULT 1,
  window_start     TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, action, window_start)
);

ALTER TABLE public.rate_limit_log ENABLE ROW LEVEL SECURITY;

-- Users cannot directly read or write the rate limit log — only service role
CREATE POLICY "rate_limit_no_user_access"
  ON public.rate_limit_log FOR ALL
  USING (false);

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: auto-update updated_at timestamps
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_pantry_items_updated_at
  BEFORE UPDATE ON public.pantry_items
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_meal_plans_updated_at
  BEFORE UPDATE ON public.meal_plans
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_shopping_lists_updated_at
  BEFORE UPDATE ON public.shopping_lists
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_shopping_items_updated_at
  BEFORE UPDATE ON public.shopping_items
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: auto-create user_profile on new auth signup
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: check_rate_limit (called from Edge Functions via service role)
-- Returns TRUE if the action is within limit, FALSE if rate limited
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_requests INTEGER,
  p_window_minutes INTEGER
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INTEGER;
  v_window_start TIMESTAMPTZ;
BEGIN
  v_window_start := date_trunc('minute', now()) -
    ((EXTRACT(MINUTE FROM now())::INTEGER % p_window_minutes) * INTERVAL '1 minute');

  SELECT COALESCE(SUM(request_count), 0) INTO v_count
  FROM public.rate_limit_log
  WHERE user_id = p_user_id
    AND action = p_action
    AND window_start >= v_window_start;

  IF v_count >= p_max_requests THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.rate_limit_log (user_id, action, request_count, window_start)
  VALUES (p_user_id, p_action, 1, v_window_start)
  ON CONFLICT (user_id, action, window_start)
  DO UPDATE SET request_count = rate_limit_log.request_count + 1;

  RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: get expiring items in next N days for a user
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_expiring_items(p_user_id UUID, p_days INTEGER DEFAULT 3)
RETURNS SETOF public.pantry_items LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM public.pantry_items
  WHERE user_id = p_user_id
    AND expiry_date IS NOT NULL
    AND expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + p_days)
  ORDER BY expiry_date ASC;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Clean up old rate limit entries (run via pg_cron or scheduled function)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cleanup_rate_limits()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.rate_limit_log WHERE window_start < now() - INTERVAL '1 day';
$$;
