import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/greek/vocabulary/learning_card.dart';
import '../models/memorization/memorization_card.dart';

/// Lokaler Speicher für Lernstände und Lerneinstellungen im Gastmodus
/// (auf Web: localStorage über shared_preferences).
///
/// Die Struktur spiegelt die Firestore-Daten unter `users/{uid}`:
///   * Karten je Collection (`vocabulary`, `learning_cards`,
///     `latin_vocabulary`, `grammar`, `memorization`) mit denselben Feldern
///     wie in Firestore
///   * die Einstellungs-Felder des `users/{uid}`-Dokuments
///     (`vocabulary_settings`, `latin_vocabulary_settings`,
///     `greek_grammar_settings`, `memorization_settings`)
///   * `quiz_settings/perikopen`
///   * die Dokumente von „Bücher systematisch lernen“, der Fortschritt in
///     „Einführung in die Logik“, Lernstand/Einstellungen des lateinischen
///     Grammatiktrainers und der Bereiche Kirchengeschichte und Altes
///     Testament unter `quiz_settings` ([quizDocuments])
///
/// Alle Keys sind versioniert (`guest.v1.`), damit sich das Format später
/// migrieren lässt. Fehlende oder ungültige Daten werden als "nicht
/// vorhanden" behandelt; die Aufrufer verwenden dann ihre normalen Defaults.
class LocalLearningStore {
  LocalLearningStore._();

  static final LocalLearningStore instance = LocalLearningStore._();

  static const int schemaVersion = 1;

  static const String _versionKey = "guest.schemaVersion";
  static const String _prefix = "guest.v1.";
  static const String _settingsKey = "${_prefix}settings";
  static const String _perikopenSettingsKey =
      "${_prefix}quiz_settings.perikopen";
  static const String _transferDeclinedKey = "guest.transferDeclinedFor";
  static const String _guestModeChosenKey = "guest.modeChosen";

  /// Karten-Collections mit denselben Namen wie unter `users/{uid}/...`.
  static const String greekVocabulary = "vocabulary";
  static const String perikopen = "learning_cards";
  static const String latinVocabulary = "latin_vocabulary";
  static const String greekGrammar = "grammar";
  static const String memorization = "memorization";

  static const List<String> cardCollections = [
    greekVocabulary,
    perikopen,
    latinVocabulary,
    greekGrammar,
    memorization,
  ];

  /// Erlaubte Einstellungs-Felder je Gruppe (entspricht den Feldern, die die
  /// Trainer bisher in Firestore speichern). Unbekannte oder falsch
  /// typisierte Werte werden beim Lesen verworfen.
  static const Map<String, Map<String, _FieldType>> _settingsSchema = {
    "vocabulary_settings": {
      "includeArticle": _FieldType.boolean,
      "includeGenitive": _FieldType.boolean,
      "includeAorist": _FieldType.boolean,
      "requireOnlyOneTranslation": _FieldType.boolean,
      "enabledSteps": _FieldType.intList,
      "enabledTypes": _FieldType.stringList,
      "onlyDifficult": _FieldType.boolean,
    },
    "latin_vocabulary_settings": {
      "includeVerbForm": _FieldType.boolean,
      "includeNounForm": _FieldType.boolean,
      "includeGender": _FieldType.boolean,
      "includeAdjectiveForms": _FieldType.boolean,
      "requireOnlyOneTranslation": _FieldType.boolean,
      "disabledLessons": _FieldType.intList,
      // Älterer Stand (Unter-Schritte je Lektion), nur noch gelesen.
      "enabledSubsteps": _FieldType.intListMap,
      "enabledTypes": _FieldType.stringList,
      "onlyDifficult": _FieldType.boolean,
    },
    "greek_grammar_settings": {
      "enabledSteps": _FieldType.intList,
      "enabledTypes": _FieldType.stringList,
      "showLemmaFieldNoun": _FieldType.boolean,
      "showLemmaFieldVerb": _FieldType.boolean,
    },
    "memorization_settings": {
      "texts": _FieldType.stringList,
      "paused": _FieldType.stringList,
      "favorites": _FieldType.stringList,
    },
  };

  static Iterable<String> get settingsGroups => _settingsSchema.keys;

  /// Dokumente unter `quiz_settings` für „Bücher systematisch lernen“: der
  /// Lernstand je Perikope, persönliche Verspräzisierungen und Lernpläne.
  /// Getrennt von den Karten des Endlos-Quiz (`learning_cards`).
  static const String pericopeBooks = "pericope_books";
  static const String pericopePrecision = "pericope_precision";
  static const String pericopePlans = "pericope_plans";

  static const List<String> bookLearningDocuments = [
    pericopeBooks,
    pericopePrecision,
    pericopePlans,
  ];

