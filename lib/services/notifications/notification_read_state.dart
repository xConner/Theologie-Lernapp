import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_notification.dart';

/// Nutzerbezogener Lesestatus der Glocke – ein einziges kleines Dokument
/// statt einer Kopie jeder Nachricht je Nutzer:
///
///   [readUpTo]  alles mit `createdAt <= readUpTo` gilt als gelesen
///               ("Glocke geöffnet" verschiebt diese Marke).
///   [readKeys]  einzeln gelesene Nachrichten nach der Marke (z. B. später
///               über einen Push-Deep-Link geöffnet), Schlüssel =
///               [AppNotification.key].
///
/// Die Marke wird auf das `createdAt` der neuesten angezeigten Nachricht
/// gesetzt (nicht auf die Geräteuhr), damit eine falsch gehende Uhr keine
/// noch nicht gesehenen Nachrichten als gelesen markiert.
class NotificationReadState {
  final DateTime? readUpTo;
  final Map<String, DateTime> readKeys;

  const NotificationReadState({this.readUpTo, this.readKeys = const {}});

  static const NotificationReadState empty = NotificationReadState();

  bool isRead(AppNotification notification) {
    final upTo = readUpTo;

    if (upTo != null && !notification.createdAt.isAfter(upTo)) {
      return true;
    }

    return readKeys.containsKey(notification.key);
  }

  /// Höchstzahl gespeicherter Einzelmarkierungen (älteste fallen weg).
  static const int maxReadKeys = 100;

  /// Markiert alle [visible] Nachrichten als gelesen. Einzelmarkierungen,
  /// die die neue Marke abdeckt, werden entfernt (Dokument bleibt klein).
  NotificationReadState markAllRead(Iterable<AppNotification> visible) {
    DateTime? newest = readUpTo;

    for (final notification in visible) {
      if (newest == null || notification.createdAt.isAfter(newest)) {
        newest = notification.createdAt;
      }
    }

    if (newest == null || newest == readUpTo) {
      return this;
    }

    final covered = {for (final n in visible) n.key};

    return NotificationReadState(
      readUpTo: newest,
      readKeys: {
        for (final entry in readKeys.entries)
          if (!covered.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  NotificationReadState markRead(AppNotification notification, DateTime now) {
    if (isRead(notification)) return this;

    final keys = {...readKeys, notification.key: now};

    if (keys.length > maxReadKeys) {
      final oldestFirst = keys.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final entry in oldestFirst.take(keys.length - maxReadKeys)) {
        keys.remove(entry.key);
      }
    }

    return NotificationReadState(readUpTo: readUpTo, readKeys: keys);
  }

  /// Übernimmt Markierungen aus [other] (z. B. von einem anderen Gerät),
  /// ohne eigene zu verlieren.
  NotificationReadState union(NotificationReadState other) {
    final a = readUpTo;
    final b = other.readUpTo;

    return NotificationReadState(
      readUpTo: a == null ? b : (b == null || a.isAfter(b) ? a : b),
      readKeys: {...other.readKeys, ...readKeys},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "readUpTo": readUpTo?.toUtc().toIso8601String(),
      "readKeys": readKeys.map(
        (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
      ),
    };
  }

  factory NotificationReadState.fromMap(Object? data) {
    if (data is! Map) return empty;

    final keys = <String, DateTime>{};

    final rawKeys = data["readKeys"];

    if (rawKeys is Map) {
      for (final entry in rawKeys.entries) {
        final value = _dateTime(entry.value);

        if (value != null) {
          keys[entry.key.toString()] = value;
        }
      }
    }

    return NotificationReadState(
      readUpTo: _dateTime(data["readUpTo"]),
      readKeys: keys,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
