import 'package:flutter/material.dart';

import '../screens/notifications_screen.dart';
import '../services/notifications/notification_service.dart';
import '../theme/app_theme.dart';
import 'notification_style.dart';

/// Glocke für die AppBar mit Anzahl ungelesener Nachrichten. Zählt nur
/// veröffentlichte Nachrichten, nie Streak- oder Lernstatus.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final label = notificationBadgeLabel(service.unreadCount);

        return IconButton(
          tooltip: label == null
              ? "Benachrichtigungen"
              : "Benachrichtigungen ($label ungelesen)",
          icon: Badge(
            isLabelVisible: label != null,
            label: Text(label ?? ""),
            backgroundColor: AppColors.accent,
            textColor: Colors.white,
            child: Icon(
              label == null
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_rounded,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        );
      },
    );
  }
}
