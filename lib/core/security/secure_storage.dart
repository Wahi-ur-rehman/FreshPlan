// lib/core/security/secure_storage.dart
// ─────────────────────────────────────────────────────────────────────────────
// Secure key-value storage backed by:
//   iOS  → Keychain
//   Android → EncryptedSharedPreferences (via flutter_secure_storage)
// Never use SharedPreferences for sensitive data.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const kAccessToken = 'fp_access_token';
  static const kRefreshToken = 'fp_refresh_token';
  static const kUserId = 'fp_user_id';
  static const kBiometricEnabled = 'fp_biometric_enabled';
  static const kLoginAttempts = 'fp_login_attempts';
  static const kLockoutUntil = 'fp_lockout_until';
  static const kLastActivity = 'fp_last_activity';
  static const kDeviceId = 'fp_device_id';
  static const kPinHash = 'fp_pin_hash';

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();

  Future<Map<String, String>> readAll() => _storage.readAll();

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  // ── Convenience methods ───────────────────────────────────────────────────
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      write(kAccessToken, accessToken),
      write(kRefreshToken, refreshToken),
      write(kUserId, userId),
      write(kLastActivity, DateTime.now().toIso8601String()),
    ]);
  }

  Future<void> clearSession() async {
    await Future.wait([
      delete(kAccessToken),
      delete(kRefreshToken),
      delete(kUserId),
      delete(kLastActivity),
    ]);
  }

  Future<void> updateLastActivity() async {
    await write(kLastActivity, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastActivity() async {
    final raw = await read(kLastActivity);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<int> getLoginAttempts() async {
    final raw = await read(kLoginAttempts);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  Future<void> incrementLoginAttempts() async {
    final current = await getLoginAttempts();
    await write(kLoginAttempts, (current + 1).toString());
  }

  Future<void> resetLoginAttempts() async {
    await Future.wait([
      delete(kLoginAttempts),
      delete(kLockoutUntil),
    ]);
  }

  Future<DateTime?> getLockoutUntil() async {
    final raw = await read(kLockoutUntil);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLockout(DateTime until) async {
    await write(kLockoutUntil, until.toIso8601String());
  }
}
