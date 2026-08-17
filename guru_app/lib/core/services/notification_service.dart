import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // OS shows notification payload when app is killed; data-only handled here if needed.
}

/// Local reminders work with app closed. FCM covers remote when token is registered.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://192.168.1.2:3000',
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool firebaseReady = false;
  String? fcmToken;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'wtf_calls',
      'Call & Chat',
      channelDescription: 'Call reminders and chat alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Set this callback after the router is ready so notification taps can navigate.
  void Function(String callRequestId)? onCallTap;

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();
    try {
      // Assessment devices / India default; falls back safely
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          onCallTap?.call(payload);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _ready = true;
    await _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      fcmToken = await messaging.getToken();
      logger.auth(
        '[NOTIFY] FCM token: ${fcmToken != null ? '${fcmToken!.substring(0, 12)}…' : 'null'}',
      );

      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'WTF';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        showNow(title: title, body: body);
      });

      // App opened by tapping FCM notification (background/killed)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final callId = message.data['callRequestId'] as String?;
        if (callId != null && callId.isNotEmpty) {
          onCallTap?.call(callId);
        }
      });

      // App launched from killed state via FCM notification
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final callId = initial.data['callRequestId'] as String?;
        if (callId != null && callId.isNotEmpty) {
          // Delay to let the router initialize first
          Future.delayed(const Duration(milliseconds: 800), () {
            onCallTap?.call(callId);
          });
        }
      }
    } catch (e) {
      firebaseReady = false;
      logger.auth('[NOTIFY] Firebase not configured yet: $e');
      if (kDebugMode) {
        debugPrint('Local call reminders still work without Firebase.');
      }
    }
  }

  Future<void> registerUser(String userId) async {
    if (fcmToken == null || fcmToken!.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$_tokenServerUrl/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 5));
      logger.auth('[NOTIFY] registered FCM for $userId');
    } catch (e) {
      logger.auth('[NOTIFY] FCM register failed: $e');
    }
  }

  Future<void> showNow({required String title, required String body}) async {
    if (!_ready) await init();
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      _details,
    );
  }

  /// Schedules T-10 reminder + exact schedule-time call alert (works if app is closed).
  Future<void> scheduleCallReminder({
    required String callRequestId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();

    final baseId = callRequestId.hashCode.abs() % 90000;
    final soonId = baseId;
    final nowId = baseId + 1;

    final t10 = scheduledFor.subtract(const Duration(minutes: 10));
    await _scheduleOne(
      id: soonId,
      when: t10,
      title: title,
      body: body,
      callRequestId: callRequestId,
    );
    await _scheduleOne(
      id: nowId,
      when: scheduledFor,
      title: 'Join Call',
      body: 'Your scheduled call is starting now. Open the app to join.',
      callRequestId: callRequestId,
    );
  }

  Future<void> _scheduleOne({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String callRequestId,
  }) async {
    if (when.isBefore(DateTime.now())) {
      if (when.isAfter(DateTime.now().subtract(const Duration(minutes: 2)))) {
        await showNow(title: title, body: body);
      }
      return;
    }

    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: callRequestId,
    );
    logger.schedule('[NOTIFY] scheduled #$id at $when ($callRequestId)');
  }

  Future<void> notifyRemote({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_tokenServerUrl/notify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'title': title, 'body': body}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      logger.auth('[NOTIFY] remote push skipped: $e');
    }
  }
}
