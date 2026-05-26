// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../recipes/providers/recipe_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../pantry/widgets/pantry_item_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);
    final expiringAsync = ref.watch(expiringItemsProvider);
    final statsAsync = ref.watch(pantryStatsProvider);
    final aiState = ref.watch(aiSuggestionsProvider);

    final greeting = _getGreeting();
    final name = profileAsync.value?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            ref.invalidate(expiringItemsProvider);
            ref.invalidate(pantryStatsProvider);
            ref.invalidate(userProfileProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, $name 👋',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ).animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 4),
                            statsAsync.when(
                              data: (s) => Text(
                                '${s.totalItems} items in your pantry',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                              ),
                              loading: () => Text(
                                'Loading pantry...',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/home/profile'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expiry Alert Banner ────────────────────────────────────
              expiringAsync.when(
                data: (items) => items.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : SliverToBoxAdapter(
                        child: _ExpiryAlertBanner(items: items).animate().slideX(
                          begin: -0.1, end: 0, duration: 400.ms, delay: 200.ms,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // ── Quick Stats ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (s) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _QuickStatsRow(stats: s),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  loading: () => const SizedBox(height: 80),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ── AI Suggest Quick Action ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _AiQuickAction(
                    isLoading: aiState.isLoading,
                    hasSuggestions: aiState.suggestions.isNotEmpty,
                    onGenerate: () {
                      ref.read(aiSuggestionsProvider.notifier).generateSuggestions();
                      context.go('/home/recipes');
                    },
                    onView: () => context.go('/home/recipes'),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              ),

              // ── Expiring Soon Section ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expiring Soon',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () => context.go('/home/pantry'),
                        child: const Text('View All →'),
                      ),
                    ],
                  ),
                ),
              ),

              expiringAsync.when(
                data: (items) => items.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'All your items are fresh! Nothing expiring in the next 3 days.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.success),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: PantryItemCard(item: items[i]),
                            ).animate().fadeIn(
                              delay: Duration(milliseconds: 200 + i * 60),
                              duration: 300.ms,
                            ),
                            childCount: items.take(5).length,
                          ),
                        ),
                      ),
                loading: () => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Expiry Alert Banner ───────────────────────────────────────────────────────
class _ExpiryAlertBanner extends StatelessWidget {
  final List<PantryItem> items;
  const _ExpiryAlertBanner({required this.items});

  @override
  Widget build(BuildContext context) {
    final expired = items.where((i) => i.expiryStatus == ExpiryStatus.expired).length;
    final expiring = items.where((i) => i.expiryStatus == ExpiryStatus.expiringSoon).length;
    final hasExpired = expired > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasExpired ? AppTheme.error.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasExpired ? AppTheme.error.withOpacity(0.3) : AppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasExpired ? Icons.warning_amber_rounded : Icons.schedule_outlined,
            color: hasExpired ? AppTheme.error : AppTheme.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasExpired
                  ? '$expired item${expired != 1 ? 's' : ''} expired${expiring > 0 ? ' + $expiring expiring soon' : ''}'
                  : '$expiring item${expiring != 1 ? 's' : ''} expiring in the next 3 days',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasExpired ? AppTheme.error : AppTheme.warning,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

// ── Quick Stats Row ───────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final PantryStats stats;
  const _QuickStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _MiniStat(label: 'Items', value: '${stats.totalItems}', icon: Icons.inventory_2_outlined, color: AppTheme.info),
      const SizedBox(width: 12),
      _MiniStat(label: 'Categories', value: '${stats.byCategory.length}', icon: Icons.category_outlined, color: AppTheme.secondary),
      const SizedBox(width: 12),
      _MiniStat(label: 'Expired', value: '${stats.expiredCount}', icon: Icons.report_outlined, color: AppTheme.error),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    ),
  );
}

// ── AI Quick Action Card ──────────────────────────────────────────────────────
class _AiQuickAction extends StatelessWidget {
  final bool isLoading, hasSuggestions;
  final VoidCallback onGenerate, onView;
  const _AiQuickAction({
    required this.isLoading, required this.hasSuggestions,
    required this.onGenerate, required this.onView,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Recipe Suggestions',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                hasSuggestions ? 'Suggestions ready to view' : 'Generate recipes from your pantry',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : (hasSuggestions ? onView : onGenerate),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6A11CB),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF6A11CB),
                  ),
                )
              : Text(
                  hasSuggestions ? 'View' : 'Generate',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
        ),
      ],
    ),
  );
}
