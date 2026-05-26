// lib/core/utils/notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Local notification service for expiry alerts and reminders.
// Uses flutter_local_notifications — no push token, no tracking.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../models/models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Channels ──────────────────────────────────────────────────────────────
  static const _expiryChannelId = 'freshplan_expiry';
  static const _expiryChannelName = 'Expiry Alerts';
  static const _expiryChannelDesc = 'Notifications for items expiring soon';

  static const _reminderChannelId = 'freshplan_reminders';
  static const _reminderChannelName = 'Meal Reminders';
  static const _reminderChannelDesc = 'Daily meal planning reminders';

  // ── Notification IDs (stable per pantry item) ─────────────────────────────
  // We hash the item ID to get a stable int ID for the notification
  int _stableId(String itemId) => itemId.hashCode.abs() % 100000;

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,  // We ask at appropriate time
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels
    const expiryChannel = AndroidNotificationChannel(
      _expiryChannelId,
      _expiryChannelName,
      description: _expiryChannelDesc,
      importance: Importance.high,
      enableVibration: true,
    );
    const reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      description: _reminderChannelDesc,
      importance: Importance.defaultImportance,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(expiryChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    _initialized = true;
  }

  // ── Request permissions ───────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    final androidGranted = await android?.requestNotificationsPermission() ?? true;

    return iosGranted || androidGranted;
  }

  // ── Schedule expiry alerts for all pantry items ───────────────────────────
  Future<void> scheduleExpiryAlerts(List<PantryItem> items) async {
    if (!_initialized) await initialize();

    // Cancel existing expiry notifications before rescheduling
    await cancelExpiryNotifications();

    final now = DateTime.now();

    for (final item in items) {
      if (item.expiryDate == null) continue;

      final daysLeft = item.daysUntilExpiry;

      // Schedule 3-days-before alert
      if (daysLeft >= 3) {
        final alertTime = item.expiryDate!.subtract(const Duration(days: 3));
        final scheduledTime = DateTime(alertTime.year, alertTime.month, alertTime.day, 9, 0);
        if (scheduledTime.isAfter(now)) {
          await _scheduleNotification(
            id: _stableId(item.id),
            title: '⏰ Expiring in 3 days',
            body: '${item.name} (${item.quantity} ${item.unit}) expires on ${_formatDate(item.expiryDate!)}.',
            scheduledDate: scheduledTime,
            channelId: _expiryChannelId,
            payload: 'pantry_expiry:${item.id}',
          );
        }
      }

      // Schedule day-of alert
      if (daysLeft >= 0) {
        final dayOfTime = DateTime(
          item.expiryDate!.year, item.expiryDate!.month, item.expiryDate!.day, 8, 0,
        );
        if (dayOfTime.isAfter(now)) {
          await _scheduleNotification(
            id: _stableId(item.id) + 50000,
            title: '🚨 Expires today!',
            body: '${item.name} expires today. Use it now or it will go to waste.',
            scheduledDate: dayOfTime,
            channelId: _expiryChannelId,
            payload: 'pantry_expiry:${item.id}',
          );
        }
      }
    }
  }

  // ── Show immediate expiry summary ─────────────────────────────────────────
  Future<void> showExpirySummary(List<PantryItem> expiring) async {
    if (!_initialized) await initialize();
    if (expiring.isEmpty) return;

    final expired = expiring.where((i) => i.expiryStatus == ExpiryStatus.expired).length;
    final soonCount = expiring.where((i) => i.expiryStatus == ExpiryStatus.expiringSoon).length;

    String title, body;
    if (expired > 0) {
      title = '$expired item${expired > 1 ? 's' : ''} expired!';
      body = 'Check your pantry and remove expired items.';
    } else {
      title = '$soonCount item${soonCount > 1 ? 's' : ''} expiring soon';
      body = expiring.take(2).map((i) => i.name).join(', ') +
          (expiring.length > 2 ? ' and ${expiring.length - 2} more...' : '');
    }

    await _plugin.show(
      999999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _expiryChannelId,
          _expiryChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'expiry_summary',
    );
  }

  // ── Schedule a single notification ───────────────────────────────────────
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _expiryChannelId ? _expiryChannelName : _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel expiry notifications ───────────────────────────────────────────
  Future<void> cancelExpiryNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.payload?.startsWith('pantry_expiry') == true) {
        await _plugin.cancel(n.id);
      }
    }
  }

  // ── Cancel all ────────────────────────────────────────────────────────────
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Tap handler ──────────────────────────────────────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    // TODO: navigate to relevant screen via router
    // GoRouter.of(navigatorKey.currentContext!).go('/pantry');
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
