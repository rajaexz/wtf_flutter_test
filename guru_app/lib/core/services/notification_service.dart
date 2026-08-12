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
}

/// Local reminders always work. FCM works after Firebase + google-services.json.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool firebaseReady = false;
  String? fcmToken;

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
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
      logger.auth('[NOTIFY] FCM token: ${fcmToken != null ? '${fcmToken!.substring(0, 12)}…' : 'null'}');

      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'WTF';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        showNow(title: title, body: body);
      });
    } catch (e) {
      firebaseReady = false;
      logger.auth('[NOTIFY] Firebase not configured yet: $e');
      if (kDebugMode) {
        debugPrint(
          'Add google-services.json / GoogleService-Info.plist to enable FCM. '
          'Local call reminders still work.',
        );
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wtf_calls',
          'Call & Chat',
          channelDescription: 'Call reminders and chat alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule reminder 10 minutes before scheduled call (assessment stretch).
  Future<void> scheduleCallReminder({
    required String callRequestId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();

    final when = scheduledFor.subtract(const Duration(minutes: 10));
    if (when.isBefore(DateTime.now())) {
      await showNow(title: title, body: body);
      return;
    }

    final id = callRequestId.hashCode.abs() % 100000;
    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'wtf_calls',
          'Call & Chat',
          channelDescription: 'Call reminders and chat alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    logger.schedule('[NOTIFY] reminder set for $when ($callRequestId)');
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
