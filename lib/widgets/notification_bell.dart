import 'package:flutter/material.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/shared/notifications_screen.dart';
import 'package:provider/provider.dart';

class NotificationBell extends StatelessWidget {
  final Color? iconColor;

  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<AppState>().unreadNotificationCount;

    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
