// lib/core/config/app_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// App-wide configuration loaded from --dart-define at build time.
// NEVER hardcode secrets here. Use:
//   flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=yyy
// Or via CI/CD environment variables in your build pipeline.
// ─────────────────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._();

  // ── Supabase ──────────────────────────────────────────────────────────────
  // These are safe to expose (anon key is public, RLS protects data)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co', // Replace before release
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY', // Replace before release
  );

  // ── Edge Function Endpoint ────────────────────────────────────────────────
  static const String geminiProxyEndpoint = '$supabaseUrl/functions/v1/gemini_proxy';

  // ── App Identity ──────────────────────────────────────────────────────────
  static const String appName = 'FreshPlan';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@freshplan.app';

  // ── Security Settings ─────────────────────────────────────────────────────
  static const int sessionTimeoutMinutes = 30;
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;
  static const int tokenRefreshThresholdMinutes = 5;

  // ── Rate Limiting (client-side) ───────────────────────────────────────────
  static const int aiRequestsPerHour = 20;
  static const int searchDebounceMs = 500;

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── Notifications ─────────────────────────────────────────────────────────
  static const int expiryWarningDays = 3;

  // ── Feature Flags ─────────────────────────────────────────────────────────
  static const bool enableBiometrics = true;
  static const bool enableAnalytics = true;
  static const bool enableOfflineMode = true;
}
