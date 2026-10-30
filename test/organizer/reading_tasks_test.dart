import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_repository.dart';
import 'package:theologie_lernapp/services/bible/bible_reading_service.dart';
import 'package:theologie_lernapp/services/bible/bible_text_source.dart';
import 'package:theologie_lernapp/services/organizer/org_dates.dart';
import 'package:theologie_lernapp/services/organizer/organizer_controller.dart';
import 'package:theologie_lernapp/services/organizer/reading_tasks.dart';
import 'package:theologie_lernapp/services/streak/streak_repository.dart';
import 'package:theologie_lernapp/services/streak/streak_service.dart';
import 'package:theologie_lernapp/services/streak/streak_state.dart';

import '../lecture_materials_test_support.dart';
import '../test_asset_bundle.dart';
import 'organizer_test_support.dart';

const String planId = "course-bibelkunde-at-wise-2026";

class _Repo implements BibleReadingRepository {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  Future<Map<String, Map<String, dynamic>>> loadAll() async => {
    for (final e in data.entries)
      e.key: Map<String, dynamic>.from(jsonDecode(jsonEncode(e.value)) as Map),
  };

  @override
  Future<void> save(
    String id,
    Map<String, dynamic> d, {
    bool merge = false,
  }) async {
    data[id] = merge && data[id] != null ? {...data[id]!, ...d} : d;
  }

  @override
  Future<void> delete(String id) async => data.remove(id);
}

class _Streaks implements StreakRepository {
  final Map<String, StreakState> data = {};

  @override
  Future<Map<String, StreakState>> loadAll() async => {...data};

  @override
  Future<void> save(StreakState state) async => data[state.trackId] = state;
}

void main() {
  if (!lectureMaterialsPresent) {
    skipWithoutLectureMaterials("Leseaufgaben aus dem Bibelkunde-Leseplan");
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => useLectureMaterials(directoryLectureMaterialsSource()));

  final bundle = FileAssetBundle();
  late List<BibleTranslation> translations;

  setUpAll(() async {
    translations = await AssetBibleTextSource(
      bundle: bundle,
    ).loadTranslations();
  });

  ({BibleReadingService service, _Repo repo, TestClock clock}) make() {
    final clock = TestClock(DateTime(2026, 10, 30, 9));
    final repo = _Repo();
    final service = BibleReadingService(
      repositoryFor: (_) => repo,
      bundle: bundle,
      clock: clock.call,
      translations: () async => translations,
      streaks: StreakService(
        repositoryFor: (_) => _Streaks(),
        clock: clock.call,
      ),
    );
    return (service: service, repo: repo, clock: clock);
  }

  test("heutiges Pensum erscheint als Aufgabe und ist erledigt, sobald die "
      "Kapitel im Leseplan gelesen sind", () async {
    final (:service, :repo, :clock) = make();
    final source = CourseReadingTaskSource(uid: null, service: service);
    await source.load();
    // Nicht begonnen: keine Aufgabe.
    expect(source.tasks(OrgDate.of(clock.now)), isEmpty);

    await service.startCoursePlan(null, planId);
    final tasks = source.tasks(OrgDate.of(clock.now));
    final today = tasks.singleWhere((t) => !t.overdue);
    expect(today.pieces, isNotEmpty);
    expect(today.pieces.first.label, startsWith("Ex"));
    expect(today.session, "Sitzung 3: Exodus; Levitikus");
    expect(today.done, isFalse);
    expect(today.title, startsWith("Lesen: Ex"));

    // Im Leseplan gelesen → Aufgabe erledigt.
    await service.setCoursePieces(
      uid: null,
      planId: planId,
      pieces: [for (final p in today.pieces) p.piece],
      done: true,
    );
    final after = source
        .tasks(OrgDate.of(clock.now))
        .singleWhere((t) => !t.overdue);
    expect(after.done, isTrue);
    // Bleibt heute stehen (nichts verschwindet beim Abhaken).
    expect(after.pieces.length, today.pieces.length);
    expect(repo.data["course_$planId"]!["done"], isNotEmpty);
  });

  test(
    "Aufgaben ändern nie den Lesefortschritt und werden nicht gespeichert",
    () async {
      final (:service, :repo, :clock) = make();
      final source = CourseReadingTaskSource(uid: null, service: service);
      await source.load();
      await service.startCoursePlan(null, planId);
      final before = jsonEncode(repo.data);

      final backend = MemoryOrganizerBackend();
      final c = OrganizerController(
        backend: backend,
        clock: clock.call,
        readingSource: source,
      );
      c.start();
      addTearDown(c.dispose);
      await settle();
      expect(c.readingTasks.where((t) => !t.overdue).length, 1);
      // Alle gespeicherten Aufgaben abhaken: der Leseplan bleibt unberührt.
      c.newTask(
        title: "Bibelkunde lesen",
        due: c.today,
        areaId: "area_bibelkunde",
      );
      await settle();
      for (final t in c.tasks) {
        await c.toggleTask(t);
      }
      await settle();
      expect(jsonEncode(repo.data), before);
      expect(c.readingTasks.every((t) => !t.done), isTrue);
      expect(
        backend.docs.values.where((d) => "${d["title"]}".startsWith("Lesen:")),
        isEmpty,
      );

      // Abschalten in den Einstellungen.
      await c.saveConfig(c.config.copyWith(readingTasks: false));
      await settle();
      expect(c.readingTasks, isEmpty);
    },
  );

  test(
    "Rückstand nach der Sitzung als „Nachholen“; pausiert: keine Aufgabe",
    () async {
      final (:service, :repo, :clock) = make();
      final source = CourseReadingTaskSource(uid: null, service: service);
      await source.load();
      await service.startCoursePlan(null, planId);
      // Eine Woche später, nichts gelesen: Sitzung 3 (5.11.) ist vorbei.
      clock.now = DateTime(2026, 11, 6, 9);
      final tasks = source.tasks(OrgDate.of(clock.now));
      final overdue = tasks.singleWhere((t) => t.overdue);
      expect(overdue.title, startsWith("Nachholen: "));
      expect(overdue.pieces.map((p) => p.label), contains("Ex 1"));
      expect(overdue.done, isFalse);

      await service.setCoursePaused(null, planId, true);
      expect(source.tasks(OrgDate.of(clock.now)), isEmpty);
      expect(repo.data.containsKey("course_$planId"), isTrue);
    },
  );
}
