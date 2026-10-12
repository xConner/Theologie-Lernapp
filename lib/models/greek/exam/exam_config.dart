import '../../../services/greek/exam/grammar_phenomena.dart';

/// Konfiguration einer Übungsklausur. Wird je Nutzer gespeichert
/// (`ExamStore`); ungültige oder unbekannte Werte fallen beim Lesen auf die
/// Defaults zurück.
class ExamConfig {
  /// Ausgewählte Textkorpora (`corpora.json`).
  final List<String> corpusIds;

  /// Ausgewählte Bücher; leer = alle Bücher der ausgewählten Korpora.
  final List<String> bookIds;

  /// Kapitelbereich (nur wenn genau ein Buch gewählt ist), sonst `null`.
  final int? chapterFrom;
  final int? chapterTo;

  /// Konkrete Textstelle statt automatischer Auswahl (Passage-ID), sonst
  /// `null`.
  final String? fixedPassage;

  final int minWords;
  final int maxWords;

  /// Höchstzahl der Vokabelhilfen (Schwierigkeit); `null` = beliebig.
  final int? maxHints;

  /// Bereits bearbeitete Abschnitte (und Überschneidungen) ausschließen.
  final bool excludeDone;

  /// Anforderungen je Phänomen; fehlende Einträge = erlaubt.
  final Map<String, PhenomenonRequirement> requirements;

  /// Vokabelschritte (Lernschritte der Vokabelliste), die als bekannt gelten.
  final List<int> knownSteps;

  /// Anzahl der Verbformen in Aufgabe 2.
  final int verbCount;

  /// Aufgabenarten der Aufgaben 3 und 4 (`ExamTaskTypes`).
  final List<String> extraTaskTypes;

  const ExamConfig({
    this.corpusIds = const ["nt"],
    this.bookIds = const [],
    this.chapterFrom,
    this.chapterTo,
    this.fixedPassage,
    this.minWords = defaultMinWords,
    this.maxWords = defaultMaxWords,
    this.maxHints,
    this.excludeDone = true,
    this.requirements = const {},
    this.knownSteps = allSteps,
    this.verbCount = 5,
    this.extraTaskTypes = defaultExtraTasks,
  });

  static const int defaultMinWords = 60;
  static const int defaultMaxWords = 120;

  /// Grenzen der Wortzahl in der Oberfläche.
  static const int lowestWords = 10;
  static const int highestWords = 300;

  static const int maxVerbCount = 12;

  /// Lernschritte der Vokabelliste (siehe `VocabularySettings.allSteps`).
  static const List<int> allSteps = [1, 2, 3, 4, 5, 6, 7, 8];

  static const List<String> defaultExtraTasks = ["find_forms", "noun_parsing"];

  PhenomenonRequirement requirementOf(String phenomenonId) =>
      requirements[phenomenonId] ?? PhenomenonRequirement.allowed;

  Iterable<String> get requiredPhenomena => requirements.entries
      .where((e) => e.value == PhenomenonRequirement.required)
      .map((e) => e.key);

  Iterable<String> get excludedPhenomena => requirements.entries
      .where((e) => e.value == PhenomenonRequirement.excluded)
      .map((e) => e.key);

  ExamConfig copyWith({
    List<String>? corpusIds,
    List<String>? bookIds,
    int? Function()? chapterFrom,
    int? Function()? chapterTo,
    String? Function()? fixedPassage,
    int? minWords,
    int? maxWords,
    int? Function()? maxHints,
    bool? excludeDone,
    Map<String, PhenomenonRequirement>? requirements,
    List<int>? knownSteps,
    int? verbCount,
    List<String>? extraTaskTypes,
  }) {
    return ExamConfig(
      corpusIds: corpusIds ?? this.corpusIds,
      bookIds: bookIds ?? this.bookIds,
      chapterFrom: chapterFrom != null ? chapterFrom() : this.chapterFrom,
      chapterTo: chapterTo != null ? chapterTo() : this.chapterTo,
      fixedPassage: fixedPassage != null ? fixedPassage() : this.fixedPassage,
      minWords: minWords ?? this.minWords,
      maxWords: maxWords ?? this.maxWords,
      maxHints: maxHints != null ? maxHints() : this.maxHints,
      excludeDone: excludeDone ?? this.excludeDone,
      requirements: requirements ?? this.requirements,
      knownSteps: knownSteps ?? this.knownSteps,
      verbCount: verbCount ?? this.verbCount,
      extraTaskTypes: extraTaskTypes ?? this.extraTaskTypes,
    );
  }