  /// Lernfortschritt im Lernbereich „Einführung in die Logik“
  /// (`quiz_settings/logic_course`, siehe `LogicProgressStore`).
  static const String logicCourse = "logic_course";

  /// Lernstand und Einstellungen des lateinischen Grammatiktrainers
  /// (`quiz_settings/latin_grammar` bzw. `latin_grammar_settings`, siehe
  /// `LatinGrammarStore`).
  static const String latinGrammar = "latin_grammar";
  static const String latinGrammarSettings = "latin_grammar_settings";

  /// Lernstand und Einstellungen im Bereich Kirchengeschichte
  /// (`quiz_settings/church_history` bzw. `church_history_settings`, siehe
  /// `ChurchHistoryStore`).
  static const String churchHistory = "church_history";
  static const String churchHistorySettings = "church_history_settings";

  /// Lernstand und Einstellungen im Bereich Altes Testament
  /// (`quiz_settings/old_testament` bzw. `old_testament_settings`, siehe
  /// `OldTestamentStore`).
  static const String oldTestament = "old_testament";
  static const String oldTestamentSettings = "old_testament_settings";

  /// Lernplan der lateinischen Vokabeln und die Einführungen im Plan
  /// (`quiz_settings/latin_vocabulary_plan` bzw.
  /// `latin_vocabulary_plan_progress`, siehe `LatinVocabularyPlanStore`).
  /// Der Lernstand je Vokabel liegt wie im Vokabeltrainer in der Collection
  /// `latin_vocabulary`.
  static const String latinVocabularyPlan = "latin_vocabulary_plan";
  static const String latinVocabularyPlanProgress =
      "latin_vocabulary_plan_progress";

  /// Lernplan der griechischen Vokabeln, wie beim Latein-Lernplan
  /// (`GreekVocabularyPlanStore`). Der Lernstand je Vokabel liegt wie im
  /// Vokabeltrainer in der Collection `vocabulary`.
  static const String greekVocabularyPlan = "greek_vocabulary_plan";
  static const String greekVocabularyPlanProgress =
      "greek_vocabulary_plan_progress";

  /// Alle Dokumente unter `quiz_settings`, die bei der Übernahme von
  /// Gastdaten übertragen und beim Löschen der Gastdaten entfernt werden.
  static const List<String> quizDocuments = [
    ...bookLearningDocuments,
    logicCourse,
    latinGrammar,
    latinGrammarSettings,
    churchHistory,
    churchHistorySettings,
    oldTestament,
    oldTestamentSettings,
    latinVocabularyPlan,
    latinVocabularyPlanProgress,
    greekVocabularyPlan,
    greekVocabularyPlanProgress,
  ];

  /// Dokumente unter `quiz_settings`, die nur Lernfortschritt enthalten und
  /// beim Zurücksetzen aller Lernfortschritte gelöscht werden (Konto und
  /// Gast). Einstellungen, Verspräzisierungen und Lernpläne gehören nicht
  /// dazu. Entspricht den Dokumenten aller `ProgressArea`s (Test).
  static const List<String> progressDocuments = [
    pericopeBooks,
    logicCourse,
    latinGrammar,
    churchHistory,
    oldTestament,
    latinVocabularyPlanProgress,
    greekVocabularyPlanProgress,
  ];

  static String _quizDocumentKey(String name) =>
      "${_prefix}quiz_settings.$name";

  static String _cardsKey(String collection) => "${_prefix}cards.$collection";

  // ==========================
  // GASTMODUS AKTIV?
  // ==========================

  /// true, sobald in diesem Browser als Gast gearbeitet wurde (bewusst
  /// "Als Gast fortfahren" gewählt oder lokale Gastdaten vorhanden). Ohne
  /// Anmeldung zeigt AuthGate dann die Startseite statt des Login-Screens.
  final ValueNotifier<bool> guestModeActive = ValueNotifier(false);

