// lib/core/security/session_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Session manager: detects inactivity, auto-locks the app, and handles
// token refresh. Works in conjunction with Supabase Auth.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'secure_storage.dart';

class SessionManager with WidgetsBindingObserver {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  Timer? _inactivityTimer;
  bool _isLocked = false;

  final _lockedController = StreamController<bool>.broadcast();
  Stream<bool> get lockStream => _lockedController.stream;

  bool get isLocked => _isLocked;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _lockedController.close();
  }

  // Called on every user interaction
  void recordActivity() {
    if (_isLocked) return;
    SecureStorage.instance.updateLastActivity();
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(minutes: AppConfig.sessionTimeoutMinutes),
      _lockSession,
    );
  }

  void _lockSession() {
    _isLocked = true;
    _lockedController.add(true);
  }

  void unlock() {
    _isLocked = false;
    _lockedController.add(false);
    _resetTimer();
  }

  // App lifecycle: lock when sent to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lockSession();
        break;
      case AppLifecycleState.resumed:
        _checkSessionValidity();
        break;
      default:
        break;
    }
  }

  Future<void> _checkSessionValidity() async {
    final lastActivity = await SecureStorage.instance.getLastActivity();
    if (lastActivity == null) {
      _lockSession();
      return;
    }

    final elapsed = DateTime.now().difference(lastActivity);
    if (elapsed.inMinutes >= AppConfig.sessionTimeoutMinutes) {
      _lockSession();
    } else {
      _resetTimer();
    }
  }

  Future<void> signOut() async {
    _inactivityTimer?.cancel();
    _isLocked = false;
    await SecureStorage.instance.clearSession();
    await Supabase.instance.client.auth.signOut();
  }
}
