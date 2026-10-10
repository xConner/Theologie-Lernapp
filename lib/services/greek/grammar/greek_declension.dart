import '../../../utils/greek_accents.dart';

/// Kasus in der Reihenfolge der Formentabellen.
const List<String> declensionCases = [
  "Nominativ",
  "Genitiv",
  "Dativ",
  "Akkusativ",
];

/// Numeri in der Schreibweise der Formbestimmungen.
const List<String> declensionNumbers = ["Sg", "Pl"];

const List<String> declensionGenders = ["m", "f", "n"];

/// Eine Form eines dreigeschlechtigen Paradigmas mit ihrer Bestimmung.
typedef DeclinedForm = ({
  String grammaticalCase,
  String number,
  String gender,
  String form,
});

/// Vollständige Deklination eines Adjektivs oder Partizips: Kasus × Numerus
/// × Genus.
///
/// Die Formen werden nach den Tabellen der Lehrveranstaltung gebildet
/// (Partizipien, Steigerung der Adjektive). Das bewegliche ν steht wie dort
/// in Klammern: παύουσι(ν).
class DeclensionParadigm {
  final List<DeclinedForm> forms;

  const DeclensionParadigm._(this.forms);

  /// Je Genus acht Formen: Nom., Gen., Dat., Akk. Singular, dann Plural.
  factory DeclensionParadigm({
    required List<String> masculine,
    required List<String> feminine,
    required List<String> neuter,
  }) {
    final byGender = {"m": masculine, "f": feminine, "n": neuter};

    return DeclensionParadigm._([
      for (final gender in declensionGenders)
        for (var n = 0; n < declensionNumbers.length; n++)
          for (var c = 0; c < declensionCases.length; c++)
            (
              grammaticalCase: declensionCases[c],
              number: declensionNumbers[n],
              gender: gender,
              form: byGender[gender]![n * declensionCases.length + c],
            ),
    ]);
  }

  /// Dasselbe Paradigma mit [to] an jeder Stelle von [from] (πλείων bildet
  /// das Neutrum vom kürzeren Stamm: πλέον).
  DeclensionParadigm replacing(String from, String to) {
    return DeclensionParadigm._([
      for (final cell in forms)
        if (cell.form == from)
          (
            grammaticalCase: cell.grammaticalCase,
            number: cell.number,
            gender: cell.gender,
            form: to,
          )
        else
          cell,
    ]);
  }

  String? form(String grammaticalCase, String number, String gender) {
    for (final cell in forms) {
      if (cell.grammaticalCase == grammaticalCase &&
          cell.number == number &&
          cell.gender == gender) {
        return cell.form;
      }
    }

    return null;
  }
}

// -----------------------------------------------------------------------------
// A-/O-DEKLINATION
// -----------------------------------------------------------------------------

/// A-/O-Deklination mit zurückgezogenem Akzent. [short] ist der Stamm mit
/// dem Akzent vor kurzer Endsilbe (σοφώτερ-ος, παυόμεν-ος, πλεῖστ-ος),
/// [long] der vor langer Endsilbe (σοφωτέρ-ου, παυομέν-ου, πλείστ-ου).
/// Das Femininum endet auf -η oder, mit [alphaFeminine], auf langes -α.
DeclensionParadigm declineRecessive({
  required String short,
  required String long,
  required bool alphaFeminine,
}) {
  return DeclensionParadigm(
    masculine: [
      "$shortος",
      "$longου",
      "$longῳ",
      "$shortον",
      "$shortοι",
      "$longων",
      "$longοις",
      "$longους",
    ],
    feminine: [
      alphaFeminine ? "$longα" : "$longη",
      alphaFeminine ? "$longας" : "$longης",
      alphaFeminine ? "$longᾳ" : "$longῃ",
      alphaFeminine ? "$longαν" : "$longην",
      "$shortαι",
      "$longων",
      "$longαις",
      "$longας",
    ],
    neuter: [
      "$shortον",
      "$longου",
      "$longῳ",
      "$shortον",
      "$shortα",
      "$longων",
      "$longοις",
      "$shortα",
    ],
  );
}

