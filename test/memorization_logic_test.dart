import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/memorization/memorization_card.dart';
import 'package:theologie_lernapp/models/memorization/memorization_text.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/memorization/hint_generator.dart';
import 'package:theologie_lernapp/services/memorization/memorization_catalog.dart';
import 'package:theologie_lernapp/services/memorization/memorization_repository.dart';
import 'package:theologie_lernapp/services/memorization/memorization_scheduler.dart';
import 'package:theologie_lernapp/services/memorization/memorization_session.dart';
import 'package:theologie_lernapp/services/memorization/text_evaluator.dart';
import 'package:theologie_lernapp/services/memorization/text_segmenter.dart';
import 'package:theologie_lernapp/services/memorization/text_tokens.dart';

MemorizationText textOf(List<String> segments, {String id = "test.text.de"}) {
  return MemorizationText(
    id: id,
    workId: "test.text",
    title: "Testtext",
    workTitle: "Testtext",
    languageCode: "de",
    type: MemorizationTextType.other,
    segments: [
      for (var i = 0; i < segments.length; i++)
        MemorizationSegment(id: "$id.s$i", text: segments[i], order: i),
    ],
  );
}

List<String> wordsOf(String text) => [
  for (final token in MemorizationNormalizer.tokenize(text))
    if (token.isWord) token.norm,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorizationCatalog catalog;

  setUpAll(() async {
    catalog = await MemorizationCatalog.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("Abschnitte", () {
    const segmenter = TextSegmenter();

    test("Vaterunser: Zeilen bis zum Satzende gehören zusammen", () {
      final text = catalog.text("prayer.vaterunser.de")!;
      final segments = text.segments.map((s) => s.text).toList();

      expect(segments, hasLength(8));
      expect(segments[0], "Vater unser im Himmel!");
      expect(segments[2], "Dein Reich komme.");
      expect(segments[3], "Dein Wille geschehe,\nwie im Himmel, so auf Erden.");
      expect(segments.last, endsWith("in Ewigkeit.\nAmen."));
      expect(text.segments[3].id, "prayer.vaterunser.de.s3");
      expect(text.segments[3].order, 3);
    });

    test("Absätze trennen, ein kurzer Rest hängt am vorigen Abschnitt", () {
      final segments = segmenter.segment(
        "Ich glaube an Gott,\nden Vater.\n\nUnd an Jesus Christus.\n\nAmen.",
      );

      expect(segments, [
        "Ich glaube an Gott,\nden Vater.",
        "Und an Jesus Christus.\nAmen.",
      ]);
    });

    test("lange Prosa wird an Satzenden und Kommas geteilt", () {
      final segments = segmenter.segment(
        "Ich danke dir, mein himmlischer Vater, durch Jesum Christum, "
        "deinen lieben Sohn, daß du mich diese Nacht vor allem Schaden und "
        "Gefahr behütet hast. Dein heiliger Engel sei mit mir!",
      );

      expect(segments.length, greaterThan(2));
      expect(segments.last, "Dein heiliger Engel sei mit mir!");

      for (final segment in segments) {
        expect(MemorizationNormalizer.wordCount(segment), lessThanOrEqualTo(14));
      }
    });

    test("Abkürzungen und Ordnungszahlen beenden keinen Satz", () {
      expect(segmenter.segment("Das steht in 1. Mose geschrieben."), [
        "Das steht in 1. Mose geschrieben.",
      ]);
    });

    test("alle Texte der App: nichts geht verloren, IDs sind eindeutig", () {
      final textIds = <String>{};
      final segmentIds = <String>{};

      expect(catalog.works, isNotEmpty);

      for (final work in catalog.works) {
        expect(work.versions, isNotEmpty, reason: work.id);

        for (final text in work.versions) {
          expect(textIds.add(text.id), isTrue, reason: text.id);
          expect(text.workId, work.id);
          expect(text.segments, isNotEmpty, reason: text.id);
          expect(text.id, isNot(contains("/")));

          for (final segment in text.segments) {
            expect(segmentIds.add(segment.id), isTrue, reason: segment.id);
            expect(
              MemorizationNormalizer.wordCount(segment.text),
              greaterThan(0),
              reason: segment.id,
            );
          }

          // Mehrteilige Texte haben keine winzigen Abschnitte.
          if (text.segments.length > 1) {
            for (final segment in text.segments) {
              expect(
                MemorizationNormalizer.wordCount(segment.text),
                greaterThanOrEqualTo(3),
                reason: segment.id,
              );
            }
          }
        }
      }
    });

    test("die Abschnitte ergeben zusammen wieder den ganzen Text", () async {
      final text = catalog.text("confession.apostolicum.full.de")!;

      final joined = wordsOf(text.textOf(0, text.segments.length - 1));

      expect(joined.first, "ich");
      expect(joined.last, "amen");
      expect(joined.where((w) => w == "glaube"), hasLength(2));
      expect(joined, hasLength(103));
    });
  });

  group("Sprachfassungen", () {
    test("jede Sprache ist ein eigener Lerntext", () {
      final work = catalog.works.firstWhere((w) => w.id == "prayer.vaterunser");

      expect(work.type, MemorizationTextType.prayer);
      expect(work.versions.map((v) => v.languageCode), [
        "de",
        "en",
        "la",
        "gr",
      ]);
      expect(work.versions.map((v) => v.id).toSet(), hasLength(4));
      expect(catalog.text("prayer.vaterunser.la")!.title, "Pater noster");
      expect(catalog.text("prayer.vaterunser.la")!.workTitle, "Vaterunser");
    });

    test("Bekenntnisse: Symbole ganz, Augsburger Konfession je Artikel", () {
      expect(
        catalog.text("confession.apostolicum.full.de")!.type,
        MemorizationTextType.creed,
      );
      expect(catalog.text("confession.nicenum.full.gr"), isNotNull);

      final article = catalog.text("confession.augsburger_konfession.art_4.de")!;

      expect(article.type, MemorizationTextType.confession);
      expect(article.title, contains("–"));

      expect(catalog.text("confession.augsburger_konfession.art_4.en"), isNotNull);

      // Fassungen ohne Text werden nicht angeboten.
      expect(catalog.text("confession.apostolicum.full.gr"), isNull);
    });

    test("Kleiner Katechismus je Hauptstück, Auswahltexte als ein Werk", () {
      for (var i = 1; i <= 6; i++) {
        for (final language in ["de", "la", "en"]) {
          final text = catalog.text(
            "confession.kleiner_katechismus.hauptstueck_$i.$language",
          );
          expect(text, isNotNull, reason: "Hauptstück $i/$language");
          expect(text!.type, MemorizationTextType.confession);
          expect(text.segments.length, greaterThan(1));
        }
      }

      final commandments = catalog.text(
        "confession.kleiner_katechismus.hauptstueck_1.de",
      )!;
      expect(commandments.title, contains("Kleine Katechismus –"));
      expect(commandments.segments.first.text, startsWith("Das erste Gebot."));

      final chief = catalog.text(
        "confession.schmalkaldische_artikel.teil_2_art_1.de",
      )!;
      // Ein einziger Abschnitt: Titel ohne Abschnittszusatz.
      expect(chief.title, "Schmalkaldische Artikel – Teil II, Art. I: Der Hauptartikel");

      for (final id in [
        "prayer.sanctus.la",
        "prayer.dankkollekte_abendmahl.de",
        "prayer.kollekte_um_frieden.en",
        "confession.apologie.art_9.la",
        "confession.grosser_katechismus.gebot_1.de",
        "confession.konkordienformel_epitome.regel_und_richtschnur.en",
      ]) {
        expect(catalog.text(id), isNotNull, reason: id);
      }
    });
  });

  group("Hilfestufen", () {
    const hints = HintGenerator();
    const segment = "Dein Wille geschehe,\nwie im Himmel so auf Erden.";

    test("Mitlesen zeigt den ganzen Abschnitt", () {
      final prompt = hints.build([segment], HintLevel.read);

      expect(prompt.display, segment);
      expect(prompt.hidden, isEmpty);
      expect(prompt.words, hasLength(9));
    });

    test("Lücken nehmen progressiv zu", () {
      final few = hints.build([segment], HintLevel.fewGaps);
      final many = hints.build([segment], HintLevel.manyGaps);

      expect(few.hidden, hasLength(2));
      expect(many.hidden, hasLength(5));
      expect(many.hidden.toSet(), containsAll(few.hidden));

      expect(HintGenerator.gap.allMatches(few.display), hasLength(2));
      expect(HintGenerator.gap.allMatches(many.display), hasLength(5));

      // Satzzeichen und Zeilenumbruch bleiben stehen.
      expect(few.display, contains("\n"));
      expect(few.display, endsWith("."));
      expect(few.hiddenWords, hasLength(2));
    });

    test("gleiche Aufgabe bei gleichem Versuch, andere beim nächsten", () {
      final a = hints.build([segment], HintLevel.manyGaps, variant: 1);
      final b = hints.build([segment], HintLevel.manyGaps, variant: 1);

      expect(a.display, b.display);

      final variants = {
        for (var v = 0; v < 6; v++)
          hints.build([segment], HintLevel.manyGaps, variant: v).display,
      };

      expect(variants.length, greaterThan(1));
    });

    test("Anfangsbuchstaben", () {
      final prompt = hints.build([segment], HintLevel.firstLetters);

      expect(prompt.display, "D W g,\nw i H s a E.");
    });

    test("kaum Hinweise: nur der Einstieg je Abschnitt", () {
      final prompt = hints.build([
        "Dein Reich komme.",
        segment,
      ], HintLevel.minimal);

      expect(prompt.display, "Dein …\nDein …");
      expect(prompt.words.map((w) => w.segment).toSet(), {0, 1});
    });

    test("frei zeigt nichts", () {
      expect(hints.build([segment], HintLevel.free).display, isEmpty);
    });

    test("ein Wort wird nie ohne Lücke abgefragt", () {
      final prompt = hints.build(["Amen."], HintLevel.fewGaps);

      expect(prompt.hidden, [0]);
      expect(prompt.display, "_____.");
    });
  });

  group("Lernstand (Karte)", () {
    test("lokales Format bewahrt alle Felder", () {
      final card = MemorizationCard(
        id: "a",
        stability: 12.5,
        difficulty: 4,
        lastReviewed: DateTime(2026, 5, 1, 8),
        level: 4,
        attempts: 7,
        successes: 3,
        failures: 2,
        learned: true,
        startedAt: DateTime(2026, 4, 28),
      );

      final loaded = MemorizationCard.fromJson("a", card.toJson());

      expect(loaded.stability, 12.5);
      expect(loaded.difficulty, 4);
      expect(loaded.lastReviewed, card.lastReviewed);
      expect(loaded.level, 4);
      expect(loaded.attempts, 7);
      expect(loaded.successes, 3);
      expect(loaded.failures, 2);
      expect(loaded.learned, isTrue);
      expect(loaded.startedAt, card.startedAt);
    });

    test("Firestore-Format bewahrt alle Felder", () {
      final card = MemorizationCard(
        id: "a",
        stability: 30,
        lastReviewed: DateTime(2026, 5, 1, 8),
        level: 5,
        attempts: 2,
        successes: 2,
        learned: true,
        startedAt: DateTime(2026, 4, 28),
      );

      final loaded = MemorizationCard.fromFirestore("a", card.toFirestore());

      expect(loaded.stability, 30);
      expect(loaded.lastReviewed, card.lastReviewed);
      expect(loaded.level, 5);
      expect(loaded.learned, isTrue);
      expect(loaded.startedAt, card.startedAt);
    });

    test("defekte Daten ergeben eine neue Karte", () {
      final card = MemorizationCard.fromJson("a", {
        "stability": "x",
        "level": 99,
        "attempts": -3,
        "learned": "ja",
        "startedAt": "gestern",
      });

      expect(card.stability, 1.0);
      expect(card.level, MemorizationCard.maxLevel);
      expect(card.attempts, 0);
      expect(card.learned, isFalse);
      expect(card.startedAt, isNull);
    });
  });

  group("Lernfortschritt und Wiederholung", () {
    late DateTime now;
    late MemorizationScheduler scheduler;
    late Map<String, MemorizationCard> cards;

    final text = textOf([
      "Vater unser im Himmel!",
      "Geheiligt werde dein Name.",
      "Dein Reich komme.",
      "Dein Wille geschehe.",
    ]);

    PracticeUnit segment(int index, HintLevel level) =>
        PracticeUnit.segment(text, index, level);

    MemorizationCard card(int index) => cards[text.segments[index].id]!;

    /// Lernt einen Abschnitt bis zur freien Wiedergabe.
    void learn(int index) {
      scheduler.apply(
        unit: segment(index, HintLevel.free),
        practiced: HintLevel.free,
        outcome: RecallOutcome.correct,
        cards: cards,
      );
    }

    setUp(() {
      now = DateTime(2026, 3, 1, 9);
      scheduler = MemorizationScheduler(clock: () => now);
      cards = {};
    });

    test("neuer Text: die ersten Abschnitte in Textreihenfolge", () {
      final plan = scheduler.planFor(text, cards);

      expect(plan.newSegments, MemorizationScheduler.dailyNew);
      expect(plan.reviewSegments, 0);
      expect(plan.fullDue, isFalse);
      expect(plan.units.map((u) => u.from), [0, 1]);
      expect(plan.units.every((u) => u.level == HintLevel.read), isTrue);

      final progress = scheduler.progress(text, cards);

      expect(progress.learned, 0);
      expect(progress.count(SegmentStatus.fresh), 4);
      expect(progress.lastFullRecitation, isNull);
    });

    test("Übungen mit Hilfen heben nur die Hilfestufe", () {
      scheduler.apply(
        unit: segment(0, HintLevel.read),
        practiced: HintLevel.read,
        outcome: RecallOutcome.correct,
        cards: cards,
      );

      expect(card(0).level, 1);
      expect(card(0).attempts, 0);
      expect(scheduler.status(card(0)), SegmentStatus.learning);

      scheduler.apply(
        unit: segment(0, HintLevel.fewGaps),
        practiced: HintLevel.fewGaps,
        outcome: RecallOutcome.correct,
        cards: cards,
      );

      expect(card(0).level, 2);
      expect(card(0).attempts, 1);
      expect(card(0).learned, isFalse);
      expect(card(0).lastReviewed, isNull);
      expect(card(0).stability, 1.0);

      // Fehler mit Hilfen: eine Stufe zurück, „fast“ bleibt.
      scheduler.apply(
        unit: segment(0, HintLevel.manyGaps),
        practiced: HintLevel.manyGaps,
        outcome: RecallOutcome.almost,
        cards: cards,
      );
      expect(card(0).level, 2);

      scheduler.apply(
        unit: segment(0, HintLevel.manyGaps),
        practiced: HintLevel.manyGaps,
        outcome: RecallOutcome.incorrect,
        cards: cards,
      );
      expect(card(0).level, 1);
    });

    test("freie Wiedergabe: gelernt, mit wachsendem Abstand", () {
      learn(0);

      expect(card(0).learned, isTrue);
      expect(card(0).level, 5);
      expect(card(0).successes, 1);
      expect(card(0).lastReviewed, now);
      expect(scheduler.status(card(0)), SegmentStatus.recent);
      expect(scheduler.isDue(card(0)), isFalse);

      final first = card(0).stability;

      // Am nächsten Tag fällig; die Wiederholung verlängert den Abstand.
      now = now.add(const Duration(days: 1));
      expect(scheduler.isDue(card(0)), isTrue);

      learn(0);
      expect(card(0).stability, greaterThan(first));
      expect(scheduler.isDue(card(0)), isFalse);

      now = now.add(const Duration(days: 2));
      learn(0);
      now = now.add(const Duration(days: 4));
      learn(0);

      expect(scheduler.status(card(0)), SegmentStatus.stable);
      expect(scheduler.dueAt(card(0))!.isAfter(now), isTrue);
    });

    test("Fehler bei freier Wiedergabe: bald wieder, mit mehr Hilfe", () {
      learn(0);
      now = now.add(const Duration(days: 1));

      scheduler.apply(
        unit: segment(0, HintLevel.free),
        practiced: HintLevel.free,
        outcome: RecallOutcome.incorrect,
        cards: cards,
      );

      expect(card(0).failures, 1);
      expect(card(0).learned, isTrue);
      expect(card(0).level, HintLevel.firstLetters.index);
      expect(scheduler.status(card(0)), SegmentStatus.shaky);

      final plan = scheduler.planFor(text, cards);

      expect(plan.units.first.from, 0);
      expect(plan.units.first.level, HintLevel.firstLetters);
      expect(plan.reviewSegments, 1);

      final weak = scheduler.weakUnits(text, cards);

      expect(weak.map((u) => u.from), [0]);
    });

    test("Tagesmenge: nach zwei begonnenen Abschnitten keine weiteren", () {
      learn(0);
      learn(1);

      final plan = scheduler.planFor(text, cards);

      expect(plan.newSegments, 0);
      expect(plan.isEmpty, isTrue);

      // Auf ausdrücklichen Wunsch gibt es mehr.
      final more = scheduler.planFor(text, cards, extraNew: 2);
      expect(more.units.map((u) => u.from), [2, 3]);

      // Am nächsten Tag: Wiederholung der gelernten und zwei neue.
      now = now.add(const Duration(days: 1));

      final next = scheduler.planFor(text, cards);

      expect(next.newSegments, 2);
      expect(next.reviewSegments, 2);
    });

    test("benachbarte fällige Abschnitte werden gemeinsam wiederholt", () {
      learn(0);
      learn(1);
      learn(3);

      now = now.add(const Duration(days: 1));

      final plan = scheduler.planFor(text, cards);
      final reviews = plan.units.where((u) => u.level == HintLevel.free);

      expect(reviews.map((u) => (u.kind, u.from, u.to)), [
        (UnitKind.chain, 0, 1),
        (UnitKind.segment, 3, 3),
      ]);
    });

    test("sind alle Abschnitte gelernt, steht der ganze Text an", () {
      for (var i = 0; i < 4; i++) {
        learn(i);
      }

      final plan = scheduler.planFor(text, cards);

      expect(plan.fullDue, isTrue);
      expect(plan.units.single.kind, UnitKind.full);
      expect(scheduler.progress(text, cards).isComplete, isTrue);

      scheduler.apply(
        unit: plan.units.single,
        practiced: HintLevel.free,
        outcome: RecallOutcome.correct,
        cards: cards,
      );

      expect(scheduler.progress(text, cards).lastFullRecitation, now);
      expect(scheduler.planFor(text, cards).isEmpty, isTrue);
    });

    test("Fehler im ganzen Text treffen nur die betroffenen Abschnitte", () {
      for (var i = 0; i < 4; i++) {
        learn(i);
      }

      now = now.add(const Duration(days: 1));

      scheduler.apply(
        unit: scheduler.fullUnit(text),
        practiced: HintLevel.free,
        outcome: RecallOutcome.almost,
        cards: cards,
        errorSegments: {2},
      );

      expect(scheduler.status(card(2)), SegmentStatus.shaky);
      expect(card(2).failures, 1);
      expect(card(1).failures, 0);
      expect(card(1).successes, 2);
      expect(cards[text.fullCardId]!.failures, 1);
      expect(scheduler.weakUnits(text, cards).map((u) => u.from), [2]);
    });

    test("verbundene Abschnitte mit Hilfen ändern den Lernstand nicht", () {
      learn(0);
      learn(1);

      final before = card(0).attempts;

      final changed = scheduler.apply(
        unit: scheduler.chainEndingAt(text, 1, cards)!,
        practiced: HintLevel.firstLetters,
        outcome: RecallOutcome.correct,
        cards: cards,
      );

      expect(changed, isEmpty);
      expect(card(0).attempts, before);
    });
  });

  group("Lernrunde", () {
    late DateTime now;
    late MemorizationScheduler scheduler;
    late Map<String, MemorizationCard> cards;

    setUp(() {
      now = DateTime(2026, 3, 1, 9);
      scheduler = MemorizationScheduler(clock: () => now);
      cards = {};
    });

    /// Beantwortet die aktuelle Übung auf ihrer vorgeschlagenen Stufe.
    void answer(
      MemorizationSession session, {
      RecallOutcome outcome = RecallOutcome.correct,
      Set<int> errors = const {},
    }) {
      session.complete(
        practiced: session.current!.level,
        outcome: outcome,
        errorSegments: errors,
      );
    }

    test("vom Mitlesen zur freien Wiedergabe, dann verbinden", () {
      final text = textOf(["Dein Reich komme.", "Dein Wille geschehe."]);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: scheduler.planFor(text, cards).units,
      );

      final seen = <String>[];

      while (!session.isFinished) {
        final unit = session.current!;
        seen.add("${unit.kind.name} ${unit.from}-${unit.to} ${unit.level.name}");

        answer(session);

        expect(seen.length, lessThan(40));
      }

      // Jeder Abschnitt durchläuft alle Stufen.
      for (final level in HintLevel.values) {
        expect(seen, contains("segment 0-0 ${level.name}"));
        expect(seen, contains("segment 1-1 ${level.name}"));
      }

      // Zum Schluss beide zusammen – hier zugleich der ganze Text.
      expect(seen.last, "full 0-1 free");
      expect(seen.where((s) => s.startsWith("full")), hasLength(1));

      expect(cards.values.every((c) => c.learned), isTrue);
      expect(cards[text.fullCardId]!.lastReviewed, now);
      expect(session.touched, hasLength(2));
    });

    test("drei Abschnitte: A+B, dann A+B+C", () {
      final text = textOf(["Eins zwei drei.", "Vier fünf sechs.", "Sieben acht."]);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: scheduler.planFor(text, cards, extraNew: 1).units,
      );

      final combined = <String>[];

      while (!session.isFinished) {
        final unit = session.current!;

        if (unit.kind != UnitKind.segment) {
          combined.add("${unit.kind.name} ${unit.from}-${unit.to}");
        }

        answer(session);
      }

      expect(combined, ["chain 0-1", "full 0-2"]);
    });

    test("Fehler beim Verbinden: betroffener Abschnitt, dann noch einmal", () {
      final text = textOf(["Eins zwei drei.", "Vier fünf sechs.", "Sieben acht."]);

      for (final i in [0, 1]) {
        scheduler.apply(
          unit: PracticeUnit.segment(text, i, HintLevel.free),
          practiced: HintLevel.free,
          outcome: RecallOutcome.correct,
          cards: cards,
        );
      }

      final chain = scheduler.chainEndingAt(text, 1, cards)!;

      expect(chain.kind, UnitKind.chain);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: [chain],
      );

      answer(session, outcome: RecallOutcome.almost, errors: {1});

      // Abschnitt 2 kommt einzeln zurück, mit etwas Hilfe …
      expect(session.current!.kind, UnitKind.segment);
      expect(session.current!.from, 1);
      expect(session.current!.level, HintLevel.minimal);

      answer(session);
      answer(session);

      // … danach einmal die Verbindung.
      expect(session.current!.kind, UnitKind.chain);
      expect(session.current!.retry, isTrue);

      answer(session);

      expect(session.isFinished, isTrue);
    });

    test("eine Runde endet auch bei anhaltenden Fehlern", () {
      final text = textOf(["Eins zwei drei.", "Vier fünf sechs."]);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: [PracticeUnit.segment(text, 0, HintLevel.free)],
      );

      var steps = 0;

      while (!session.isFinished) {
        answer(session, outcome: RecallOutcome.incorrect);
        steps++;
        expect(steps, lessThan(50));
      }

      expect(cards[text.segments[0].id]!.learned, isFalse);
    });

    test("Überspringen bewertet nichts", () {
      final text = textOf(["Eins zwei drei.", "Vier fünf sechs."]);

      final session = MemorizationSession(
        scheduler: scheduler,
        cards: cards,
        units: scheduler.planFor(text, cards).units,
      );

      session.skip();
      session.skip();

      expect(session.isFinished, isTrue);
      expect(cards, isEmpty);
      expect(session.touched, isEmpty);
    });
  });

  group("Speicherung im Gastmodus", () {
    test("Lernstand und „Meine Texte“ bleiben erhalten", () async {
      final repository = MemorizationRepository(null);

      await repository.load();

      expect(repository.cards, isEmpty);
      expect(repository.textIds, isEmpty);

      await repository.addText("prayer.vaterunser.de");
      await repository.addText("prayer.vaterunser.la");
      await repository.addText("prayer.vaterunser.de");
      await repository.setActive("prayer.vaterunser.la", false);

      await repository.saveCards([
        MemorizationCard(id: "prayer.vaterunser.de.s0", level: 3, attempts: 2),
      ]);

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      expect(reloaded.textIds, [
        "prayer.vaterunser.de",
        "prayer.vaterunser.la",
      ]);
      expect(reloaded.isActive("prayer.vaterunser.de"), isTrue);
      expect(reloaded.isActive("prayer.vaterunser.la"), isFalse);
      expect(reloaded.cards["prayer.vaterunser.de.s0"]!.level, 3);

      // Die lateinische Fassung hat ihren eigenen (leeren) Lernstand.
      expect(reloaded.cards["prayer.vaterunser.la.s0"], isNull);
    });

    test("Entfernen behält den Lernstand", () async {
      final repository = MemorizationRepository(null);
      await repository.load();

      await repository.addText("a");
      await repository.saveCards([MemorizationCard(id: "a.s0", learned: true)]);
      await repository.removeText("a");

      final reloaded = MemorizationRepository(null);
      await reloaded.load();

      expect(reloaded.contains("a"), isFalse);
      expect(reloaded.cards["a.s0"]!.learned, isTrue);
    });

    test("Gastdaten: Übernahme behält alle Felder, Reset löscht", () async {
      final store = LocalLearningStore.instance;

      final repository = MemorizationRepository(null);
      await repository.load();
      await repository.saveCards([
        MemorizationCard(id: "a.s0", level: 4, learned: true, attempts: 5),
      ]);

      expect(await store.hasGuestData(), isTrue);

      // So liest die Übernahme in ein Konto die Karten.
      final transferred = (await store.loadCards(
        LocalLearningStore.memorization,
      ))["a.s0"]!;

      expect(transferred, isA<MemorizationCard>());
      expect(transferred.toFirestore()["level"], 4);
      expect(transferred.toFirestore()["learned"], isTrue);

      await store.resetProgress();

      expect(await store.loadCards(LocalLearningStore.memorization), isEmpty);
    });
  });
}
