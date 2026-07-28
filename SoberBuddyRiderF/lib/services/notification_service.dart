import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService(this._db);

  final FirebaseFirestore _db;
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
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _initialized = true;
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> saveTokenToUser(String uid) async {
    final token = await getToken();
    if (token == null) return;
    await _db.collection('users').doc(uid).set(
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

  void listenTokenRefresh(String uid) {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _db.collection('users').doc(uid).update({
          'fcmToken': token,
          'updatedAt': DateTime.now(),
        });
      } catch (e) {
        debugPrint('FCM token refresh save failed: $e');
      }
    });
  }
}
