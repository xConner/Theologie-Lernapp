import 'dart:math' as math;

import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';

/// Lernstand einer Perikope beim systematischen Lernen eines Buchs.
///
/// Erweitert die [LearningCard] des Endlos-Quiz um Zähler, aus denen sich
/// der Status ableitet. Die Wiederholungsabstände rechnet dieselbe
/// [SpacedRepetition] wie im Endlos-Quiz.
///
/// Gespeichert wird kompakt (Zeitpunkte als Millisekunden) in einem
/// Dokument je Nutzer, getrennt von den Karten des Endlos-Quiz
/// (siehe `BookLearningStorage`).
class BookCard extends LearningCard {
  /// Richtige bzw. falsche Abrufe insgesamt.
  int correctCount;
  int wrongCount;

  /// Richtige Abrufe in Folge, die jeweils mindestens
  /// [BookLearningRules.minSpacing] nach der vorigen Abfrage lagen. Ein
  /// Fehler setzt den Wert auf 0.
  int spacedStreak;

  DateTime? lastWrong;

  /// Wann die Perikope beim Lernen des Buchs eingeführt wurde.
  DateTime? introducedAt;

  /// Ergebnisse der Reihenfolge-Aufgaben. Sie ändern weder Status noch
  /// Wiederholungsabstand der Stelle.
  int orderCorrect;
  int orderWrong;

  /// Nach dem Zurücksetzen eines Buchs: Der Lernstand des Endlos-Quiz gilt
  /// für diese Perikope nicht mehr als Startwert (sonst wäre der gerade
  /// gelöschte Fortschritt über die gemeinsame Perikopen-ID sofort wieder da).
  bool ignoreEndlessQuiz;

  BookCard({
    required super.id,
    super.stability,
    super.difficulty,
    super.lastReviewed,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.spacedStreak = 0,
    this.lastWrong,
    this.introducedAt,
    this.orderCorrect = 0,
    this.orderWrong = 0,
    this.ignoreEndlessQuiz = false,
  });

  /// Erste Karte für eine Perikope, die im Endlos-Quiz schon gelernt wurde:
  /// Abstand, Schwierigkeit und letzte Abfrage werden übernommen, damit
  /// niemand von vorn beginnen muss. Hat das Endlos-Quiz bereits einen
  /// langen Abstand ermittelt, gilt die Perikope als sicher (siehe
  /// [BookLearningRules.legacySecureStability]).
  factory BookCard.seeded(String id, LearningCard? legacy) {
    if (legacy == null || legacy.lastReviewed == null) {
      return BookCard(id: id);
    }

    return BookCard(
      id: id,
      stability: legacy.stability,
      difficulty: legacy.difficulty,
      lastReviewed: legacy.lastReviewed,
      spacedStreak: BookLearningRules.legacyIsSecure(legacy)
          ? BookLearningRules.secureSpacedRecalls
          : 0,
    );
  }

  bool get started =>
      lastReviewed != null || introducedAt != null || orderAnswered;

  bool get orderAnswered => orderCorrect + orderWrong > 0;

  static DateTime? _time(Object? value) {
    return value is num && value.isFinite
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : null;
  }

  static int _count(Object? value) {
    return value is num && value.isFinite ? math.max(0, value.toInt()) : 0;
  }

  /// Ungültige Werte fallen auf die Defaults zurück.
  factory BookCard.fromJson(String id, Map<String, dynamic> data) {
    final card = BookCard(id: id);

    final s = data["s"];
    final d = data["d"];

    if (s is num && s.isFinite && s > 0) card.stability = s.toDouble();
    if (d is num && d.isFinite) card.difficulty = d.toDouble();

    card.lastReviewed = _time(data["r"]);
    card.correctCount = _count(data["n"]);
    card.wrongCount = _count(data["w"]);
    card.spacedStreak = _count(data["sp"]);
    card.lastWrong = _time(data["lw"]);
    card.introducedAt = _time(data["i"]);
    card.orderCorrect = _count(data["oc"]);
    card.orderWrong = _count(data["ow"]);
    card.ignoreEndlessQuiz = data["nl"] == true;

    return card;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "s": stability,
      "d": difficulty,
      "r": lastReviewed?.millisecondsSinceEpoch,
      "n": correctCount,
      "w": wrongCount,
      "sp": spacedStreak,
      "lw": lastWrong?.millisecondsSinceEpoch,
      "i": introducedAt?.millisecondsSinceEpoch,
      "oc": orderCorrect,
      "ow": orderWrong,
      if (ignoreEndlessQuiz) "nl": true,
    };
  }
}

/// Fortschrittsstufe; „fällig“ ist davon unabhängig (siehe [PericopeStatus]).
enum LearningLevel { fresh, learning, secure }

extension LearningLevelLabel on LearningLevel {
  String get label {
    switch (this) {
      case LearningLevel.fresh:
        return "Neu";
      case LearningLevel.learning:
        return "In Bearbeitung";
      case LearningLevel.secure:
        return "Sicher gelernt";
    }
  }
}

/// Status einer Perikope. Stufe und Fälligkeit sind getrennt: Eine sicher
/// gelernte Perikope kann zugleich zur Wiederholung fällig sein.
class PericopeStatus {
  final LearningLevel level;

  /// Die Wiederholung steht jetzt an.
  final bool due;

  /// Wann die nächste Wiederholung ansteht (`null` bei neuen Perikopen).
  final DateTime? dueAt;

  final bool recentlyWrong;

  final bool difficult;

  /// Der Stand stammt (noch) aus dem Endlos-Quiz.
  final bool fromEndlessQuiz;

  final int wrongCount;

