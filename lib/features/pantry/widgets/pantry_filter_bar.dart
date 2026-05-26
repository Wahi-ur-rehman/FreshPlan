// lib/features/pantry/widgets/pantry_filter_bar.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PantryFilterBar extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const PantryFilterBar({
    super.key,
    this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const _filters = [
    ('all', Icons.apps_rounded, 'All'),
    ('produce', Icons.eco_outlined, 'Produce'),
    ('dairy', Icons.water_drop_outlined, 'Dairy'),
    ('meat', Icons.set_meal_outlined, 'Meat'),
    ('grains', Icons.grain_outlined, 'Grains'),
    ('canned', Icons.inventory_2_outlined, 'Canned'),
    ('frozen', Icons.ac_unit_outlined, 'Frozen'),
    ('snacks', Icons.cookie_outlined, 'Snacks'),
    ('beverages', Icons.local_drink_outlined, 'Drinks'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final isSelected = f.$1 == 'all'
              ? selectedCategory == null
              : selectedCategory == f.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (_) => onCategoryChanged(f.$1),
              avatar: Icon(f.$2, size: 14),
              label: Text(f.$3),
              backgroundColor: Colors.transparent,
              selectedColor: AppTheme.primary.withOpacity(0.15),
              checkmarkColor: AppTheme.primary,
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.primary.withOpacity(0.2),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }
}
