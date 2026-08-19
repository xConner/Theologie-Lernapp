class LatinVocabularyEntry {
  final int id;
  final int step;
  final int substep;
  final String type;

  /// Grundform:
  /// Verb: Infinitiv
  /// Nomen: Nominativ Singular
  /// Adjektiv: Nominativ Singular Maskulinum
  final String lemma;

  /// Verb: im jeweiligen Lernschritt verlangte Personalform
  /// z. B. cogitat, venit, stat
  ///
  /// Nomen: Genitiv bzw. andere im Buch verlangte Zusatzform
  /// z. B. domini
  ///
  /// Adjektiv: feminine und neutrale Form
  /// z. B. magna, magnum
  ///
  /// Bei Wörtern ohne zusätzliche Form: null
  final String? form;

  /// Genus eines Nomens: m, f oder n
  final String? gender;

  final List<String> translations;

  final String? note;
  final String? mnemonic;

  const LatinVocabularyEntry({
    required this.id,
    required this.step,
    required this.substep,
    required this.type,
    required this.lemma,
    this.form,
    this.gender,
    required this.translations,
    this.note,
    this.mnemonic,
  });

  factory LatinVocabularyEntry.fromJson(Map<String, dynamic> json) {
    return LatinVocabularyEntry(
      id: json["id"],
      step: int.parse(json["step"].toString()),
      substep: int.parse(json["substep"].toString()),
      type: json["type"],
      lemma: json["lemma"],
      form: json["principalForm"],
      gender: json["gender"],
      translations: List<String>.from(json["translations"]),
      note: json["note"],
      mnemonic: json["mnemonic"],
    );
  }
}