/// A-/O-Deklination mit dem Akzent auf der Endung (σοφ-ός, σοφ-ή, σοφ-όν).
DeclensionParadigm declineOxytone({
  required String stem,
  required bool alphaFeminine,
}) {
  return DeclensionParadigm(
    masculine: [
      "$stemός",
      "$stemοῦ",
      "$stemῷ",
      "$stemόν",
      "$stemοί",
      "$stemῶν",
      "$stemοῖς",
      "$stemούς",
    ],
    feminine: [
      alphaFeminine ? "$stemά" : "$stemή",
      alphaFeminine ? "$stemᾶς" : "$stemῆς",
      alphaFeminine ? "$stemᾷ" : "$stemῇ",
      alphaFeminine ? "$stemάν" : "$stemήν",
      "$stemαί",
      "$stemῶν",
      "$stemαῖς",
      "$stemάς",
    ],
    neuter: [
      "$stemόν",
      "$stemοῦ",
      "$stemῷ",
      "$stemόν",
      "$stemά",
      "$stemῶν",
      "$stemοῖς",
      "$stemά",
    ],
  );
}

// -----------------------------------------------------------------------------
// KOMPARATIV AUF -ων, -ον
// -----------------------------------------------------------------------------

/// Komparativ auf -(ί)ων, -(ι)ον (Gen. -ονος): Maskulinum und Femininum sind
/// gleich. [neuter] ist der Nominativ Sg. Neutrum (ἄμεινον); sein Akzent
/// lässt sich aus dem Maskulinum nicht ableiten. `null`, wenn [masculine]
/// nicht auf -ων endet oder die beiden Formen nicht zusammenpassen.
///
/// Gebildet werden die unkontrahierten Formen (ἀμείνονα, ἀμείνονες).
DeclensionParadigm? declineComparative({
  required String masculine,
  required String neuter,
}) {
  if (!masculine.endsWith("ων")) {
    return null;
  }

  final stem = masculine.substring(0, masculine.length - 2);
  final plain = stripGreekAccent(stem);

  if (stem.isEmpty || stem == plain || stripGreekAccent(neuter) != "$plainον") {
    return null;
  }

  final common = [
    masculine,
    "$stemονος",
    "$stemονι",
    "$stemονα",
    "$stemονες",
    "$plainόνων",
    "$stemοσι(ν)",
    "$stemονας",
  ];

  return DeclensionParadigm(
    masculine: common,
    feminine: common,
    neuter: [
      neuter,
      "$stemονος",
      "$stemονι",
      neuter,
      "$stemονα",
      "$plainόνων",
      "$stemοσι(ν)",
      "$stemονα",
    ],
  );
}

// -----------------------------------------------------------------------------
// PARTIZIPIEN
// -----------------------------------------------------------------------------

// Partizip Präsens Aktiv von εἰμί: Stamm und Endung fallen zusammen, der
// Spiritus steht auf der Endung.
final DeclensionParadigm _eimiParticiple = DeclensionParadigm(
  masculine: const [
    "ὤν",
    "ὄντος",
    "ὄντι",
    "ὄντα",
    "ὄντες",
    "ὄντων",
    "οὖσι(ν)",
    "ὄντας",
  ],
  feminine: const [
    "οὖσα",
    "οὔσης",
    "οὔσῃ",
    "οὖσαν",
    "οὖσαι",
    "οὐσῶν",
    "οὔσαις",
    "οὔσας",
  ],
  neuter: const [
    "ὄν",
    "ὄντος",
    "ὄντι",
    "ὄν",
    "ὄντα",
    "ὄντων",
    "οὖσι(ν)",
    "ὄντα",
  ],
);

