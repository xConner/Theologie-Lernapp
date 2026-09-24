import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/greek/vocabulary/learning_card.dart';

/// Lokaler Speicher für Lernstände und Lerneinstellungen im Gastmodus
/// (auf Web: localStorage über shared_preferences).
///
/// Die Struktur spiegelt die Firestore-Daten unter `users/{uid}`:
///   * Karten je Collection (`vocabulary`, `learning_cards`,
///     `latin_vocabulary`) mit denselben Feldern wie in Firestore
///   * die Einstellungs-Felder des `users/{uid}`-Dokuments
///     (`vocabulary_settings`, `latin_vocabulary_settings`,
///     `greek_grammar_settings`)
///   * `quiz_settings/perikopen`
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

  static const List<String> cardCollections = [
    greekVocabulary,
    perikopen,
    latinVocabulary,
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
    },
    "latin_vocabulary_settings": {
      "includeVerbForm": _FieldType.boolean,
      "includeNounForm": _FieldType.boolean,
      "includeGender": _FieldType.boolean,
      "includeAdjectiveForms": _FieldType.boolean,
      "requireOnlyOneTranslation": _FieldType.boolean,
      "enabledSteps": _FieldType.intList,
      "enabledSubsteps": _FieldType.intListMap,
      "enabledTypes": _FieldType.stringList,
    },
    "greek_grammar_settings": {
      "enabledSteps": _FieldType.intList,
      "enabledTypes": _FieldType.stringList,
      "showLemmaFieldNoun": _FieldType.boolean,
      "showLemmaFieldVerb": _FieldType.boolean,
    },
  };

  static Iterable<String> get settingsGroups => _settingsSchema.keys;

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
          (prefs.getBool(_guestModeChosenKey) ?? false) ||
          await hasGuestData();
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

    return raw.map(
      (id, data) => MapEntry(id, LearningCard.fromJson(id, data)),
    );
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
  Future<void> saveCard(String collection, LearningCard card) async {
    final cards = await _readCardMaps(collection);

    cards[card.id] = {...?cards[card.id], ...card.toJson()};

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
  }

  // ==========================
  // RESET
  // ==========================

  /// Setzt alle lokalen Lernstände auf die Initialwerte zurück. Eigene
  /// Eselsbrücken und Einstellungen bleiben erhalten.
  Future<void> resetProgress() async {
    for (final collection in cardCollections) {
      final cards = await loadCards(collection);

      final kept = <String, Map<String, dynamic>>{};

      for (final card in cards.values) {
        final mnemonic = card.mnemonic;

        if (mnemonic != null && mnemonic.isNotEmpty) {
          kept[card.id] = LearningCard(id: card.id, mnemonic: mnemonic).toJson();
        }
      }

      if (kept.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cardsKey(collection));
      } else {
        await _writeCardMaps(collection, kept);
      }
    }
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
