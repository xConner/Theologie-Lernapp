import 'package:flutter/material.dart';

import '../services/notifications/app_notification.dart';

/// Darstellungshilfen der Glocke (ohne Abhängigkeiten zu Screens).

/// Badge-Text für [count] ungelesene Nachrichten; null = kein Badge.
String? notificationBadgeLabel(int count) {
  if (count <= 0) return null;
  return count > 9 ? "9+" : "$count";
}

extension NotificationCategoryStyle on NotificationCategory {
  IconData get icon {
    return switch (this) {
      NotificationCategory.content => Icons.auto_awesome_rounded,
      NotificationCategory.system => Icons.info_outline_rounded,
      NotificationCategory.account => Icons.shield_outlined,
      NotificationCategory.announcement => Icons.campaign_outlined,
    };
  }

  /// Kurzer Name für die Filterleiste.
  String get filterLabel {
    return switch (this) {
      NotificationCategory.content => "Neue Inhalte",
      NotificationCategory.system => "System",
      NotificationCategory.account => "Account",
      NotificationCategory.announcement => "theologie.app",
    };
  }
}

const List<String> _weekdays = [
  "Montag",
  "Dienstag",
  "Mittwoch",
  "Donnerstag",
  "Freitag",
  "Samstag",
  "Sonntag",
];

/// "Heute, 14:05" · "Gestern, 09:30" · "Dienstag" (letzte Woche) ·
/// "03.08.2026".
String formatNotificationDate(DateTime date, DateTime now) {
  final local = date.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);

  String two(int v) => v.toString().padLeft(2, "0");

  final time = "${two(local.hour)}:${two(local.minute)}";

  if (day == today) return "Heute, $time";

  if (day == DateTime(now.year, now.month, now.day - 1)) {
    return "Gestern, $time";
  }

  if (day.isBefore(today) &&
      day.isAfter(DateTime(now.year, now.month, now.day - 7))) {
    return _weekdays[local.weekday - 1];
  }

  return "${two(local.day)}.${two(local.month)}.${local.year}";
}
