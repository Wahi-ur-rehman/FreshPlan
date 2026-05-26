# FreshPlan — Flutter Production App

> AI-powered pantry management & meal planning with enterprise-grade security.

---

## Features

- **Pantry Management** — track items, quantities, expiry dates with category/location filters
- **AI Recipe Suggestions** — Gemini 1.5 Flash generates recipes from your pantry, prioritising items expiring soon
- **Weekly Meal Planner** — plan breakfast, lunch and dinner for any week
- **Smart Shopping List** — add items, tick them off, auto-clear purchased
- **Waste Analytics** — pie charts, bar charts, sustainability score, waste-by-reason tracking
- **Expiry Notifications** — local alerts 3 days before and day-of expiry
- **Per-user data isolation** — Supabase RLS ensures every query is scoped to the signed-in user
- **Offline banner** — graceful degradation when network is unavailable

---

## Security Architecture

### Supabase Row Level Security (RLS)
Every table has RLS enabled with policies that enforce:
```
auth.uid() = user_id
```
Even if a bug exposed a raw query, the DB rejects cross-user data access at the Postgres level.

### API Key Protection
| Secret | Location | Exposed? |
|---|---|---|
| Supabase URL | `AppConfig` (client) | ✅ Safe — public |
| Supabase Anon Key | `AppConfig` (client) | ✅ Safe — RLS enforced |
| Gemini API Key | Supabase Edge Function env var | ❌ Never in app |

### Rate Limiting (layered defence)
1. **Client-side** (`RateLimiter`) — prevents runaway loops
2. **Edge Function** — server checks via `check_rate_limit()` DB function
3. **Supabase built-in** — project-level request throttling

### Authentication Security
- PKCE auth flow (more secure than implicit)
- Brute-force lockout: 5 failed attempts → 15-minute lockout
- Inactivity timeout: auto-locks after 30 minutes
- Session stored in OS Keychain (iOS) / EncryptedSharedPreferences (Android)
- All passwords checked for strength before submission

### Input Sanitization
`InputSanitizer` validates/sanitizes all user input:
- HTML tag stripping
- Control character removal
- AI prompt injection prevention
- Email normalisation
- Password strength scoring

### Network Security
- Android: `network_security_config.xml` enforces HTTPS-only
- iOS: `NSAppTransportSecurity` with `NSAllowsArbitraryLoads: false`
- No cleartext HTTP to any domain

### Data Protection
- Android: `allowBackup="false"` prevents ADB data extraction
- `backup_rules.xml` excludes all sensitive files from cloud backup
- `data_extraction_rules.xml` (Android 12+) blocks device transfer of tokens

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── config/app_config.dart         # Env vars (--dart-define)
│   ├── router/app_router.dart         # GoRouter with auth guards
│   ├── theme/app_theme.dart           # Light + dark Material 3 themes
│   ├── security/
│   │   ├── secure_storage.dart        # Keychain/EncryptedSharedPrefs
│   │   ├── rate_limiter.dart          # Client-side request throttling
│   │   ├── input_sanitizer.dart       # XSS/injection prevention
│   │   └── session_manager.dart       # Inactivity timeout + lifecycle
│   ├── network/
│   │   └── connectivity_service.dart  # Online/offline monitoring
│   └── utils/
│       ├── notification_service.dart  # Local expiry notifications
│       └── error_handler.dart         # Global error boundary
├── models/
│   └── models.dart                    # PantryItem, Recipe, ShoppingItem…
├── features/
│   ├── auth/                          # Login, Register, ForgotPassword
│   ├── pantry/                        # Pantry CRUD + expiry tracking
│   ├── recipes/                       # AI suggestions + saved recipes
│   ├── meal_plan/                     # Weekly meal planner
│   ├── shopping/                      # Shopping list
│   ├── analytics/                     # Charts + sustainability score
│   ├── home/                          # Dashboard
│   └── profile/                       # Settings + account management
└── shared/
    └── widgets/offline_banner.dart

supabase/
├── migrations/001_initial_schema.sql  # Full DB schema + RLS + functions
└── edge_functions/
    └── gemini_proxy/index.ts          # Gemini API proxy (key never in app)

android/app/src/main/
├── AndroidManifest.xml                # Security flags + deep links
└── res/xml/
    ├── network_security_config.xml    # HTTPS enforcement
    ├── backup_rules.xml               # Exclude sensitive data from backup
    └── data_extraction_rules.xml      # Android 12+ backup rules

ios/Runner/
└── Info.plist                         # ATS + privacy strings + URL scheme
```

---

## Quick Start

### 1. Create a Supabase project
1. Go to [supabase.com](https://supabase.com) → New project
2. Copy your **Project URL** and **anon key**
3. Go to **SQL Editor** and run the full migration:
   ```
   supabase/migrations/001_initial_schema.sql
   ```

### 2. Deploy the Edge Function
```bash
# Install Supabase CLI
brew install supabase/tap/supabase   # macOS

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Set the Gemini secret (NEVER commit this to git)
supabase secrets set GEMINI_API_KEY=your_gemini_key_here

