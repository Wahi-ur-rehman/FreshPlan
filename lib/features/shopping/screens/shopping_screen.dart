// lib/features/shopping/screens/shopping_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../core/security/input_sanitizer.dart';

// ── Service ───────────────────────────────────────────────────────────────────
class ShoppingService {
  final _supabase = Supabase.instance.client;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  Future<List<ShoppingItem>> fetchItems() async {
    // Get or create active list
    final lists = await _supabase
        .from('shopping_lists')
        .select()
        .eq('user_id', _userId)
        .eq('is_active', true)
        .limit(1);

    if ((lists as List).isEmpty) {
      await _supabase.from('shopping_lists').insert({
        'user_id': _userId,
        'name': 'My Shopping List',
        'is_active': true,
      });
      return [];
    }

    final listId = lists[0]['id'] as String;
    final items = await _supabase
        .from('shopping_items')
        .select()
        .eq('list_id', listId)
        .eq('user_id', _userId)
        .order('sort_order');

    return (items as List).map((e) => ShoppingItem.fromJson(e)).toList();
  }

  Future<String> _getOrCreateListId() async {
    final lists = await _supabase
        .from('shopping_lists')
        .select()
        .eq('user_id', _userId)
        .eq('is_active', true)
        .limit(1);

    if ((lists as List).isNotEmpty) return lists[0]['id'] as String;

    final newList = await _supabase.from('shopping_lists').insert({
      'user_id': _userId,
      'name': 'My Shopping List',
      'is_active': true,
    }).select().single();
    return newList['id'] as String;
  }

  Future<ShoppingItem> addItem(String name, double quantity, String unit) async {
    final listId = await _getOrCreateListId();
    final sanitized = InputSanitizer.sanitizeText(name, maxLength: 200);
    if (sanitized.isEmpty) throw Exception('Item name cannot be empty');

    final data = await _supabase.from('shopping_items').insert({
      'list_id': listId,
      'user_id': _userId,
      'name': sanitized,
      'quantity': quantity,
      'unit': unit,
      'status': 'pending',
      'sort_order': DateTime.now().millisecondsSinceEpoch,
    }).select().single();

    return ShoppingItem.fromJson(data);
  }

  Future<void> updateStatus(String itemId, String status) async {
    await _supabase
        .from('shopping_items')
        .update({'status': status})
        .eq('id', itemId)
        .eq('user_id', _userId);
  }

  Future<void> deleteItem(String itemId) async {
    await _supabase
        .from('shopping_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', _userId);
  }

  Future<void> clearPurchased() async {
    await _supabase
        .from('shopping_items')
        .delete()
        .eq('user_id', _userId)
        .eq('status', 'purchased');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final shoppingServiceProvider = Provider<ShoppingService>((ref) => ShoppingService());

final shoppingItemsProvider = FutureProvider.autoDispose<List<ShoppingItem>>((ref) async {
  return ref.read(shoppingServiceProvider).fetchItems();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _unit = 'pcs';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    try {
      await ref.read(shoppingServiceProvider).addItem(name, qty, _unit);
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      ref.invalidate(shoppingItemsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _toggleItem(ShoppingItem item) async {
    final newStatus = item.isPurchased ? 'pending' : 'purchased';
    await ref.read(shoppingServiceProvider).updateStatus(item.id, newStatus);
    ref.invalidate(shoppingItemsProvider);
  }

  Future<void> _deleteItem(String id) async {
    await ref.read(shoppingServiceProvider).deleteItem(id);
    ref.invalidate(shoppingItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(shoppingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          itemsAsync.when(
            data: (items) => items.any((i) => i.isPurchased)
                ? TextButton.icon(
                    onPressed: () async {
                      await ref.read(shoppingServiceProvider).clearPurchased();
                      ref.invalidate(shoppingItemsProvider);
                    },
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('Clear Done'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Add Item Row ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    onSubmitted: (_) => _addItem(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add item...',
                      prefixIcon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                    ),
                    items: ['pcs', 'kg', 'g', 'L', 'ml', 'pack', 'can']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // ── Items List ────────────────────────────────────────────────────
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Your list is empty', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Add items above to start your shopping list.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final pending = items.where((i) => !i.isPurchased).toList();
                final purchased = items.where((i) => i.isPurchased).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    if (pending.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'To Buy (${pending.length})',
                          style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                      ...pending.map((item) => _ShoppingItemTile(
                        item: item,
                        onToggle: () => _toggleItem(item),
                        onDelete: () => _deleteItem(item.id),
                      )),
                    ],
                    if (purchased.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Purchased (${purchased.length})',
                          style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textTertiary),
                        ),
                      ),
                      ...purchased.map((item) => _ShoppingItemTile(
                        item: item,
                        onToggle: () => _toggleItem(item),
                        onDelete: () => _deleteItem(item.id),
                      )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load list'),
                    TextButton(
                      onPressed: () => ref.invalidate(shoppingItemsProvider),
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

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle, onDelete;
  const _ShoppingItemTile({required this.item, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Slidable(
      key: Key(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Remove',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: item.isPurchased
                ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8))
                : (Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: item.isPurchased ? AppTheme.success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isPurchased ? AppTheme.success : AppTheme.textTertiary,
                    width: 2,
                  ),
                ),
                child: item.isPurchased
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                    color: item.isPurchased ? AppTheme.textTertiary : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.isPurchased ? AppTheme.textTertiary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
