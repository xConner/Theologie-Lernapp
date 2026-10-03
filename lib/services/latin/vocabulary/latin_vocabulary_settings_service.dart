import 'package:cloud_firestore/cloud_firestore.dart';

import '../../local_learning_store.dart';

/// Einstellungen des lateinischen Vokabeltrainers. Ohne gespeicherte Werte
/// gelten die Defaults des Konstruktors.
class LatinVocabularySettings {
  static const List<String> allTypes = [
    "noun",
    "verb",
    "adjective",
    "adverb",
    "pronoun",
    "preposition",
    "conjunction",
    "particle",
    "question_word",
    "phrase",
  ];

  final bool includeVerbForm;
  final bool includeNounForm;
  final bool includeGender;
  final bool includeAdjectiveForms;
  final bool requireOnlyOneTranslation;

  /// Je Schritt die ausgewählten Unter-Schritte. Schritte ohne Eintrag
  /// haben keine gespeicherte Auswahl.
  final Map<int, List<int>> enabledSubsteps;

  final List<String> enabledTypes;

  const LatinVocabularySettings({
    this.includeVerbForm = true,
    this.includeNounForm = true,
    this.includeGender = true,
    this.includeAdjectiveForms = true,
    this.requireOnlyOneTranslation = true,
    this.enabledSubsteps = const {},
    this.enabledTypes = allTypes,
  });

  /// Liest das gespeicherte Feld `latin_vocabulary_settings`. Die Listen
  /// sind eigene, veränderbare Kopien.
  factory LatinVocabularySettings.fromMap(Map<String, dynamic> data) {
    final substeps = <int, List<int>>{};

    final savedSubsteps = data["enabledSubsteps"];

    if (savedSubsteps != null) {
      for (final entry in Map<String, dynamic>.from(savedSubsteps).entries) {
        substeps[int.parse(entry.key)] = List<int>.from(entry.value);
      }
    }

    return LatinVocabularySettings(
      includeVerbForm: data["includeVerbForm"] ?? true,
      includeNounForm: data["includeNounForm"] ?? true,
      includeGender: data["includeGender"] ?? true,
      includeAdjectiveForms: data["includeAdjectiveForms"] ?? true,
      requireOnlyOneTranslation: data["requireOnlyOneTranslation"] ?? true,
      enabledSubsteps: substeps,
      enabledTypes: List<String>.from(data["enabledTypes"] ?? allTypes),
    );
  }
}

/// uid == null bedeutet Gastmodus (lokale Speicherung).
class LatinVocabularySettingsService {
  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static const String _group = "latin_vocabulary_settings";

  DocumentReference<Map<String, dynamic>> _document(String uid) {
    return firestore.collection("users").doc(uid);
  }

  /// Lädt alle Einstellungen mit einem einzigen Lesezugriff.
  Future<LatinVocabularySettings> load(String? uid) async {
    if (uid == null) {
      return LatinVocabularySettings.fromMap(
        await LocalLearningStore.instance.loadSettingsGroup(_group),
      );
    }

    final data = (await _document(uid).get()).data();

    return LatinVocabularySettings.fromMap(data?[_group] ?? {});
  }

  Future<void> saveSettings({
    required String? uid,
    required bool includeVerbForm,
    required bool includeNounForm,
    required bool includeGender,
    required bool includeAdjectiveForms,
    required bool requireOnlyOneTranslation,
    required List<int> enabledSteps,
    required Map<int, List<int>> enabledSubsteps,
    required List<String> enabledTypes,
  }) async {
    final substeps = <String, dynamic>{};

    for (final entry in enabledSubsteps.entries) {
      substeps[entry.key.toString()] = entry.value;
    }

    final settings = {
      "includeVerbForm": includeVerbForm,
      "includeNounForm": includeNounForm,
      "includeGender": includeGender,
      "includeAdjectiveForms": includeAdjectiveForms,
      "requireOnlyOneTranslation": requireOnlyOneTranslation,

      "enabledSteps": enabledSteps,
      "enabledSubsteps": substeps,
      "enabledTypes": enabledTypes,
    };

    if (uid == null) {
      return LocalLearningStore.instance.saveSettingsGroup(_group, settings);
    }

    await _document(uid).set({_group: settings}, SetOptions(merge: true));
  }
}
