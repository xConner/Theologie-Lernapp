import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/greek/perikope.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/quiz/books/book_catalog.dart';
import 'package:theologie_lernapp/quiz/books/book_outline.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_widgets.dart';
import 'package:theologie_lernapp/services/bible/bible_reference_parser.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_quiz.dart';
import 'package:theologie_lernapp/services/old_testament/pericope_links.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import 'old_testament_test_data.dart';

final _allKinds = OtQuizKind.values.toSet();

/// Alle Einträge der Genesis in der Perikopenliste vor dieser Sitzung
/// (`Buch|ID|Kapitel,Vers`). Die Zuordnung zur Folie darf keinen davon
/// verändern, entfernen oder verdoppeln.
const _genesisKeys = [
  "Gen|die_erschaffung_der_welt|1,1",
  "Gen|das_paradies|2,4",
  "Gen|der_fall_des_menschen|3,1",
  "Gen|kain_und_abel|4,1",
  "Gen|die_nachkommen_kains|4,17",
  "Gen|die_nachkommen_sets|4,25",
  "Gen|adam_bis_noah|5,1",
  "Gen|die_bosheit_der_menschen|6,1",
  "Gen|die_bosheit_der_menschen|6,9",
  "Gen|die_grosse_flut|7,1",
  "Gen|noahs_opfer|8,1",
  "Gen|gottes_bund_mit_noach|9,1",
  "Gen|noachs_fluch_und_segen|9,18",
  "Gen|die_nachkommen_noachs_voelkertafel|10,1",
  "Gen|der_turmbau_zu_babel|11,1",
  "Gen|die_vorfahren_abrahams|11,10",
  "Gen|abrahams_berufung_und_wanderung_nach_kanaan|12,1",
  "Gen|abraham_und_sara_in_aegypten|12,10",
  "Gen|abraham_und_lot|13,1",
  "Gen|gottes_verheissung_an_abraham|13,14",
  "Gen|abraham_und_melchisedek|14,1",
  "Gen|gottes_bund_mit_abraham|15,1",
  "Gen|ismaels_geburt|16,1",
  "Gen|die_beschneidung_als_bundeszeichen|17,1",
  "Gen|gott_zu_gast_bei_abraham|18,1",
  "Gen|das_gericht_ueber_sodom_und_die_rettung_lots|19,1",
  "Gen|die_stammvaeter_der_moabiter_und_ammoniter|19,30",
  "Gen|abraham_in_gerar|20,1",
  "Gen|isaaks_geburt|21,1",
  "Gen|hagar_und_ismael|21,8",
  "Gen|der_vertrag_abrahams_mit_abimelech|21,22",
  "Gen|abrahams_opfer|22,1",
  "Gen|abrahams_verwandtschaft|22,20",
  "Gen|saras_tod_und_grabstaette|23,1",
  "Gen|isaak_und_rebekka|24,1",
  "Gen|die_nachkommen_abrahams|25,1",
  "Gen|abrahams_tod_und_begraebnis|25,7",
  "Gen|der_stammbaum_der_ismaeliter|25,12",
  "Gen|geburt_esaus_und_jakobs|25,19",
  "Gen|verkauf_des_erstgeburtsrechts_an_jakob|25,27",
  "Gen|isaak_in_gerar|26,1",
  "Gen|isaak_in_beerscheba|26,23",
  "Gen|der_erstgeburtssegen|27,1",
  "Gen|jakobs_flucht_nach_haran|27,41",
  "Gen|jakobs_frauen_und_soehne|29,1",
  "Gen|jakobs_list_gegen_laban|30,25",
  "Gen|jakobs_trennung_von_laban|31,1",
  "Gen|die_boten_und_geschenke_fuer_esau|32,1",
  "Gen|jakobs_kampf_mit_gott|32,23",
  "Gen|jakobs_versoehnung_mit_esau|33,1",
  "Gen|die_rache_der_jakobssoehne_an_den_sichemiten|34,1",
  "Gen|jakob_wieder_in_betel|35,1",
  "Gen|benjamins_geburt_und_rahels_tod|35,16",
  "Gen|die_soehne_jakobs_und_der_tod_isaaks|35,21",
  "Gen|die_nachkommen_esaus|36,1",
  "Gen|josef_und_seine_brueder|37,1",
  "Gen|die_familiengeschichte_judas|38,1",
  "Gen|josef_als_sklave_in_aegypten|39,1",
  "Gen|josef_im_gefaengnis|39,22",
  "Gen|der_traum_des_pharao_und_seine_deutung|41,1",
  "Gen|josefs_macht_ueber_aegypten|41,37",
  "Gen|die_erste_reise_der_brueder_josefs_nach_aegypten|42,1",
  "Gen|die_zweite_reise_der_brueder_josefs_nach_aegypten|43,1",
  "Gen|gen_44|44,1",
  "Gen|josef_gibt_sich_seinen_bruedern_zu_erkennen|45,1",
  "Gen|jakobs_familie_in_aegypten|46,1",
  "Gen|josefs_verwaltung_in_aegypten|47,13",
  "Gen|jakobs_letzter_wille|47,27",
  "Gen|jakobs_segen_ueber_ephrain_und_manasse|48,1",
  "Gen|der_segen_jakobs|49,1",
  "Gen|jakobs_tod_und_begraebnis|49,28",
  "Gen|josefs_letzte_lebensjahre_und_sein_tod|50,14",
];

