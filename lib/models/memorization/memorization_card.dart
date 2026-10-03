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

  static const int maxLevel = 5;

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
    return MemorizationCard(
      id: base.id,
      stability: base.stability,
      difficulty: base.difficulty,
      lastReviewed: lastReviewed,
      mnemonic: base.mnemonic,
      level: _count(data["level"]).clamp(0, maxLevel),
      attempts: _count(data["attempts"]),
      successes: _count(data["successes"]),
      failures: _count(data["failures"]),
      learned: data["learned"] == true,
      startedAt: startedAt,
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ...super.toFirestore(),
      ..._extras,
      "startedAt": startedAt == null ? null : Timestamp.fromDate(startedAt!),
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      ..._extras,
      "startedAt": startedAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> get _extras {
    return {
      "level": level,
      "attempts": attempts,
      "successes": successes,
      "failures": failures,
      "learned": learned,
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
