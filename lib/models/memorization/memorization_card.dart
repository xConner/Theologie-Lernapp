import 'package:cloud_firestore/cloud_firestore.dart';

import '../greek/vocabulary/learning_card.dart';

/// Lernstand eines Abschnitts (oder des ganzen Textes) beim Auswendiglernen.
///
/// Erweitert die gemeinsame [LearningCard]: `stability`, `difficulty` und
/// `lastReviewed` werden wie in den anderen Trainern von `SpacedRepetition`
/// geführt. Hinzu kommen nur die Angaben, die das schrittweise Lernen
/// braucht.
class MemorizationCard extends LearningCard {
  /// Aktuelle Hilfestufe (Index von `HintLevel`): 0 = Mitlesen … 5 = frei.
  int level;

  /// Ausgewertete Versuche (ohne reines Mitlesen).
  int attempts;

  /// Freie Abrufe ohne Fehler bzw. mit Fehlern.
  int successes;
  int failures;

  /// Wurde der Abschnitt schon einmal frei und fehlerlos wiedergegeben?
  bool learned;

  /// Erste Beschäftigung mit dem Abschnitt (für die Tagesmenge neuer
  /// Abschnitte).
  DateTime? startedAt;

  // Kurzfristiger Übungsstand – getrennt von der langfristigen `stability`.
  // Er reagiert auf jede freie Wiedergabe, auch auf mehrere kurz
  // hintereinander; der Wiederholungsabstand wächst dagegen nur mit der
  // Zeit zwischen den Wiedergaben.

  /// Fehlerfreie freie Wiedergaben, die nach einem Fehler noch ausstehen,
  /// bis der Abschnitt wieder als gelernt gilt (0 = nichts offen).
  int relearn;

  /// Fehlerfreie freie Wiedergaben in Folge seit dem letzten Fehler.
  int streak;

  /// Letzter Fehler bei freier Wiedergabe.
  DateTime? lastLapse;

  static const int maxLevel = 5;

  /// Unter diesem Abstand (Stunden) galt ein Abschnitt mit Fehlern vor der
  /// Einführung von [relearn] als unsicher.
  static const double _legacyLapseHours = 0.5;

  MemorizationCard({
    required super.id,
    super.stability,
    super.difficulty,
    super.lastReviewed,
    super.mnemonic,
    this.level = 0,
    this.attempts = 0,
    this.successes = 0,
    this.failures = 0,
    this.learned = false,
    this.startedAt,
    this.relearn = 0,
    this.streak = 0,
    this.lastLapse,
  });

  bool get isStarted => startedAt != null || attempts > 0 || level > 0;

  factory MemorizationCard.fromFirestore(String id, Map<String, dynamic> data) {
    final base = LearningCard.fromJson(id, {
      "stability": data["stability"],
      "difficulty": data["difficulty"],
      "mnemonic": data["mnemonic"],
    });

    return MemorizationCard._from(
      base,
      data,
      lastReviewed: _date(data["lastReviewed"]),
      startedAt: _date(data["startedAt"]),
    );
  }

  /// Lokale Speicherung im Gastmodus; ungültige Werte fallen auf die
  /// Defaults zurück.
  factory MemorizationCard.fromJson(String id, Map<String, dynamic> data) {
    final base = LearningCard.fromJson(id, data);

    return MemorizationCard._from(
      base,
      data,
      lastReviewed: base.lastReviewed,
      startedAt: _date(data["startedAt"]),
    );
  }

  factory MemorizationCard._from(
    LearningCard base,
    Map<String, dynamic> data, {
    required DateTime? lastReviewed,
    required DateTime? startedAt,
  }) {
    final learned = data["learned"] == true;
    final successes = _count(data["successes"]);
    final failures = _count(data["failures"]);

    // Lernstände von vor der Einführung des Kurzzeit-Stands: Was bisher
    // wegen eines Fehlers als unsicher galt, braucht noch eine fehlerfreie
    // Wiedergabe; alles andere gilt als bestätigt. Der Lernfortschritt
    // selbst bleibt unverändert.
    final legacy = !data.containsKey("relearn");
    final legacyShaky =
        legacy &&
        learned &&
        failures > 0 &&
        base.stability < _legacyLapseHours;

    return MemorizationCard(
      id: base.id,
      stability: base.stability,
      difficulty: base.difficulty,
      lastReviewed: lastReviewed,
      mnemonic: base.mnemonic,
      level: _count(data["level"]).clamp(0, maxLevel),
      attempts: _count(data["attempts"]),
      successes: successes,
      failures: failures,
      learned: learned,
      startedAt: startedAt,
      relearn: legacy ? (legacyShaky ? 1 : 0) : _count(data["relearn"]),
      streak: legacy
          ? (learned && !legacyShaky ? successes.clamp(0, 2) : 0)
          : _count(data["streak"]),
      lastLapse: _date(data["lastLapse"]),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ...super.toFirestore(),
      ..._extras,
      "startedAt": startedAt == null ? null : Timestamp.fromDate(startedAt!),
      "lastLapse": lastLapse == null ? null : Timestamp.fromDate(lastLapse!),
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      ..._extras,
      "startedAt": startedAt?.millisecondsSinceEpoch,
      "lastLapse": lastLapse?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> get _extras {
    return {
      "level": level,
      "attempts": attempts,
      "successes": successes,
      "failures": failures,
      "learned": learned,
      "relearn": relearn,
      "streak": streak,
    };
  }

  static int _count(Object? value) {
    return value is num && value.isFinite && value >= 0 ? value.toInt() : 0;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();

    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    return null;
  }
}
