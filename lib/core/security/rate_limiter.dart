// lib/core/security/rate_limiter.dart
// ─────────────────────────────────────────────────────────────────────────────
// Client-side rate limiter — complements server-side Supabase RLS rate limiting.
// Prevents rapid-fire API calls and protects against accidental DoS.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

class RateLimiter {
  final int maxRequests;
  final Duration window;

  final List<DateTime> _timestamps = [];
  Completer<void>? _pendingCompleter;

  RateLimiter({
    required this.maxRequests,
    required this.window,
  });

  /// Returns true if the request is allowed, false if rate limited.
  bool tryAcquire() {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Remove timestamps outside the window
    _timestamps.removeWhere((t) => t.isBefore(windowStart));

    if (_timestamps.length >= maxRequests) {
      return false;
    }

    _timestamps.add(now);
    return true;
  }

  /// Waits until a slot is available, then returns.
  Future<void> acquire() async {
    while (!tryAcquire()) {
      final oldestInWindow = _timestamps.first;
      final waitUntil = oldestInWindow.add(window);
      final delay = waitUntil.difference(DateTime.now());
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
    }
  }

  /// How many milliseconds until next request is allowed (0 if allowed now).
  int msUntilAvailable() {
    final now = DateTime.now();
    final windowStart = now.subtract(window);
    _timestamps.removeWhere((t) => t.isBefore(windowStart));

    if (_timestamps.length < maxRequests) return 0;
    final waitUntil = _timestamps.first.add(window);
    final diff = waitUntil.difference(now);
    return diff.inMilliseconds.clamp(0, window.inMilliseconds);
  }

  void reset() => _timestamps.clear();
}

// ── Pre-configured limiters ───────────────────────────────────────────────────
class AppRateLimiters {
  AppRateLimiters._();

  // AI recipe generation: max 20 per hour
  static final aiGeneration = RateLimiter(
    maxRequests: 20,
    window: const Duration(hours: 1),
  );

  // Auth: max 5 attempts per 15 minutes
  static final authentication = RateLimiter(
    maxRequests: 5,
    window: const Duration(minutes: 15),
  );

  // Pantry CRUD: max 100 per minute (guards against runaway loops)
  static final pantryOperations = RateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 1),
  );

  // Search: max 30 per minute (debounce + server protection)
  static final search = RateLimiter(
    maxRequests: 30,
    window: const Duration(minutes: 1),
  );
}
