import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/models/apocrypha/apocrypha.dart';
import 'package:theologie_lernapp/screens/apocrypha/apocrypha_reader_screen.dart';
import 'package:theologie_lernapp/services/apocrypha/apocrypha_repository.dart';
import 'package:theologie_lernapp/services/apocrypha/apocrypha_user_data.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/quiz_documents.dart';

import '../test_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApocryphaRepository repo;
  late ApocryphaCatalog catalog;

  setUp(() async {
    repo = ApocryphaRepository(bundle: FileAssetBundle());
    catalog = await repo.catalog();
  });

  group("Modell", () {
    test("Werk mit mehreren Fassungen und Standardfassung", () {
      final tobit = catalog.work("tobit")!;
      expect(tobit.versions.length, greaterThanOrEqualTo(3));
      expect(tobit.defaultVersion!.language, "de");
      expect(tobit.hasOriginalText, isTrue);
      expect(tobit.textLanguages, containsAll(["de", "grc", "la"]));
    });

    test("Werk in mehreren Kategorien, Text nur einmal", () {
      final multi = catalog.works.where((w) => w.categories.length > 1);
      expect(multi, isNotEmpty);
      for (final w in multi) {
        for (final c in w.categories) {
          expect(catalog.worksIn(c), contains(w));
        }
      }
    });

    test("Epochen überschneiden den Datierungsrahmen", () {
      const d = Dating("2. Jh.", 100, 160);
      expect(ApocryphaEpoch.secondCentury.overlaps(d), isTrue);
      expect(ApocryphaEpoch.hellenistic.overlaps(d), isFalse);
    });
  });

  group("Filter und Suche", () {
    test("Kategorie, Herkunft und Text", () {
      final av = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(category: "apostolische_vaeter"),
      );
      expect(av.map((w) => w.id), contains("didache"));
      expect(
        av.every((w) => w.categories.contains("apostolische_vaeter")),
        isTrue,
      );

      final jewish = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(tradition: Tradition.juedisch, textOnly: true),
      );
      expect(jewish, isNotEmpty);
      expect(
        jewish.every((w) => w.tradition == Tradition.juedisch && w.hasText),
        isTrue,
      );
    });

    test("Sprache, Original, Übersetzungen, Vollständigkeit", () {
      final coptic = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(language: "cop"),
      );
      expect(coptic.map((w) => w.id), ["thomasevangelium"]);

      final two = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(minTranslations: 2),
      );
      expect(two.every((w) => w.translationCount >= 2), isTrue);
      expect(two.map((w) => w.id), contains("sirach"));

      final fragments = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(fragmentaryOnly: true),
      );
      expect(fragments.map((w) => w.id), contains("papias"));
      final complete = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(completeOnly: true),
      );
      expect(complete.map((w) => w.id), isNot(contains("papias")));

      final original = ApocryphaSearch.works(
        catalog,
        "",
        const ApocryphaFilter(originalOnly: true),
      );
      expect(original.every((w) => w.hasOriginalText), isTrue);
    });

    test("Suche nach Titel, anderem Titel und Übersetzer", () {
      expect(
        ApocryphaSearch.works(
          catalog,
          "Hirt",
          const ApocryphaFilter(),
        ).first.id,
        "hermas",
      );
      expect(
        ApocryphaSearch.works(
          catalog,
          "Jesus Sirach",
          const ApocryphaFilter(),
        ).map((w) => w.id),
        contains("sirach"),
      );
      expect(
        ApocryphaSearch.works(
          catalog,
          "menge",
          const ApocryphaFilter(),
        ).map((w) => w.id),
        contains("tobit"),
      );
    });

    test("copyWith setzt und leert einzelne Filter", () {
      const f = ApocryphaFilter(category: "evangelien", textOnly: true);
      expect(f.copyWith(category: null).category, isNull);
      expect(f.copyWith(category: null).textOnly, isTrue);
      expect(f.copyWith(textOnly: false).category, "evangelien");
      expect(const ApocryphaFilter().isEmpty, isTrue);
      expect(
        const ApocryphaFilter(category: "x").isEmptyBesidesCategory,
        isTrue,
      );
    });
  });

  group("Laden", () {
    test("eigener Text und Text aus dem Bibelbereich", () async {
      final didache = await repo.toc("didache.lake");
      final unit = await repo.unit("didache.lake", didache[1]);
      expect(unit.blocks.first.text, contains("Ὁδοὶ δύο"));

      final lxx = await repo.toc("tobit.lxx_brenton");
      expect(lxx.first.bible, isNotNull);
      final chapter = await repo.unit("tobit.lxx_brenton", lxx.first);
      expect(chapter.blocks.length, lxx.first.count);
      expect(chapter.blocks.first.number, "1");
      expect(chapter.blocks.first.text, startsWith("ΒΙΒΛΟΣ"));
    });

    test("Volltextsuche findet Wortlaut", () async {
      final hits = await repo
          .fullText("Rhode", works: [catalog.work("hermas")!])
          .toList();
      expect(hits, isNotEmpty);
      expect(hits.first.version.id, "hermas.anf");
    });
  });

  group("Vergleichsansicht", () {
    test("nach Versnummern", () {
      final rows = alignBlocks(
        const [TextBlock("1", "a"), TextBlock("2", "b"), TextBlock("3", "c")],
        const [TextBlock("1", "A"), TextBlock("3", "C")],
      );
      expect(rows.length, 3);
      expect(rows[1].secondary, isEmpty);
      expect(rows[2].secondary.single.text, "C");
    });

    test("ohne Zählung bei gleicher Länge der Reihe nach", () {
      final rows = alignBlocks(
        const [TextBlock("", "a"), TextBlock("", "b")],
        const [TextBlock("", "A"), TextBlock("", "B")],
      );
      expect(rows.map((r) => r.secondary.single.text), ["A", "B"]);
    });

    test("andere Zählung: beide Texte als Ganzes", () {
      final rows = alignBlocks(
        const [TextBlock("", "a")],
        const [TextBlock("", "A"), TextBlock("", "B")],
      );
      expect(rows.single.primary.length, 1);
      expect(rows.single.secondary.length, 2);
    });
  });

  group("Persönliche Daten", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Position, Merkliste, Lesezeichen und Ansicht (Gast)", () async {
      final data = ApocryphaUserData(LocalQuizDocuments());
      await data.setPosition(
        ReadingPosition(
          workId: "tobit",
          versionId: "tobit.menge1939",
          unitId: "3",
          updated: DateTime(2026),
        ),
      );
      await data.setFavorite("hermas", true);
      final mark = ApocryphaBookmark(
        versionId: "tobit.menge1939",
        unitId: "3",
        block: "7",
        added: DateTime(2026),
      );
      await data.setBookmark(mark, true);
      await data.setVersion("tobit", "tobit.vulgata");
      await data.setParallel("tobit", "tobit.lxx_brenton");
      await data.setTextScale(1.2);

      var state = await data.load();
      expect(state.positions["tobit"]!.unitId, "3");
      expect(state.isFavorite("hermas"), isTrue);
      expect(state.bookmarks[mark.key]!.workId, "tobit");
      expect(state.versions["tobit"], "tobit.vulgata");
      expect(state.parallels["tobit"], "tobit.lxx_brenton");
      expect(state.textScale, closeTo(1.2, 0.001));

      await data.setFavorite("hermas", false);
      await data.setBookmark(mark, false);
      await data.setParallel("tobit", null);
      state = await data.load();
      expect(state.favorites, isEmpty);
      expect(state.bookmarks, isEmpty);
      expect(state.parallels, isEmpty);
    });

    test("Dokument wird bei Übernahme und Löschen der Gastdaten erfasst", () {
      expect(
        LocalLearningStore.quizDocuments,
        contains(ApocryphaUserData.document),
      );
      expect(
        LocalLearningStore.progressDocuments,
        isNot(contains(ApocryphaUserData.document)),
      );
    });
  });
}