  const PericopeStatus({
    required this.level,
    this.due = false,
    this.dueAt,
    this.recentlyWrong = false,
    this.difficult = false,
    this.fromEndlessQuiz = false,
    this.wrongCount = 0,
  });

  static const PericopeStatus fresh = PericopeStatus(
    level: LearningLevel.fresh,
  );

  String get label =>
      due ? "${level.label} · Wiederholung fällig" : level.label;
}

/// Die Regeln, nach denen der Status entsteht – an einer Stelle, damit sie
/// sich nachvollziehen und testen lassen (siehe docs/pericope-books.md).
class BookLearningRules {
  BookLearningRules._();

  /// Ein richtiger Abruf zählt erst als „zeitlich getrennt“, wenn seit der
  /// vorigen Abfrage mindestens so viel Zeit vergangen ist. Wer die Lösung
  /// gerade gesehen hat, erfüllt das nicht.
  static const Duration minSpacing = Duration(hours: 12);

  /// So viele zeitlich getrennte richtige Abrufe in Folge machen eine
  /// Perikope „sicher gelernt“.
  static const int secureSpacedRecalls = 2;

  /// Karten des Endlos-Quiz mit mindestens diesem Abstand (Stunden) gelten
  /// als sicher. Die SpacedRepetition vergrößert den Abstand nur bei
  /// richtigen Antworten mit zeitlichem Abstand; 3 Tage erreicht eine Karte
  /// erst nach mehreren solchen Abrufen.
  static const double legacySecureStability = 72;

  /// „Kürzlich falsch“: Fehler in diesem Zeitraum.
  static const Duration recentWindow = Duration(days: 7);

  /// „Schwierig“: mindestens so viele Fehler und noch erhöhte
  /// Schwierigkeit (Startwert 5, +1 je Fehler, bis −0,5 je Treffer).
  static const int difficultMinWrong = 2;
  static const double difficultMinDifficulty = 6;

  static bool legacyIsSecure(LearningCard card) =>
      card.lastReviewed != null && card.stability >= legacySecureStability;

  static DateTime dueAt(LearningCard card) {
    return card.lastReviewed!.add(
      Duration(minutes: (card.stability * 60).round()),
    );
  }

  /// Status aus der Buch-Karte, ersatzweise aus der Karte des Endlos-Quiz.
  static PericopeStatus statusOf(
    BookCard? card,
    LearningCard? legacy,
    DateTime now,
  ) {
    if (card != null && card.lastReviewed != null) {
      final dueAt = BookLearningRules.dueAt(card);

      final lastWrong = card.lastWrong;

      return PericopeStatus(
        level: card.spacedStreak >= secureSpacedRecalls
            ? LearningLevel.secure
            : LearningLevel.learning,
        due: !dueAt.isAfter(now),
        dueAt: dueAt,
        recentlyWrong:
            lastWrong != null && now.difference(lastWrong) <= recentWindow,
        difficult:
            card.wrongCount >= difficultMinWrong &&
            card.difficulty >= difficultMinDifficulty,
        wrongCount: card.wrongCount,
      );
    }

    if (legacy != null &&
        legacy.lastReviewed != null &&
        !(card?.ignoreEndlessQuiz ?? false)) {
      final dueAt = BookLearningRules.dueAt(legacy);

      return PericopeStatus(
        level: legacyIsSecure(legacy)
            ? LearningLevel.secure
            : LearningLevel.learning,
        due: !dueAt.isAfter(now),
        dueAt: dueAt,
        fromEndlessQuiz: true,
      );
    }

    // Eingeführt, aber noch nie abgefragt.
    if (card != null && card.introducedAt != null) {
      return const PericopeStatus(level: LearningLevel.learning);
    }

    return PericopeStatus.fresh;
  }

  /// Verbucht einen Abruf der Stelle.
  ///
  /// [revealed]: Die Lösung war vorher sichtbar (z. B. direkt nach der
  /// Einführung). Dann zählt eine richtige Antwort nie als zeitlich
  /// getrennter Abruf.
  static void recordRecall(
    BookCard card,
    bool correct,
    SpacedRepetition algorithm,
    DateTime now, {
    bool revealed = false,
  }) {
    final previous = card.lastReviewed;

    final spaced =
        !revealed && previous != null && now.difference(previous) >= minSpacing;

    algorithm.answer(card, correct);

    if (correct) {
      card.correctCount++;

      if (spaced) card.spacedStreak++;
    } else {
      card.wrongCount++;
      card.spacedStreak = 0;
      card.lastWrong = now;
    }
  }

  static void recordOrder(BookCard card, bool correct) {
    if (correct) {
      card.orderCorrect++;
    } else {
      card.orderWrong++;
    }
  }
}

/// Zählung für ein Buch, ein Kapitel oder eine Auswahl.
class LearningProgress {
  final int total;
  final int fresh;
  final int learning;
  final int secure;
  final int due;

  const LearningProgress({
    this.total = 0,
    this.fresh = 0,
    this.learning = 0,
    this.secure = 0,
    this.due = 0,
  });

  factory LearningProgress.of(Iterable<PericopeStatus> statuses) {
    int total = 0, fresh = 0, learning = 0, secure = 0, due = 0;

    for (final s in statuses) {
      total++;

      switch (s.level) {
        case LearningLevel.fresh:
          fresh++;
        case LearningLevel.learning:
          learning++;
        case LearningLevel.secure:
          secure++;
      }

      if (s.due) due++;
    }

    return LearningProgress(
      total: total,
      fresh: fresh,
      learning: learning,
      secure: secure,
      due: due,
    );
  }

  /// Anteil sicher gelernter Perikopen (0–1).
  double get secureShare => total == 0 ? 0 : secure / total;

  /// Anteil begonnener Perikopen (0–1).
  double get startedShare => total == 0 ? 0 : (secure + learning) / total;
}
