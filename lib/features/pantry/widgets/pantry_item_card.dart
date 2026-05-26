// lib/features/pantry/widgets/pantry_item_card.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onTap;

  const PantryItemCard({super.key, required this.item, this.onTap});

  Color get _statusColor {
    switch (item.expiryStatus) {
      case ExpiryStatus.expired: return AppTheme.expiredRed;
      case ExpiryStatus.expiringSoon: return AppTheme.expiringSoonOrange;
      case ExpiryStatus.fresh: return AppTheme.freshGreen;
    }
  }

  String get _expiryText {
    if (item.expiryDate == null) return 'No expiry';
    final days = item.daysUntilExpiry;
    if (days < 0) return 'Expired ${(-days)} day${(-days) == 1 ? '' : 's'} ago';
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow';
    if (days <= 7) return 'Expires in $days days';
    final d = item.expiryDate!;
    return '${d.day}/${d.month}/${d.year}';
  }

  IconData get _categoryIcon {
    switch (item.category) {
      case 'produce': return Icons.eco_outlined;
      case 'dairy': return Icons.water_drop_outlined;
      case 'meat': return Icons.set_meal_outlined;
      case 'seafood': return Icons.set_meal_outlined;
      case 'grains': return Icons.grain_outlined;
      case 'canned': return Icons.inventory_2_outlined;
      case 'frozen': return Icons.ac_unit_outlined;
      case 'beverages': return Icons.local_drink_outlined;
      case 'condiments': return Icons.restaurant_outlined;
      case 'snacks': return Icons.cookie_outlined;
      case 'bakery': return Icons.bakery_dining_outlined;
      case 'herbs_spices': return Icons.spa_outlined;
      default: return Icons.kitchen_outlined;
    }
  }

  IconData get _locationIcon {
    switch (item.storageLocation) {
      case 'fridge': return Icons.kitchen_outlined;
      case 'freezer': return Icons.ac_unit_outlined;
      case 'pantry': return Icons.shelves;
      case 'counter': return Icons.countertops_outlined;
      default: return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.expiryStatus == ExpiryStatus.fresh
                ? (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB))
                : _statusColor.withOpacity(0.3),
            width: item.expiryStatus == ExpiryStatus.fresh ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Expiry Status Indicator ─────────────────────────────────────
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),

            // ── Category Icon ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(12),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon, color: _statusColor, size: 22),
            ),

            // ── Name + Details ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isStaple)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Staple',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.primary, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(_locationIcon, size: 12, color: AppTheme.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          item.storageLocation,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: AppTheme.textTertiary)),
                        const SizedBox(width: 8),
                        Text(
                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Expiry Badge ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _expiryText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
