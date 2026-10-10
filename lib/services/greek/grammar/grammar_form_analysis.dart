/// Eine grammatisch mögliche Bestimmung einer konkreten Nominalform.
///
/// Kasus und Numerus stehen in der Schreibweise der Backend-Anfrage
/// ("Nominativ", "Sg").
typedef NounFormAnalysis = ({String grammaticalCase, String number});

/// Eine grammatisch mögliche Bestimmung einer konkreten Pronominalform.
///
/// Kasus und Numerus wie bei [NounFormAnalysis]; [pronounId] ist die ID des
/// Vokabeleintrags, [gender] ist `null` bei Pronomen ohne Genus (ἐγώ, σύ).
/// Anders als beim Nomen gehört das Genus hier zur Form, nicht zum Wort.
typedef PronounFormAnalysis = ({
  int pronounId,
  String grammaticalCase,
  String number,
  String? gender,
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
