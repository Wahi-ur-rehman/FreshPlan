// lib/features/meal_plan/screens/meal_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

// ── Service ───────────────────────────────────────────────────────────────────
class MealPlanService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> fetchWeekPlan(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final data = await _supabase
        .from('meal_plans')
        .select('*, recipes(title, prep_time_mins, cook_time_mins, difficulty)')
        .eq('user_id', _uid)
        .gte('plan_date', weekStart.toIso8601String().split('T').first)
        .lte('plan_date', weekEnd.toIso8601String().split('T').first)
        .order('plan_date');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> upsertMeal({
    required DateTime date,
    required String slot,
    String? recipeId,
    String? customMealName,
  }) async {
    await _supabase.from('meal_plans').upsert({
      'user_id': _uid,
      'plan_date': date.toIso8601String().split('T').first,
      'meal_slot': slot,
      'recipe_id': recipeId,
      'custom_meal_name': customMealName,
    }, onConflict: 'user_id,plan_date,meal_slot');
  }

  Future<void> toggleCompleted(String mealPlanId, bool completed) async {
    await _supabase.from('meal_plans')
        .update({'is_completed': completed})
        .eq('id', mealPlanId)
        .eq('user_id', _uid);
  }

  Future<void> deleteMeal(String mealPlanId) async {
    await _supabase.from('meal_plans')
        .delete()
        .eq('id', mealPlanId)
        .eq('user_id', _uid);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final mealPlanServiceProvider = Provider<MealPlanService>((ref) => MealPlanService());

final currentWeekStartProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
});

final weekMealPlanProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTime>((ref, weekStart) {
  return ref.read(mealPlanServiceProvider).fetchWeekPlan(weekStart);
});

// ── Screen ────────────────────────────────────────────────────────────────────
class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(currentWeekStartProvider);
    final mealsAsync = ref.watch(weekMealPlanProvider(weekStart));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              final now = DateTime.now();
              final monday = now.subtract(Duration(days: now.weekday - 1));
              ref.read(currentWeekStartProvider.notifier).state = monday;
            },
            tooltip: 'Go to current week',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Week Navigation ────────────────────────────────────────────
          _WeekNavigator(
            weekStart: weekStart,
            onPrevious: () {
              ref.read(currentWeekStartProvider.notifier).state =
                  weekStart.subtract(const Duration(days: 7));
            },
            onNext: () {
              ref.read(currentWeekStartProvider.notifier).state =
                  weekStart.add(const Duration(days: 7));
            },
          ),

          // ── Meal Plan Grid ─────────────────────────────────────────────
          Expanded(
            child: mealsAsync.when(
              data: (meals) => _WeekGrid(
                weekStart: weekStart,
                meals: meals,
                onRefresh: () => ref.invalidate(weekMealPlanProvider(weekStart)),
                service: ref.read(mealPlanServiceProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    const Text('Failed to load meal plan'),
                    TextButton(
                      onPressed: () => ref.invalidate(weekMealPlanProvider(weekStart)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week Navigator ────────────────────────────────────────────────────────────
class _WeekNavigator extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrevious, onNext;
  const _WeekNavigator({required this.weekStart, required this.onPrevious, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
          ),
          Column(
            children: [
              Text(
                '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                DateFormat('yyyy').format(weekStart),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
          ),
        ],
      ),
    );
  }
}

// ── Week Grid ─────────────────────────────────────────────────────────────────
class _WeekGrid extends StatelessWidget {
  final DateTime weekStart;
  final List<Map<String, dynamic>> meals;
  final VoidCallback onRefresh;
  final MealPlanService service;

  const _WeekGrid({
    required this.weekStart,
    required this.meals,
    required this.onRefresh,
    required this.service,
  });

  static const _slots = ['breakfast', 'lunch', 'dinner'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Map<String, dynamic>? _findMeal(String dateStr, String slot) {
    try {
      return meals.firstWhere(
        (m) => m['plan_date'] == dateStr && m['meal_slot'] == slot,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
      itemCount: _slots.length,
      itemBuilder: (ctx, slotIdx) {
        final slot = _slots[slotIdx];
        final slotIcon = slotIdx == 0 ? Icons.wb_sunny_outlined
            : slotIdx == 1 ? Icons.lunch_dining_outlined
            : Icons.dinner_dining_outlined;
        final slotColor = slotIdx == 0 ? AppTheme.secondary
            : slotIdx == 1 ? AppTheme.info
            : AppTheme.primary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(slotIcon, size: 16, color: slotColor),
                  const SizedBox(width: 6),
                  Text(
                    slot[0].toUpperCase() + slot.substring(1),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: slotColor),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 7,
                itemBuilder: (ctx, dayIdx) {
                  final day = weekStart.add(Duration(days: dayIdx));
                  final dateStr = day.toIso8601String().split('T').first;
                  final meal = _findMeal(dateStr, slot);
                  final isToday = DateTime.now().toIso8601String().split('T').first == dateStr;

                  return _MealCell(
                    dayLabel: _days[dayIdx],
                    dateLabel: '${day.day}',
                    meal: meal,
                    isToday: isToday,
                    onTap: () => _showAddMealDialog(context, day, slot, meal),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddMealDialog(
    BuildContext context,
    DateTime date,
    String slot,
    Map<String, dynamic>? existing,
  ) {
    final ctrl = TextEditingController(text: existing?['custom_meal_name'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('EEE, MMM d').format(date)} — ${slot[0].toUpperCase()}${slot.substring(1)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'e.g. Pasta Primavera, Overnight Oats...',
                prefixIcon: Icon(Icons.restaurant_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await service.deleteMeal(existing['id']);
                        Navigator.pop(ctx);
                        onRefresh();
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (ctrl.text.trim().isEmpty) return;
                      await service.upsertMeal(
                        date: date, slot: slot,
                        customMealName: ctrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      onRefresh();
                    },
                    child: Text(existing != null ? 'Update' : 'Add Meal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meal Cell ─────────────────────────────────────────────────────────────────
class _MealCell extends StatelessWidget {
  final String dayLabel, dateLabel;
  final Map<String, dynamic>? meal;
  final bool isToday;
  final VoidCallback onTap;

  const _MealCell({
    required this.dayLabel, required this.dateLabel,
    this.meal, required this.isToday, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMeal = meal != null;
    final mealName = meal?['custom_meal_name'] as String?
        ?? meal?['recipes']?['title'] as String?
        ?? '';
    final isCompleted = meal?['is_completed'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isToday
              ? AppTheme.primary.withOpacity(0.12)
              : hasMeal
                  ? (isDark ? const Color(0xFF252525) : const Color(0xFFF8F8F8))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? AppTheme.primary.withOpacity(0.5)
                : hasMeal
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFE5E7EB).withOpacity(0.5),
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday ? AppTheme.primary : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (hasMeal)
              Text(
                mealName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? AppTheme.textTertiary : null,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              const Icon(Icons.add_rounded, size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