/// Partizipien mit dem Akzent auf der Endung. [oblique] ist der Stammausgang
/// der übrigen Maskulin- und Neutrumformen, [feminine] / [feminineLong] der
/// des Femininums vor kurzer bzw. langer Endsilbe.
typedef _EndingAccented = ({
  String masculine,
  String neuter,
  String oblique,
  String genitivePlural,
  String dativePlural,
  String feminine,
  String feminineLong,
  String feminineGenitivePlural,
});

const List<_EndingAccented> _endingAccented = [
  // Starker Aorist: ἰδών, ἰδοῦσα, ἰδόν.
  (
    masculine: "ών",
    neuter: "όν",
    oblique: "όντ",
    genitivePlural: "όντων",
    dativePlural: "οῦσι(ν)",
    feminine: "οῦσ",
    feminineLong: "ούσ",
    feminineGenitivePlural: "ουσῶν",
  ),
  // Wurzelaorist: γνούς, γνοῦσα, γνόν.
  (
    masculine: "ούς",
    neuter: "όν",
    oblique: "όντ",
    genitivePlural: "όντων",
    dativePlural: "οῦσι(ν)",
    feminine: "οῦσ",
    feminineLong: "ούσ",
    feminineGenitivePlural: "ουσῶν",
  ),
  // Wurzelaorist: βάς, βᾶσα, βάν.
  (
    masculine: "άς",
    neuter: "άν",
    oblique: "άντ",
    genitivePlural: "άντων",
    dativePlural: "ᾶσι(ν)",
    feminine: "ᾶσ",
    feminineLong: "άσ",
    feminineGenitivePlural: "ασῶν",
  ),
  // Verba contracta auf -έω und -όω: ποιῶν, ποιοῦσα, ποιοῦν.
  (
    masculine: "ῶν",
    neuter: "οῦν",
    oblique: "οῦντ",
    genitivePlural: "ούντων",
    dativePlural: "οῦσι(ν)",
    feminine: "οῦσ",
    feminineLong: "ούσ",
    feminineGenitivePlural: "ουσῶν",
  ),
  // Verba contracta auf -άω: τιμῶν, τιμῶσα, τιμῶν.
  (
    masculine: "ῶν",
    neuter: "ῶν",
    oblique: "ῶντ",
    genitivePlural: "ώντων",
    dativePlural: "ῶσι(ν)",
    feminine: "ῶσ",
    feminineLong: "ώσ",
    feminineGenitivePlural: "ωσῶν",
  ),
];

DeclensionParadigm _declineEndingAccented(String stem, _EndingAccented type) {
  final oblique = "$stem${type.oblique}";
  final genitivePlural = "$stem${type.genitivePlural}";
  final dativePlural = "$stem${type.dativePlural}";
  final feminine = "$stem${type.feminine}";
  final feminineLong = "$stem${type.feminineLong}";
  final neuter = "$stem${type.neuter}";

  return DeclensionParadigm(
    masculine: [
      "$stem${type.masculine}",
      "$obliqueος",
      "$obliqueι",
      "$obliqueα",
      "$obliqueες",
      genitivePlural,
      dativePlural,
      "$obliqueας",
    ],
    feminine: [
      "$feminineα",
      "$feminineLongης",
      "$feminineLongῃ",
      "$feminineαν",
      "$feminineαι",
      "$stem${type.feminineGenitivePlural}",
      "$feminineLongαις",
      "$feminineLongας",
    ],
    neuter: [
      neuter,
      "$obliqueος",
      "$obliqueι",
      neuter,
      "$obliqueα",
      genitivePlural,
      dativePlural,
      "$obliqueα",
    ],
  );
}

