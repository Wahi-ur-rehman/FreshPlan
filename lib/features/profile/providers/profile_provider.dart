// lib/features/profile/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/models.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  Future<UserProfile?> fetchProfile() async {
    try {
      final data = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();
      return data != null ? UserProfile.fromJson(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final data = await _supabase
        .from('user_profiles')
        .update(profile.toUpdateJson())
        .eq('id', _userId)
        .select()
        .single();
    return UserProfile.fromJson(data);
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  return ref.read(profileServiceProvider).fetchProfile();
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final ProfileService _service;
  final Ref _ref;

  ProfileNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _service.fetchProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    int? householdSize,
    List<String>? dietaryPrefs,
    List<String>? allergens,
  }) async {
    final current = state.value;
    if (current == null) return false;

    final updated = UserProfile(
      id: current.id,
      displayName: displayName ?? current.displayName,
      avatarUrl: current.avatarUrl,
      householdSize: householdSize ?? current.householdSize,
      dietaryPrefs: dietaryPrefs ?? current.dietaryPrefs,
      allergens: allergens ?? current.allergens,
      sustainabilityScore: current.sustainabilityScore,
      totalWasteSavedG: current.totalWasteSavedG,
      createdAt: current.createdAt,
    );

    try {
      final saved = await _service.updateProfile(updated);
      state = AsyncValue.data(saved);
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() => _load();
}

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return ProfileNotifier(ref.read(profileServiceProvider), ref);
});
