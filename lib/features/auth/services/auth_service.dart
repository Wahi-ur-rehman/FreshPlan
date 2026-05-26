// lib/features/auth/services/auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Authentication service: email/password + Google Sign-In via Supabase Auth.
// Includes lockout, brute-force protection, and secure session management.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../../core/security/session_manager.dart';

class AuthException implements Exception {
  final String message;
  final String? code;
  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthService {
  final _supabase = Supabase.instance.client;

  // ── Sign Up ───────────────────────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Validate inputs
    final normalizedEmail = InputSanitizer.normalizeEmail(email);
    if (normalizedEmail == null) {
      throw const AuthException('Please enter a valid email address.');
    }

    final strength = InputSanitizer.checkPasswordStrength(password);
    if (strength == PasswordStrength.weak) {
      throw const AuthException(
        'Password is too weak. Use at least 8 characters with uppercase, numbers, and symbols.',
      );
    }

    final sanitizedName = InputSanitizer.sanitizeDisplayName(displayName);
    if (sanitizedName.trim().isEmpty) {
      throw const AuthException('Please enter a valid display name.');
    }

    try {
      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': sanitizedName},
      );

      if (response.user == null) {
        throw const AuthException('Sign up failed. Please try again.');
      }

      await SecureStorage.instance.resetLoginAttempts();
      return response;
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } catch (e) {
      throw AuthException('Sign up failed: ${e.toString()}');
    }
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    // Check lockout
    final lockoutUntil = await SecureStorage.instance.getLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      final remaining = lockoutUntil.difference(DateTime.now()).inMinutes + 1;
      throw AuthException(
        'Account temporarily locked. Try again in $remaining minute(s).',
        code: 'locked',
      );
    }

    final normalizedEmail = InputSanitizer.normalizeEmail(email);
    if (normalizedEmail == null) {
      throw const AuthException('Please enter a valid email address.');
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      if (response.session == null) {
        await _handleFailedAttempt();
        throw const AuthException('Invalid email or password.');
      }

      // Success — reset attempts and save session
      await SecureStorage.instance.resetLoginAttempts();
      await SecureStorage.instance.saveSession(
        accessToken: response.session!.accessToken,
        refreshToken: response.session!.refreshToken ?? '',
        userId: response.user!.id,
      );
      SessionManager.instance.recordActivity();

      return response;
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      if (e.statusCode == '400' || e.statusCode == '422') {
        await _handleFailedAttempt();
        throw const AuthException('Invalid email or password.');
      }
      throw AuthException(_mapSupabaseError(e.message));
    } catch (e) {
      throw AuthException('Sign in failed. Please check your connection.');
    }
  }

  Future<void> _handleFailedAttempt() async {
    await SecureStorage.instance.incrementLoginAttempts();
    final attempts = await SecureStorage.instance.getLoginAttempts();
    if (attempts >= AppConfig.maxLoginAttempts) {
      final lockUntil = DateTime.now().add(
        Duration(minutes: AppConfig.lockoutDurationMinutes),
      );
      await SecureStorage.instance.setLockout(lockUntil);
      await SecureStorage.instance.resetLoginAttempts();
      throw AuthException(
        'Too many failed attempts. Account locked for ${AppConfig.lockoutDurationMinutes} minutes.',
        code: 'locked',
      );
    }
    final remaining = AppConfig.maxLoginAttempts - attempts;
    throw AuthException(
      'Invalid email or password. $remaining attempt(s) remaining.',
    );
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = InputSanitizer.normalizeEmail(email);
    if (normalizedEmail == null) {
      throw const AuthException('Please enter a valid email address.');
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: 'freshplan://reset-password',
      );
    } catch (e) {
      // Don't reveal if email exists (security best practice)
      // Silently succeed
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await SessionManager.instance.signOut();
  }

  // ── Update Password ────────────────────────────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    final strength = InputSanitizer.checkPasswordStrength(newPassword);
    if (strength == PasswordStrength.weak) {
      throw const AuthException(
        'New password is too weak. Use at least 8 characters with uppercase, numbers, and symbols.',
      );
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw AuthException('Failed to update password: ${e.toString()}');
    }
  }

  // ── Delete Account ─────────────────────────────────────────────────────────
  // All user data is deleted via CASCADE in the database (RLS ensures only
  // the authenticated user can trigger this on their own account)
  Future<void> deleteAccount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated.');

    // Delete user data (Supabase RLS ensures only own data)
    await _supabase.from('pantry_items').delete().eq('user_id', userId);
    await _supabase.from('recipes').delete().eq('user_id', userId);
    await _supabase.from('meal_plans').delete().eq('user_id', userId);
    await _supabase.from('shopping_lists').delete().eq('user_id', userId);
    await _supabase.from('waste_logs').delete().eq('user_id', userId);

    await signOut();
    // Note: To delete the auth.users entry, call a server-side function
    // or use Supabase Admin API from your backend
  }

  // ── Current User ──────────────────────────────────────────────────────────
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _mapSupabaseError(String msg) {
    if (msg.contains('Email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many requests. Please wait a moment.';
    }
    return 'An error occurred. Please try again.';
  }
}