/// Partizipien mit dem Akzent auf dem Stamm: παύ-ων (Thema [vowel] = ο,
/// Femininum -ουσα) und παύσ-ας (α, -ασα). Der Nominativ Sg. Neutrum
/// ([neuter]) wird übernommen, weil sein Akzent von der Länge des
/// Stammvokals abhängt (παῦον, aber βάλλον).
DeclensionParadigm _declineStemAccented({
  required String stem,
  required String masculine,
  required String neuter,
  required String vowel,
  required String accentedVowel,
  required String feminine,
  required String accentedFeminine,
}) {
  final plain = stripGreekAccent(stem);

  return DeclensionParadigm(
    masculine: [
      masculine,
      "$stem$vowelντος",
      "$stem$vowelντι",
      "$stem$vowelντα",
      "$stem$vowelντες",
      "$plain$accentedVowelντων",
      "$stem$feminineι(ν)",
      "$stem$vowelντας",
    ],
    feminine: [
      "$stem$feminineα",
      "$plain$accentedFeminineης",
      "$plain$accentedFeminineῃ",
      "$stem$feminineαν",
      "$stem$feminineαι",
      "$plain$feminineῶν",
      "$plain$accentedFeminineαις",
      "$plain$accentedFeminineας",
    ],
    neuter: [
      neuter,
      "$stem$vowelντος",
      "$stem$vowelντι",
      neuter,
      "$stem$vowelντα",
      "$plain$accentedVowelντων",
      "$stem$feminineι(ν)",
      "$stem$vowelντα",
    ],
  );
}

/// Dekliniert ein Partizip aus den drei Nominativen des Singulars.
///
/// Gebildet werden nur die Typen der Lehrveranstaltung: -ων/-ουσα/-ον,
/// -ας/-ασα/-αν, -μενος/-μένη/-μενον, der starke Aorist (-ών/-οῦσα/-όν)
/// samt Wurzelaorist und Verba contracta sowie ὤν. Feminin- und Neutrumform
/// dienen als Gegenprobe: Passen sie nicht zur Bildung aus dem Maskulinum,
/// gilt das Partizip als nicht zuverlässig und das Ergebnis ist `null`.
DeclensionParadigm? declineParticiple({
  required String masculine,
  required String feminine,
  required String neuter,
}) {
  bool confirmed(DeclensionParadigm paradigm) {
    return paradigm.form("Nominativ", "Sg", "f") == feminine &&
        paradigm.form("Nominativ", "Sg", "n") == neuter;
  }

  if (confirmed(_eimiParticiple) && masculine == "ὤν") {
    return _eimiParticiple;
  }

  if (masculine.endsWith("μενος")) {
    final prefix = masculine.substring(0, masculine.length - 5);

    if (!hasGreekAccent(prefix)) {
      return null;
    }

    final paradigm = declineRecessive(
      short: "$prefixμεν",
      long: "${stripGreekAccent(prefix)}μέν",
      alphaFeminine: false,
    );

    return confirmed(paradigm) ? paradigm : null;
  }

  for (final type in _endingAccented) {
    if (!masculine.endsWith(type.masculine)) {
      continue;
    }

    final stem = masculine.substring(
      0,
      masculine.length - type.masculine.length,
    );

    if (stem.isEmpty || hasGreekAccent(stem)) {
      continue;
    }

    final paradigm = _declineEndingAccented(stem, type);

    if (confirmed(paradigm)) {
      return paradigm;
    }
  }

  for (final (ending, vowel, accentedVowel, feminineStem, accentedFeminine)
      in const [("ων", "ο", "ό", "ουσ", "ούσ"), ("ας", "α", "ά", "ασ", "άσ")]) {
    if (!masculine.endsWith(ending)) {
      continue;
    }

    final stem = masculine.substring(0, masculine.length - 2);

    if (!hasGreekAccent(stem) ||
        stripGreekAccent(neuter) != "${stripGreekAccent(stem)}$vowelν") {
      return null;
    }

    final paradigm = _declineStemAccented(
      stem: stem,
      masculine: masculine,
      neuter: neuter,
      vowel: vowel,
      accentedVowel: accentedVowel,
      feminine: feminineStem,
      accentedFeminine: accentedFeminine,
    );

    return confirmed(paradigm) ? paradigm : null;
  }

  return null;
}
