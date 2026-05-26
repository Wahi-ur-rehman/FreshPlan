// lib/features/analytics/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../pantry/providers/pantry_provider.dart';

// ── Analytics Service ────────────────────────────────────────────────────────
class AnalyticsService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<Map<String, dynamic>> fetchStats() async {
    // Waste logs for the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final wasteLogs = await _supabase
        .from('waste_logs')
        .select()
        .eq('user_id', _uid)
        .gte('logged_at', thirtyDaysAgo.toIso8601String());

    int totalWastedG = 0;
    final byReason = <String, int>{};
    final dailyWaste = <String, int>{};

    for (final log in wasteLogs as List) {
      final g = (log['quantity_wasted_g'] as int?) ?? 0;
      totalWastedG += g;
      final reason = log['reason'] as String? ?? 'other';
      byReason[reason] = (byReason[reason] ?? 0) + g;
      final day = (log['logged_at'] as String).split('T').first;
      dailyWaste[day] = (dailyWaste[day] ?? 0) + g;
    }

    // Profile stats
    final profile = await _supabase
        .from('user_profiles')
        .select('sustainability_score, total_waste_saved_g')
        .eq('id', _uid)
        .maybeSingle();

    return {
      'total_wasted_g': totalWastedG,
      'by_reason': byReason,
      'daily_waste': dailyWaste,
      'sustainability_score': profile?['sustainability_score'] ?? 0,
      'total_waste_saved_g': profile?['total_waste_saved_g'] ?? 0,
      'log_count': (wasteLogs as List).length,
    };
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

final analyticsStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(analyticsServiceProvider).fetchStats();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(analyticsStatsProvider);
    final pantryStats = ref.watch(pantryStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(analyticsStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(analyticsStatsProvider);
          ref.invalidate(pantryStatsProvider);
        },
        child: statsAsync.when(
          data: (stats) => _AnalyticsContent(stats: stats, pantryStats: pantryStats.value),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                const Text('Failed to load analytics'),
                TextButton(
                  onPressed: () => ref.invalidate(analyticsStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  final PantryStats? pantryStats;
  const _AnalyticsContent({required this.stats, this.pantryStats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalWastedKg = ((stats['total_wasted_g'] as int? ?? 0) / 1000.0);
    final savedG = stats['total_waste_saved_g'] as int? ?? 0;
    final score = stats['sustainability_score'] as int? ?? 0;
    final byReason = stats['by_reason'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        // ── Sustainability Score ──────────────────────────────────────────
        _SustainabilityCard(score: score, savedG: savedG),
        const SizedBox(height: 20),

        // ── Key Metrics Row ───────────────────────────────────────────────
        Row(
          children: [
            _MetricCard(
              label: 'Wasted (30d)',
              value: '${totalWastedKg.toStringAsFixed(2)} kg',
              icon: Icons.delete_outline,
              color: AppTheme.error,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              label: 'Total Items',
              value: '${pantryStats?.totalItems ?? 0}',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.info,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              label: 'Expiring',
              value: '${pantryStats?.expiringCount ?? 0}',
              icon: Icons.schedule_outlined,
              color: AppTheme.warning,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Pantry Distribution Pie Chart ─────────────────────────────────
        if (pantryStats != null && pantryStats!.byCategory.isNotEmpty) ...[
          Text('Pantry by Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _CategoryPieChart(byCategory: pantryStats!.byCategory),
          const SizedBox(height: 24),
        ],

        // ── Storage Location Bar Chart ─────────────────────────────────────
        if (pantryStats != null && pantryStats!.byLocation.isNotEmpty) ...[
          Text('Items by Storage Location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _LocationBarChart(byLocation: pantryStats!.byLocation),
          const SizedBox(height: 24),
        ],

        // ── Waste by Reason ───────────────────────────────────────────────
        if (byReason.isNotEmpty) ...[
          Text('Waste Causes (30 days)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _WasteReasonsList(byReason: byReason),
          const SizedBox(height: 24),
        ],

        // ── Tips ──────────────────────────────────────────────────────────
        _TipsCard(expiringCount: pantryStats?.expiringCount ?? 0),
      ],
    );
  }
}

// ── Sustainability Score Card ─────────────────────────────────────────────────
class _SustainabilityCard extends StatelessWidget {
  final int score, savedG;
  const _SustainabilityCard({required this.score, required this.savedG});

  @override
  Widget build(BuildContext context) {
    final savedKg = (savedG / 1000.0).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌱 Sustainability Score', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '$score pts',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('$savedKg kg food saved from waste', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Category Pie Chart ────────────────────────────────────────────────────────
class _CategoryPieChart extends StatefulWidget {
  final Map<String, int> byCategory;
  const _CategoryPieChart({required this.byCategory});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touchedIndex = -1;

  static const _colors = [
    Color(0xFF2D6A4F), Color(0xFF52B788), Color(0xFFFF9F1C),
    Color(0xFF1976D2), Color(0xFFE63946), Color(0xFF9C27B0),
    Color(0xFF00BCD4), Color(0xFFFF5722), Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.byCategory.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                    });
                  },
                ),
                sections: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value;
                  final isTouched = idx == _touchedIndex;
                  final pct = (entry.value / total * 100).toStringAsFixed(1);
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: _colors[idx % _colors.length],
                    radius: isTouched ? 55 : 45,
                    title: isTouched ? '$pct%' : '',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ListView(
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: _colors[idx % _colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${entry.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location Bar Chart ────────────────────────────────────────────────────────
class _LocationBarChart extends StatelessWidget {
  final Map<String, int> byLocation;
  const _LocationBarChart({required this.byLocation});

  @override
  Widget build(BuildContext context) {
    final entries = byLocation.entries.toList();
    final maxVal = entries.fold(0, (m, e) => e.value > m ? e.value : m);

    const colors = {
      'fridge': Color(0xFF1976D2),
      'freezer': Color(0xFF00BCD4),
      'pantry': Color(0xFF2D6A4F),
      'counter': Color(0xFFFF9F1C),
    };

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.3).toDouble(),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final loc = entries[val.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(loc[0].toUpperCase() + loc.substring(1), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            final color = colors[e.value.key] ?? AppTheme.primary;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: color,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: (maxVal * 1.3).toDouble(),
                    color: color.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Waste Reasons ─────────────────────────────────────────────────────────────
class _WasteReasonsList extends StatelessWidget {
  final Map<String, dynamic> byReason;
  const _WasteReasonsList({required this.byReason});

  @override
  Widget build(BuildContext context) {
    final total = byReason.values.fold(0, (s, v) => s + (v as int));
    final entries = byReason.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: entries.map((entry) {
          final grams = entry.value as int;
          final pct = total > 0 ? grams / total : 0.0;
          final label = entry.key[0].toUpperCase() + entry.key.substring(1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      '${(grams / 1000.0).toStringAsFixed(2)} kg',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct,
                  color: AppTheme.error,
                  backgroundColor: AppTheme.error.withOpacity(0.1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tips Card ─────────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  final int expiringCount;
  const _TipsCard({required this.expiringCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.secondary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.secondary.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: AppTheme.secondary),
            const SizedBox(width: 8),
            Text(
              'Tips to Reduce Waste',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.secondary, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...[
          if (expiringCount > 0) '🍽️ Use AI recipes to cook items expiring this week.',
          '🛒 Plan meals before shopping to avoid over-buying.',
          '📦 Store items correctly — fridge for dairy, cool pantry for grains.',
          '🔄 FIFO: always move older items to the front.',
          '🧊 Freeze items before they expire to extend shelf life.',
        ].map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(tip, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
        )),
      ],
    ),
  );
}
