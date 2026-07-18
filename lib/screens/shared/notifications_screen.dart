import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<AppState>().notifications;
    final unreadCount = context.watch<AppState>().unreadNotificationCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => context.read<AppState>().markAllNotificationsRead(),
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(notification: n);
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.primary,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.done, color: Colors.white),
      ),
      onDismissed: (_) => context.read<AppState>().markNotificationRead(notification.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isRead ? Colors.grey.shade200 : AppTheme.primary.withAlpha(26),
          child: Icon(
            _iconForType(notification.type),
            color: notification.isRead ? Colors.grey : AppTheme.primary,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              Helpers.formatDateOnly(notification.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: notification.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
              ),
        onTap: () {
          if (!notification.isRead) {
            context.read<AppState>().markNotificationRead(notification.id);
          }
        },
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.inquiry:
        return Icons.message;
      case NotificationType.appointment:
        return Icons.calendar_today;
      case NotificationType.propertyApproved:
        return Icons.check_circle;
      case NotificationType.propertyRejected:
        return Icons.cancel;
      case NotificationType.tenancyApplication:
        return Icons.assignment;
      case NotificationType.tenancyApproved:
        return Icons.home;
      case NotificationType.maintenanceUpdate:
        return Icons.build;
      case NotificationType.rentDue:
        return Icons.payment;
      case NotificationType.paymentReceived:
        return Icons.attach_money;
      case NotificationType.withdrawalProcessed:
        return Icons.account_balance_wallet;
      case NotificationType.system:
        return Icons.info;
    }
  }
}
