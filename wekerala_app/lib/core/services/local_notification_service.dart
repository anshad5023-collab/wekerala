import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'wk_daily_sales';
  static const _channelName = 'Daily Sales Report';
  static const _notificationId = 1001;

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // Run timezone DB load on a background isolate — it takes ~200ms and blocks main thread
    await compute<void, void>((_) => tz.initializeTimeZones(), null);
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );
  }

  static void _onTap(NotificationResponse response) {
    // NavigationService handles the actual navigation — see main.dart
    _pendingPayload = response.payload;
  }

  // Stored so main.dart can read it after app resumes from a notification tap
  static String? _pendingPayload;
  static String? consumePendingPayload() {
    final p = _pendingPayload;
    _pendingPayload = null;
    return p;
  }

  // Schedule the 9 PM daily sales notification.
  // Call this once after the user's shop is known (in FcmService.init).
  static Future<void> scheduleDailySalesReport() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily sales summary at 9 PM',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'Today\'s Sales Report 📊',
        'Tap to view and share today\'s sales summary on WhatsApp',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'analytics',
      );
    } catch (_) {
      // Notification scheduling not available on this device — safe to ignore
    }
  }

  // Show an immediate notification about low-stock / expiring products.
  // Call this from StockNotificationService after querying Firestore.
  static Future<void> scheduleDailyStockAlert({
    required int lowStockCount,
    required int expiringCount,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (lowStockCount == 0 && expiringCount == 0) {
      // Cancel any existing alert if nothing to report
      await _plugin.cancel(42);
      return;
    }

    final parts = <String>[];
    if (lowStockCount > 0) parts.add('$lowStockCount items low on stock');
    if (expiringCount > 0) parts.add('$expiringCount items expiring soon');
    final body = parts.join(' · ');

    const androidDetails = AndroidNotificationDetails(
      'stock_alerts',
      'Stock Alerts',
      channelDescription: 'Daily alerts for low stock and expiry',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      42,
      '⚠️ Shop Alert',
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // Schedule a repeating 9 AM morning check notification.
  // Call this once during app init so the device schedules it.
  static Future<void> scheduleDailyMorningCheck() async {
    if (kIsWeb || !Platform.isAndroid) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_summary',
      'Daily Summary',
      channelDescription: 'Morning shop summary notification',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        43,
        '🌅 Good morning!',
        'Check your stock and orders for today',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Exact alarms may not be available on all devices — safe to ignore
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
