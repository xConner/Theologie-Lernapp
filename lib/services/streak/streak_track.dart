/// Ein Lernbereich mit eigener täglicher Streak (z. B. eine Sprache oder ein
/// Quiz). Mehrere Trainer können zu demselben Track beitragen – z. B.
/// Vokabel- und Grammatiktrainer zum Track "greek".
///
/// Neue Sprache / neues Quiz → neuen Track anlegen und in [all] eintragen.
/// Neuer Trainer für eine bestehende Sprache → [StreakSource] ergänzen und
/// in [sources] des Tracks aufnehmen.
class StreakTrack {
  /// Stabile Kennung, zugleich Dokument-ID unter `users/{uid}/streaks`.
  final String id;

  /// Anzeigename, z. B. "Altgriechisch".
  final String label;

  /// Trainer/Quizze, die zu diesem Track beitragen (für die Aufschlüsselung
  /// "Heute" in der Detailansicht).
  final List<String> sources;

  /// Richtige Antworten pro Kalendertag, um die Streak fortzuführen.
  final int dailyGoal;

  /// Meldung beim Start einer Streak, falls sich [label] nicht zu
  /// "…-Streak" zusammensetzen lässt (mehrteilige Namen).
  final String? streakStartedMessage;

  const StreakTrack({
    required this.id,
    required this.label,
    required this.sources,
    this.dailyGoal = defaultDailyGoal,
    this.streakStartedMessage,
  });

  static const int defaultDailyGoal = 10;

  static const StreakTrack greek = StreakTrack(
    id: "greek",
    label: "Altgriechisch",
    sources: [StreakSource.vocabulary, StreakSource.grammar],
  );

  static const StreakTrack latin = StreakTrack(
    id: "latin",
    label: "Latein",
    sources: [StreakSource.vocabulary],
  );

  static const StreakTrack perikope = StreakTrack(
    id: "perikope",
    label: "Perikopen",
    sources: [StreakSource.perikopenQuiz],
  );

  /// Texte auswendig lernen: Das Tagesziel sind zehn wortgetreu richtige
  /// Eingaben (siehe `MemorizationStreakRule`), unabhängig von der Zahl der
  /// Texte und vom Wiederholungsplan.
  static const StreakTrack memorization = StreakTrack(
    id: "memorization",
    label: "Texte auswendig lernen",
    sources: [StreakSource.memorization],
    streakStartedMessage: "Streak für „Texte auswendig lernen“ gestartet!",
  );

  /// Bibellesen: Der Tag zählt, sobald der Nutzer eine Lesung ausdrücklich
  /// bestätigt hat – frei gewählt oder aus einem Leseplan (siehe
  /// `BibleReadingService`). Weitere Lesungen am selben Tag ändern nichts.
  static const StreakTrack bible = StreakTrack(
    id: "bible",
    label: "Bibellesen",
    sources: [StreakSource.bibleReading, StreakSource.readingPlan],
    dailyGoal: 1,
  );

  /// Alle in der App verfügbaren Tracks (Reihenfolge = Anzeige-Reihenfolge).
  static const List<StreakTrack> all = [
    greek,
    latin,
    perikope,
    memorization,
    bible,
  ];
}

/// Herkunft einer richtigen Antwort innerhalb eines Tracks.
class StreakSource {
  StreakSource._();

  static const String vocabulary = "vocabulary";
  static const String grammar = "grammar";
  static const String perikopenQuiz = "perikopen_quiz";
  static const String memorization = "memorization";
  static const String bibleReading = "bible_reading";
  static const String readingPlan = "reading_plan";

  static const Map<String, String> labels = {
    vocabulary: "Vokabeln",
    grammar: "Grammatik",
    perikopenQuiz: "Perikopen",
    memorization: "Texte auswendig lernen",
    bibleReading: "Freie Lesung",
    readingPlan: "Leseplan",
  };

  static String label(String source) => labels[source] ?? source;
}
