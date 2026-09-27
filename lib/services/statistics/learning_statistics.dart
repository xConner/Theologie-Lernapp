import '../streak/streak_state.dart';

/// Ein Trainer mit eigener Statistik. Anders als bei den Streaks (je Sprache)
/// wird jeder Trainer getrennt gezählt.
class StatisticsTrainer {
  /// Stabile Kennung, zugleich Dokument-ID unter `users/{uid}/statistics`.
  final String id;

  /// Anzeigename, z. B. "Vokabeltrainer".
  final String label;

  const StatisticsTrainer({required this.id, required this.label});

  static const StatisticsTrainer greekVocabulary = StatisticsTrainer(
    id: "greek_vocabulary",
    label: "Vokabeltrainer",
  );

  static const StatisticsTrainer greekGrammar = StatisticsTrainer(
    id: "greek_grammar",
    label: "Grammatiktrainer",
  );

  static const StatisticsTrainer latinVocabulary = StatisticsTrainer(
    id: "latin_vocabulary",
    label: "Latein-Vokabeltrainer",
  );

  static const StatisticsTrainer perikopenQuiz = StatisticsTrainer(
    id: "perikopen_quiz",
    label: "Perikopenquiz",
  );

  static const List<StatisticsTrainer> all = [
    greekVocabulary,
    greekGrammar,
    latinVocabulary,
    perikopenQuiz,
  ];
}

/// Bewertete Antworten eines Trainers an einem lokalen Kalendertag
/// ([date] im Format `yyyy-MM-dd`).
///
/// Gespeichert werden nur [correct] und [wrong]; [answered] ergibt sich
/// daraus, sodass immer `Fragen = richtig + falsch` gilt.
class DailyStatistics {
  final String date;
  final int correct;
  final int wrong;

  const DailyStatistics({
    required this.date,
    this.correct = 0,
    this.wrong = 0,
  });

  int get answered => correct + wrong;

  /// Richtigquote in Prozent; null, wenn nichts beantwortet wurde.
  double? get accuracy => answered == 0 ? null : correct / answered * 100;

  /// Stand nach einer weiteren bewerteten Antwort.
  DailyStatistics withAnswer({required bool correct}) {
    return DailyStatistics(
      date: date,
      correct: this.correct + (correct ? 1 : 0),
      wrong: wrong + (correct ? 0 : 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {"answered": answered, "correct": correct, "wrong": wrong};
  }

  /// Liest gespeicherte Daten; ungültige Werte werden als 0 gelesen.
  factory DailyStatistics.fromMap(String date, Map<dynamic, dynamic> data) {
    return DailyStatistics(
      date: date,
      correct: _int(data["correct"]),
      wrong: _int(data["wrong"]),
    );
  }

  static int _int(Object? value) {
    return value is num && value >= 0 ? value.toInt() : 0;
  }
}

/// Tage eines Trainers, nach Datum (`yyyy-MM-dd`).
typedef TrainerDays = Map<String, DailyStatistics>;

/// Reine, kalenderbasierte Statistik-Berechnung ohne Speicherzugriff.
class StatisticsCalculator {
  StatisticsCalculator._();

  static final RegExp _datePattern = RegExp(r"^\d{4}-\d{2}-\d{2}$");

  static bool isDateKey(String value) => _datePattern.hasMatch(value);

  /// Lokaler Kalendertag (gleiches Format wie bei den Streaks).
  static String dateKey(DateTime date) => StreakCalculator.dateKey(date);

  /// Die letzten [count] lokalen Kalendertage einschließlich heute, ältester
  /// zuerst (unabhängig von Sommerzeit-Umstellungen).
  static List<DateTime> lastDays(DateTime now, {int count = 7}) {
    return [
      for (var i = count - 1; i >= 0; i--)
        DateTime(now.year, now.month, now.day - i),
    ];
  }

  /// Statistik der letzten [count] Kalendertage, Tage ohne Aktivität mit 0.
  /// Der letzte Eintrag ist heute.
  static List<DailyStatistics> lastDaysStatistics(
    TrainerDays days,
    DateTime now, {
    int count = 7,
  }) {
    return [
      for (final day in lastDays(now, count: count))
        days[dateKey(day)] ?? DailyStatistics(date: dateKey(day)),
    ];
  }

  /// Richtigquote für die Anzeige, z. B. "75 %"; "–" ohne Antworten.
  ///
  /// Gerundet, aber nie 100 % mit falschen bzw. 0 % mit richtigen
  /// Antworten.
  static String formatAccuracy(int correct, int answered) {
    if (answered <= 0) {
      return "–";
    }

    var percent = (correct * 100 / answered).round();

    if (correct < answered && percent == 100) percent = 99;
    if (correct > 0 && percent == 0) percent = 1;

    return "$percent %";
  }

  static const List<String> _weekdays = [
    "Mo",
    "Di",
    "Mi",
    "Do",
    "Fr",
    "Sa",
    "So",
  ];

  /// Wochentag-Kürzel, z. B. "Mo".
  static String weekdayLabel(DateTime date) => _weekdays[date.weekday - 1];

  /// Datum, z. B. "21.09.".
  static String shortDate(DateTime date) {
    final d = date.day.toString().padLeft(2, "0");
    final m = date.month.toString().padLeft(2, "0");

    return "$d.$m.";
  }

  /// Liest einen `yyyy-MM-dd`-Schlüssel als lokales Datum.
  static DateTime parseDateKey(String key) {
    final parts = key.split("-").map(int.parse).toList();

    return DateTime(parts[0], parts[1], parts[2]);
  }
}
