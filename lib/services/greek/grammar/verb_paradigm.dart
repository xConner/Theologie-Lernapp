import '../../../utils/greek_normalization.dart';
import 'greek_declension.dart';

/// Modi der Verbaufgaben. Das Partizip steht als infinite Form neben den
/// beiden finiten Modi, weil es wie sie am Verb bestimmt wird.
class VerbMood {
  VerbMood._();

  static const String indicative = "Indikativ";
  static const String imperative = "Imperativ";
  static const String participle = "Partizip";

  static const List<String> all = [indicative, imperative, participle];
}

/// Eine grammatisch mögliche Bestimmung einer Verbform.
///
/// Finite Formen haben eine [person], Partizipien stattdessen
/// [grammaticalCase] und [gender]. [number] steht in der Schreibweise der
/// Backend-Anfrage ("Sg", "Pl"), [voice] wie im Trainer angezeigt ("Aktiv",
/// "Medium/Passiv", "Medium", "Passiv").
typedef VerbAnalysis = ({
  String mood,
  String tense,
  String voice,
  int? person,
  String number,
  String? grammaticalCase,
  String? gender,
});

/// Eine Verbform samt ihrer Bestimmung.
typedef VerbForm = ({String form, VerbAnalysis analysis});

/// "3. Pl. Präsens Indikativ Aktiv" bzw.
/// "Partizip Aorist Medium · Dativ Pl. m".
String describeVerbAnalysis(VerbAnalysis analysis) {
  if (analysis.mood == VerbMood.participle) {
    return "Partizip ${analysis.tense} ${analysis.voice} · "
        "${analysis.grammaticalCase} ${analysis.number}. ${analysis.gender}";
  }

  return "${analysis.person}. ${analysis.number}. ${analysis.tense} "
      "${analysis.mood} ${analysis.voice}";
}

/// Alle Formen eines Verbs, die der Trainer kennt: Indikativ und Imperativ
/// aus den Tabellen des Backends, die Partizipien aus ihren Nominativen
/// lokal dekliniert ([declineParticiple]).
///
/// Unzuverlässige Daten werden nicht zu Formen: Ein Imperativ, dessen
/// Endungen nicht zum Genus Verbi passen, und ein Partizip, dessen Bildung
/// sich nicht bestätigen lässt, fehlen im Paradigma.
class VerbParadigm {
  final List<VerbForm> forms;

  const VerbParadigm(this.forms);

  static const List<String> _tenses = ["Präsens", "Imperfekt", "Aorist"];

  // Reihenfolge der finiten Formen in der Antwort des Backends.
  static const List<(int, String)> _persons = [
    (1, "Sg"),
    (2, "Sg"),
    (3, "Sg"),
    (1, "Pl"),
    (2, "Pl"),
    (3, "Pl"),
  ];

  /// Genus Verbi einer Tabellenzeile in der Schreibweise des Trainers. Im
  /// Präsens und Imperfekt sind Medium und Passiv formgleich, im Aorist
  /// getrennt.
  static String? voiceLabel(String tense, String key) {
    switch (key) {
      case "active":
        return "Aktiv";

      case "middle/passive":
        return "Medium/Passiv";

      case "middle":
        return tense == "Aorist" ? "Medium" : "Medium/Passiv";

      case "passive":
        return "Passiv";

      default:
        return null;
    }
  }

  /// Liest das Feld `paradigm` der Backend-Antwort. Fehlende oder ungültige
  /// Teile werden ausgelassen.
  factory VerbParadigm.fromJson(Object? json) {
    final forms = <VerbForm>[];

    if (json is! Map) {
      return VerbParadigm(forms);
    }

    for (final tense in _tenses) {
      final data = json[tense];

      if (data is! Map) continue;

      final indicative = _finiteForms(data['indicative']);
      final imperative = _finiteForms(data['imperative']);

      for (final MapEntry(key: key, value: cells) in indicative.entries) {
        final voice = voiceLabel(tense, key);

        if (voice == null) continue;

        forms.addAll(_finite(VerbMood.indicative, tense, voice, cells));
      }

      // Imperfekt gibt es nur im Indikativ.
      if (tense == "Imperfekt") continue;

      for (final MapEntry(key: key, value: cells) in imperative.entries) {
        final voice = voiceLabel(tense, key);

        if (voice == null ||
            !_imperativeIsReliable(tense, cells, indicative[key])) {
          continue;
        }

        forms.addAll(_finite(VerbMood.imperative, tense, voice, cells));
      }

      final participles = data['participles'];

      if (participles is! Map) continue;

      for (final MapEntry(key: key, value: nominatives)
          in participles.entries) {
        final voice = key is String ? voiceLabel(tense, key) : null;

        if (voice == null || nominatives is! Map) continue;

        final masculine = nominatives['m'];
        final feminine = nominatives['f'];
        final neuter = nominatives['n'];

        if (masculine is! String || feminine is! String || neuter is! String) {
          continue;
        }

        final declension = declineParticiple(
          masculine: normalizeGreekForDisplay(masculine),
          feminine: normalizeGreekForDisplay(feminine),
          neuter: normalizeGreekForDisplay(neuter),
        );

        if (declension == null) continue;

        for (final cell in declension.forms) {
          forms.add((
            form: cell.form,
            analysis: (
              mood: VerbMood.participle,
              tense: tense,
              voice: voice,
              person: null,
              number: cell.number,
              grammaticalCase: cell.grammaticalCase,
              gender: cell.gender,
            ),
          ));
        }
      }
    }

    return VerbParadigm(forms);
  }