(int, int) _start(Perikope p) => (p.startChapter, p.startVerse);
(int, int) _end(Perikope p) => (p.endChapter, p.endVerse);

bool _before((int, int) a, (int, int) b) =>
    a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 <= b.$2);

/// Sitzung 2 der Übung Bibelkunde AT: Pentateuch und Genesis.
void main() {
  final all = loadOldTestament();
  final bk = all.forCourse(OtCourseId.bibelkunde);
  final lecture = all.forCourse(OtCourseId.lecture);
  final session = bk.unit("bk.02")!;

  final perikopen = [
    for (final entry
        in jsonDecode(File("assets/perikopen.json").readAsStringSync()) as List)
      Perikope.fromJson(Map<String, dynamic>.from(entry)),
  ];
  final links = OtPericopeLinks.fromPerikopen(perikopen);
  final genesis = [
    for (final p in perikopen)
      if (p.book == "Gen") p,
  ];

  group("Sitzung 2 der Übung", () {
    test("ist eingebunden, mit allen 16 Folien", () {
      expect(bk.units.map((u) => u.id), ["bk.01", "bk.02"]);
      expect(session.label, "Sitzung 2");
      expect(session.file, "Genesis.pdf");
      expect(session.relatedUnitIds, ["bk.01"]);
      expect(
        [for (final s in session.slides) s.number],
        [for (var i = 1; i <= 16; i++) i],
      );
      // Die Vorlesung sieht die Sitzung nicht.
      expect(lecture.units.map((u) => u.id), ["unit.01"]);
    });

    test("Folienbilder liegen vor, ohne Kontaktdaten der Titelfolie", () {
      for (final s in session.slides) {
        if (s.number == 1) {
          expect(s.image, isNull);
          expect(s.text, isNot(contains("@")));
          expect(s.text, isNot(contains("880")));
        } else {
          expect(File(s.image!).existsSync(), isTrue, reason: s.image);
          expect(s.image, contains("bk02-folie-"));
        }
      }
    });

    test("Tabellen und Farbmarkierung sind abgeschrieben", () {
      expect(session.slide(8)!.text, contains("Engelehen und Göttersöhne"));
      expect(session.slide(10)!.text, contains("10-12"));
      expect(session.slide(12)!.text, contains("Kampf am Jabbok"));
      expect(session.slide(14)!.text, contains("[38"));
      expect(session.slide(16)!.text, contains("Leviratsehe"));
      for (final n in [10, 11, 12, 13]) {
        expect(session.slide(n)!.figure!.toLowerCase(), contains("blau"));
      }
      // Die Tonspur fehlt im PDF; das steht bei den Folien.
      expect(session.slide(2)!.figure, contains("Tonspur"));
    });

    test("Grobgliederung und Unterteilungen als Merklisten", () {
      final grob = session.lists.firstWhere(
        (l) => l.id == "list.bk02.grobgliederung",
      );
      expect(grob.items, [
        "Urgeschichte",
        "Erzelterngeschichte",
        "Josephsgeschichte",
      ]);
      expect(grob.details.last, contains("ohne Gen 38"));

      // Jede Zeile der Genesis-Tabellen steht in genau einer Merkliste.
      final rows = [
        for (final l in session.lists)
          if (RegExp(
            r"(urgeschichte|abraham|isaak|jakob|joseph)_?\d?$",
          ).hasMatch(l.id))
            ...l.items,
      ];
      expect(rows, hasLength(12 + 16 + 4 + 14 + 12));
    });
  });

  group("Abgleich mit der Perikopenliste", () {
    final linked = [
      for (final p in session.passages)
        if (p.pericopeKeys.isNotEmpty) p,
    ];

    test("Liste unverändert: gleiche Einträge, IDs und Grenzen", () {
      expect(perikopen, hasLength(2884));
      expect(genesis.map(BookPericope.keyOf).toList(), _genesisKeys);
    });

    test("nur eindeutige Bezeichnungen vereinheitlicht", () {
      String title(String key) => links.byKey(key)!.title;
      expect(
        title("Gen|jakobs_trennung_von_laban|31,1"),
        "Jakobs Trennung von Laban",
      );
      expect(title("Gen|gottes_bund_mit_noach|9,1"), "Gottes Bund mit Noah");
      expect(title("Gen|noachs_fluch_und_segen|9,18"), "Noahs Fluch und Segen");
      expect(
        title("Gen|die_nachkommen_noachs_voelkertafel|10,1"),
        "Die Nachkommen Noahs - Völkertafel",
      );
      for (final p in genesis) {
        expect(p.title, isNot(contains("Noach")), reason: p.id);
      }
    });

    test("jeder Verweis trifft genau einen Eintrag und überschneidet sich", () {
      for (final p in linked) {
        final ref = BibleReferenceParser.parse(p.openText)!;
        final from = (ref.chapter, ref.verse ?? 1);
        final to = (ref.endChapter, ref.endVerse ?? 999);

        for (final key in p.pericopeKeys) {
          final matches = [
            for (final g in genesis)
              if (BookPericope.keyOf(g) == key) g,
          ];
          expect(matches, hasLength(1), reason: key);
          final g = matches.single;
          expect(
            _before(_start(g), to) && _before(from, _end(g)),
            isTrue,
            reason: "${p.label} ↔ $key",
          );
        }
      }
    });

    test("jede Perikope der Genesis ist einer Folienzeile zugeordnet", () {
      final covered = {for (final p in linked) ...p.pericopeKeys};
      for (final key in _genesisKeys) {
        expect(covered, contains(key));
      }
    });

    test("feinere Unterteilung der Liste bleibt sichtbar", () {
      List<String> of(String label) => [
        for (final g in links.of(
          session.passages.firstWhere((p) => p.label == label),
        ))
          g.title,
      ];
      // Folie: eine Zeile, Liste: drei Perikopen.
      expect(of("Gen 4"), [
        "Kain und Abel",
        "Die Nachkommen Kains",
        "Set und Enosch",
      ]);
      expect(of("Gen 43-45"), hasLength(3));
      // Folie feiner als die Liste: beide Zeilen verweisen auf denselben
      // Eintrag, die Liste wird nicht geteilt.
      expect(of("Gen 18,1-15"), of("Gen 18,16-33"));
      // Halbvers 2,4a: die Liste endet mit 2,3.
      expect(of("Gen 1,1-2,4a"), ["Die Erschaffung der Welt"]);
    });

    test("doppelte ID der Liste wird über die Stelle unterschieden", () {
      final bosheit = [
        for (final g in genesis)
          if (g.id == "die_bosheit_der_menschen") BookPericope.keyOf(g),
      ];
      expect(bosheit, hasLength(2));
      final flut = session.passages.firstWhere(
        (p) => p.label == "Gen 6,5-8,22",
      );
      expect(flut.pericopeKeys, containsAll(bosheit));
    });

    test("ungültiger Verweis wird beim Laden abgelehnt", () {
      final json = oldTestamentJson();
      final unit = json.units.firstWhere((u) => u["id"] == "bk.02");
      ((unit["passages"] as List).last as Map)["pericopes"] = ["Gen 50"];
      expect(() => parseOldTestament(json), throwsFormatException);
    });

    testWidgets("Detailansicht nennt die Perikopen der Liste", (tester) async {
      final passage = session.passages.firstWhere((p) => p.label == "Gen 4");
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: PericopeLinksNote(passage, links: links)),
        ),
      );
      expect(find.textContaining("Kain und Abel (Gen 4,1-16)"), findsOneWidget);
      expect(
        find.textContaining("Set und Enosch (Gen 4,25-26)"),
        findsOneWidget,
      );
    });
  });

  group("Buchgliederung der Genesis", () {
    final catalog = BookCatalog.fromPerikopen(perikopen);
    final outlines = BookOutlines.fromJson(
      jsonDecode(File(BookOutlines.asset).readAsStringSync())
          as Map<String, dynamic>,
    );
    final outline = outlines.outlineFor(catalog, "Gen");

    test("nach der Folie, verbindlich, jede Perikope genau einmal", () {
      expect(outline.automatic, isFalse);
      expect(outline.provisional, isFalse);
      expect(outline.note, contains("Folie 7"));
      expect(outline.sections.map((s) => s.id), [
        "gen-urgeschichte",
        "gen-abraham",
        "gen-isaak",
        "gen-jakob",
        "gen-joseph-brueder",
        "gen-juda-tamar",
        "gen-joseph-aegypten",
      ]);

      final inOrder = [
        for (final s in outline.sections) ...pericopesOfSection(catalog, s),
      ];
      expect(inOrder, catalog.pericopesOf("Gen"));
    });

    test("Grenzen: Isaak ab 25,19, Gen 38 eigener Abschnitt", () {
      String sectionOf(String key) => outline.sections
          .firstWhere(
            (s) => pericopesOfSection(catalog, s).any((p) => p.key == key),
          )
          .id;
      expect(
        sectionOf("Gen|der_stammbaum_der_ismaeliter|25,12"),
        "gen-abraham",
      );
      expect(sectionOf("Gen|geburt_esaus_und_jakobs|25,19"), "gen-isaak");
      expect(sectionOf("Gen|der_erstgeburtssegen|27,1"), "gen-jakob");
      expect(
        sectionOf("Gen|die_familiengeschichte_judas|38,1"),
        "gen-juda-tamar",
      );
      expect(
        sectionOf("Gen|josefs_letzte_lebensjahre_und_sein_tod|50,14"),
        "gen-joseph-aegypten",
      );
    });
  });

  group("Begriffe", () {
    test("neue Begriffe stehen einmal und nur in der Übung", () {
      const added = [
        "term.nomos",
        "term.urgeschichte",
        "term.erzelterngeschichte",
        "term.josephsgeschichte",
        "term.toledot",
        "term.bundesbuch",
        "term.heiligkeitsgesetz",
        "term.deuteronomisches_gesetz",
        "term.leviratsehe",
      ];
      final ids = all.allTerms.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      final lectureTerms = lecture.terms.map((t) => t.id).toSet();
      for (final id in added) {
        expect(all.unitsOfTerm(id).map((u) => u.id), ["bk.02"], reason: id);
        expect(lectureTerms, isNot(contains(id)));
      }
      // Ergänzung der App, nicht von der Folie erklärt.
      expect(all.term("term.leviratsehe")!.fromSlides, isFalse);
      // Tora und nomos sind keine Ablenker füreinander.
      expect(
        all.confusable(all.term("term.tora")!, all.term("term.nomos")!),
        isTrue,
      );
    });

    test("vorhandene Begriffe werden nur genannt, nicht neu angelegt", () {
      for (final id in ["term.pentateuch", "term.tora", "term.septuaginta"]) {
        expect(session.mentionOf(id), isNotNull, reason: id);
        expect(
          all.unitsOfTerm(id).map((u) => u.id),
          containsAll(["unit.01", "bk.01", "bk.02"]),
        );
      }
      expect(all.term("term.pentateuch")!.supplement, contains("Fünf-Gefäß"));
    });
  });

  group("Lernen", () {
    final quiz = OldTestamentQuiz(data: bk);
    const scope = OtScope.unit("bk.02");
    final candidates = quiz.candidates(scope, _allKinds);
    final questions = [
      for (var seed = 0; seed < 5; seed++)
        for (final c in candidates) ?c.build(Random(seed)),
    ];

    test("alle Aufgabenarten, eindeutige Karten", () {
      expect(questions.map((q) => q.kind).toSet(), OtQuizKind.values.toSet());
      final ids = candidates.map((c) => c.cardId).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains("q.u01.tora_namen|lecture"));
      expect(ids, contains("passage.bk02.gen_6_5_8_22|passage"));
      expect(ids, contains("list.bk02.jakob_2|order"));
    });

    test("Auswahlfragen: eindeutige Optionen, Erklärung mit Folie", () {
      for (final q in questions.whereType<OtChoiceQuestion>()) {
        final normalized = q.options.map((o) => o.trim().toLowerCase());
        expect(normalized.toSet().length, q.options.length, reason: q.prompt);
        expect(q.options[q.correctIndex], q.answer);
      }
      for (final q in session.questions) {
        expect(q.explanation, contains("Folie"), reason: q.id);
        expect(
          q.prompt.toLowerCase(),
          isNot(contains(q.answer.toLowerCase())),
          reason: q.id,
        );
        expect(q.explanation.split("Ergänzung: ").length, lessThanOrEqualTo(2));
      }
    });

    test("Bibelstellen: Beschreibung eindeutig, Unklares nicht abgefragt", () {
      final asked = [
        for (final p in session.passages)
          if (p.clue != null) p,
      ];
      expect(asked.length, greaterThan(60));
      expect(asked.map((p) => p.clue).toSet().length, asked.length);
      expect(
        session.passages.map((p) => p.label).toSet().length,
        session.passages.length,
      );

      // „10-12“ auf Folie 10 ist nicht eindeutig.
      final ahnfrau = session.passages.firstWhere(
        (p) => p.label == "Gen 12,10-20",
      );
      expect(ahnfrau.clue, isNull);
      expect(
        session.sections.map((s) => s.unclear?.text ?? "").join(),
        contains("10-12"),
      );
      for (final q in session.questions) {
        expect("${q.prompt} ${q.answer}", isNot(contains("12,10")));
      }
    });

    test("alle Stellen lassen sich aufschlagen", () {
      for (final p in session.passages) {
        expect(biblePassageOf(p), isNotNull, reason: p.label);
      }
    });

    test("Umstrittenes ist als Position der Folie gekennzeichnet", () {
      for (final id in ["q.bk02.mose_rolle", "q.bk02.kultorte"]) {
        final q = session.questions.firstWhere((q) => q.id == id);
        expect(q.answer.toLowerCase(), contains("nach der folie"), reason: id);
        expect(q.explanation, contains("nicht unumstritten"), reason: id);
      }
    });

    test("keine Frage wiederholt Sitzung 1 oder die Vorlesung", () {
      String norm(String s) => s.toLowerCase().replaceAll(RegExp(r"\W"), "");
      final earlier = [
        ...all.unit("unit.01")!.questions,
        ...all.unit("bk.01")!.questions,
      ];
      final prompts = {for (final q in earlier) norm(q.prompt)};
      for (final q in session.questions) {
        expect(prompts, isNot(contains(norm(q.prompt))), reason: q.id);
      }
    });

    test("bestehende Lernstände bleiben unberührt", () {
      final cards = <String, LearningCard>{
        "q.bk01.ziel|lecture": LearningCard(id: "q.bk01.ziel|lecture"),
        "term.tora|term": LearningCard(id: "term.tora|term"),
      };
      final before = {
        for (final e in cards.entries) e.key: e.value.toFirestore().toString(),
      };
      final quiz = OldTestamentQuiz(data: bk, cards: cards);
      final candidate = quiz
          .candidates(scope, {OtQuizKind.passage})
          .firstWhere((c) => c.cardId == "passage.bk02.gen_37|passage");
      quiz.record(candidate.build(Random(1))!, true);

      for (final e in before.entries) {
        expect(cards[e.key]!.toFirestore().toString(), e.value);
      }
      expect(cards.keys, contains("passage.bk02.gen_37|passage"));

      // Karten der Sitzung 1 sind dieselben wie vorher.
      final first = OldTestamentQuiz(
        data: bk,
      ).candidates(const OtScope.unit("bk.01"), _allKinds).map((c) => c.cardId);
      expect(first.where((id) => id.contains("bk02")), isEmpty);
    });
  });
}
