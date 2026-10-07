import 'package:cloud_firestore/cloud_firestore.dart';

import '../../local_learning_store.dart';

/// Einstellungen des griechischen Vokabeltrainers. Ohne gespeicherte Werte
/// gelten die Defaults des Konstruktors.
class VocabularySettings {
  /// Schritt 8: zusätzliche Vokabeln für die Klausur (nicht im Lehrbuch).
  static const List<int> allSteps = [1, 2, 3, 4, 5, 6, 7, 8];

  static String stepLabel(int step) {
    return step == 8 ? "Schritt 8 (Klausur-Extra)" : "Schritt $step";
  }

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
    "numeral",
    "phrase",
  ];

  final bool includeArticle;
  final bool includeGenitive;
  final bool includeAorist;
  final bool requireOnlyOneTranslation;
  final List<int> enabledSteps;
  final List<String> enabledTypes;

  const VocabularySettings({
    this.includeArticle = true,
    this.includeGenitive = true,
    this.includeAorist = true,
    this.requireOnlyOneTranslation = false,
    this.enabledSteps = allSteps,
    this.enabledTypes = allTypes,
  });

  /// Liest das gespeicherte Feld `vocabulary_settings`. Die Listen sind
  /// eigene, veränderbare Kopien.
  factory VocabularySettings.fromMap(Map<String, dynamic> data) {
    final steps = data["enabledSteps"];
    final types = data["enabledTypes"];

    return VocabularySettings(
      includeArticle: data["includeArticle"] ?? true,
      includeGenitive: data["includeGenitive"] ?? true,
      includeAorist: data["includeAorist"] ?? true,
      requireOnlyOneTranslation: data["requireOnlyOneTranslation"] ?? false,
      enabledSteps: List<int>.from(steps ?? allSteps),
      enabledTypes: List<String>.from(types ?? allTypes),
    );
  }
}

/// uid == null bedeutet Gastmodus (lokale Speicherung).
class VocabularySettingsService {
  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static const String _group = "vocabulary_settings";

  DocumentReference<Map<String, dynamic>> _document(String uid) {
    return firestore.collection("users").doc(uid);
  }

  /// Lädt alle Einstellungen mit einem einzigen Lesezugriff.
  Future<VocabularySettings> load(String? uid) async {
    if (uid == null) {
      return VocabularySettings.fromMap(
        await LocalLearningStore.instance.loadSettingsGroup(_group),
      );
    }

    final data = (await _document(uid).get()).data();

    return VocabularySettings.fromMap(data?[_group] ?? {});
  }

  Future<void> saveSettings({
    required String? uid,
    required bool includeArticle,
    required bool includeGenitive,
    required bool includeAorist,
    required bool requireOnlyOneTranslation,
    required List<int> enabledSteps,
    required List<String> enabledTypes,
  }) async {
    final settings = {
      "includeArticle": includeArticle,
      "includeGenitive": includeGenitive,
      "includeAorist": includeAorist,
      "requireOnlyOneTranslation": requireOnlyOneTranslation,

      "enabledSteps": enabledSteps,

      "enabledTypes": enabledTypes,
    };

    if (uid == null) {
      return LocalLearningStore.instance.saveSettingsGroup(_group, settings);
    }

    await _document(uid).set({_group: settings}, SetOptions(merge: true));
  }
}
