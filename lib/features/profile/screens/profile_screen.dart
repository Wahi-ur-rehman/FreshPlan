// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: profileAsync.when(
        data: (profile) => _ProfileContent(profile: profile, user: authState.user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text('Failed to load profile'),
              TextButton(
                onPressed: () => ref.read(profileNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final UserProfile? profile;
  final dynamic user;
  const _ProfileContent({this.profile, this.user});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  final _nameCtrl = TextEditingController();
  bool _isEditing = false;
  int _householdSize = 2;
  List<String> _dietaryPrefs = [];
  List<String> _allergens = [];

  static const _dietaryOptions = [
    'Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free',
    'Keto', 'Paleo', 'Halal', 'Kosher', 'Low-Sodium', 'Nut-Free',
  ];

  static const _allergenOptions = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat',
    'Soy', 'Fish', 'Shellfish', 'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameCtrl.text = profile?.displayName ?? '';
    _householdSize = profile?.householdSize ?? 2;
    _dietaryPrefs = List.from(profile?.dietaryPrefs ?? []);
    _allergens = List.from(profile?.allergens ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
      displayName: _nameCtrl.text.trim(),
      householdSize: _householdSize,
      dietaryPrefs: _dietaryPrefs,
      allergens: _allergens,
    );
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated!' : 'Failed to update'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again to access your pantry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and ALL your data (pantry, recipes, shopping lists). This CANNOT be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.user?.email ?? 'Unknown';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Avatar + Name ──────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primary,
                child: Text(
                  (widget.profile?.displayName ?? email).isNotEmpty
                      ? (widget.profile?.displayName ?? email)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.profile?.displayName ?? 'User',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${widget.profile?.sustainabilityScore ?? 0}',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Edit Profile Section ───────────────────────────────────────────
        _SectionHeader(
          title: 'Personal Information',
          trailing: TextButton(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            child: Text(_isEditing ? 'Cancel' : 'Edit'),
          ),
        ),

        if (_isEditing) ...[
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Household Size:', style: theme.textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _householdSize > 1 ? () => setState(() => _householdSize--) : null,
                color: AppTheme.primary,
              ),
              Text('$_householdSize', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _householdSize < 20 ? () => setState(() => _householdSize++) : null,
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Dietary Preferences', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _dietaryOptions.map((pref) => FilterChip(
              label: Text(pref, style: const TextStyle(fontSize: 12)),
              selected: _dietaryPrefs.contains(pref),
              onSelected: (v) => setState(() {
                if (v) _dietaryPrefs.add(pref); else _dietaryPrefs.remove(pref);
              }),
              selectedColor: AppTheme.primary.withOpacity(0.15),
              checkmarkColor: AppTheme.primary,
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text('Allergens to Avoid', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allergenOptions.map((allergen) => FilterChip(
              label: Text(allergen, style: const TextStyle(fontSize: 12)),
              selected: _allergens.contains(allergen),
              onSelected: (v) => setState(() {
                if (v) _allergens.add(allergen); else _allergens.remove(allergen);
              }),
              selectedColor: AppTheme.error.withOpacity(0.15),
              checkmarkColor: AppTheme.error,
            )).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saveProfile, child: const Text('Save Changes')),
        ] else ...[
          _InfoRow(label: 'Household Size', value: '${widget.profile?.householdSize ?? 2} people'),
          if ((widget.profile?.dietaryPrefs ?? []).isNotEmpty)
            _InfoRow(label: 'Dietary Prefs', value: (widget.profile?.dietaryPrefs ?? []).join(', ')),
          if ((widget.profile?.allergens ?? []).isNotEmpty)
            _InfoRow(label: 'Allergens', value: (widget.profile?.allergens ?? []).join(', ')),
        ],

        const SizedBox(height: 24),
        const _SectionHeader(title: 'Security'),

        _SettingsTile(
          icon: Icons.lock_reset_outlined,
          title: 'Change Password',
          onTap: () => context.push('/change-password'),
        ),
        _SettingsTile(
          icon: Icons.fingerprint_outlined,
          title: 'Biometric Login',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.devices_outlined,
          title: 'Active Sessions',
          subtitle: 'View devices signed in to your account',
          onTap: () {},
        ),

        const SizedBox(height: 24),
        const _SectionHeader(title: 'App'),

        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.color_lens_outlined,
          title: 'Appearance',
          subtitle: 'Theme & display settings',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () {},
        ),

        const SizedBox(height: 24),
        const _SectionHeader(title: 'Account'),

        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          titleColor: AppTheme.error,
          onTap: _confirmSignOut,
        ),
        _SettingsTile(
          icon: Icons.delete_forever_outlined,
          title: 'Delete Account',
          subtitle: 'Permanently delete all your data',
          titleColor: AppTheme.error,
          onTap: _confirmDeleteAccount,
        ),

        const SizedBox(height: 40),
        Center(
          child: Text(
            'FreshPlan v1.0.0\nData secured with Supabase RLS',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon, required this.title, required this.onTap,
    this.subtitle, this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (titleColor ?? AppTheme.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: titleColor ?? AppTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
