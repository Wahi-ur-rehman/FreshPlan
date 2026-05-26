// lib/features/pantry/providers/pantry_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../services/pantry_service.dart';

final pantryServiceProvider = Provider<PantryService>((ref) => PantryService());

// ── Filter State ─────────────────────────────────────────────────────────────
class PantryFilter {
  final String? category;
  final String? storageLocation;
  final String? searchQuery;
  final bool sortByExpiry;

  const PantryFilter({
    this.category,
    this.storageLocation,
    this.searchQuery,
    this.sortByExpiry = true,
  });

  PantryFilter copyWith({
    String? category,
    String? storageLocation,
    String? searchQuery,
    bool? sortByExpiry,
    bool clearCategory = false,
    bool clearSearch = false,
  }) => PantryFilter(
    category: clearCategory ? null : category ?? this.category,
    storageLocation: storageLocation ?? this.storageLocation,
    searchQuery: clearSearch ? null : searchQuery ?? this.searchQuery,
    sortByExpiry: sortByExpiry ?? this.sortByExpiry,
  );
}

final pantryFilterProvider = StateProvider<PantryFilter>((ref) => const PantryFilter());

// ── Pantry Items Provider ─────────────────────────────────────────────────────
final pantryItemsProvider = FutureProvider.autoDispose<List<PantryItem>>((ref) async {
  final service = ref.read(pantryServiceProvider);
  final filter = ref.watch(pantryFilterProvider);
  return service.fetchItems(
    category: filter.category,
    storageLocation: filter.storageLocation,
    searchQuery: filter.searchQuery,
    sortByExpiry: filter.sortByExpiry,
  );
});

// ── Expiring Items Provider ───────────────────────────────────────────────────
final expiringItemsProvider = FutureProvider.autoDispose<List<PantryItem>>((ref) async {
  final service = ref.read(pantryServiceProvider);
  return service.fetchExpiringItems(days: 3);
});

// ── Pantry Stats Provider ─────────────────────────────────────────────────────
final pantryStatsProvider = FutureProvider.autoDispose<PantryStats>((ref) async {
  final items = await ref.watch(pantryItemsProvider.future);
  return PantryStats.fromItems(items);
});

class PantryStats {
  final int totalItems;
  final int expiringCount;
  final int expiredCount;
  final Map<String, int> byCategory;
  final Map<String, int> byLocation;

  const PantryStats({
    required this.totalItems,
    required this.expiringCount,
    required this.expiredCount,
    required this.byCategory,
    required this.byLocation,
  });

  factory PantryStats.fromItems(List<PantryItem> items) {
    int expiring = 0, expired = 0;
    final byCategory = <String, int>{};
    final byLocation = <String, int>{};

    for (final item in items) {
      switch (item.expiryStatus) {
        case ExpiryStatus.expiringSoon: expiring++; break;
        case ExpiryStatus.expired: expired++; break;
        default: break;
      }
      byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
      byLocation[item.storageLocation] = (byLocation[item.storageLocation] ?? 0) + 1;
    }

    return PantryStats(
      totalItems: items.length,
      expiringCount: expiring,
      expiredCount: expired,
      byCategory: byCategory,
      byLocation: byLocation,
    );
  }
}

// ── Pantry Notifier (CRUD) ────────────────────────────────────────────────────
class PantryNotifier extends StateNotifier<AsyncValue<void>> {
  final PantryService _service;
  final Ref _ref;

  PantryNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addItem({
    required String name,
    required String category,
    required String storageLocation,
    required double quantity,
    required String unit,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? brand,
    String? notes,
    bool isStaple = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.addItem(
        name: name, category: category, storageLocation: storageLocation,
        quantity: quantity, unit: unit, expiryDate: expiryDate,
        purchaseDate: purchaseDate, brand: brand, notes: notes, isStaple: isStaple,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(pantryItemsProvider);
      _ref.invalidate(expiringItemsProvider);
      _ref.invalidate(pantryStatsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateItem(id, updates);
      state = const AsyncValue.data(null);
      _ref.invalidate(pantryItemsProvider);
      _ref.invalidate(expiringItemsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _service.deleteItem(id);
      _ref.invalidate(pantryItemsProvider);
      _ref.invalidate(expiringItemsProvider);
      _ref.invalidate(pantryStatsProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logWaste({
    required String itemName,
    required int quantityG,
    String? reason,
    String? pantryItemId,
  }) async {
    await _service.logWaste(
      itemName: itemName,
      quantityWastedG: quantityG,
      reason: reason,
      pantryItemId: pantryItemId,
    );
  }
}

final pantryNotifierProvider = StateNotifierProvider<PantryNotifier, AsyncValue<void>>((ref) {
  return PantryNotifier(ref.read(pantryServiceProvider), ref);
});