  /// Setzt die Anforderung an ein Phänomen (erlaubt = Eintrag entfernen).
  ExamConfig withRequirement(String id, PhenomenonRequirement requirement) {
    final next = Map.of(requirements);

    if (requirement == PhenomenonRequirement.allowed) {
      next.remove(id);
    } else {
      next[id] = requirement;
    }

    return copyWith(requirements: next);
  }

  Map<String, dynamic> toMap() {
    return {
      "corpusIds": corpusIds,
      "bookIds": bookIds,
      "chapterFrom": chapterFrom,
      "chapterTo": chapterTo,
      "fixedPassage": fixedPassage,
      "minWords": minWords,
      "maxWords": maxWords,
      "maxHints": maxHints,
      "excludeDone": excludeDone,
      "requirements": {
        for (final e in requirements.entries) e.key: e.value.name,
      },
      "knownSteps": knownSteps,
      "verbCount": verbCount,
      "extraTaskTypes": extraTaskTypes,
    };
  }

  /// Liest eine gespeicherte Konfiguration. Unbekannte Phänomene und
  /// Anforderungen, die ein Phänomen nicht unterstützt (z. B. „ausgeschlossen“
  /// bei heuristischer Erkennung), werden verworfen.
  factory ExamConfig.fromMap(Object? data) {
    if (data is! Map) return const ExamConfig();

    int? intOrNull(Object? value) => value is num ? value.toInt() : null;

    List<String> strings(Object? value, List<String> fallback) {
      if (value is! List) return List.of(fallback);
      return value.whereType<String>().toList();
    }

    final requirements = <String, PhenomenonRequirement>{};
    final rawRequirements = data["requirements"];

    if (rawRequirements is Map) {
      for (final entry in rawRequirements.entries) {
        final phenomenon = GrammarPhenomena.byId(entry.key.toString());
        final requirement = PhenomenonRequirement.values
            .where((r) => r.name == entry.value)
            .firstOrNull;

        if (phenomenon == null ||
            requirement == null ||
            requirement == PhenomenonRequirement.allowed ||
            !phenomenon.supports(requirement)) {
          continue;
        }

        requirements[phenomenon.id] = requirement;
      }
    }

    var minWords = (intOrNull(data["minWords"]) ?? defaultMinWords).clamp(
      lowestWords,
      highestWords,
    );
    var maxWords = (intOrNull(data["maxWords"]) ?? defaultMaxWords).clamp(
      lowestWords,
      highestWords,
    );

    if (maxWords < minWords) {
      (minWords, maxWords) = (maxWords, minWords);
    }

    final steps = data["knownSteps"];
    final corpusIds = strings(data["corpusIds"], const ["nt"]);
    final extraTasks = strings(data["extraTaskTypes"], defaultExtraTasks);

    return ExamConfig(
      corpusIds: corpusIds.isEmpty ? const ["nt"] : corpusIds,
      bookIds: strings(data["bookIds"], const []),
      chapterFrom: intOrNull(data["chapterFrom"]),
      chapterTo: intOrNull(data["chapterTo"]),
      fixedPassage: data["fixedPassage"] is String
          ? data["fixedPassage"] as String
          : null,
      minWords: minWords,
      maxWords: maxWords,
      maxHints: intOrNull(data["maxHints"]),
      excludeDone: data["excludeDone"] is bool
          ? data["excludeDone"] as bool
          : true,
      requirements: requirements,
      knownSteps: steps is List
          ? (steps
                .whereType<num>()
                .map((s) => s.toInt())
                .where(allSteps.contains)
                .toSet()
                .toList()
              ..sort())
          : List.of(allSteps),
      verbCount: (intOrNull(data["verbCount"]) ?? 5).clamp(1, maxVerbCount),
      extraTaskTypes: extraTasks.length == 2 ? extraTasks : defaultExtraTasks,
    );
  }
}
