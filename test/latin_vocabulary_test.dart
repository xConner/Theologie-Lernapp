import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/latin/vocabulary/latin_vocabulary_question.dart';
import 'package:theologie_lernapp/screens/latin/latin_vocabulary_overview_screen.dart';
import 'package:theologie_lernapp/services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/utils/latin_normalization.dart';

List<dynamic> _json() {
  return jsonDecode(File("assets/latin_vocabulary.json").readAsStringSync());
}

List<LatinVocabularyEntry> _entries() {
  return [for (final item in _json()) LatinVocabularyEntry.fromJson(item)];
}

/// Lemmata der ursprünglichen Einträge je ID. Lernstände sind an die ID
/// gebunden; eine Umnummerierung würde sie fremden Wörtern zuordnen.
const Map<int, String> _originalLemmas = {
  1: "cogitare", 2: "ubi", 3: "esse", 4: "non", 5: "venire", //
  6: "dominus", 7: "et", 8: "domina", 9: "servus", 10: "serva",
  11: "stare", 12: "spectare", 13: "clamare", 14: "sed", 15: "tacere",
  16: "nunc", 17: "equus", 18: "etiam", 19: "videre", 20: "victor",
  21: "gaudere", 22: "populus", 23: "undique", 24: "clamor", 25: "victoria",
  26: "mercator", 27: "rogare", 28: "ibi", 29: "frumentum", 30: "ridere",
  31: "amare", 32: "quis", 33: "hic", 34: "adesse", 35: "debere",
  36: "furtum", 37: "cur", 38: "ad", 39: "properare", 40: "forum",
  41: "circus", 42: "diu", 43: "amicus", 44: "amica", 45: "per",
  46: "via", 47: "reperire", 48: "audire", 49: "itaque", 50: "iterum",
  51: "iam", 52: "exspectare", 53: "narrare", 54: "subito", 55: "non iam",
  56: "io", 57: "nos", 58: "adiuvare", 59: "vocare", 60: "statim",
  61: "aedificium", 62: "bene", 63: "taberna", 64: "senator", 65: "ecce",
  66: "ante", 67: "semper", 68: "bestia", 69: "ego", 70: "parare",
  71: "tu", 72: "sedere", 73: "scire", 74: "aliter", 75: "parere",
  76: "recte", 77: "verbum", 78: "certe", 79: "monere", 80: "quin",
  81: "laborare", 82: "quid", 83: "apud", 84: "autem", 85: "paulo",
  86: "post", 87: "paulo post", 88: "salutare", 89: "salve", 90: "salvete",
  91: "in", 92: "tum", 93: "intrare", 94: "consilium", 95: "volo",
  96: "audere", 97: "necare", 98: "servare", 99: "quemadmodum",
  100: "propter", 101: "audacia", 102: "laudare",
};

