import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/notification_service.dart';

/// In-app notifications + the launcher-icon badge/dot. Tracks app
/// lifecycle (drives whether a new notification posts a device alert
/// or just updates the in-app bell).
class NotificationState extends ChangeNotifier with WidgetsBindingObserver {
  List<NotificationModel> _notifications = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;
  UserModel? _currentUser;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _notificationsPrimed = false;

  NotificationState() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  List<NotificationModel> get notifications => _notifications;

  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _data.markNotificationRead(id).catchError((e) {
        debugPrint('markNotificationRead error: $e');
      });
      _syncNotificationBadge();
      notifyListeners();
    }
  }

  void markAllNotificationsRead(String? userId) {
    if (userId == null) return;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _data.markAllNotificationsRead(userId).catchError((e) {
      debugPrint('markAllNotificationsRead error: $e');
    });
    _syncNotificationBadge();
    notifyListeners();
  }

  /// Keeps the launcher-icon badge/dot aligned with unread notifications.
  /// iOS gets the numeric badge via NotificationService.updateAppBadge;
  /// Android shows a launcher dot while the summary alert (id
  /// NotificationService.newNotificationsId) is posted, cancelled when
  /// everything is read. A device alert is only posted for genuinely new
  /// rows while the app is backgrounded — the in-app bell covers the
  /// foreground case. [previousIds] is null on the first stream emission
  /// (initial sync), which never posts an alert.
  void _syncNotificationBadge({Set<String>? previousIds}) {
    final unread = unreadNotificationCount;
    NotificationService.updateAppBadge(unread);
    if (unread == 0) {
      NotificationService.cancelNewNotificationsAlert();
      return;
    }
    if (previousIds == null || _lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final fresh = _notifications.where((n) => !n.isRead && !previousIds.contains(n.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (fresh.isEmpty) return;
    NotificationService.showLocalNotification(
      id: NotificationService.newNotificationsId,
      title: fresh.first.title,
      body: fresh.length > 1 ? '${fresh.first.body} (+${fresh.length - 1} more)' : fresh.first.body,
      badgeNumber: unread,
    );
  }

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribe(UserModel user) {
    _subscriptions.add(_data.getNotificationsForUser(user.id).listen((list) {
      final previousIds = _notifications.map((n) => n.id).toSet();
      final primed = _notificationsPrimed;
      _notifications = list;
      _notificationsPrimed = true;
      _syncNotificationBadge(previousIds: primed ? previousIds : null);
      notifyListeners();
    }));
  }

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _currentUser = user;
    _unsubscribe();
    _notificationsPrimed = false;
    if (user == null) {
      _notifications = [];
      NotificationService.updateAppBadge(0);
      NotificationService.cancelNewNotificationsAlert();
      notifyListeners();
      return;
    }
    _subscribe(user);
  }

  /// Re-fetch by re-subscribing (pull-to-refresh). Completes once fresh
  /// data has been delivered (5s timeout fallback so the spinner never
  /// hangs); a no-op when no user is signed in.
  Future<void> refreshData() async {
    final user = _currentUser;
    if (user == null) return;
    final delivered = Completer<void>();
    final probe = _data.getNotificationsForUser(user.id).listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onError: (_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onDone: () {
      if (!delivered.isCompleted) delivered.complete();
    });
    _unsubscribe();
    _subscribe(user);
    await delivered.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    await probe.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe();
    super.dispose();
  }
}