  /// Wird einmal beim App-Start geladen (siehe main.dart).
  Future<void> loadGuestModeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      guestModeActive.value =
          (prefs.getBool(_guestModeChosenKey) ?? false) || await hasGuestData();
    } catch (_) {
      guestModeActive.value = false;
    }
  }

  Future<void> enterGuestMode() async {
    guestModeActive.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestModeChosenKey, true);
    } catch (_) {
      // Ohne persistenten Speicher gilt die Wahl nur für diese Sitzung.
    }
  }

  // ==========================
  // KARTEN
  // ==========================

  Future<Map<String, LearningCard>> loadCards(String collection) async {
    final raw = await _readCardMaps(collection);

    // Memorier-Karten tragen zusätzliche Felder (Hilfestufe, Versuche), die
    // auch bei der Übernahme in ein Konto erhalten bleiben müssen.
    if (collection == memorization) {
      return raw.map(
        (id, data) => MapEntry(id, MemorizationCard.fromJson(id, data)),
      );
    }

    return raw.map((id, data) => MapEntry(id, LearningCard.fromJson(id, data)));
  }

  Future<LearningCard> loadCard(String collection, String id) async {
    final data = (await _readCardMaps(collection))[id];

    if (data == null) {
      return LearningCard(id: id);
    }

    return LearningCard.fromJson(id, data);
  }

  /// Entspricht `set(card.toFirestore(), SetOptions(merge: true))`:
  /// vorhandene Felder, die die Karte nicht mitschickt (z. B. eine
  /// Eselsbrücke), bleiben erhalten.
  Future<void> saveCard(String collection, LearningCard card) {
    return saveCards(collection, [card]);
  }

  Future<void> saveCards(String collection, List<LearningCard> changed) async {
    final cards = await _readCardMaps(collection);

    for (final card in changed) {
      cards[card.id] = {...?cards[card.id], ...card.toJson()};
    }

    await _writeCardMaps(collection, cards);
  }

  Future<Map<String, Map<String, dynamic>>> _readCardMaps(
    String collection,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final decoded = _decodeMap(prefs.getString(_cardsKey(collection)));

    final result = <String, Map<String, dynamic>>{};

    for (final entry in decoded.entries) {
      final value = entry.value;

      if (value is Map) {
        result[entry.key] = Map<String, dynamic>.from(value);
      }
    }

    return result;
  }

  Future<void> _writeCardMaps(
    String collection,
    Map<String, Map<String, dynamic>> cards,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await _markSchema(prefs);

    await prefs.setString(_cardsKey(collection), jsonEncode(cards));
  }

  // ==========================
  // EINSTELLUNGEN
  // ==========================

  /// Liefert die validierten Werte einer Einstellungs-Gruppe (z. B.
  /// `vocabulary_settings`); leer, wenn nichts gespeichert ist.
  Future<Map<String, dynamic>> loadSettingsGroup(String group) async {
    final prefs = await SharedPreferences.getInstance();

    final all = _decodeMap(prefs.getString(_settingsKey));

    return _sanitizeGroup(group, all[group]);
  }

  /// Entspricht `set({group: values}, SetOptions(merge: true))` auf dem
  /// `users/{uid}`-Dokument.
  Future<void> saveSettingsGroup(
    String group,
    Map<String, dynamic> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final all = _decodeMap(prefs.getString(_settingsKey));

    final existing = all[group];

    all[group] = {
      if (existing is Map) ...Map<String, dynamic>.from(existing),
      ...values,
    };

    await _markSchema(prefs);

    await prefs.setString(_settingsKey, jsonEncode(all));
  }

  /// Leeres Set = nichts gespeichert (wie bei Firestore `loadBooks`).
  Future<Set<String>> loadSelectedBooks() async {
    final prefs = await SharedPreferences.getInstance();

    final data = _decodeMap(prefs.getString(_perikopenSettingsKey));

    final raw = data["selectedBooks"];

    if (raw is List) {
      return raw.whereType<String>().toSet();
    }

    return {};
  }

  Future<void> saveSelectedBooks(Set<String> books) async {
    final prefs = await SharedPreferences.getInstance();

    await _markSchema(prefs);

    await prefs.setString(
      _perikopenSettingsKey,
      jsonEncode({"selectedBooks": books.toList()}),
    );
  }

  Future<bool> hasSelectedBooks() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.containsKey(_perikopenSettingsKey);
  }

  // ==========================
  // BÜCHER SYSTEMATISCH LERNEN
  // ==========================

  /// Inhalt eines Dokuments aus [quizDocuments]; leer, wenn nichts
  /// (Gültiges) gespeichert ist.
  Future<Map<String, dynamic>> loadQuizDocument(String name) async {
    final prefs = await SharedPreferences.getInstance();

    return _decodeMap(prefs.getString(_quizDocumentKey(name)));
  }

  /// Ersetzt die Einträge [entries] im Feld [field] des Dokuments; ein Wert
  /// `null` entfernt den Eintrag (wie `FieldValue.delete()`).
  Future<void> mergeQuizDocument(
    String name,
    String field,
    Map<String, Object?> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final doc = _decodeMap(prefs.getString(_quizDocumentKey(name)));

    final existing = doc[field];

    final values = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    for (final entry in entries.entries) {
      if (entry.value == null) {
        values.remove(entry.key);
      } else {
        values[entry.key] = entry.value;
      }
    }

    doc[field] = values;

    await _markSchema(prefs);

    await prefs.setString(_quizDocumentKey(name), jsonEncode(doc));
  }

  Future<bool> _hasQuizDocumentEntries(String name) async {
    final doc = await loadQuizDocument(name);

    return doc.values.any((value) => value is Map && value.isNotEmpty);
  }

  // ==========================
  // GAST → KONTO
  // ==========================

  /// Gibt es lokale Lernstände oder Lerneinstellungen?
  Future<bool> hasGuestData() async {
    for (final collection in cardCollections) {
      if ((await _readCardMaps(collection)).isNotEmpty) {
        return true;
      }
    }

    for (final group in settingsGroups) {
      if ((await loadSettingsGroup(group)).isNotEmpty) {
        return true;
      }
    }

    for (final name in quizDocuments) {
      if (await _hasQuizDocumentEntries(name)) {
        return true;
      }
    }

    return hasSelectedBooks();
  }

  Future<bool> isTransferDeclined(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_transferDeclinedKey)?.contains(uid) ?? false;
  }

  Future<void> markTransferDeclined(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final list = prefs.getStringList(_transferDeclinedKey) ?? [];

    if (!list.contains(uid)) {
      await prefs.setStringList(_transferDeclinedKey, [...list, uid]);
    }
  }

  /// Entfernt alle lokalen Gast-Lernstände und -Lerneinstellungen (nach der
  /// Übernahme in ein Konto).
  Future<void> clearGuestData() async {
    final prefs = await SharedPreferences.getInstance();

    for (final collection in cardCollections) {
      await prefs.remove(_cardsKey(collection));
    }

    await prefs.remove(_settingsKey);
    await prefs.remove(_perikopenSettingsKey);

    for (final name in quizDocuments) {
      await prefs.remove(_quizDocumentKey(name));
    }
  }

  // ==========================
  // RESET
  // ==========================

  /// Setzt alle lokalen Lernstände auf die Initialwerte zurück (auch den
  /// Fortschritt in „Einführung in die Logik“ und im lateinischen
  /// Grammatiktrainer). Eigene Eselsbrücken und
  /// Einstellungen (auch Verspräzisierungen und Lernpläne) bleiben erhalten.
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();

    for (final name in progressDocuments) {
      await prefs.remove(_quizDocumentKey(name));
    }

    for (final collection in cardCollections) {
      await resetCollection(collection);
    }
  }

  /// Setzt die Karten einer Collection zurück (alle oder nur [ids]): Karten
  /// mit Eselsbrücke behalten nur diese, alle anderen werden entfernt.
  /// Andere Collections, Einstellungen und Dokumente bleiben unberührt.
  Future<void> resetCollection(String collection, {Set<String>? ids}) async {
    final raw = await _readCardMaps(collection);

    final cards = await loadCards(collection);

    final kept = <String, Map<String, dynamic>>{};

    for (final entry in raw.entries) {
      final id = entry.key;

      if (ids != null && !ids.contains(id)) {
        // Nicht betroffen: unverändert (auch zusätzliche Felder).
        kept[id] = entry.value;
        continue;
      }

      final mnemonic = cards[id]?.mnemonic;

      if (mnemonic != null && mnemonic.isNotEmpty) {
        kept[id] = LearningCard(id: id, mnemonic: mnemonic).toJson();
      }
    }

    if (kept.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cardsKey(collection));
    } else {
      await _writeCardMaps(collection, kept);
    }
  }

  /// Entfernt ein Dokument aus [quizDocuments] vollständig.
  Future<void> removeQuizDocument(String name) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_quizDocumentKey(name));
  }

  // ==========================
  // HILFSFUNKTIONEN
  // ==========================

  Future<void> _markSchema(SharedPreferences prefs) async {
    if (prefs.getInt(_versionKey) != schemaVersion) {
      await prefs.setInt(_versionKey, schemaVersion);
    }
  }

  static Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Defekte lokale Daten werden ignoriert.
    }

    return {};
  }

  static Map<String, dynamic> _sanitizeGroup(String group, Object? raw) {
    final schema = _settingsSchema[group];

    if (schema == null || raw is! Map) {
      return {};
    }

    final result = <String, dynamic>{};

    for (final field in schema.entries) {
      final value = _sanitizeValue(field.value, raw[field.key]);

      if (value != null) {
        result[field.key] = value;
      }
    }

    return result;
  }

  static Object? _sanitizeValue(_FieldType type, Object? value) {
    switch (type) {
      case _FieldType.boolean:
        return value is bool ? value : null;

      case _FieldType.intList:
        return _intList(value);

      case _FieldType.stringList:
        if (value is! List || value.any((e) => e is! String)) return null;
        return List<String>.from(value);

      case _FieldType.intListMap:
        if (value is! Map) return null;

        final result = <String, List<int>>{};

        for (final entry in value.entries) {
          final key = entry.key.toString();
          final list = _intList(entry.value);

          if (int.tryParse(key) == null || list == null) return null;

          result[key] = list;
        }

        return result;
    }
  }

  static List<int>? _intList(Object? value) {
    if (value is! List || value.any((e) => e is! num)) return null;

    return value.map((e) => (e as num).toInt()).toList();
  }
}

enum _FieldType { boolean, intList, stringList, intListMap }
