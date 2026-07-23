import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Handles local device notifications and Supabase notification syncing.
class NotificationService {
  static final _db = SupabaseService.client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Fixed id for the "new notifications" summary alert posted while the app
  /// is backgrounded. Keeping one id lets us cancel it (clearing the Android
  /// launcher dot) the moment everything is read.
  static const int newNotificationsId = 1001;

  /// iOS-only launcher badge channel (see ios/Runner/AppDelegate.swift).
  static const MethodChannel _badgeChannel = MethodChannel('dalali/app_badge');

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

    // Android 13+ (API 33) requires a runtime grant before notifications
    // can be posted; on older versions this is a no-op.
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Show a local notification on the device.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    int? badgeNumber,
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
    final iosDetails = DarwinNotificationDetails(badgeNumber: badgeNumber);
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: id ?? DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Mirror the unread count onto the launcher icon. iOS gets a numeric
  /// badge through the `dalali/app_badge` channel; Android has no portable
  /// count API — its launcher dot follows the posted summary notification.
  static Future<void> updateAppBadge(int unreadCount) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _badgeChannel.invokeMethod('setBadgeCount', {'count': unreadCount});
    } on PlatformException catch (e) {
      debugPrint('updateAppBadge error: $e');
    }
  }

  /// Remove the background "new notifications" summary alert (Android dot).
  static Future<void> cancelNewNotificationsAlert() async {
    if (kIsWeb || !_initialized) return;
    try {
      await _localNotifications.cancel(id: newNotificationsId);
    } on PlatformException catch (e) {
      debugPrint('cancelNewNotificationsAlert error: $e');
    }
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
