// lib/features/pantry/services/pantry_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/models.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../../core/security/rate_limiter.dart';

class PantryService {
  final _supabase = Supabase.instance.client;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  // ── Fetch All Items ───────────────────────────────────────────────────────
  Future<List<PantryItem>> fetchItems({
    String? category,
    String? storageLocation,
    String? searchQuery,
    bool sortByExpiry = true,
  }) async {
    if (!AppRateLimiters.pantryOperations.tryAcquire()) {
      throw Exception('Too many requests. Please slow down.');
    }

    var query = _supabase
        .from('pantry_items')
        .select()
        .eq('user_id', _userId);

    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    if (storageLocation != null && storageLocation != 'all') {
      query = query.eq('storage_location', storageLocation);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final sanitized = InputSanitizer.sanitizeSearch(searchQuery);
      query = query.ilike('name', '%$sanitized%');
    }

    final data = await query.order(
      sortByExpiry ? 'expiry_date' : 'created_at',
      ascending: sortByExpiry,
      nullsFirst: false,
    );

    return (data as List).map((e) => PantryItem.fromJson(e)).toList();
  }

  // ── Fetch Expiring Items ───────────────────────────────────────────────────
  Future<List<PantryItem>> fetchExpiringItems({int days = 3}) async {
    final data = await _supabase.rpc('get_expiring_items', params: {
      'p_user_id': _userId,
      'p_days': days,
    });
    return (data as List).map((e) => PantryItem.fromJson(e)).toList();
  }

  // ── Add Item ───────────────────────────────────────────────────────────────
  Future<PantryItem> addItem({
    required String name,
    required String category,
    required String storageLocation,
    required double quantity,
    required String unit,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? brand,
    String? notes,
    String? barcode,
    bool isStaple = false,
  }) async {
    if (!AppRateLimiters.pantryOperations.tryAcquire()) {
      throw Exception('Too many requests. Please slow down.');
    }

    // Sanitize all text inputs
    final sanitizedName = InputSanitizer.sanitizeText(name, maxLength: 200);
    if (sanitizedName.isEmpty) throw Exception('Item name cannot be empty.');

    final sanitizedBrand = brand != null ? InputSanitizer.sanitizeText(brand, maxLength: 200) : null;
    final sanitizedNotes = notes != null ? InputSanitizer.sanitizeText(notes, maxLength: 1000) : null;
    final sanitizedUnit = InputSanitizer.sanitizeText(unit, maxLength: 50);

    if (quantity <= 0) throw Exception('Quantity must be greater than 0.');

    final insertData = {
      'user_id': _userId,
      'name': sanitizedName,
      'category': category,
      'storage_location': storageLocation,
      'quantity': quantity,
      'unit': sanitizedUnit,
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      'purchase_date': purchaseDate?.toIso8601String().split('T').first,
      'brand': sanitizedBrand,
      'notes': sanitizedNotes,
      'barcode': barcode,
      'is_staple': isStaple,
    };

    final response = await _supabase
        .from('pantry_items')
        .insert(insertData)
        .select()
        .single();

    return PantryItem.fromJson(response);
  }

  // ── Update Item ────────────────────────────────────────────────────────────
  Future<PantryItem> updateItem(String id, Map<String, dynamic> updates) async {
    if (!AppRateLimiters.pantryOperations.tryAcquire()) {
      throw Exception('Too many requests. Please slow down.');
    }

    // Sanitize text fields if present
    if (updates['name'] != null) {
      updates['name'] = InputSanitizer.sanitizeText(updates['name'], maxLength: 200);
    }
    if (updates['notes'] != null) {
      updates['notes'] = InputSanitizer.sanitizeText(updates['notes'], maxLength: 1000);
    }

    final response = await _supabase
        .from('pantry_items')
        .update(updates)
        .eq('id', id)
        .eq('user_id', _userId)   // Extra safety: user can only update their own
        .select()
        .single();

    return PantryItem.fromJson(response);
  }

  // ── Delete Item ────────────────────────────────────────────────────────────
  Future<void> deleteItem(String id) async {
    await _supabase
        .from('pantry_items')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);  // RLS handles this, but belt+suspenders
  }

  // ── Decrement Quantity ─────────────────────────────────────────────────────
  Future<PantryItem> decrementQuantity(String id, double amount) async {
    final item = await _supabase
        .from('pantry_items')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .single();

    final currentQty = (item['quantity'] as num).toDouble();
    final newQty = (currentQty - amount).clamp(0.0, double.infinity);

    return updateItem(id, {'quantity': newQty});
  }

  // ── Log Waste ─────────────────────────────────────────────────────────────
  Future<void> logWaste({
    required String itemName,
    required int quantityWastedG,
    String? reason,
    String? pantryItemId,
  }) async {
    await _supabase.from('waste_logs').insert({
      'user_id': _userId,
      'pantry_item_id': pantryItemId,
      'item_name': InputSanitizer.sanitizeText(itemName, maxLength: 200),
      'quantity_wasted_g': quantityWastedG.clamp(0, 100000),
      'reason': reason,
    });
  }

  // ── Realtime Stream ────────────────────────────────────────────────────────
  Stream<List<PantryItem>> watchItems() {
    return _supabase
        .from('pantry_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('expiry_date', ascending: true)
        .map((data) => data.map((e) => PantryItem.fromJson(e)).toList());
  }
}