void main() {
  group("Datenintegrität der Vokabelliste", () {
    test("jeder Eintrag lässt sich einlesen", () {
      final json = _json();

      expect(json, isNotEmpty);
      expect(_entries(), hasLength(json.length));
    });

    test("IDs sind eindeutig und positiv", () {
      final ids = [for (final e in _entries()) e.id];

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.every((id) => id > 0), isTrue);
    });

    test("bestehende IDs behalten ihr Wort (Lernstand bleibt gültig)", () {
      final byId = {for (final e in _entries()) e.id: e};

      for (final original in _originalLemmas.entries) {
        expect(
          byId[original.key],
          isNotNull,
          reason: "ID ${original.key} fehlt",
        );
        expect(
          latinSearchKey(byId[original.key]!.lemma),
          original.value,
          reason: "ID ${original.key}",
        );
      }
    });

    test("nur bekannte Felder", () {
      const known = {
        "id",
        "step",
        "substep",
        "type",
        "lemma",
        "principalForm",
        "gender",
        "translations",
        "note",
        "mnemonic",
        "weight",
      };

      for (final item in _json()) {
        final keys = (item as Map<String, dynamic>).keys.toSet();

        expect(
          keys.difference(known),
          isEmpty,
          reason: "Eintrag ${item["id"]}",
        );
      }
    });

    test("Schritte und Unter-Schritte sind positiv und lückenlos", () {
      final entries = _entries();
      final steps = entries.map((e) => e.step).toSet().toList()..sort();

      expect(steps.first, 1);
      expect(steps.last, steps.length, reason: "Schritte ohne Lücke");

      for (final step in steps) {
        final substeps =
            entries
                .where((e) => e.step == step)
                .map((e) => e.substep)
                .toSet()
                .toList()
              ..sort();

        expect(substeps.first, 1, reason: "Schritt $step");
        expect(substeps.last, substeps.length, reason: "Schritt $step");
      }
    });

    test("Wortarten sind im Trainer auswählbar", () {
      for (final entry in _entries()) {
        expect(
          LatinVocabularySettings.allTypes,
          contains(entry.type),
          reason: "${entry.lemma}: Wortart ${entry.type}",
        );
      }
    });

    test("Nomen haben ein gültiges Genus", () {
      for (final entry in _entries().where((e) => e.type == "noun")) {
        expect(["m", "f", "n"], contains(entry.gender), reason: entry.lemma);
      }
    });

    test("Genus nur bei Nomen", () {
      for (final entry in _entries().where((e) => e.type != "noun")) {
        expect(entry.gender, isNull, reason: entry.lemma);
      }
    });

    test("Übersetzungen sind vorhanden, nicht leer und nicht doppelt", () {
      for (final entry in _entries()) {
        expect(entry.translations, isNotEmpty, reason: entry.lemma);

        for (final translation in entry.translations) {
          expect(translation.trim(), isNotEmpty, reason: entry.lemma);
          expect(translation, translation.trim(), reason: entry.lemma);
        }

        expect(
          entry.translations.toSet(),
          hasLength(entry.translations.length),
          reason: entry.lemma,
        );
      }
    });

    test("keine doppelten Lemmata derselben Wortart", () {
      final seen = <String, int>{};

      for (final entry in _entries()) {
        final key = "${latinSearchKey(entry.lemma)}|${entry.type}";

        expect(
          seen.containsKey(key),
          isFalse,
          reason: "${entry.lemma} doppelt (IDs ${seen[key]}, ${entry.id})",
        );

        seen[key] = entry.id;
      }
    });

    test("Lemmata und Formen nutzen nur lateinische Buchstaben", () {
      final allowed = RegExp(r"^[A-Za-zāēīōūȳĀĒĪŌŪȲ ?!]+$");

      for (final entry in _entries()) {
        expect(allowed.hasMatch(entry.lemma), isTrue, reason: entry.lemma);

        if (entry.form != null) {
          expect(allowed.hasMatch(entry.form!), isTrue, reason: entry.form);
        }

        // Zerlegte Längenzeichen würden Suche und Prüfung stören.
        expect(entry.lemma, composeLatinMacrons(entry.lemma));
      }
    });

    test("Zusatzformen werden im Trainer abgefragt", () {
      for (final entry in _entries().where((e) => e.form != null)) {
        final question = LatinVocabularyQuestion(entry: entry);

        expect(
          question.hasExtraLatinFields,
          isTrue,
          reason: "${entry.lemma}: Zusatzform ${entry.form} ohne Feld",
        );
      }
    });
  });

  group("Trainer und Übersicht", () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test("Standard-Einstellungen nehmen alle Vokabeln auf", () {
      const settings = LatinVocabularySettings();

      // Ohne gespeicherte Auswahl sind alle Schritte aktiv (siehe Trainer)
      // und alle Wortarten ausgewählt.
      expect(settings.enabledSubsteps, isEmpty);

      for (final entry in _entries()) {
        expect(settings.enabledTypes, contains(entry.type));
      }
    });

    Widget app(List<LatinVocabularyEntry> entries) {
      return MaterialApp(
        theme: AppTheme.light,
        home: LatinVocabularyOverviewScreen(vocabulary: Future.value(entries)),
      );
    }

    testWidgets("Übersicht zählt alle Vokabeln der Liste", (tester) async {
      final entries = _entries();

      await tester.pumpWidget(app(entries));
      await tester.pumpAndSettle();

      expect(find.text("${entries.length} Vokabeln"), findsOneWidget);
      expect(find.text("Schritt 1.1"), findsOneWidget);
    });

    testWidgets("Suche ohne Längenzeichen findet Lemma und Bedeutung", (
      tester,
    ) async {
      final entries = _entries();

      await tester.pumpWidget(app(entries));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey("latin-vocabulary-search")),
        "cogitare",
      );
      await tester.pumpAndSettle();

      expect(find.text("cōgitāre"), findsOneWidget);
      expect(find.text("1 von ${entries.length} Vokabeln"), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey("latin-vocabulary-search")),
        "Sklavin",
      );
      await tester.pumpAndSettle();

      expect(find.text("serva"), findsOneWidget);
    });

    testWidgets("jede Vokabel erscheint in der Übersicht", (tester) async {
      final entries = _entries();

      tester.view.physicalSize = const Size(1200, 40000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(entries));
      await tester.pumpAndSettle();

      for (final entry in entries) {
        expect(find.text(entry.lemma), findsWidgets, reason: entry.lemma);
      }
    });
  });
}
