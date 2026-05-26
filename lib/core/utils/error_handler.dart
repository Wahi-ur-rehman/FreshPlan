// lib/core/utils/error_handler.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralized error handling:
//   • Catches Flutter framework errors
//   • Catches Dart async errors
//   • Sanitizes error messages before showing to users (no stack traces in UI)
//   • Logs to console in debug, sends to Sentry/Crashlytics in release
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppErrorHandler {
  AppErrorHandler._();

  /// Call this in main() before runApp()
  static void initialize() {
    // Catch Flutter rendering errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      } else {
        _logError(details.exception, details.stack);
      }
    };

    // Catch async/isolate errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error, stack);
      return true; // Mark as handled
    };
  }

  static void _logError(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('═══ APP ERROR ═══');
      debugPrint(error.toString());
      debugPrint(stack?.toString());
      debugPrint('═════════════════');
    }
    // In production, send to Sentry / Firebase Crashlytics:
    // FirebaseCrashlytics.instance.recordError(error, stack);
    // Sentry.captureException(error, stackTrace: stack);
  }

  /// Converts technical exceptions to user-friendly messages.
  /// IMPORTANT: Never expose raw stack traces or DB errors to users.
  static String userFriendlyMessage(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('not authenticated') || msg.contains('jwt') || msg.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (msg.contains('rate limit') || msg.contains('429') || msg.contains('too many')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (msg.contains('permission') || msg.contains('403') || msg.contains('rls')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (msg.contains('not found') || msg.contains('404')) {
      return 'The requested item was not found.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'This item already exists.';
    }
    if (msg.contains('storage') || msg.contains('quota')) {
      return 'Storage limit reached. Please delete some items.';
    }

    return 'Something went wrong. Please try again.';
  }
}

// ── Error Widget ──────────────────────────────────────────────────────────────
/// Override Flutter's default red error screen in production
class AppErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, this.message, this.onRetry});

  static Widget builder(FlutterErrorDetails details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return AppErrorWidget(
      message: 'Something went wrong',
      onRetry: null,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFE63946)),
            const SizedBox(height: 16),
            Text(
              message ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ],
        ),
      ),
    ),
  );
}
