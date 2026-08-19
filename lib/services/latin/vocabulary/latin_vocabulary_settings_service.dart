import 'package:cloud_firestore/cloud_firestore.dart';

class LatinVocabularySettingsService {
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

    return data["latin_vocabulary_settings"] ?? {};
  }

  Future<bool> getIncludeVerbForm(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeVerbForm"] ?? true;
  }

  Future<bool> getIncludeNounForm(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeNounForm"] ?? true;
  }

  Future<bool> getIncludeGender(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeGender"] ?? true;
  }

  Future<bool> getIncludeAdjectiveForms(String uid) async {
    final data = await _loadSettings(uid);

    return data["includeAdjectiveForms"] ?? true;
  }

  Future<bool> getRequireOnlyOneTranslation(String uid) async {
    final data = await _loadSettings(uid);

    return data["requireOnlyOneTranslation"] ?? true;
  }

  Future<List<int>> getEnabledSteps(String uid) async {
    final data = await _loadSettings(uid);

    final value = data["enabledSteps"];

    if (value == null) {
      return [1, 2, 3, 4, 5, 6, 7];
    }

    return List<int>.from(value);
  }

  Future<Map<int, List<int>>> getEnabledSubsteps(String uid) async {
    final data = await _loadSettings(uid);

    final value = data["enabledSubsteps"];

    if (value == null) {
      return {};
    }

    final result = <int, List<int>>{};

    final map = Map<String, dynamic>.from(value);

    for (final entry in map.entries) {
      result[int.parse(entry.key)] = List<int>.from(entry.value);
    }

    return result;
  }

  Future<Map<int, List<int>>> getAllEnabledSubsteps(String uid) async {
    final data = await _loadSettings(uid);

    final value = data["enabledSubsteps"];

    if (value == null) {
      return {};
    }

    final result = <int, List<int>>{};

    for (final entry in value.entries) {
      result[int.parse(entry.key)] = List<int>.from(entry.value);
    }

    return result;
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
        "question_word",
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

    await _document(uid).set({
      "latin_vocabulary_settings": {
        "includeVerbForm": includeVerbForm,
        "includeNounForm": includeNounForm,
        "includeGender": includeGender,
        "includeAdjectiveForms": includeAdjectiveForms,
        "requireOnlyOneTranslation": requireOnlyOneTranslation,
        "enabledSteps": enabledSteps,
        "enabledSubsteps": substeps,
        "enabledTypes": enabledTypes,
      },
    }, SetOptions(merge: true));
  }
}
