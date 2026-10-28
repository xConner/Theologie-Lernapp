import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/screens/greek/grammar_overview_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/adjectives_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/aorist_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/aorist_sheet_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/article_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/comparison_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/conjugations_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/declinations_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/grammar_topics.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/imperative_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/infinitive_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/participles_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/prepositions_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/pronouns_screen.dart';
import 'package:theologie_lernapp/screens/greek/grammar_topics/syntax_screen.dart';
import 'package:theologie_lernapp/services/greek/grammar/adjective_comparisons.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/pronoun_paradigms.dart';
import 'package:theologie_lernapp/services/greek/grammar/verb_paradigm.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/grammar_overview_widgets.dart';

List<GreekVocabularyEntry> _vocabulary() {
  final List<dynamic> json = jsonDecode(
    File("assets/greek_vocabulary.json").readAsStringSync(),
  );

  return [for (final item in json) GreekVocabularyEntry.fromJson(item)];
}

PronounParadigms _pronouns() {
  return PronounParadigms.fromJson(
    File("assets/greek_pronoun_forms.json").readAsStringSync(),
  );
}

Widget _app(Widget home, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.light, home: home);
}

/// Themenseiten, die ohne Laden auskommen bzw. hier ihre Daten direkt
/// bekommen.
Map<String, Widget Function()> _screens() {
  final vocabulary = _vocabulary();
  final pronouns = _pronouns();

  return {
    "article": () => const ArticleScreen(),
    "declensions": () => const DeclinationsScreen(),
    "adjectives": () => const AdjectivesScreen(),
    "comparison": () => const ComparisonScreen(),
    "pronouns": () => PronounsScreen(paradigms: Future.value(pronouns)),
    "conjugations": () => const ConjugationsScreen(),
    "aorist": () => AoristScreen(vocabulary: Future.value(vocabulary)),
    "aorist_sheet": () => const AoristSheetScreen(),
    "imperative": () => const ImperativeScreen(),
    "infinitive": () => const InfinitiveScreen(),
    "participles": () => const ParticiplesScreen(),
    "prepositions": () =>
        PrepositionsScreen(vocabulary: Future.value(vocabulary)),
    "syntax": () => const SyntaxScreen(),
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("Themenliste", () {
    test("enthält die bisherigen Einträge", () {
      final titles = [for (final topic in GrammarTopics.all) topic.title];

      expect(
        titles,
        containsAll([
          "Bestimmter Artikel",
          "Deklinationen",
          "Pronomen",
          "Konjugationen",
        ]),
      );
    });

    test("enthält die zuvor fehlenden Themen", () {
      final titles = [for (final topic in GrammarTopics.all) topic.title];

      expect(
        titles,
        containsAll([
          "Imperativ",
          "Infinitiv",
          "Partizipien",
          "Aorist und Stammformen",
          "Aoristblatt",
          "Adjektive",
          "Steigerung der Adjektive",
          "Präpositionen",
          "Syntax und Konstruktionen",
        ]),
      );
    });

    test("deckt jeden Modus des Grammatiktrainers ab", () {
      final text = [
        for (final topic in GrammarTopics.all)
          "${topic.title} ${topic.subtitle}",
      ].join(" ");

      for (final mood in VerbMood.all) {
        expect(text, contains(mood), reason: mood);
      }
    });

    test("hat keine doppelten Kennungen oder Titel", () {
      final ids = [for (final topic in GrammarTopics.all) topic.id];
      final titles = [for (final topic in GrammarTopics.all) topic.title];

      expect(ids.toSet().length, ids.length);
      expect(titles.toSet().length, titles.length);
    });

    test("führt Perfekt und Plusquamperfekt nicht als Thema", () {
      for (final topic in GrammarTopics.all) {
        for (final tense in ["Perfekt", "Plusquamperfekt", "Futur II"]) {
          expect(topic.title, isNot(contains(tense)));
          expect(topic.subtitle, isNot(contains(tense)));
        }
      }
    });

    test("jedes Thema hat eine Seite in diesem Test", () {
      expect(_screens().keys.toSet(), {
        for (final topic in GrammarTopics.all) topic.id,
      });
    });
  });

  group("Übersicht", () {
    testWidgets("zeigt alle Gruppen und Themen genau einmal", (tester) async {
      await tester.pumpWidget(_app(const GrammarOverviewScreen()));

      for (final group in GrammarTopics.groups) {
        expect(find.text(group.title), findsOneWidget);

        for (final topic in group.topics) {
          expect(find.widgetWithText(ListTile, topic.title), findsOneWidget);
        }
      }
    });

    testWidgets(
      "jeder Eintrag öffnet seine Seite, Zurück führt zur Übersicht",
      (tester) async {
        await tester.pumpWidget(_app(const GrammarOverviewScreen()));

        for (final topic in GrammarTopics.all) {
          final tile = find.widgetWithText(ListTile, topic.title);

          await tester.ensureVisible(tile);
          await tester.pump();
          await tester.tap(tile);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(
            find.byType(GrammarOverviewScreen, skipOffstage: true),
            findsNothing,
            reason: topic.id,
          );
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(topic.title),
            ),
            findsOneWidget,
            reason: topic.id,
          );
          expect(tester.takeException(), isNull, reason: topic.id);

          await tester.pageBack();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(GrammarOverviewScreen), findsOneWidget);
        }
      },
    );
  });

  group("Themenseiten", () {
    for (final (name, theme, size) in [
      ("schmal, hell", AppTheme.light, const Size(320, 568)),
      ("schmal, dunkel", AppTheme.dark, const Size(320, 568)),
      ("breit, hell", AppTheme.light, const Size(1400, 900)),
    ]) {
      testWidgets("bauen ohne Fehler und Overflow ($name)", (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final screens = {
          "overview": () => const GrammarOverviewScreen(),
          ..._screens(),
        };

        for (final MapEntry(key: id, value: build) in screens.entries) {
          await tester.pumpWidget(_app(build(), theme: theme));
          await tester.pump();

          expect(tester.takeException(), isNull, reason: id);
          expect(find.byType(GrammarTopicScaffold), findsOneWidget, reason: id);
          expect(find.byType(GrammarStatus), findsNothing, reason: id);
        }
      });
    }

    testWidgets("bisherige Tabellen bleiben erhalten", (tester) async {
      await tester.pumpWidget(_app(const ArticleScreen()));
      for (final form in ["ὁ", "τῆς", "τοῖς", "τάς"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }

      await tester.pumpWidget(_app(const ConjugationsScreen()));
      for (final form in ["-μαι", "-ντο", "ἐσμέν", "ἦσαν"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }

      await tester.pumpWidget(_app(const DeclinationsScreen()));
      for (final title in [
        "o-Deklination",
        "a-Deklination",
        "3./Konsonantische Deklination",
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.textContaining("καρδί-"), findsNWidgets(8));

      await tester.pumpWidget(
        _app(PronounsScreen(paradigms: Future.value(_pronouns()))),
      );
      await tester.pump();
      expect(find.byType(ExpansionTile), findsNWidgets(_pronouns().all.length));
      expect(find.text("οὗτος"), findsOneWidget);
    });

    testWidgets("Imperativ und Infinitiv zeigen die Formen von παύω", (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ImperativeScreen()));
      for (final form in ["παῦε", "παυέσθω", "παῦσον", "παύθητι"]) {
        expect(find.text(form), findsOneWidget, reason: form);
      }

      await tester.pumpWidget(_app(const InfinitiveScreen()));
      for (final form in ["παύειν", "παῦσαι", "παύσασθαι", "παυθῆναι"]) {
        expect(find.text(form), findsWidgets, reason: form);
      }
    });

    testWidgets("Fehler beim Laden wird angezeigt", (tester) async {
      final vocabulary = Completer<List<GreekVocabularyEntry>>();

      await tester.pumpWidget(
        _app(AoristScreen(vocabulary: vocabulary.future)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      vocabulary.completeError(StateError("x"));
      await tester.pump();

      expect(
        find.text("Die Stammformen konnten nicht geladen werden."),
        findsOneWidget,
      );
    });
  });

  group("Inhalte aus dem Lernangebot", () {
    test("jedes Partizip der Übersicht bildet der Trainer selbst", () {
      for (final example in ParticiplesScreen.examples) {
        final paradigm = ParticiplesScreen.paradigmOf(example);

        expect(paradigm, isNotNull, reason: example.title);
        expect(paradigm!.form("Nominativ", "Sg", "m"), example.masculine);
        expect(paradigm.forms, hasLength(24));
      }
    });

    test("Adjektive und Komparativ lassen sich deklinieren", () {
      expect(AdjectivesScreen.oxytone.form("Genitiv", "Sg", "f"), "σοφῆς");
      expect(AdjectivesScreen.recessive.form("Genitiv", "Sg", "m"), "βεβαίου");
      expect(
        ComparisonScreen.comparative?.form("Genitiv", "Sg", "m"),
        "ἀμείνονος",
      );
    });

    testWidgets("Steigerung zeigt alle Adjektive des Trainers", (tester) async {
      await tester.pumpWidget(_app(const ComparisonScreen()));

      for (final comparison in AdjectiveComparisons.all) {
        expect(
          find.text(comparison.positive),
          findsOneWidget,
          reason: comparison.positive,
        );
      }
    });

    test("Aoristblatt: alle Verben des Blatts, Stammform wie in der "
        "Vokabelliste", () {
      final verbs = [
        for (final (_, group) in AoristSheetScreen.groups) ...group,
      ];

      expect(
        [for (final (title, _) in AoristSheetScreen.groups) title],
        [
          "Labialstämme",
          "Dentalstämme",
          "Gutturalstämme",
          "Liquidstämme",
          "Starker Aorist",
          "Wurzelaorist",
        ],
      );
      expect(verbs, hasLength(28));
      expect({
        for (final verb in verbs) verb.present,
      }, GrammarQuestionPicker.aoristSheet);

      final vocabulary = _vocabulary();

      for (final verb in verbs) {
        final entry = vocabulary.firstWhere(
          (entry) => entry.type == "verb" && entry.lemma == verb.present,
        );

        expect(verb.aorist, entry.aorist, reason: verb.present);
        expect(verb.infinitive, isNotEmpty);
        expect(verb.meaning, isNotEmpty);
      }
    });

    test("Stammformen: übrige Verben ohne Doppelung zum Aoristblatt", () {
      final forms = AoristScreen.stemForms(_vocabulary());
      final lemmas = [for (final entry in forms) entry.lemma];

      expect(forms, isNotEmpty);
      expect(lemmas.toSet().length, lemmas.length);
      expect(forms.every((entry) => entry.aorist != null), isTrue);
      expect(
        lemmas.toSet().intersection(GrammarQuestionPicker.aoristSheet),
        isEmpty,
      );
    });

    test("Präpositionen: Kasus getrennt, gleiche Verbindung nur einmal", () {
      final uses = PrepositionsScreen.uses(_vocabulary());
      final keys = [
        for (final use in uses) "${use.preposition}|${use.grammaticalCase}",
      ];

      expect(keys.toSet().length, keys.length);
      expect(keys, containsAll(["ὑπό|Gen.", "ὑπό|Akk.", "ἐν|Dat."]));
      expect(uses.every((use) => !use.preposition.contains("+")), isTrue);
      expect(uses.every((use) => use.translations.isNotEmpty), isTrue);
    });

    test("Syntax: alle Konstruktionen mit Erklärung, keine Tempora", () {
      final phenomena = [
        for (final id in SyntaxScreen.categoryIds)
          ...SyntaxScreen.phenomenaOf(id),
      ];
      final labels = [for (final phenomenon in phenomena) phenomenon.label];

      expect(labels.toSet().length, labels.length);
      expect(
        labels,
        containsAll([
          "Genitivus absolutus",
          "Participium coniunctum (PC)",
          "AcI (Accusativus cum infinitivo)",
          "Konsekutivsatz (ὥστε)",
          // Auch, was der Klausurersteller nicht erkennt.
          "NcI (Nominativus cum infinitivo)",
          "Accusativus absolutus",
          "Prädikative Stellung (ἀγαθὸς ὁ ἄνθρωπος)",
          "Sperrung (Hyperbaton)",
        ]),
      );

      for (final phenomenon in phenomena) {
        expect(
          SyntaxScreen.explanations[phenomenon.id],
          isNotNull,
          reason: phenomenon.id,
        );
      }
      expect(SyntaxScreen.explanations.keys.toSet(), {
        for (final phenomenon in phenomena) phenomenon.id,
      });

      for (final tense in ["Futur", "Perfekt", "Plusquamperfekt"]) {
        expect(labels, isNot(contains(tense)));
      }
    });
  });
}
