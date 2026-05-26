// lib/features/recipes/screens/recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../providers/recipe_provider.dart';
import '../../pantry/providers/pantry_provider.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = ref.watch(aiSuggestionsProvider);
    final savedRecipes = ref.watch(savedRecipesProvider);

    ref.listen<AiSuggestionsState>(aiSuggestionsProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppTheme.error),
        );
        ref.read(aiSuggestionsProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'AI Suggestions'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── AI Suggestions Tab ─────────────────────────────────────────
          _AiSuggestionsTab(suggestions: suggestions),

          // ── Saved Recipes Tab ──────────────────────────────────────────
          savedRecipes.when(
            data: (recipes) => recipes.isEmpty
                ? const _EmptySavedState()
                : _SavedRecipesList(recipes: recipes),
            loading: () => const _RecipesLoadingSkeleton(),
            error: (e, _) => _ErrorState(message: e.toString(), onRetry: () => ref.invalidate(savedRecipesProvider)),
          ),
        ],
      ),
    );
  }
}

// ── AI Suggestions Tab ────────────────────────────────────────────────────────
class _AiSuggestionsTab extends ConsumerWidget {
  final AiSuggestionsState suggestions;
  const _AiSuggestionsTab({required this.suggestions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => ref.read(aiSuggestionsProvider.notifier).generateSuggestions(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AI-Powered Suggestions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recipes tailored to use your pantry items before they expire.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: suggestions.isLoading
                          ? null
                          : () => ref.read(aiSuggestionsProvider.notifier).generateSuggestions(),
                      icon: suggestions.isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(suggestions.isLoading ? 'Generating...' : 'Generate Recipes'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: const Color(0xFF6A11CB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (suggestions.suggestions.isEmpty && !suggestions.isLoading)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No suggestions yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Generate Recipes" to get AI-powered meal ideas based on your pantry.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (suggestions.isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(padding: EdgeInsets.only(bottom: 12), child: _RecipeCardSkeleton()),
                  childCount: 4,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecipeSuggestionCard(recipe: suggestions.suggestions[i]),
                  ).animate().fadeIn(delay: Duration(milliseconds: i * 80), duration: 300.ms),
                  childCount: suggestions.suggestions.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Recipe Suggestion Card ────────────────────────────────────────────────────
class _RecipeSuggestionCard extends ConsumerWidget {
  final Recipe recipe;
  const _RecipeSuggestionCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF52B788), Color(0xFF2D6A4F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recipe.cuisine != null) ...[
                        const SizedBox(height: 2),
                        Text(recipe.cuisine!, style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (recipe.description != null) ...[
              const SizedBox(height: 10),
              Text(
                recipe.description!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                if (recipe.totalTimeMins > 0) ...[
                  const Icon(Icons.schedule_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 3),
                  Text('${recipe.totalTimeMins}m', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary)),
                  const SizedBox(width: 12),
                ],
                if (recipe.difficulty != null) ...[
                  const Icon(Icons.bar_chart_outlined, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    recipe.difficulty![0].toUpperCase() + recipe.difficulty!.substring(1),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
                  ),
                  const SizedBox(width: 12),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'View Recipe →',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (recipe.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: recipe.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.secondary),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Saved Recipes List ────────────────────────────────────────────────────────
class _SavedRecipesList extends ConsumerWidget {
  final List<Recipe> recipes;
  const _SavedRecipesList({required this.recipes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: recipes.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RecipeSuggestionCard(recipe: recipes[i]),
      ).animate().fadeIn(delay: Duration(milliseconds: i * 50)),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No saved recipes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Generate AI recipes and save your favourites here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _RecipesLoadingSkeleton extends StatelessWidget {
  const _RecipesLoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 4,
    itemBuilder: (_, __) => const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: _RecipeCardSkeleton(),
    ),
  );
}

class _RecipeCardSkeleton extends StatelessWidget {
  const _RecipeCardSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
        const SizedBox(height: 12),
        Text('Failed to load', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
