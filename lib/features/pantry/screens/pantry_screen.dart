// lib/features/pantry/screens/pantry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../providers/pantry_provider.dart';
import '../widgets/pantry_item_card.dart';
import '../widgets/add_item_bottom_sheet.dart';
import '../widgets/pantry_filter_bar.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _searchCtrl = TextEditingController();
  bool _isSearchActive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(pantryFilterProvider.notifier).update(
      (s) => s.copyWith(searchQuery: query.isEmpty ? null : query),
    );
  }

  void _showAddItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(pantryItemsProvider);
    final stats = ref.watch(pantryStatsProvider);
    final filter = ref.watch(pantryFilterProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            title: _isSearchActive
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search pantry...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                    ),
                  )
                : const Text('My Pantry'),
            actions: [
              IconButton(
                icon: Icon(_isSearchActive ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearchActive = !_isSearchActive;
                    if (!_isSearchActive) {
                      _searchCtrl.clear();
                      _onSearch('');
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: () => _showFilterSheet(context),
              ),
            ],
          ),
        ],
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            ref.invalidate(pantryItemsProvider);
            ref.invalidate(expiringItemsProvider);
            ref.invalidate(pantryStatsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ── Stats Row ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: stats.when(
                  data: (s) => _StatsRow(stats: s),
                  loading: () => const _StatsRowSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ── Filter Chips ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: PantryFilterBar(
                  selectedCategory: filter.category,
                  onCategoryChanged: (cat) {
                    ref.read(pantryFilterProvider.notifier).update(
                      (s) => s.copyWith(
                        category: cat == filter.category ? null : cat,
                      ),
                    );
                  },
                ),
              ),

              // ── Items List ────────────────────────────────────────────────
              items.when(
                data: (itemList) {
                  if (itemList.isEmpty) {
                    return SliverFillRemaining(child: _EmptyState(onAdd: _showAddItem));
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final item = itemList[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Slidable(
                              key: Key(item.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.45,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _editItem(context, item),
                                    backgroundColor: AppTheme.info,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit_outlined,
                                    label: 'Edit',
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(16),
                                    ),
                                  ),
                                  SlidableAction(
                                    onPressed: (_) => _deleteItem(item),
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(16),
                                    ),
                                  ),
                                ],
                              ),
                              child: PantryItemCard(item: item),
                            ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 40),
                              duration: 300.ms,
                            ),
                          );
                        },
                        childCount: itemList.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _ItemSkeleton(),
                      ),
                      childCount: 6,
                    ),
                  ),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load pantry', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(pantryItemsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _editItem(BuildContext context, PantryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemBottomSheet(existingItem: item),
    );
  }

  Future<void> _deleteItem(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item?'),
        content: Text('Remove "${item.name}" from your pantry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await ref.read(pantryNotifierProvider.notifier).deleteItem(item.id);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete item'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showFilterSheet(BuildContext context) {
    // TODO: expand with full filter bottom sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final PantryStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        _StatChip(
          label: 'Total',
          value: '${stats.totalItems}',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.info,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Expiring',
          value: '${stats.expiringCount}',
          icon: Icons.schedule_outlined,
          color: AppTheme.warning,
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Expired',
          value: '${stats.expiredCount}',
          icon: Icons.warning_amber_outlined,
          color: AppTheme.error,
        ),
      ],
    ),
  );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: List.generate(3, (_) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        )),
      ),
    ),
  );
}

class _ItemSkeleton extends StatelessWidget {
  const _ItemSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.kitchen_outlined, size: 56, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Your pantry is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first item to start tracking freshness and getting recipe suggestions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add First Item'),
          ),
        ],
      ),
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Storage Location', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['All', 'Fridge', 'Freezer', 'Pantry', 'Counter']
              .map((loc) => FilterChip(
                label: Text(loc),
                selected: false,
                onSelected: (_) {},
              ))
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
