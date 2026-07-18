import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Handles local device notifications and Supabase notification syncing.
class NotificationService {
  static final _db = SupabaseService.client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize notification channels & permissions.
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android notification channel
    const channel = AndroidNotificationChannel(
      'dalali_channel',
      'Dalali Notifications',
      description: 'Notifications for inquiries, appointments, and updates',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Show a local notification on the device.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'dalali_channel',
      'Dalali Notifications',
      channelDescription: 'Notifications for inquiries, appointments, and updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Insert a notification into Supabase (server-side record).
  static Future<void> sendNotification(NotificationModel notification) async {
    await _db.from('notifications').insert({
      'user_id': notification.userId,
      'type': notification.type.name,
      'title': notification.title,
      'body': notification.body,
      'target_id': notification.targetId,
      'target_collection': notification.targetCollection,
      'is_read': notification.isRead,
      'created_at': notification.createdAt.toIso8601String(),
    });
  }

  /// Send + show a notification in one call.
  static Future<void> notifyUser({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? targetId,
    String? targetCollection,
  }) async {
    final notification = NotificationModel(
      id: '',
      userId: userId,
      type: type,
      title: title,
      body: body,
      targetId: targetId,
      targetCollection: targetCollection,
      createdAt: DateTime.now(),
    );

    // Persist to database
    await sendNotification(notification);

    // Show local notification if current user is the target
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == userId) {
      await showLocalNotification(title: title, body: body);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navigation handled by AppState listener or deep-linking if needed
    debugPrint('Notification tapped: ${response.payload}');
  }
}
