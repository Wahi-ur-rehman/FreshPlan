// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// FreshPlan — Production Flutter App Entry Point
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/security/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Force portrait mode ────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar styling ─────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // ── Timezone support (for local notifications) ─────────────────────────────
  tz.initializeTimeZones();

  // ── Supabase initialization ────────────────────────────────────────────────
  // The anon key is safe to embed — RLS policies protect all data.
  // The Gemini API key is NEVER in this file; it lives in the Edge Function.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,       // More secure than implicit
      autoRefreshToken: true,
      persistSession: true,
    ),
    debug: false,
  );

  // ── Session manager (inactivity timeout, lifecycle) ────────────────────────
  SessionManager.instance.initialize();

  runApp(
    const ProviderScope(
      child: FreshPlanApp(),
    ),
  );
}

class FreshPlanApp extends ConsumerWidget {
  const FreshPlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,

      // ── Themes ─────────────────────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // ── Router ─────────────────────────────────────────────────────────────
      routerConfig: router,

      // ── Accessibility ───────────────────────────────────────────────────────
      builder: (context, child) => GestureDetector(
        // Record user activity to reset inactivity timer on any tap
        onTap: () => SessionManager.instance.recordActivity(),
        onPanDown: (_) => SessionManager.instance.recordActivity(),
        behavior: HitTestBehavior.translucent,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
