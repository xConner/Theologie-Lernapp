/// Eine grammatisch mögliche Bestimmung einer konkreten Nominalform.
///
/// Kasus und Numerus stehen in der Schreibweise der Backend-Anfrage
/// ("Nominativ", "Sg").
typedef NounFormAnalysis = ({String grammaticalCase, String number});

/// Eine grammatisch mögliche Bestimmung einer konkreten Verbform.
///
/// Die Werte stehen in der Schreibweise der Backend-Anfrage
/// ("Präsens", "Aktiv", "Sg", 1).
typedef VerbFormAnalysis = ({
  int person,
  String number,
  String tense,
  String voice,
});

/// Liest die vom Nomen-Backend gelieferten Bestimmungen der Form.
///
/// Fehlende oder ungültige Daten ergeben eine leere Liste; dann gilt
/// ausschließlich die Zielbestimmung der Aufgabe.
List<NounFormAnalysis> parseNounFormAnalyses(Object? json) {
  if (json is! List) {
    return const [];
  }

  final analyses = <NounFormAnalysis>[];

  for (final item in json) {
    if (item is! Map) continue;

    final grammaticalCase = item['case'];
    final number = item['number'];

    if (grammaticalCase is String && number is String) {
      analyses.add((grammaticalCase: grammaticalCase, number: number));
    }
  }

  return analyses;
}

/// Liest die vom Verb-Backend gelieferten Bestimmungen der Form.
List<VerbFormAnalysis> parseVerbFormAnalyses(Object? json) {
  if (json is! List) {
    return const [];
  }

  final analyses = <VerbFormAnalysis>[];

  for (final item in json) {
    if (item is! Map) continue;

    final person = item['person'];
    final number = item['number'];
    final tense = item['tense'];
    final voice = item['voice'];

    if (person is int &&
        number is String &&
        tense is String &&
        voice is String) {
      analyses.add((
        person: person,
        number: number,
        tense: tense,
        voice: voice,
      ));
    }
  }

  return analyses;
}

/// Ob die Nutzerantwort (Schreibweise des Trainers, z. B. "Akkusativ" und
/// "Sg.") eine tatsächlich mögliche Bestimmung der angezeigten Form ist.
bool nounAnswerMatchesForm(
  List<NounFormAnalysis> analyses, {
  required String? userCase,
  required String? userNumber,
}) {
  return analyses.any(
    (a) => a.grammaticalCase == userCase && '${a.number}.' == userNumber,
  );
}

/// Ob die Nutzerantwort (Schreibweise des Trainers, z. B. "3. Pl.",
/// "Imperfekt", "Aktiv") eine tatsächlich mögliche Bestimmung der
/// angezeigten Form ist.
bool verbAnswerMatchesForm(
  List<VerbFormAnalysis> analyses, {
  required String? userPersonNumber,
  required String? userTense,
  required String? userVoice,
}) {
  return analyses.any(
    (a) =>
        '${a.person}. ${a.number}.' == userPersonNumber &&
        a.tense == userTense &&
        a.voice == userVoice,
  );
}
