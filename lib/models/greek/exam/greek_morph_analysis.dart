import '../../../services/greek/grammar/verb_paradigm.dart';

/// Eine morphologische Bestimmung einer Wortform im Code-Format von
/// MorphGNT (CCAT): zwei Zeichen Wortart, acht Zeichen Bestimmung, z. B.
/// `V-3AAI-S--` (3. Sg. Aorist Aktiv Indikativ) oder `N-----GSF-`.
///
/// Wortart: `A-` Adjektiv, `C-` Konjunktion, `D-` Adverb, `I-` Interjektion,
/// `N-` Nomen, `P-` Präposition, `RA` Artikel, `RD` Demonstrativ-, `RI`
/// Interrogativ-/Indefinit-, `RP` Personal-, `RR` Relativpronomen, `V-`
/// Verb, `X-` Partikel.
///
/// Bestimmung: Person (1–3), Tempus (P Präsens, I Imperfekt, F Futur,
/// A Aorist, X Perfekt, Y Plusquamperfekt), Genus Verbi (A, M, P; zusätzlich
/// `E` = Medium oder Passiv, wenn die Quelle beide nicht trennt), Modus
/// (I, D Imperativ, S Konjunktiv, O Optativ, N Infinitiv, P Partizip), Kasus
/// (N, G, D, A, V), Numerus (S, P), Genus (M, F, N), Steigerung (C, S).
/// `-` = nicht zutreffend bzw. nicht angegeben.
class GreekMorphAnalysis {
  final String code;

  const GreekMorphAnalysis(this.code) : assert(code.length == 10);

  String get pos => code.substring(0, 2);
  String get person => code[2];
  String get tense => code[3];
  String get voice => code[4];
  String get mood => code[5];
  String get grammaticalCase => code[6];
  String get number => code[7];
  String get gender => code[8];
  String get degree => code[9];

  bool get isVerb => pos == "V-";
  bool get isParticiple => isVerb && mood == "P";
  bool get isInfinitive => isVerb && mood == "N";
  bool get isFinite => isVerb && mood != "P" && mood != "N" && mood != "-";

  /// Nomen, Adjektiv, Pronomen, Artikel (deklinierte Wortarten außer dem
  /// Partizip).
  bool get isNominal =>
      pos == "N-" || pos == "A-" || (pos.startsWith("R") && pos != "R-");

  /// Kongruenz in Kasus, Numerus und Genus (fehlende Angaben gelten nicht
  /// als Übereinstimmung).
  bool agreesWith(GreekMorphAnalysis other) {
    return grammaticalCase != "-" &&
        grammaticalCase == other.grammaticalCase &&
        number != "-" &&
        number == other.number &&
        (gender == "-" || other.gender == "-" || gender == other.gender);
  }

  @override
  bool operator ==(Object other) =>
      other is GreekMorphAnalysis && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;

  // ---------------------------------------------------------------------------
  // BEZEICHNUNGEN (Schreibweise des Grammatiktrainers)
  // ---------------------------------------------------------------------------

  static const Map<String, String> posLabels = {
    "A-": "Adjektiv",
    "C-": "Konjunktion",
    "D-": "Adverb",
    "I-": "Interjektion",
    "N-": "Nomen",
    "P-": "Präposition",
    "RA": "Artikel",
    "RD": "Demonstrativpronomen",
    "RI": "Interrogativ-/Indefinitpronomen",
    "RP": "Personalpronomen",
    "RR": "Relativpronomen",
    "V-": "Verb",
    "X-": "Partikel",
  };

  static const Map<String, String> tenseLabels = {
    "P": "Präsens",
    "I": "Imperfekt",
    "F": "Futur",
    "A": "Aorist",
    "X": "Perfekt",
    "Y": "Plusquamperfekt",
  };

  static const Map<String, String> moodLabels = {
    "I": VerbMood.indicative,
    "S": "Konjunktiv",
    "O": "Optativ",
    "D": VerbMood.imperative,
    "N": VerbMood.infinitive,
    "P": VerbMood.participle,
  };

  static const Map<String, String> caseLabels = {
    "N": "Nominativ",
    "G": "Genitiv",
    "D": "Dativ",
    "A": "Akkusativ",
    "V": "Vokativ",
  };

  /// Numerus und Genus wie im Grammatiktrainer ("Sg", "m").
  static const Map<String, String> numberLabels = {"S": "Sg", "P": "Pl"};

  static const Map<String, String> genderLabels = {
    "M": "m",
    "F": "f",
    "N": "n",
  };

  static const Map<String, String> degreeLabels = {
    "C": "Komparativ",
    "S": "Superlativ",
  };

  /// Genus Verbi in der Schreibweise des Grammatiktrainers. Im Präsens,
  /// Imperfekt, Perfekt und Plusquamperfekt sind Medium und Passiv
  /// formgleich ("Medium/Passiv"); dort gelten beide Antworten.
  String? get voiceLabel {
    if (!isVerb || voice == "-") return null;

    final mediopassive =
        voice == "E" ||
        ((voice == "M" || voice == "P") && "PIXY".contains(tense));

    if (mediopassive) return "Medium/Passiv";

    return const {"A": "Aktiv", "M": "Medium", "P": "Passiv"}[voice];
  }

  /// Die Bestimmung als [VerbAnalysis] für die Antwortprüfung des
  /// Grammatiktrainers (`checkVerbAnswer`). `null` bei Nicht-Verben.
  VerbAnalysis? toVerbAnalysis() {
    if (!isVerb) return null;

    final finite = isFinite;

    return (
      mood: moodLabels[mood] ?? mood,
      tense: tenseLabels[tense] ?? tense,
      voice: voiceLabel ?? voice,
      person: finite ? int.tryParse(person) : null,
      number: finite || isParticiple ? numberLabels[number] : null,
      grammaticalCase: isParticiple ? caseLabels[grammaticalCase] : null,
      gender: isParticiple ? genderLabels[gender] : null,
    );
  }

  /// Lesbare Bestimmung, z. B. "Verb · 3. Sg. Aorist Indikativ Aktiv" oder
  /// "Nomen · Genitiv Sg. f".
  String describe() {
    final parts = <String>[];

    if (isVerb) {
      if (isFinite && person != "-") {
        parts.add("$person. ${numberLabels[number] ?? number}.");
      }

      parts.add(tenseLabels[tense] ?? "");
      parts.add(moodLabels[mood] ?? "");
      parts.add(voiceLabel ?? "");

      if (isParticiple) {
        parts.add(
          "· ${caseLabels[grammaticalCase] ?? ""} "
          "${numberLabels[number] ?? ""}. ${genderLabels[gender] ?? ""}",
        );
      }
    } else {
      if (grammaticalCase != "-") parts.add(caseLabels[grammaticalCase]!);
      if (number != "-") parts.add("${numberLabels[number]}.");
      if (gender != "-") parts.add(genderLabels[gender]!);
      if (degree != "-") parts.add(degreeLabels[degree] ?? "");
    }

    final label = posLabels[pos] ?? pos;
    final detail = parts.where((p) => p.trim().isNotEmpty).join(" ");

    return detail.isEmpty ? label : "$label · $detail";
  }
}
