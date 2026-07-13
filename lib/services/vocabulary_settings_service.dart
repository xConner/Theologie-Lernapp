import 'package:cloud_firestore/cloud_firestore.dart';

class VocabularySettingsService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _document(String uid) {
    return firestore.collection("users").doc(uid);
  }

  Future<Map<String, dynamic>> _loadSettings(String uid) async {
    final doc = await _document(uid).get();

    if (!doc.exists) {
      return {};
    }

    final data = doc.data();

    if (data == null) {
      return {};
    }

    return data["vocabulary_settings"] ?? {};
  }

  Future<bool> getIncludeArticle(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeArticle"] ?? true;
  }

  Future<bool> getIncludeGenitive(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeGenitive"] ?? true;
  }

  Future<bool> getIncludeAorist(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeAorist"] ?? true;
  }

  Future<bool> getRequireOnlyOneTranslation(String uid) async {
    final data = await _loadSettings(uid);

    return data["requireOnlyOneTranslation"] ?? false;
  }

  Future<List<int>> getEnabledSteps(String uid) async {
    final data = await _loadSettings(uid);

    final value = data["enabledSteps"];

    if (value == null) {
      return [1, 2, 3, 4, 5, 6, 7];
    }

    return List<int>.from(value);
  }

  Future<List<String>> getEnabledTypes(String uid) async {
    final data = await _loadSettings(uid);

    final value = data["enabledTypes"];

    if (value == null) {
      return [
        "noun",
        "verb",
        "adjective",
        "adverb",
        "pronoun",
        "preposition",
        "conjunction",
        "particle",
        "phrase",
      ];
    }

    return List<String>.from(value);
  }

  Future<void> saveSettings({
    required String uid,
    required bool includeArticle,
    required bool includeGenitive,
    required bool includeAorist,
    required bool requireOnlyOneTranslation,
    required List<int> enabledSteps,
    required List<String> enabledTypes,
  }) async {
    await _document(uid).set({
      "vocabulary_settings": {
        "includeArticle": includeArticle,
        "includeGenitive": includeGenitive,
        "includeAorist": includeAorist,
        "requireOnlyOneTranslation": requireOnlyOneTranslation,

        "enabledSteps": enabledSteps,

        "enabledTypes": enabledTypes,
      },
    }, SetOptions(merge: true));
  }
}
