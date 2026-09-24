import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/algorithms/spaced_repetition.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';

void main() {
  final store = LocalLearningStore.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("Karten", () {
    test("unbekannte Karte liefert die bestehenden Defaults", () async {
      final card = await store.loadCard(LocalLearningStore.greekVocabulary, "1");
      final defaults = LearningCard(id: "1");

      expect(card.stability, defaults.stability);
      expect(card.difficulty, defaults.difficulty);
      expect(card.lastReviewed, isNull);
    });

    test("SRS-Werte werden gespeichert und wieder geladen", () async {
      final card = LearningCard(id: "42");
      SpacedRepetition().answer(card, true);

      await store.saveCard(LocalLearningStore.perikopen, card);

      final loaded = (await store.loadCards(LocalLearningStore.perikopen))["42"]!;

      expect(loaded.stability, card.stability);
      expect(loaded.difficulty, card.difficulty);
      expect(
        loaded.lastReviewed!.millisecondsSinceEpoch,
        card.lastReviewed!.millisecondsSinceEpoch,
      );

      // Collections sind getrennt.
      expect(await store.loadCards(LocalLearningStore.latinVocabulary), isEmpty);
    });

    test("Speichern ohne Eselsbrücke behält die vorhandene (wie merge)", () async {
      await store.saveCard(
        LocalLearningStore.greekVocabulary,
        LearningCard(id: "7", mnemonic: "Merkhilfe"),
      );
      await store.saveCard(
        LocalLearningStore.greekVocabulary,
        LearningCard(id: "7", stability: 3),
      );

      final loaded = await store.loadCard(LocalLearningStore.greekVocabulary, "7");

      expect(loaded.stability, 3);
      expect(loaded.mnemonic, "Merkhilfe");
    });

    test("defekte lokale Daten führen nicht zum Absturz", () async {
      SharedPreferences.setMockInitialValues({
        "guest.v1.cards.vocabulary": jsonEncode({
          "1": {"stability": "x", "difficulty": null, "lastReviewed": "gestern"},
          "2": "keine Map",
          "3": {"stability": -4, "difficulty": 2.5},
        }),
        "guest.v1.cards.latin_vocabulary": "{kein json",
      });

      final cards = await store.loadCards(LocalLearningStore.greekVocabulary);
      final defaults = LearningCard(id: "x");

      expect(cards.keys, unorderedEquals(["1", "3"]));
      expect(cards["1"]!.stability, defaults.stability);
      expect(cards["1"]!.difficulty, defaults.difficulty);
      expect(cards["1"]!.lastReviewed, isNull);
      expect(cards["3"]!.stability, defaults.stability);
      expect(cards["3"]!.difficulty, 2.5);

      expect(await store.loadCards(LocalLearningStore.latinVocabulary), isEmpty);
    });
  });

  group("Einstellungen", () {
    test("werden gespeichert und validiert geladen", () async {
      await store.saveSettingsGroup("vocabulary_settings", {
        "includeArticle": false,
        "enabledSteps": [1, 3],
        "enabledTypes": ["noun"],
      });

      final loaded = await store.loadSettingsGroup("vocabulary_settings");

      expect(loaded["includeArticle"], false);
      expect(loaded["enabledSteps"], [1, 3]);
      expect(loaded["enabledTypes"], ["noun"]);
      expect(loaded.containsKey("includeGenitive"), isFalse);
    });

    test("ungültige Werte werden verworfen", () async {
      SharedPreferences.setMockInitialValues({
        "guest.v1.settings": jsonEncode({
          "greek_grammar_settings": {
            "enabledSteps": ["a"],
            "enabledTypes": ["noun", "verb"],
            "showLemmaFieldNoun": "ja",
            "unbekannt": 1,
          },
          "latin_vocabulary_settings": {
            "enabledSubsteps": {
              "1": [1, 2],
              "2": [3],
            },
          },
        }),
      });

      final grammar = await store.loadSettingsGroup("greek_grammar_settings");
      expect(grammar, {"enabledTypes": ["noun", "verb"]});

      final latin = await store.loadSettingsGroup("latin_vocabulary_settings");
      expect(latin["enabledSubsteps"], {
        "1": [1, 2],
        "2": [3],
      });
    });

    test("Perikopen-Bücher", () async {
      expect(await store.loadSelectedBooks(), isEmpty);
      expect(await store.hasSelectedBooks(), isFalse);

      await store.saveSelectedBooks({"Mt", "Mk"});

      expect(await store.loadSelectedBooks(), {"Mt", "Mk"});
      expect(await store.hasSelectedBooks(), isTrue);
    });
  });

  group("Gastdaten", () {
    test("hasGuestData erkennt Karten und Einstellungen", () async {
      expect(await store.hasGuestData(), isFalse);

      await store.saveSettingsGroup("greek_grammar_settings", {
        "showLemmaFieldNoun": false,
      });
      expect(await store.hasGuestData(), isTrue);

      await store.clearGuestData();
      expect(await store.hasGuestData(), isFalse);

      await store.saveCard(LocalLearningStore.perikopen, LearningCard(id: "1"));
      expect(await store.hasGuestData(), isTrue);
    });

    test("Ablehnung der Übernahme wird je Konto gemerkt", () async {
      expect(await store.isTransferDeclined("uid-a"), isFalse);

      await store.markTransferDeclined("uid-a");

      expect(await store.isTransferDeclined("uid-a"), isTrue);
      expect(await store.isTransferDeclined("uid-b"), isFalse);
    });

    test("clearGuestData lässt fremde Einstellungen (z. B. Sounds) stehen", () async {
      SharedPreferences.setMockInitialValues({"quiz_sound_volume": 0.5});

      await store.saveCard(LocalLearningStore.greekVocabulary, LearningCard(id: "1"));
      await store.clearGuestData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble("quiz_sound_volume"), 0.5);
    });
  });

  group("Gastmodus beim Start", () {
    test("erster Besuch: Gastmodus nicht aktiv (Login-Screen)", () async {
      await store.loadGuestModeState();

      expect(store.guestModeActive.value, isFalse);
    });

    test("'Als Gast fortfahren' bleibt nach Reload erhalten", () async {
      await store.enterGuestMode();
      expect(store.guestModeActive.value, isTrue);

      store.guestModeActive.value = false; // simuliert Neustart
      await store.loadGuestModeState();

      expect(store.guestModeActive.value, isTrue);
    });

    test("vorhandene Gastdaten aktivieren den Gastmodus", () async {
      await store.saveCard(LocalLearningStore.greekVocabulary, LearningCard(id: "1"));

      await store.loadGuestModeState();

      expect(store.guestModeActive.value, isTrue);
    });
  });

  group("Reset", () {
    test("setzt Lernstände zurück, behält Eselsbrücken und Einstellungen", () async {
      final learned = LearningCard(id: "1");
      SpacedRepetition().answer(learned, false);
      await store.saveCard(LocalLearningStore.greekVocabulary, learned);

      final withMnemonic = LearningCard(id: "2", mnemonic: "Merkhilfe");
      SpacedRepetition().answer(withMnemonic, true);
      await store.saveCard(LocalLearningStore.latinVocabulary, withMnemonic);

      await store.saveCard(LocalLearningStore.perikopen, LearningCard(id: "3"));

      await store.saveSettingsGroup("vocabulary_settings", {
        "enabledSteps": [2],
      });

      await store.resetProgress();

      expect(await store.loadCards(LocalLearningStore.greekVocabulary), isEmpty);
      expect(await store.loadCards(LocalLearningStore.perikopen), isEmpty);

      final latin = await store.loadCards(LocalLearningStore.latinVocabulary);
      final defaults = LearningCard(id: "2");

      expect(latin.keys, ["2"]);
      expect(latin["2"]!.mnemonic, "Merkhilfe");
      expect(latin["2"]!.stability, defaults.stability);
      expect(latin["2"]!.difficulty, defaults.difficulty);
      expect(latin["2"]!.lastReviewed, isNull);

      expect(
        (await store.loadSettingsGroup("vocabulary_settings"))["enabledSteps"],
        [2],
      );
    });
  });
}
