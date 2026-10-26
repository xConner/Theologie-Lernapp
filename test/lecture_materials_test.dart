import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/info/app_info.dart';
import 'package:theologie_lernapp/screens/about_screen.dart';
import 'package:theologie_lernapp/screens/old_testament/old_testament_widgets.dart';
import 'package:theologie_lernapp/screens/pericope_quiz/bibelkunde_screen.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';
import 'package:theologie_lernapp/services/lecture_materials/lecture_materials.dart';
import 'package:theologie_lernapp/services/notifications/app_deep_link.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_loader.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_track.dart';
import 'package:theologie_lernapp/widgets/deep_link_navigator.dart';
import 'package:theologie_lernapp/widgets/learning_progress_dialogs.dart';

import 'course_reading_plan_test.dart'
    show MemoryReadingRepository, MemoryStreakRepository;
import 'lecture_materials_test_support.dart';
import 'test_asset_bundle.dart';

Uint8List _json(Object value) => utf8.encode(jsonEncode(value));

/// Kleine, ausgedachte Unterlagen (ohne echte Inhalte).
Map<String, Uint8List> _fakeFiles() => {
  "info/old_testament.json": _json({
    "id": "old_testament",
    "title": "Altes Testament",
    "description": "Geheime Beschreibung",
    "sources": [
      {"title": "Vorlesungsfolien", "origin": "Prof. Dr. Geheim"},
    ],
  }),
  "old_testament/slides/e01-folie-01.png": Uint8List.fromList([1, 2, 3]),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Freigabe (Client)", () {
    test("freigeschaltet: Unterlagen, Info und Dateien verfügbar", () async {
      final source = FakeLectureMaterialsSource(_fakeFiles());
      final m = await useLectureMaterials(source);

      expect(m.available, isTrue);
      expect(m.showsArea("old_testament"), isTrue);
      expect(
        m.moduleInfo(AppModules.oldTestament).sources.single.origin,
        "Prof. Dr. Geheim",
      );
      final bytes = await m.bundle.load(
        "assets/old_testament/slides/e01-folie-01.png",
      );
      expect(bytes.lengthInBytes, 3);
    });

    test(
      "nicht freigeschaltet: nichts verfügbar, keine Inhalte abgerufen",
      () async {
        final source = FakeLectureMaterialsSource(_fakeFiles(), denied: true);
        final m = await useLectureMaterials(source);

        expect(m.available, isFalse);
        expect(m.files(), isEmpty);
        // Nur die Prüfung selbst, keine Datei vor der Freigabe.
        expect(source.requests, ["manifest"]);
        expect(m.showsArea("old_testament"), isFalse);
        expect(m.showsArea("church_history"), isFalse);
        // Die Info enthält ohne Freigabe keine geschützten Angaben.
        final info = m.moduleInfo(AppModules.oldTestament);
        expect(info.sources, isEmpty);
        expect(info.description, isEmpty);
        await expectLater(
          m.bundle.load("assets/old_testament/slides/e01-folie-01.png"),
          throwsA(anything),
        );
        expect(source.requests, ["manifest"]);
      },
    );

    test("nicht angemeldet: keine Anfrage, nichts verfügbar", () async {
      final source = FakeLectureMaterialsSource(_fakeFiles());
      final m = await useLectureMaterials(source, uid: null);
      await m.check(null);

      expect(m.available, isFalse);
      expect(source.requests, isEmpty);
    });

    test("nur die Antwort des Servers zählt, nicht die Konto-Angabe", () async {
      // Auch eine „passende“ Kennung schaltet nichts frei, wenn der Server
      // (Security Rules) ablehnt.
      final source = FakeLectureMaterialsSource(_fakeFiles(), denied: true);
      final m = await useLectureMaterials(source, uid: null);
      await m.check("connerverlinden@gmail.com");
      expect(m.available, isFalse);
    });

    test("Fehler (offline) gelten als nicht freigeschaltet", () async {
      final m = await useLectureMaterials(_FailingSource());
      expect(m.available, isFalse);
    });

    test(
      "entzogene Freigabe: Zwischenspeicher verworfen, keine Abrufe mehr",
      () async {
        final source = FakeLectureMaterialsSource(_fakeFiles());
        final m = await useLectureMaterials(source);
        const key = "assets/old_testament/slides/e01-folie-01.png";
        await m.bundle.load(key);
        final generation = m.generation;

        source.denied = true;
        // Token-Erneuerung bzw. neuer Start prüft erneut.
        await m.check("user");

        expect(m.available, isFalse);
        expect(m.generation, isNot(generation));
        await expectLater(m.bundle.load(key), throwsA(anything));
        expect(m.moduleInfo(AppModules.oldTestament).sources, isEmpty);
      },
    );

    test("Kontowechsel verwirft die Unterlagen sofort", () async {
      final source = FakeLectureMaterialsSource(_fakeFiles());
      final m = await useLectureMaterials(source, uid: "a");
      expect(m.available, isTrue);

      source.denied = true;
      final pending = m.check("b");
      // Noch bevor der Server antwortet.
      expect(m.available, isFalse);
      await pending;
      expect(m.available, isFalse);
    });

    test("Lader der Bereiche liefern ohne Freigabe nichts", () async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      await expectLater(OldTestamentLoader.load(), throwsA(anything));
      await expectLater(ChurchHistoryLoader.load(), throwsA(anything));
    });

    test(
      "übrige Bereiche (Stundenplan, Bibelkunde …) bleiben sichtbar",
      () async {
        final m = await useLectureMaterials(
          FakeLectureMaterialsSource(_fakeFiles(), denied: true),
        );
        for (final id in [
          "timetable",
          "pericope_quiz",
          "bible",
          "logic",
          "greek_vocabulary",
        ]) {
          expect(m.showsArea(id), isTrue, reason: id);
        }
        expect([
          for (final t in StreakTrack.all)
            if (m.showsArea(t.id)) t.id,
        ], isNot(contains("old_testament")));
        expect([
          for (final t in StreakTrack.all)
            if (m.showsArea(t.id)) t.id,
        ], containsAll(["greek", "latin", "perikope", "bible", "logic"]));
      },
    );
  });

  group("Oberfläche ohne Freigabe", () {
    testWidgets("Bibelkunde: keine Knöpfe der Übung", (tester) async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      await tester.pumpWidget(
        const MaterialApp(home: BibelkundeScreen(perikopen: [], uid: null)),
      );

      expect(find.byKey(const ValueKey("bibelkunde-quiz")), findsOneWidget);
      expect(find.byKey(const ValueKey("bibelkunde-books")), findsOneWidget);
      expect(find.byKey(const ValueKey("bibelkunde-basics")), findsNothing);
      expect(
        find.byKey(const ValueKey("bibelkunde-reading-plan")),
        findsNothing,
      );
      expect(find.textContaining("Übung"), findsNothing);
    });

    testWidgets("Bibelkunde: mit Freigabe wie bisher", (tester) async {
      await useLectureMaterials(FakeLectureMaterialsSource(_fakeFiles()));
      await tester.pumpWidget(
        const MaterialApp(home: BibelkundeScreen(perikopen: [], uid: null)),
      );

      expect(find.byKey(const ValueKey("bibelkunde-basics")), findsOneWidget);
      expect(
        find.byKey(const ValueKey("bibelkunde-reading-plan")),
        findsOneWidget,
      );
    });

    testWidgets("Über die App: keine geschützten Bereiche", (tester) async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text("Altes Testament"), findsNothing);
      expect(find.text("Kirchengeschichte"), findsNothing);
      expect(find.text(AppModules.timetable.title), findsOneWidget);
    });

    testWidgets("Zurücksetzen: keine geschützten Bereiche", (tester) async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => pickProgressArea(context),
              child: const Text("öffnen"),
            ),
          ),
        ),
      );
      await tester.tap(find.text("öffnen"));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey("reset-area-oldTestament")),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey("reset-area-churchHistory")),
        findsNothing,
      );
      for (final area in ProgressArea.values) {
        if (area == ProgressArea.oldTestament ||
            area == ProgressArea.churchHistory) {
          continue;
        }
        expect(find.byKey(ValueKey("reset-area-${area.name}")), findsOneWidget);
      }
    });

    testWidgets("direkter Aufruf (Link) öffnet nichts, ohne Hinweis", (
      tester,
    ) async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: Text("Start"));
            },
          ),
        ),
      );

      for (final path in [
        AppDeepLink.oldTestament,
        AppDeepLink.churchHistory,
      ]) {
        final link = AppDeepLink.parse(path)!;
        bool? opened;
        await tester.runAsync(() async {
          opened = await openDeepLink(ctx, link);
        });
        await tester.pumpAndSettle();
        expect(opened, isFalse);
        expect(find.text("Start"), findsOneWidget);
      }
    });

    testWidgets("Seite eines geschützten Bereichs zeigt ohne Freigabe nichts", (
      tester,
    ) async {
      await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text("Start")),
          routes: {
            "/ot": (_) => OldTestamentDataBuilder(
              title: "Altes Testament",
              builder: (_, _) => const Text("INHALT"),
            ),
          },
        ),
      );
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed("/ot");
      await tester.pumpAndSettle();

      expect(find.text("INHALT"), findsNothing);
      expect(find.textContaining("nicht geladen"), findsNothing);
      expect(find.text("Erneut versuchen"), findsNothing);
      // Ohne Hinweis zurück auf die vorige Seite.
      expect(find.text("Start"), findsOneWidget);
    });
  });

  group("Lesepläne zu Lehrveranstaltungen", () {
    BibleReadingService service(LectureMaterials m) => BibleReadingService(
      repositoryFor: (_) => MemoryReadingRepository(),
      streaks: StreakService(repositoryFor: (_) => MemoryStreakRepository()),
      bundle: FileAssetBundle(),
      translations: () async => const [],
      lectureMaterials: m,
    );

    test("ohne Freigabe kein Leseplan zur Übung", () async {
      final m = await useLectureMaterials(
        FakeLectureMaterialsSource(_fakeFiles(), denied: true),
      );
      final s = service(m);
      await s.load(null);
      expect(s.coursePlans, isEmpty);
      // Integrierte, öffentliche Pläne bleiben.
      expect(s.plans, isNotEmpty);
    });

    test("öffentliche Leseplan-Liste nennt keine Lehrveranstaltung", () async {
      final index = jsonDecode(
        await FileAssetBundle().loadString("assets/reading_plans/index.json"),
      );
      expect(index["coursePlans"] ?? const [], isEmpty);
    });

    if (!lectureMaterialsPresent) {
      skipWithoutLectureMaterials("mit Freigabe: Leseplan zur Übung");
      return;
    }

    test(
      "mit Freigabe: Leseplan zur Übung wie bisher; entzogen: weg",
      () async {
        final source = directoryLectureMaterialsSource();
        final m = await useLectureMaterials(source);
        final s = service(m);
        await s.load(null);
        expect(
          s.coursePlans.map((p) => p.id),
          contains(BibelkundeScreen.readingPlanId),
        );

        source.denied = true;
        await m.check("user");
        await s.load(null);
        expect(s.coursePlans, isEmpty);
      },
    );
  });

  group("echte Unterlagen über die Freigabe", () {
    if (!lectureMaterialsPresent) {
      skipWithoutLectureMaterials("Laden aus den Unterlagen");
      return;
    }

    test("Altes Testament und Kirchengeschichte laden mit Freigabe", () async {
      await useLectureMaterials(directoryLectureMaterialsSource());
      final ot = await OldTestamentLoader.load();
      final ch = await ChurchHistoryLoader.load();
      expect(ot.allUnits, isNotEmpty);
      expect(ch.units, isNotEmpty);
      // Folienbilder unter ihrem bisherigen Pfad.
      final image = ot.allUnits
          .expand((u) => u.slides)
          .firstWhere((s) => s.image != null)
          .image!;
      expect(image, startsWith("assets/old_testament/slides/"));
      final bytes = await LectureMaterials.instance.bundle.load(image);
      expect(bytes.lengthInBytes, greaterThan(100));
    });

    test("Info zu beiden Bereichen kommt aus den Unterlagen", () async {
      final m = await useLectureMaterials(directoryLectureMaterialsSource());
      expect(m.moduleInfo(AppModules.oldTestament).sources, isNotEmpty);
      expect(m.moduleInfo(AppModules.churchHistory).sources, isNotEmpty);
    });
  });
}

class _FailingSource implements LectureMaterialsSource {
  @override
  Future<LectureManifest?> manifest() => Future.error(StateError("offline"));

  @override
  Future<Uint8List> file(String path) => Future.error(StateError("offline"));
}
