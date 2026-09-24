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

  const StreakTrack({
    required this.id,
    required this.label,
    required this.sources,
    this.dailyGoal = defaultDailyGoal,
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

  /// Alle in der App verfügbaren Tracks (Reihenfolge = Anzeige-Reihenfolge).
  static const List<StreakTrack> all = [greek, latin, perikope];
}

/// Herkunft einer richtigen Antwort innerhalb eines Tracks.
class StreakSource {
  StreakSource._();

  static const String vocabulary = "vocabulary";
  static const String grammar = "grammar";
  static const String perikopenQuiz = "perikopen_quiz";

  static const Map<String, String> labels = {
    vocabulary: "Vokabeln",
    grammar: "Grammatik",
    perikopenQuiz: "Perikopen",
  };

  static String label(String source) => labels[source] ?? source;
}
