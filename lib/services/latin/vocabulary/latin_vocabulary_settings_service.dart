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

  /// Abgewählte Lektionen. Gespeichert wird die Abwahl, damit später
  /// ergänzte Lektionen ohne weiteres Zutun aktiv sind.
  final List<int> disabledLessons;

  final List<String> enabledTypes;

  const LatinVocabularySettings({
    this.includeVerbForm = true,
    this.includeNounForm = true,
    this.includeGender = true,
    this.includeAdjectiveForms = true,
    this.requireOnlyOneTranslation = true,
    this.disabledLessons = const [],
    this.enabledTypes = allTypes,
  });

  /// Liest das gespeicherte Feld `latin_vocabulary_settings`. Die Listen
  /// sind eigene, veränderbare Kopien.
  ///
  /// Ältere Stände speichern je Lektion die gewählten Unter-Schritte
  /// (`enabledSubsteps`); eine Lektion ohne gewählten Unter-Schritt gilt
  /// dort als abgewählt.
  factory LatinVocabularySettings.fromMap(Map<String, dynamic> data) {
    final disabled = <int>{};

    final savedLessons = data["disabledLessons"];
    final savedSubsteps = data["enabledSubsteps"];

    if (savedLessons is List) {
      disabled.addAll(savedLessons.whereType<num>().map((n) => n.toInt()));
    } else if (savedSubsteps is Map) {
      for (final entry in Map<String, dynamic>.from(savedSubsteps).entries) {
        final lesson = int.tryParse(entry.key);

        if (lesson != null && entry.value is List && entry.value.isEmpty) {
          disabled.add(lesson);
        }
      }
    }

    return LatinVocabularySettings(
      includeVerbForm: data["includeVerbForm"] ?? true,
      includeNounForm: data["includeNounForm"] ?? true,
      includeGender: data["includeGender"] ?? true,
      includeAdjectiveForms: data["includeAdjectiveForms"] ?? true,
      requireOnlyOneTranslation: data["requireOnlyOneTranslation"] ?? true,
      disabledLessons: disabled.toList()..sort(),
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
    required List<int> disabledLessons,
    required List<String> enabledTypes,
  }) async {
    final settings = {
      "includeVerbForm": includeVerbForm,
      "includeNounForm": includeNounForm,
      "includeGender": includeGender,
      "includeAdjectiveForms": includeAdjectiveForms,
      "requireOnlyOneTranslation": requireOnlyOneTranslation,

      "disabledLessons": disabledLessons,
      "enabledTypes": enabledTypes,
    };

    if (uid == null) {
      return LocalLearningStore.instance.saveSettingsGroup(_group, settings);
    }

    await _document(uid).set({_group: settings}, SetOptions(merge: true));
  }
}