  // Je Genus Verbi sechs Formen (1.–3. Sg., 1.–3. Pl.); fehlende sind `null`.
  static Map<String, List<String?>> _finiteForms(Object? json) {
    final result = <String, List<String?>>{};

    if (json is! Map) {
      return result;
    }

    for (final MapEntry(key: key, value: cells) in json.entries) {
      if (key is! String || cells is! List || cells.length != 6) continue;

      result[key] = [
        for (final cell in cells)
          cell is String && cell.isNotEmpty
              ? normalizeGreekForDisplay(cell)
              : null,
      ];
    }

    return result;
  }

  static Iterable<VerbForm> _finite(
    String mood,
    String tense,
    String voice,
    List<String?> cells,
  ) sync* {
    for (var i = 0; i < cells.length; i++) {
      final form = cells[i];
      final (person, number) = _persons[i];

      // Der Imperativ hat keine 1. Person.
      if (form == null || (mood == VerbMood.imperative && person == 1)) {
        continue;
      }

      yield (
        form: form,
        analysis: (
          mood: mood,
          tense: tense,
          voice: voice,
          person: person,
          number: number,
          grammaticalCase: null,
          gender: null,
        ),
      );
    }
  }

  /// Gegenprobe der Imperativformen einer Tabellenzeile an den Endungen:
  /// aktive Endungen -τω, -τε, -ντων (auch Aorist Passiv), mediale -σθω,
  /// -σθε, -σθων – je nachdem, wie die 2. Pl. des Indikativs endet. Im
  /// Präsens sind 2. Pl. Imperativ und Indikativ dieselbe Form.
  static bool _imperativeIsReliable(
    String tense,
    List<String?> imperative,
    List<String?>? indicative,
  ) {
    final thirdSingular = imperative[2];
    final secondPlural = imperative[4];
    final thirdPlural = imperative[5];
    final indicativePlural = indicative?[4];

    if (imperative[1] == null ||
        thirdSingular == null ||
        secondPlural == null ||
        thirdPlural == null ||
        indicativePlural == null) {
      return false;
    }

    if (tense == "Präsens" &&
        normalizeGreekForComparison(secondPlural) !=
            normalizeGreekForComparison(indicativePlural)) {
      return false;
    }

    if (indicativePlural.endsWith("σθε")) {
      return thirdSingular.endsWith("σθω") &&
          secondPlural.endsWith("σθε") &&
          (thirdPlural.endsWith("σθων") || thirdPlural.endsWith("σθωσαν"));
    }

    return !thirdSingular.endsWith("σθω") &&
        thirdSingular.endsWith("τω") &&
        secondPlural.endsWith("τε") &&
        (thirdPlural.endsWith("των") || thirdPlural.endsWith("τωσαν"));
  }

  // Formen gelten als gleich, wenn sie sich höchstens im beweglichen ν
  // unterscheiden: παύουσι (Indikativ) = παύουσι(ν) (Partizip).
  static String _comparable(String form) {
    return normalizeGreekForDisplay(form).replaceAll("(ν)", "");
  }

  /// Alle Bestimmungen, die für die Form [form] möglich sind (formal
  /// identische Formen: 1. Sg. = 3. Pl. im Imperfekt, παυόντων als Imperativ
  /// und Partizip, Nominativ = Akkusativ im Neutrum).
  List<VerbAnalysis> analysesOf(String form) {
    final wanted = _comparable(form);

    return [
      for (final candidate in forms)
        if (_comparable(candidate.form) == wanted) candidate.analysis,
    ];
  }
}
