// lib/features/recipes/services/recipe_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/security/rate_limiter.dart';
import '../../../models/models.dart';

class RecipeService {
  final _supabase = Supabase.instance.client;
  late final Dio _dio;

  RecipeService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 15),
    ));

    // Add auth interceptor — injects fresh JWT on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = _supabase.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        options.headers['Content-Type'] = 'application/json';
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired — Supabase auto-refreshes, but we can handle here
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            message: 'Session expired. Please sign in again.',
          ));
        }
        if (error.response?.statusCode == 429) {
          return handler.reject(DioException(
            requestOptions: error.requestOptions,
            message: 'You\'ve made too many AI requests. Please wait before trying again.',
          ));
        }
        return handler.next(error);
      },
    ));
  }

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  // ── AI: Suggest Recipes from Pantry ──────────────────────────────────────
  Future<List<Recipe>> suggestRecipesFromPantry({
    required List<PantryItem> pantryItems,
    List<String> dietaryPrefs = const [],
    List<String> allergens = const [],
    int servings = 2,
  }) async {
    if (!AppRateLimiters.aiGeneration.tryAcquire()) {
      throw Exception(
        'AI request limit reached. Please wait ${AppRateLimiters.aiGeneration.msUntilAvailable() ~/ 1000}s.',
      );
    }

    final response = await _dio.post(
      AppConfig.geminiProxyEndpoint,
      data: jsonEncode({
        'type': 'recipe_suggest',
        'pantryItems': pantryItems.map((i) => {
          'name': i.name,
          'expiry_date': i.expiryDate?.toIso8601String().split('T').first,
          'quantity': i.quantity,
          'unit': i.unit,
        }).toList(),
        'dietaryPrefs': dietaryPrefs,
        'allergens': allergens,
        'servings': servings,
      }),
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    final recipesRaw = data?['recipes'] as List<dynamic>?;
    if (recipesRaw == null) return [];

    return recipesRaw.map((r) {
      final map = r as Map<String, dynamic>;
      return Recipe(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${recipesRaw.indexOf(r)}',
        userId: _userId,
        title: map['title'] as String? ?? 'Untitled Recipe',
        description: map['description'] as String?,
        ingredients: const [],
        instructions: const [],
        prepTimeMins: map['prep_time_mins'] as int?,
        cookTimeMins: map['cook_time_mins'] as int?,
        servings: 2,
        cuisine: map['cuisine'] as String?,
        difficulty: map['difficulty'] as String?,
        tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        wasteSavedG: 0,
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  // ── AI: Get Full Recipe Detail ────────────────────────────────────────────
  Future<Recipe?> getRecipeDetail({
    required String recipeName,
    List<PantryItem> pantryItems = const [],
    List<String> allergens = const [],
    int servings = 2,
  }) async {
    if (!AppRateLimiters.aiGeneration.tryAcquire()) {
      throw Exception('AI request limit reached. Please wait before requesting another recipe.');
    }

    final response = await _dio.post(
      AppConfig.geminiProxyEndpoint,
      data: jsonEncode({
        'type': 'recipe_detail',
        'recipeName': recipeName,
        'pantryItems': pantryItems.map((i) => {'name': i.name}).toList(),
        'allergens': allergens,
        'servings': servings,
      }),
    );

    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final ingredientsRaw = data['ingredients'] as List<dynamic>? ?? [];
    final instructionsRaw = data['instructions'] as List<dynamic>? ?? [];
    final tagsRaw = data['tags'] as List<dynamic>? ?? [];

    return Recipe(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      title: data['title'] as String? ?? recipeName,
      description: data['description'] as String?,
      ingredients: ingredientsRaw
          .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      instructions: instructionsRaw.map((e) => e.toString()).toList(),
      prepTimeMins: data['prep_time_mins'] as int?,
      cookTimeMins: data['cook_time_mins'] as int?,
      servings: data['servings'] as int? ?? servings,
      cuisine: data['cuisine'] as String?,
      difficulty: data['difficulty'] as String?,
      tags: tagsRaw.map((e) => e.toString()).toList(),
      nutritionInfo: data['nutrition_info'] != null
          ? NutritionInfo.fromJson(data['nutrition_info'] as Map<String, dynamic>)
          : null,
      aiGenerated: true,
      createdAt: DateTime.now(),
    );
  }

  // ── Save Recipe to DB ─────────────────────────────────────────────────────
  Future<Recipe> saveRecipe(Recipe recipe) async {
    final data = await _supabase.from('recipes').insert({
      'user_id': _userId,
      'title': recipe.title,
      'description': recipe.description,
      'ingredients': recipe.ingredients.map((i) => {
        'name': i.name, 'quantity': i.quantity, 'unit': i.unit, 'notes': i.notes,
      }).toList(),
      'instructions': recipe.instructions,
      'prep_time_mins': recipe.prepTimeMins,
      'cook_time_mins': recipe.cookTimeMins,
      'servings': recipe.servings,
      'cuisine': recipe.cuisine,
      'difficulty': recipe.difficulty,
      'tags': recipe.tags,
      'nutrition_info': recipe.nutritionInfo != null ? {
        'calories_per_serving': recipe.nutritionInfo!.caloriesPerServing,
        'protein_g': recipe.nutritionInfo!.proteinG,
        'carbs_g': recipe.nutritionInfo!.carbsG,
        'fat_g': recipe.nutritionInfo!.fatG,
        'fiber_g': recipe.nutritionInfo!.fiberG,
      } : null,
      'ai_generated': recipe.aiGenerated,
      'is_favourite': false,
      'waste_saved_g': recipe.wasteSavedG,
    }).select().single();

    return Recipe.fromJson(data);
  }

  // ── Fetch Saved Recipes ────────────────────────────────────────────────────
  Future<List<Recipe>> fetchSavedRecipes({bool favouritesOnly = false}) async {
    var query = _supabase
        .from('recipes')
        .select()
        .eq('user_id', _userId);

    if (favouritesOnly) {
      query = query.eq('is_favourite', true);
    }

    final data = await query.order('created_at', ascending: false).limit(50);
    return (data as List).map((e) => Recipe.fromJson(e)).toList();
  }

  // ── Toggle Favourite ──────────────────────────────────────────────────────
  Future<void> toggleFavourite(String recipeId, bool isFavourite) async {
    await _supabase
        .from('recipes')
        .update({'is_favourite': isFavourite})
        .eq('id', recipeId)
        .eq('user_id', _userId);
  }

  // ── Delete Recipe ─────────────────────────────────────────────────────────
  Future<void> deleteRecipe(String recipeId) async {
    await _supabase
        .from('recipes')
        .delete()
        .eq('id', recipeId)
        .eq('user_id', _userId);
  }
}
