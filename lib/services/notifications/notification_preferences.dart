import 'package:cloud_firestore/cloud_firestore.dart';

import 'push_platform.dart';

/// Benachrichtigungs-Einstellungen eines Kontos, gespeichert als Feld
/// `notification_settings` im Dokument `users/{uid}` (wie die übrigen
/// Einstellungen). Der serverseitige Versand von Push und E-Mail liest
/// dieses Feld; die In-App-Glocke ist davon unabhängig.
///
/// Firestore-Format:
///   notification_settings: {
///     push:  { enabled, bibleReading, readingPlan, memorization, trainers,
///              newContent, systemMessages },
///     email: { announcements },
///     reminderMinutes,    // gewünschte Uhrzeit, Minuten ab Mitternacht
///     timeZone,           // IANA-Zeitzone des Geräts
///     utcOffsetMinutes,   // Ersatz, falls die Zeitzone unbekannt ist
///     nextReminderAt,     // nächste Erinnerung; fehlt, wenn Push aus ist
///     lastReminderDate,   // schreibt nur der Server (keine zweite am Tag)
///   }
class NotificationPreferences {
  /// Hauptschalter für Push auf diesem Konto (Opt-in).
  final bool pushEnabled;

  /// Uhrzeit der täglichen Erinnerung in Minuten ab Mitternacht (Ortszeit).
  final int reminderMinutes;

  // Kategorien der täglichen Erinnerung. Erinnert wird nur an das, was am
  // jeweiligen Tag noch offen ist (siehe docs/notifications.md).

  /// Bibellese-Streak: heute noch keine Lesung bestätigt.
  final bool bibleReading;

  /// Offene Tageslektüre eines laufenden Leseplans.
  final bool readingPlan;

  /// Texte auswendig lernen.
  final bool memorization;

  /// Sprachtrainer (Altgriechisch, Latein) und Perikopenquiz.
  final bool trainers;

  final bool newContent;

  final bool systemMessages;

  /// Bewusst veröffentlichte wichtige Nachrichten per E-Mail (Opt-in).
  /// Auth-Mails (Passwort, Bestätigung) sind davon unabhängig.
  final bool emailAnnouncements;

  const NotificationPreferences({
    this.pushEnabled = false,
    this.reminderMinutes = defaultReminderMinutes,
    this.bibleReading = true,
    this.readingPlan = true,
    this.memorization = true,
    this.trainers = true,
    this.newContent = false,
    this.systemMessages = true,
    this.emailAnnouncements = false,
  });

  static const NotificationPreferences defaults = NotificationPreferences();

  static const String field = "notification_settings";

  /// 18:00 Uhr.
  static const int defaultReminderMinutes = 18 * 60;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    int? reminderMinutes,
    bool? bibleReading,
    bool? readingPlan,
    bool? memorization,
    bool? trainers,
    bool? newContent,
    bool? systemMessages,
    bool? emailAnnouncements,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      bibleReading: bibleReading ?? this.bibleReading,
      readingPlan: readingPlan ?? this.readingPlan,
      memorization: memorization ?? this.memorization,
      trainers: trainers ?? this.trainers,
      newContent: newContent ?? this.newContent,
      systemMessages: systemMessages ?? this.systemMessages,
      emailAnnouncements: emailAnnouncements ?? this.emailAnnouncements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "push": {
        "enabled": pushEnabled,
        "bibleReading": bibleReading,
        "readingPlan": readingPlan,
        "memorization": memorization,
        "trainers": trainers,
        "newContent": newContent,
        "systemMessages": systemMessages,
      },
      "email": {"announcements": emailAnnouncements},
      "reminderMinutes": reminderMinutes,
    };
  }

  /// Fehlende oder ungültige Werte → Defaults.
  factory NotificationPreferences.fromMap(Object? data) {
    if (data is! Map) return defaults;

    final push = data["push"] is Map ? data["push"] as Map : const {};
    final email = data["email"] is Map ? data["email"] as Map : const {};

    bool read(Map map, String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    final minutes = data["reminderMinutes"];

    return NotificationPreferences(
      pushEnabled: read(push, "enabled", defaults.pushEnabled),
      reminderMinutes: minutes is int && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : defaultReminderMinutes,
      bibleReading: read(push, "bibleReading", defaults.bibleReading),
      readingPlan: read(push, "readingPlan", defaults.readingPlan),
      memorization: read(push, "memorization", defaults.memorization),
      trainers: read(push, "trainers", defaults.trainers),
      newContent: read(push, "newContent", defaults.newContent),
      systemMessages: read(push, "systemMessages", defaults.systemMessages),
      emailAnnouncements: read(
        email,
        "announcements",
        defaults.emailAnnouncements,
      ),
    );
  }

  /// Der nächste Zeitpunkt nach [now], an dem es [minutes] nach Mitternacht
  /// Ortszeit ist. Danach plant der Server selbst weiter.
  static DateTime nextReminderAfter(DateTime now, int minutes) {
    DateTime at(int day) {
      return DateTime(now.year, now.month, day, minutes ~/ 60, minutes % 60);
    }

    final today = at(now.day);

    return today.isAfter(now) ? today : at(now.day + 1);
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationPreferences &&
        other.pushEnabled == pushEnabled &&
        other.reminderMinutes == reminderMinutes &&
        other.bibleReading == bibleReading &&
        other.readingPlan == readingPlan &&
        other.memorization == memorization &&
        other.trainers == trainers &&
        other.newContent == newContent &&
        other.systemMessages == systemMessages &&
        other.emailAnnouncements == emailAnnouncements;
  }

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    reminderMinutes,
    bibleReading,
    readingPlan,
    memorization,
    trainers,
    newContent,
    systemMessages,
    emailAnnouncements,
  );
}

/// Laden/Speichern der [NotificationPreferences] eines Kontos.
class NotificationPreferencesService {
  NotificationPreferencesService({
    this._db,
    DateTime Function()? clock,
    String? Function()? timeZone,
  }) : _clock = clock ?? DateTime.now,
       _timeZone = timeZone ?? (() => PushPlatform().timeZone);

  final FirebaseFirestore? _db;
  final DateTime Function() _clock;
  final String? Function() _timeZone;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return (_db ?? FirebaseFirestore.instance).collection("users").doc(uid);
  }

  Future<NotificationPreferences> load(String uid) async {
    final doc = await _userDoc(uid).get();

    return NotificationPreferences.fromMap(
      doc.data()?[NotificationPreferences.field],
    );
  }

  // Schreibvorgänge nacheinander, damit schnelles Umschalten mehrerer
  // Schalter nie mit einem älteren Stand endet.
  Future<void> _queue = Future.value();

  /// Speichert den vollständigen Stand samt Zeitzone und dem nächsten
  /// Erinnerungszeitpunkt, nach dem der Server die fälligen Konten findet.
  Future<void> save(String uid, NotificationPreferences preferences) {
    final result = _queue.then((_) {
      final now = _clock();

      return _userDoc(uid).set({
        NotificationPreferences.field: {
          ...preferences.toMap(),
          "timeZone": _timeZone(),
          "utcOffsetMinutes": now.timeZoneOffset.inMinutes,
          "nextReminderAt": preferences.pushEnabled
              ? Timestamp.fromDate(
                  NotificationPreferences.nextReminderAfter(
                    now,
                    preferences.reminderMinutes,
                  ),
                )
              : FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    });

    _queue = result.then((_) {}, onError: (_) {});

    return result;
  }
}