# Deploy
supabase functions deploy gemini_proxy
```

### 3. Configure the Flutter app
Never hardcode secrets. Use `--dart-define` at build time:

**Development:**
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

**VS Code** — add to `.vscode/launch.json`:
```json
{
  "configurations": [{
    "name": "FreshPlan Dev",
    "request": "launch",
    "type": "dart",
    "args": [
      "--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co",
      "--dart-define=SUPABASE_ANON_KEY=your_anon_key_here"
    ]
  }]
}
```

**Production build:**
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here

flutter build ios --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

### 4. Install dependencies
```bash
flutter pub get
```

### 5. Run
```bash
flutter run
```

---

## Supabase Auth Configuration

In your Supabase dashboard → **Authentication → URL Configuration**:

| Setting | Value |
|---|---|
| Site URL | `freshplan://login-callback` |
| Redirect URLs | `freshplan://login-callback`, `freshplan://reset-password` |

Enable **Email confirmations** under Authentication → Settings.

---

## Environment Variables Reference

| Variable | Where Set | Description |
|---|---|---|
| `SUPABASE_URL` | `--dart-define` at build time | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | `--dart-define` at build time | Supabase public anon key |
| `GEMINI_API_KEY` | Supabase Edge Function secrets | Never in the Flutter app |

---

## Adding Fonts

Download from [Google Fonts — Poppins](https://fonts.google.com/specimen/Poppins) and place in `assets/fonts/`:
- `Poppins-Regular.ttf`
- `Poppins-Medium.ttf`
- `Poppins-SemiBold.ttf`
- `Poppins-Bold.ttf`

Or swap to `Inter`, `Nunito`, or any other font by updating `pubspec.yaml` and `app_theme.dart`.

---

## Production Checklist

- [ ] Replace placeholder Supabase URL and anon key (via `--dart-define`)
- [ ] Deploy `gemini_proxy` Edge Function with `GEMINI_API_KEY` secret
- [ ] Run `001_initial_schema.sql` migration in Supabase SQL editor
- [ ] Enable Email Confirmations in Supabase Auth settings
- [ ] Set Redirect URLs in Supabase Auth URL Configuration
- [ ] Add actual font files to `assets/fonts/`
- [ ] Create app icon and update `@mipmap/ic_launcher` (Android) and `AppIcon` (iOS)
- [ ] Set correct `CFBundleIdentifier` in `ios/Runner.xcodeproj`
- [ ] Set correct `applicationId` in `android/app/build.gradle`
- [ ] Enable certificate pinning in `network_security_config.xml` (replace placeholder hashes)
- [ ] Add Sentry/Crashlytics to `error_handler.dart`
- [ ] Review and customise session timeout in `AppConfig.sessionTimeoutMinutes`
- [ ] Test deep links (`freshplan://`) on both platforms

---

## Security Hardening Checklist

- [x] RLS enabled on all tables with per-user policies
- [x] Gemini API key in Edge Function — never in client code
- [x] PKCE auth flow
- [x] Brute-force lockout (5 attempts → 15 min)
- [x] Inactivity session timeout (30 min)
- [x] Tokens stored in OS Keychain / EncryptedSharedPreferences
- [x] Input sanitization (HTML, control chars, prompt injection)
- [x] HTTPS enforced on Android and iOS
- [x] `allowBackup="false"` on Android
- [x] Sensitive files excluded from backup
- [x] Server-side rate limiting via DB function
- [x] Client-side rate limiting (belt + suspenders)
- [x] User-friendly error messages (no stack traces exposed)
- [x] Password strength enforcement (min 8 chars + complexity)
- [x] Email normalisation before auth calls
- [ ] Certificate pinning (see `network_security_config.xml` comments)
- [ ] Obfuscation: `flutter build apk --obfuscate --split-debug-info=...`

---

## Dependencies

| Package | Purpose |
|---|---|
| `supabase_flutter` | Auth + DB + Realtime + Storage |
| `flutter_riverpod` | State management |
| `go_router` | Declarative navigation + auth guards |
| `flutter_secure_storage` | Encrypted token storage |
| `local_auth` | Biometric unlock |
| `dio` | HTTP client with auth interceptors |
| `connectivity_plus` | Offline detection |
| `flutter_local_notifications` | Expiry alerts |
| `fl_chart` | Analytics charts |
| `flutter_slidable` | Swipe-to-delete |
| `flutter_animate` | Smooth animations |
| `shimmer` | Skeleton loading screens |
| `cached_network_image` | Efficient image loading |
| `image_picker` | Camera/gallery for item photos |

---

## License

MIT — see `LICENSE` file.
