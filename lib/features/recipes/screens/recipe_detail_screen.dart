// lib/features/recipes/screens/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../providers/recipe_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late Recipe _recipe;
  bool _isLoadingFull = false;
  bool _isSaved = false;
  bool _isSaving = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _tabController = TabController(length: 2, vsync: this);
    if (_recipe.instructions.isEmpty) {
      _loadFullRecipe();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFullRecipe() async {
    setState(() => _isLoadingFull = true);
    try {
      final full = await ref.read(aiSuggestionsProvider.notifier)
          .getFullRecipe(_recipe.title, []);
      if (full != null && mounted) {
        setState(() => _recipe = full);
      }
    } finally {
      if (mounted) setState(() => _isLoadingFull = false);
    }
  }

  Future<void> _saveRecipe() async {
    setState(() => _isSaving = true);
    final success = await ref.read(aiSuggestionsProvider.notifier).saveRecipe(_recipe);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSaved = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Recipe saved!' : 'Failed to save recipe'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _recipe.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black45)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.restaurant_menu_outlined, size: 72, color: Colors.white24),
                ),
              ),
            ),
            actions: [
              if (!_isSaved)
                IconButton(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_border_outlined, color: Colors.white),
                  onPressed: _isSaving ? null : _saveRecipe,
                  tooltip: 'Save recipe',
                ),
              if (_isSaved)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.bookmark, color: Colors.white),
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meta info ──────────────────────────────────────────────
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      if (_recipe.totalTimeMins > 0)
                        _MetaChip(icon: Icons.schedule_outlined, label: '${_recipe.totalTimeMins} min'),
                      if (_recipe.difficulty != null)
                        _MetaChip(
                          icon: Icons.bar_chart_outlined,
                          label: _recipe.difficulty![0].toUpperCase() + _recipe.difficulty!.substring(1),
                        ),
                      _MetaChip(icon: Icons.people_outline, label: '${_recipe.servings} servings'),
                      if (_recipe.cuisine != null)
                        _MetaChip(icon: Icons.restaurant_outlined, label: _recipe.cuisine!),
                    ],
                  ),

                  if (_recipe.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _recipe.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.6),
                    ),
                  ],

                  if (_recipe.nutritionInfo != null) ...[
                    const SizedBox(height: 20),
                    Text('Nutrition per serving', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _NutritionBadge(label: 'Cal', value: '${_recipe.nutritionInfo!.caloriesPerServing?.toInt() ?? "?"}'),
                        const SizedBox(width: 8),
                        _NutritionBadge(label: 'Protein', value: '${_recipe.nutritionInfo!.proteinG?.toInt() ?? "?"}g'),
                        const SizedBox(width: 8),
                        _NutritionBadge(label: 'Carbs', value: '${_recipe.nutritionInfo!.carbsG?.toInt() ?? "?"}g'),
                        const SizedBox(width: 8),
                        _NutritionBadge(label: 'Fat', value: '${_recipe.nutritionInfo!.fatG?.toInt() ?? "?"}g'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_isLoadingFull)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text('Generating full recipe with Gemini AI...'),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textTertiary,
                indicatorColor: AppTheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [Tab(text: 'Ingredients'), Tab(text: 'Instructions')],
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Ingredients
                    _recipe.ingredients.isEmpty
                        ? const Center(child: Text('No ingredients available.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _recipe.ingredients.length,
                            itemBuilder: (ctx, i) {
                              final ing = _recipe.ingredients[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary, shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${ing.name} — ${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                                        style: Theme.of(ctx).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                    // Instructions
                    _recipe.instructions.isEmpty
                        ? const Center(child: Text('No instructions available.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _recipe.instructions.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _recipe.instructions[i],
                                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _NutritionBadge extends StatelessWidget {
  final String label, value;
  const _NutritionBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );
}
