// lib/features/pantry/widgets/add_item_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../../models/models.dart';
import '../providers/pantry_provider.dart';

class AddItemBottomSheet extends ConsumerStatefulWidget {
  final PantryItem? existingItem;
  const AddItemBottomSheet({super.key, this.existingItem});

  @override
  ConsumerState<AddItemBottomSheet> createState() => _AddItemBottomSheetState();
}

class _AddItemBottomSheetState extends ConsumerState<AddItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _notesCtrl;

  String _category = 'other';
  String _storageLocation = 'pantry';
  String _unit = 'pcs';
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _isStaple = false;

  bool get _isEditing => widget.existingItem != null;

  static const _categories = [
    ('produce', Icons.eco_outlined, 'Produce'),
    ('dairy', Icons.water_drop_outlined, 'Dairy'),
    ('meat', Icons.set_meal_outlined, 'Meat'),
    ('seafood', Icons.set_meal_outlined, 'Seafood'),
    ('grains', Icons.grain_outlined, 'Grains'),
    ('canned', Icons.inventory_2_outlined, 'Canned'),
    ('frozen', Icons.ac_unit_outlined, 'Frozen'),
    ('beverages', Icons.local_drink_outlined, 'Beverages'),
    ('condiments', Icons.restaurant_outlined, 'Condiments'),
    ('snacks', Icons.cookie_outlined, 'Snacks'),
    ('bakery', Icons.bakery_dining_outlined, 'Bakery'),
    ('herbs_spices', Icons.spa_outlined, 'Herbs'),
    ('other', Icons.kitchen_outlined, 'Other'),
  ];

  static const _locations = ['fridge', 'freezer', 'pantry', 'counter'];
  static const _units = ['pcs', 'kg', 'g', 'lb', 'oz', 'L', 'ml', 'cup', 'tbsp', 'tsp', 'pack', 'can', 'bottle', 'box'];

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _quantityCtrl = TextEditingController(
      text: item != null ? (item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString()) : '1',
    );
    _brandCtrl = TextEditingController(text: item?.brand ?? '');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    if (item != null) {
      _category = item.category;
      _storageLocation = item.storageLocation;
      _unit = item.unit;
      _expiryDate = item.expiryDate;
      _purchaseDate = item.purchaseDate;
      _isStaple = item.isStaple;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _brandCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final qty = InputSanitizer.parseQuantity(_quantityCtrl.text);
    if (qty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: AppTheme.error),
      );
      return;
    }

    bool success;
    final notifier = ref.read(pantryNotifierProvider.notifier);

    if (_isEditing) {
      success = await notifier.updateItem(widget.existingItem!.id, {
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'storage_location': _storageLocation,
        'quantity': qty,
        'unit': _unit,
        'expiry_date': _expiryDate?.toIso8601String().split('T').first,
        'purchase_date': _purchaseDate?.toIso8601String().split('T').first,
        'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'is_staple': _isStaple,
      });
    } else {
      success = await notifier.addItem(
        name: _nameCtrl.text.trim(),
        category: _category,
        storageLocation: _storageLocation,
        quantity: qty,
        unit: _unit,
        expiryDate: _expiryDate,
        purchaseDate: _purchaseDate,
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isStaple: _isStaple,
      );
    }

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Item updated!' : 'Item added to pantry!'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save item. Please try again.'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickDate(bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry
          ? (_expiryDate ?? now.add(const Duration(days: 7)))
          : (_purchaseDate ?? now),
      firstDate: isExpiry ? now.subtract(const Duration(days: 1)) : now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) _expiryDate = picked;
        else _purchaseDate = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Set date';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifierState = ref.watch(pantryNotifierProvider);
    final isLoading = notifierState is AsyncLoading;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _isEditing ? 'Edit Item' : 'Add Pantry Item',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),

              // ── Name ─────────────────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length > 200) return 'Name too long';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Quantity + Unit ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final qty = InputSanitizer.parseQuantity(v);
                        if (qty == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Category ──────────────────────────────────────────────────
              Text('Category', style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((cat) {
                    final isSelected = _category == cat.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.$2, color: isSelected ? Colors.white : AppTheme.primary, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              cat.$3,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? Colors.white : AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ── Storage Location ──────────────────────────────────────────
              Text('Storage Location', style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: _locations.map((loc) {
                  final isSelected = _storageLocation == loc;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _storageLocation = loc),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: loc == _locations.last ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          loc[0].toUpperCase() + loc.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Dates ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'Expiry Date',
                      icon: Icons.event_available_outlined,
                      value: _formatDate(_expiryDate),
                      color: _expiryDate != null
                          ? (_expiryDate!.isBefore(DateTime.now().add(const Duration(days: 3)))
                              ? AppTheme.warning
                              : AppTheme.success)
                          : AppTheme.textTertiary,
                      onTap: () => _pickDate(true),
                      onClear: _expiryDate != null ? () => setState(() => _expiryDate = null) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateButton(
                      label: 'Purchase Date',
                      icon: Icons.shopping_cart_outlined,
                      value: _formatDate(_purchaseDate),
                      color: AppTheme.textTertiary,
                      onTap: () => _pickDate(false),
                      onClear: _purchaseDate != null ? () => setState(() => _purchaseDate = null) : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Brand ─────────────────────────────────────────────────────
              TextFormField(
                controller: _brandCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Brand (optional)',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),

              const SizedBox(height: 16),

              // ── Notes ─────────────────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // ── Staple Toggle ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: _isStaple ? AppTheme.primary.withOpacity(0.07) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: SwitchListTile(
                  value: _isStaple,
                  onChanged: (v) => setState(() => _isStaple = v),
                  title: const Text('Mark as Staple Item'),
                  subtitle: const Text('Always keep this stocked'),
                  activeColor: AppTheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),

              const SizedBox(height: 28),

              // ── Submit Button ─────────────────────────────────────────────
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Add to Pantry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateButton({
    required this.label, required this.value, required this.icon,
    required this.color, required this.onTap, this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textTertiary)),
                  Text(value, style: theme.textTheme.bodySmall?.copyWith(
                    color: value == 'Set date' ? AppTheme.textTertiary : color,
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}
