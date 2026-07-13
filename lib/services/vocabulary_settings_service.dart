import 'package:shared_preferences/shared_preferences.dart';

class VocabularySettingsService {
  static const String includeArticleKey = "include_article";
  static const String includeGenitiveKey = "include_genitive";
  static const String includeAoristKey = "include_aorist";

  static const String requireOnlyOneTranslationKey =
      "require_only_one_translation";

  static Future<SharedPreferences> _prefs() async {
    return await SharedPreferences.getInstance();
  }

  static Future<bool> getIncludeArticle() async {
    final prefs = await _prefs();

    return prefs.getBool(includeArticleKey) ?? true;
  }

  static Future<bool> getIncludeGenitive() async {
    final prefs = await _prefs();

    return prefs.getBool(includeGenitiveKey) ?? true;
  }

  static Future<bool> getIncludeAorist() async {
    final prefs = await _prefs();

    return prefs.getBool(includeAoristKey) ?? true;
  }

  static Future<bool> getRequireOnlyOneTranslation() async {
    final prefs = await _prefs();

    return prefs.getBool(requireOnlyOneTranslationKey) ?? false;
  }

  static Future<void> setIncludeArticle(bool value) async {
    final prefs = await _prefs();

    await prefs.setBool(includeArticleKey, value);
  }

  static Future<void> setIncludeGenitive(bool value) async {
    final prefs = await _prefs();

    await prefs.setBool(includeGenitiveKey, value);
  }

  static Future<void> setIncludeAorist(bool value) async {
    final prefs = await _prefs();

    await prefs.setBool(includeAoristKey, value);
  }

  static Future<void> setRequireOnlyOneTranslation(bool value) async {
    final prefs = await _prefs();

    await prefs.setBool(requireOnlyOneTranslationKey, value);
  }
}
