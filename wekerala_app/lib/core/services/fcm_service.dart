import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;


@pragma('vm:entry-point')
Future<void> handleFcmBackground(RemoteMessage _) async {}

class FcmService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'wk_daily_sales';
  static const _channelName = 'Daily Sales Report';
  static const _notificationId = 1001;

  static Future<void> init(String shopId) async {
    // FCM push notifications are Android-only in this app
    if (kIsWeb || !Platform.isAndroid) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) {
      await _saveToken(shopId, token);
    }
    messaging.onTokenRefresh.listen((t) => _saveToken(shopId, t));

    // Schedule the 9 PM daily sales report notification
    try {
      await scheduleDailySalesNotification();
    } catch (_) {
      // Non-fatal — app works fine without the notification
    }
  }

  /// Schedules a daily repeating notification at 9 PM (21:00) local time.
  /// Notification ID: 1001. Safe to call multiple times — cancels any
  /// previously scheduled instance first.
  static Future<void> scheduleDailySalesNotification() async {
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily sales summary at 9 PM',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.zonedSchedule(
      _notificationId,
      'Daily Sales Summary',
      'Tap to view today\'s sales report',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'analytics',
    );
  }

  static Future<void> _saveToken(String shopId, String token) =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({'fcmToken': token});
}
