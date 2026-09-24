import 'package:cloud_firestore/cloud_firestore.dart';

/// Kategorie einer Nachricht in der Glocke.
///
/// Bewusst KEINE Kategorie für Streaks, Tagesziel oder Lernfortschritt –
/// diese gehören auf Home bzw. in die Trainer. Neue Kategorie → hier
/// ergänzen (stabiler [id] = Wert in Firestore) und in der Glocken-UI ein
/// Icon vergeben.
enum NotificationCategory {
  /// Neue Inhalte (Vokabeln, Perikopenfragen, Trainer, Module).
  content("content", "Neue Inhalte"),

  /// Wartung, Störungen, wichtige technische Änderungen und Funktionen.
  system("system", "System"),

  /// Sicherheitsrelevante Ereignisse des eigenen Kontos (nur persönlich).
  account("account", "Account & Sicherheit"),

  /// Bewusst veröffentlichte Nachricht des Betreibers.
  announcement("announcement", "Nachricht von theologie.app");

  final String id;
  final String label;

  const NotificationCategory(this.id, this.label);

  static NotificationCategory? fromId(Object? id) {
    for (final category in values) {
      if (category.id == id) return category;
    }

    return null;
  }
}

enum NotificationPriority {
  normal("normal"),
  high("high");

  final String id;

  const NotificationPriority(this.id);

  static NotificationPriority fromId(Object? id) {
    return id == high.id ? high : normal;
  }
}

/// Woher eine Nachricht stammt – bestimmt Speicherort und Sichtbarkeit.
enum NotificationScope {
  /// `notifications/{id}`: für alle Nutzer (inkl. Gäste) veröffentlicht.
  global("g"),

  /// `users/{uid}/inbox/{id}`: nur für diesen Nutzer (z. B. Account).
  personal("u");

  final String prefix;

  const NotificationScope(this.prefix);
}

/// Auf welchen Kanälen eine Nachricht ausgeliefert wird bzw. wurde.
///
/// Eine Nachricht ist EIN inhaltliches Objekt; Push und E-Mail sind nur
/// zusätzliche Auslieferungen desselben Objekts (serverseitig, unter
/// Beachtung der Nutzer-Einstellungen). Der Client wertet nur [inApp] aus.
class NotificationChannels {
  final bool inApp;
  final bool push;
  final bool email;

  const NotificationChannels({
    this.inApp = true,
    this.push = false,
    this.email = false,
  });

  factory NotificationChannels.fromMap(Object? data) {
    if (data is! Map) return const NotificationChannels();

    return NotificationChannels(
      inApp: data["inApp"] != false,
      push: data["push"] == true,
      email: data["email"] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {"inApp": inApp, "push": push, "email": email};
  }
}

/// Eine Nachricht der In-App-Glocke.
///
/// Firestore-Felder (global und persönlich identisch):
///   category   String   – siehe [NotificationCategory]
///   title      String
///   body       String
///   createdAt  Timestamp
///   expiresAt  Timestamp? – danach nicht mehr angezeigt
///   deepLink   String?    – siehe AppDeepLink, z. B. "/greek/vocabulary"
///   priority   String?    – "normal" | "high"
///   channels   Map?       – {inApp, push, email}
///
/// Der Lesestatus ist NICHT Teil der Nachricht, sondern wird je Nutzer in
/// `NotificationReadState` gespeichert (keine Kopien je Nutzer).
class AppNotification {
  final String id;
  final NotificationScope scope;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? deepLink;
  final NotificationPriority priority;
  final NotificationChannels channels;

  const AppNotification({
    required this.id,
    required this.scope,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.expiresAt,
    this.deepLink,
    this.priority = NotificationPriority.normal,
    this.channels = const NotificationChannels(),
  });

  /// Eindeutiger Schlüssel über globale und persönliche Nachrichten hinweg
  /// (für den Lesestatus).
  String get key => "${scope.prefix}:$id";

  bool isExpired(DateTime now) {
    final expires = expiresAt;
    return expires != null && !now.isBefore(expires);
  }

  /// Soll in der Glocke erscheinen?
  bool isVisible(DateTime now) => channels.inApp && !isExpired(now);

  /// Liest ein Firestore-Dokument. Liefert null bei ungültigen oder
  /// unvollständigen Daten, damit eine fehlerhaft angelegte Nachricht die
  /// Glocke nicht stört. Account-Nachrichten werden nur persönlich
  /// akzeptiert.
  static AppNotification? tryParse(
    String id,
    Map<String, dynamic> data, {
    required NotificationScope scope,
  }) {
    final category = NotificationCategory.fromId(data["category"]);
    final title = data["title"];
    final body = data["body"];
    final createdAt = _dateTime(data["createdAt"]);

    if (category == null ||
        title is! String ||
        title.trim().isEmpty ||
        createdAt == null) {
      return null;
    }

    if (category == NotificationCategory.account &&
        scope != NotificationScope.personal) {
      return null;
    }

    final deepLink = data["deepLink"];

    return AppNotification(
      id: id,
      scope: scope,
      category: category,
      title: title.trim(),
      body: body is String ? body.trim() : "",
      createdAt: createdAt,
      expiresAt: _dateTime(data["expiresAt"]),
      deepLink: deepLink is String && deepLink.trim().isNotEmpty
          ? deepLink.trim()
          : null,
      priority: NotificationPriority.fromId(data["priority"]),
      channels: NotificationChannels.fromMap(data["channels"]),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
