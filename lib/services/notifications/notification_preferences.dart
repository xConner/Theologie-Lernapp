import 'package:cloud_firestore/cloud_firestore.dart';

/// Benachrichtigungs-Einstellungen eines Kontos, gespeichert als Feld
/// `notification_settings` im Dokument `users/{uid}` (wie die übrigen
/// Einstellungen). Der serverseitige Versand von Push und E-Mail liest
/// dieses Feld; die In-App-Glocke ist davon unabhängig.
///
/// Bewusst gibt es KEINE Einstellungen für allgemeine Lernerinnerungen oder
/// fällige Wiederholungen – beides wird nicht versendet. Die einzige
/// persönliche Lern-Erinnerung ist die Streak-Erinnerung.
///
/// Firestore-Format:
///   notification_settings: {
///     push:  { enabled, streakReminders, newContent, systemMessages },
///     email: { announcements },
///     utcOffsetMinutes,   // für Streak-Erinnerungen zur lokalen Tageszeit
///   }
class NotificationPreferences {
  /// Hauptschalter für Push auf diesem Konto (Opt-in).
  final bool pushEnabled;

  /// Höchstens eine Erinnerung je Track und Tag, nur wenn eine laufende
  /// Streak heute noch nicht gesichert ist.
  final bool streakReminders;

  final bool newContent;

  final bool systemMessages;

  /// Bewusst veröffentlichte wichtige Nachrichten per E-Mail (Opt-in).
  /// Auth-Mails (Passwort, Bestätigung) sind davon unabhängig.
  final bool emailAnnouncements;

  const NotificationPreferences({
    this.pushEnabled = false,
    this.streakReminders = true,
    this.newContent = false,
    this.systemMessages = true,
    this.emailAnnouncements = false,
  });

  static const NotificationPreferences defaults = NotificationPreferences();

  static const String field = "notification_settings";

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? streakReminders,
    bool? newContent,
    bool? systemMessages,
    bool? emailAnnouncements,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      streakReminders: streakReminders ?? this.streakReminders,
      newContent: newContent ?? this.newContent,
      systemMessages: systemMessages ?? this.systemMessages,
      emailAnnouncements: emailAnnouncements ?? this.emailAnnouncements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "push": {
        "enabled": pushEnabled,
        "streakReminders": streakReminders,
        "newContent": newContent,
        "systemMessages": systemMessages,
      },
      "email": {"announcements": emailAnnouncements},
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

    return NotificationPreferences(
      pushEnabled: read(push, "enabled", defaults.pushEnabled),
      streakReminders: read(push, "streakReminders", defaults.streakReminders),
      newContent: read(push, "newContent", defaults.newContent),
      systemMessages: read(push, "systemMessages", defaults.systemMessages),
      emailAnnouncements: read(
        email,
        "announcements",
        defaults.emailAnnouncements,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationPreferences &&
        other.pushEnabled == pushEnabled &&
        other.streakReminders == streakReminders &&
        other.newContent == newContent &&
        other.systemMessages == systemMessages &&
        other.emailAnnouncements == emailAnnouncements;
  }

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    streakReminders,
    newContent,
    systemMessages,
    emailAnnouncements,
  );
}

/// Laden/Speichern der [NotificationPreferences] eines Kontos.
class NotificationPreferencesService {
  NotificationPreferencesService({
    FirebaseFirestore? db,
    DateTime Function()? clock,
  }) : _db = db ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection("users").doc(uid);
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

  /// Speichert den vollständigen Stand (inkl. aktueller UTC-Abweichung für
  /// die zeitliche Planung von Streak-Erinnerungen).
  Future<void> save(String uid, NotificationPreferences preferences) {
    final result = _queue.then((_) {
      return _userDoc(uid).set({
        NotificationPreferences.field: {
          ...preferences.toMap(),
          "utcOffsetMinutes": _clock().timeZoneOffset.inMinutes,
          "updatedAt": FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    });

    _queue = result.then((_) {}, onError: (_) {});

    return result;
  }
}
