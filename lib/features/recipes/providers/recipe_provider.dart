// lib/features/recipes/providers/recipe_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../services/recipe_service.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../profile/providers/profile_provider.dart';

final recipeServiceProvider = Provider<RecipeService>((ref) => RecipeService());

// ── Saved Recipes ─────────────────────────────────────────────────────────────
final savedRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  return ref.read(recipeServiceProvider).fetchSavedRecipes();
});

final favouriteRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  return ref.read(recipeServiceProvider).fetchSavedRecipes(favouritesOnly: true);
});

// ── AI Suggestions State ──────────────────────────────────────────────────────
class AiSuggestionsState {
  final List<Recipe> suggestions;
  final bool isLoading;
  final String? errorMessage;

  const AiSuggestionsState({
    this.suggestions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AiSuggestionsState copyWith({
    List<Recipe>? suggestions,
    bool? isLoading,
    String? errorMessage,
  }) => AiSuggestionsState(
    suggestions: suggestions ?? this.suggestions,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
  );
}

class AiSuggestionsNotifier extends StateNotifier<AiSuggestionsState> {
  final RecipeService _service;
  final Ref _ref;

  AiSuggestionsNotifier(this._service, this._ref) : super(const AiSuggestionsState());

  Future<void> generateSuggestions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pantryItems = await _ref.read(pantryItemsProvider.future);
      final profile = _ref.read(userProfileProvider).value;

      final suggestions = await _service.suggestRecipesFromPantry(
        pantryItems: pantryItems,
        dietaryPrefs: profile?.dietaryPrefs ?? [],
        allergens: profile?.allergens ?? [],
        servings: profile?.householdSize ?? 2,
      );
      state = state.copyWith(isLoading: false, suggestions: suggestions);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Recipe?> getFullRecipe(String recipeName, List<PantryItem> pantryItems) async {
    try {
      final profile = _ref.read(userProfileProvider).value;
      return await _service.getRecipeDetail(
        recipeName: recipeName,
        pantryItems: pantryItems,
        allergens: profile?.allergens ?? [],
        servings: profile?.householdSize ?? 2,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> saveRecipe(Recipe recipe) async {
    try {
      await _service.saveRecipe(recipe);
      _ref.invalidate(savedRecipesProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleFavourite(String recipeId, bool isFavourite) async {
    await _service.toggleFavourite(recipeId, isFavourite);
    _ref.invalidate(savedRecipesProvider);
    _ref.invalidate(favouriteRecipesProvider);
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final aiSuggestionsProvider = StateNotifierProvider<AiSuggestionsNotifier, AiSuggestionsState>((ref) {
  return AiSuggestionsNotifier(ref.read(recipeServiceProvider), ref);
});
