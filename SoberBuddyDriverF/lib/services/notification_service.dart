import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _messaging.requestPermission();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (_) {},
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _initialized = true;
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> saveTokenToFirestore(String uid, String collection) async {
    final token = await getToken();
    if (token == null) return;
    await FirebaseService.db.collection(collection).doc(uid).set(
      {'fcmToken': token, 'updatedAt': DateTime.now()},
      SetOptions(merge: true),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'soberbuddy_trips',
        'Trip Updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  void listenTokenRefresh(String uid, String collection) {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await FirebaseService.db.collection(collection).doc(uid).update({
          'fcmToken': token,
          'updatedAt': DateTime.now(),
        });
      } catch (e) {
        debugPrint('FCM token refresh save failed: $e');
      }
    });
  }
}
