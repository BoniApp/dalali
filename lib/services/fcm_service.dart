import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/deep_link_service.dart';
import 'package:dalali/services/dpo_payment_service.dart';
import 'package:dalali/services/notification_service.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/screens/shared/conversations_screen.dart';
import 'package:dalali/screens/wallet/payment_success_screen.dart';

/// Top-level background message handler (required by firebase_messaging).
/// Kept minimal: FCM displays notification payloads itself in the
/// background; taps route through [FcmService._openFromMessage].
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// ═══════════════════════════════════════════════════════════════
/// FCM SERVICE — Firebase Cloud Messaging
/// ═══════════════════════════════════════════════════════════════
///
/// Push layer for the app-closed case; the in-app Realtime stack
/// (notifications table stream + flutter_local_notifications) is
/// untouched. Sending happens ONLY server-side (send-notification
/// edge function, service account in Supabase secrets).
///
/// Lifecycle: initialize() in main() after Firebase init; the device
/// token syncs to users.fcm_token on login and on refresh, and is
/// cleared on logout so a signed-out device stops receiving pushes.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

    // iOS shows a system prompt; Android 13+ is handled by
    // NotificationService (POST_NOTIFICATIONS).
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Token sync: now (if already logged in), on login, and on refresh.
    await _saveTokenToProfile(await _messaging.getToken());
    _messaging.onTokenRefresh.listen(_saveTokenToProfile);
    SupabaseService.onAuthStateChange.listen((state) async {
      final event = state.event.name;
      if (event == 'signedIn') {
        await _saveTokenToProfile(await _messaging.getToken());
      } else if (event == 'signedOut') {
        await _clearToken();
      }
    });

    // Foreground → local notification (same channel as app alerts).
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n != null) {
        NotificationService.showLocalNotification(
          title: n.title ?? 'Dalali',
          body: n.body ?? '',
          payload: message.data['target_id'] as String?,
        );
      }
    });

    // Taps (background → app, and cold start).
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _openFromMessage(initial);
  }

  static Future<void> _saveTokenToProfile(String? token) async {
    final uid = SupabaseService.currentUserId;
    if (token == null || uid == null) return;
    try {
      await SupabaseService.client.from('users').update({
        'fcm_token': token,
        'device_platform': defaultTargetPlatform.name,
        'last_token_update': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  static Future<void> _clearToken() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('users').update({
        'fcm_token': null,
        'last_token_update': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('FCM token clear error: $e');
    }
  }

  /// Route a tapped push into the app, mirroring the notifications
  /// screen's target navigation (data: target_collection + target_id).
  static Future<void> _openFromMessage(RemoteMessage message) async {
    final nav = DeepLinkService.instance.navigatorKey.currentState;
    if (nav == null) return;
    final collection = message.data['target_collection'];
    final targetId = message.data['target_id'];
    if (targetId is! String) return;
    try {
      switch (collection) {
        case 'properties':
          await DeepLinkService.instance.openListingById(targetId);
          break;
        case 'payments':
          final payment = await DpoPaymentService().getPaymentById(targetId);
          if (payment != null) {
            final property = await DataService().getPropertyById(payment.propertyId);
            final nav2 = DeepLinkService.instance.navigatorKey.currentState;
            if (nav2 != null) {
              nav2.push(MaterialPageRoute(
                builder: (_) => PaymentSuccessScreen(
                  payment: payment,
                  propertyTitle: property?.title ?? '',
                  tenantName: '',
                ),
              ));
            }
          }
          break;
        case 'conversations':
          final uid = SupabaseService.currentUserId;
          if (uid != null) {
            nav.push(MaterialPageRoute(builder: (_) => ConversationsScreen(userId: uid)));
          }
          break;
      }
    } catch (e) {
      debugPrint('FCM tap navigation error: $e');
    }
  }
}
