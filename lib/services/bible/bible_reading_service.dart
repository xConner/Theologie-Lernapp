import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_reading.dart';
import '../../models/bible/bible_translation.dart';
import '../../models/bible/reading_plan.dart';
import '../streak/streak_service.dart';
import '../streak/streak_state.dart';
import '../streak/streak_track.dart';
import 'bible_reading_repository.dart';
import 'bible_repository.dart';
import 'reading_plan_codec.dart';

/// Ergebnis einer bestätigten Lesung.
class BibleReadingResult {
  /// Streak-Stand nach der Lesung; `null`, wenn er nicht geladen werden
  /// konnte.
  final StreakUpdate? streak;

  /// Die Lesung steht (neu oder schon vorher) im Leseverlauf.
  final bool logged;

  const BibleReadingResult({required this.streak, required this.logged});
}

/// Bibellesen: Leseverlauf, Lesepläne und deren Fortschritt.
///
/// Eine Lesung zählt nur, wenn der Nutzer sie ausdrücklich bestätigt
/// ([confirmReading], [setPlanReading]); das Öffnen eines Kapitels zählt
/// nie. Jede bestätigte Lesung wird dem Track `bible` des [StreakService]
/// gemeldet – dort zählt ein Kalendertag höchstens einmal. Der Fortschritt
/// eines Plans ist davon getrennt: Er ändert sich nur durch
/// [setPlanReading].
///
/// Aufbau wie beim StreakService: Die Daten des aktuellen Nutzers (uid,
/// null = Gast) werden einmal geladen und im Speicher gehalten, alle
/// Vorgänge laufen nacheinander.
///
/// Dokumente im [BibleReadingRepository]:
///   `log_<Jahr>`     `{days: {"2026-10-10": [{id, text, plan?, day?, reading?}]}}`
///   `plan_<Plan>`    [ReadingPlanProgress.toMap]
///   `custom_<Plan>`  `{json: <Plandatei als Text>}`
class BibleReadingService extends ChangeNotifier {
  BibleReadingService({
    BibleReadingRepository Function(String? uid)? repositoryFor,
    DateTime Function()? clock,
    StreakService? streaks,
    this.bundle,
    Future<List<BibleTranslation>> Function()? translations,
  }) : _repositoryFor = repositoryFor ?? BibleReadingRepository.forUser,
       _clock = clock ?? DateTime.now,
       _streaks = streaks ?? StreakService.instance,
       _translations = translations ?? BibleRepository.instance.translations;

  static final BibleReadingService instance = BibleReadingService();

  static const String plansRoot = "assets/reading_plans";

  final BibleReadingRepository Function(String? uid) _repositoryFor;
  final DateTime Function() _clock;
  final StreakService _streaks;

  /// Nur für Tests ersetzbar; standardmäßig das Bundle der App.
  final AssetBundle? bundle;

  final Future<List<BibleTranslation>> Function() _translations;

  String? _uid;
  bool _loaded = false;
  BibleReadingRepository? _repository;

  // Kalendertag → bestätigte Lesungen.
  Map<String, List<BibleReadingEntry>> _log = {};
  Map<String, ReadingPlanProgress> _progress = {};
  Map<String, ReadingPlan> _custom = {};

  List<ReadingPlan>? _builtIn;

  bool _saveFailed = false;

  Future<void> _queue = Future.value();

  // ==========================
  // LESEN
  // ==========================

  /// Lädt die Daten für [uid] (null = Gast), falls noch nicht geschehen oder
  /// der Nutzer gewechselt hat. [refresh] lädt erneut (z. B. um Fortschritte
  /// von anderen Geräten zu übernehmen).
  Future<void> load(String? uid, {bool refresh = false}) {
    return _enqueue(() => _load(uid, refresh: refresh));
  }

  /// Sind Leseverlauf und Pläne für [uid] geladen?
  bool isLoaded(String? uid) => _loaded && _uid == uid;

  /// Eine Änderung konnte nicht gespeichert werden (z. B. offline).
  bool get saveFailed => _saveFailed;

  String get today => StreakCalculator.dateKey(_clock());

  /// Integrierte und eigene Pläne.
  List<ReadingPlan> get plans => [...?_builtIn, ..._custom.values];

  ReadingPlan? plan(String id) {
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }

    return null;
  }

  ReadingPlanProgress? progressOf(String? uid, String planId) {
    return isLoaded(uid) ? _progress[planId] : null;
  }

  /// Begonnene Pläne: laufende zuerst, dann pausierte.
  List<(ReadingPlan, ReadingPlanProgress)> startedPlans(String? uid) {
    if (!isLoaded(uid)) return const [];

    final result = <(ReadingPlan, ReadingPlanProgress)>[];

    for (final plan in plans) {
      final progress = _progress[plan.id];

      if (progress != null) result.add((plan, progress));
    }

    result.sort((a, b) => (a.$2.paused ? 1 : 0) - (b.$2.paused ? 1 : 0));

    return result;
  }

  List<BibleReadingEntry> entriesOn(String? uid, String date) {
    return isLoaded(uid) ? _log[date] ?? const [] : const [];
  }

  /// Zahl der Kalendertage mit mindestens einer bestätigten Lesung.
  int readingDayCount(String? uid) {
    if (!isLoaded(uid)) return 0;

    return _log.values.where((entries) => entries.isNotEmpty).length;
  }

  /// Die letzten Lesetage, neuester zuerst.
  List<(String date, List<BibleReadingEntry> entries)> recentDays(
    String? uid, {
    int limit = 7,
  }) {
    if (!isLoaded(uid)) return const [];

    final dates = [
      for (final entry in _log.entries)
        if (entry.value.isNotEmpty) entry.key,
    ]..sort((a, b) => b.compareTo(a));

    return [for (final date in dates.take(limit)) (date, _log[date]!)];
  }

  // ==========================
  // LESUNG BESTÄTIGEN
  // ==========================

  /// Trägt eine frei gewählte, vom Nutzer bestätigte Lesung für heute ein
  /// und meldet sie der Streak. [text] ist die optionale Stellenangabe.
  ///
  /// Dieselbe Angabe am selben Tag ergibt nur einen Eintrag; mehrere
  /// Lesungen am Tag sind möglich, die Streak zählt den Tag einmal.
  Future<BibleReadingResult> confirmReading({
    required String? uid,
    String? text,
  }) {
    return _enqueue(() async {
      await _load(uid, refresh: false);

      final logged = isLoaded(uid);

      if (logged) _addEntry(BibleReadingEntry.free(text));

      // Die Streak hat einen eigenen Speicher und zählt auch dann, wenn der
      // Leseverlauf gerade nicht erreichbar ist.
      final streak = await _streaks.recordCorrectAnswer(
        uid: uid,
        track: StreakTrack.bible,
        source: StreakSource.bibleReading,
      );

      return BibleReadingResult(streak: streak, logged: logged);
    });
  }

  /// Markiert die Lesung [reading] (ab 0) von Tag [day] (ab 1) als erledigt
  /// bzw. wieder offen. Erledigen zählt als bestätigte Lesung für heute.
  ///
  /// Liefert `null`, wenn sich nichts geändert hat (Plan nicht begonnen,
  /// pausiert, Lesung unbekannt oder schon im gewünschten Zustand) – ein
  /// zweiter Klick erzeugt also nichts.
  Future<BibleReadingResult?> setPlanReading({
    required String? uid,
    required String planId,
    required int day,
    required int reading,
    required bool done,
  }) {
    return _enqueue(() async {
      await _load(uid, refresh: false);

      if (!isLoaded(uid)) return null;

      final plan = this.plan(planId);
      final progress = _progress[planId];
      final readings = plan?.readingsOn(day) ?? const [];

      if (progress == null ||
          progress.paused ||
          reading < 0 ||
          reading >= readings.length ||
          progress.isDone(day, reading) == done) {
        return null;
      }

      _saveProgress(progress.withReading(day, reading, done));

      final entryId = BibleReadingEntry.planEntryId(planId, day, reading);

      if (!done) {
        // Den Eintrag im Verlauf zurücknehmen. Eine bereits gezählte Streak
        // bleibt bestehen.
        _removeEntry(entryId);

        return const BibleReadingResult(streak: null, logged: false);
      }

      _addEntry(
        BibleReadingEntry.plan(
          planId: planId,
          day: day,
          reading: reading,
          text: readings[reading].label,
        ),
      );

      final streak = await _streaks.recordCorrectAnswer(
        uid: uid,
        track: StreakTrack.bible,
        source: StreakSource.readingPlan,
      );

      return BibleReadingResult(streak: streak, logged: true);
    });
  }

  // ==========================
  // PLÄNE VERWALTEN
  // ==========================

  /// Beginnt den Plan; ein bereits begonnener bleibt unverändert.
  Future<void> startPlan(String? uid, String planId) {
    return _change(uid, () {
      if (plan(planId) == null || _progress.containsKey(planId)) return;

      _saveProgress(ReadingPlanProgress(planId: planId, startedOn: today));
    });
  }

  Future<void> setPaused(String? uid, String planId, bool paused) {
    return _change(uid, () {
      final progress = _progress[planId];

      if (progress == null || progress.paused == paused) return;

      _saveProgress(progress.copyWith(paused: paused));
    });
  }

  /// Beendet den Plan und verwirft seinen Fortschritt. Leseverlauf und
  /// Streak bleiben erhalten.
  Future<void> endPlan(String? uid, String planId) {
    return _change(uid, () {
      if (_progress.remove(planId) == null) return;

      notifyListeners();

      _run(_repository!.delete("plan_$planId"));
    });
  }

  /// Prüft eine Plandatei, ohne sie zu speichern.
  Future<ReadingPlan> parsePlan(String source) async {
    return ReadingPlanCodec.decode(source, translations: await _translations());
  }

  /// Importiert einen eigenen Plan aus dem Inhalt einer Plandatei.
  ///
  /// Wirft [ReadingPlanFormatException] bei einer ungültigen Datei, einer
  /// ungültigen Bibelstelle oder wenn es die Kennung schon gibt.
  Future<ReadingPlan> importPlan(String? uid, String source) async {
    final parsed = await parsePlan(source);

    return addPlan(uid, parsed);
  }

  /// Speichert einen geprüften eigenen Plan.
  Future<ReadingPlan> addPlan(String? uid, ReadingPlan plan) {
    return _enqueue(() async {
      await _load(uid, refresh: false);

      if (!isLoaded(uid)) {
        throw const ReadingPlanFormatException([
          "Die Lesepläne konnten nicht geladen werden. Bitte versuche es "
              "später erneut.",
        ]);
      }

      final existing = this.plan(plan.id);

      if (existing != null) {
        throw ReadingPlanFormatException([
          "Ein Plan mit der Kennung „${plan.id}“ ist bereits vorhanden "
              "(„${existing.name}“). Er wurde nicht erneut importiert.",
        ]);
      }

      _custom[plan.id] = plan;
      notifyListeners();

      _run(
        _repository!.save("custom_${plan.id}", {
          "json": jsonEncode(ReadingPlanCodec.toJson(plan)),
        }),
      );

      return plan;
    });
  }

  /// Löscht einen eigenen Plan samt Fortschritt.
  Future<void> deletePlan(String? uid, String planId) {
    return _change(uid, () {
      if (_custom.remove(planId) == null) return;

      final hadProgress = _progress.remove(planId) != null;

      notifyListeners();

      _run(_repository!.delete("custom_$planId"));

      if (hadProgress) _run(_repository!.delete("plan_$planId"));
    });
  }

  // ==========================
  // INTERN
  // ==========================

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());

    _queue = result.then((_) {}, onError: (_) {});

    return result;
  }

  /// Führt [change] aus, sobald die Daten für [uid] geladen sind.
  Future<void> _change(String? uid, void Function() change) {
    return _enqueue(() async {
      await _load(uid, refresh: false);

      if (isLoaded(uid)) change();
    });
  }

  Future<void> _load(String? uid, {required bool refresh}) async {
    await _loadBuiltIn();

    if (_loaded && _repository != null && _uid == uid && !refresh) {
      return;
    }

    if (_repository == null || _uid != uid) {
      _uid = uid;
      _loaded = false;
      _log = {};
      _progress = {};
      _custom = {};
      _saveFailed = false;
      _repository = _repositoryFor(uid);
      notifyListeners();
    }

    try {
      _read(await _repository!.loadAll());
      _loaded = true;
    } catch (e) {
      // Ohne gelesene Daten wird nichts geschrieben, damit vorhandene
      // Stände nicht überschrieben werden. Beim nächsten Aufruf neuer
      // Versuch.
      debugPrint("Bibellese-Daten konnten nicht geladen werden: $e");
    }

    notifyListeners();
  }

  Future<void> _loadBuiltIn() async {
    if (_builtIn != null) return;

    final bundle = this.bundle ?? rootBundle;

    try {
      final index = jsonDecode(
        await bundle.loadString("$plansRoot/index.json"),
      );

      final loaded = <ReadingPlan>[];

      for (final file in (index as Map)["plans"] as List) {
        loaded.add(
          ReadingPlanCodec.decode(
            await bundle.loadString("$plansRoot/$file"),
            builtIn: true,
          ),
        );
      }

      _builtIn = loaded;
    } catch (e) {
      debugPrint("Integrierte Lesepläne konnten nicht geladen werden: $e");
    }
  }

  void _read(Map<String, Map<String, dynamic>> documents) {
    final log = <String, List<BibleReadingEntry>>{};
    final progress = <String, ReadingPlanProgress>{};
    final custom = <String, ReadingPlan>{};

    for (final document in documents.entries) {
      final id = document.key;
      final data = document.value;

      if (id.startsWith("log_")) {
        final days = data["days"];

        if (days is! Map) continue;

        for (final day in days.entries) {
          final entries = day.value;

          if (entries is! List) continue;

          final seen = <String>{};

          log[day.key.toString()] = [
            for (final raw in entries)
              if (BibleReadingEntry.fromMap(raw) case final entry?)
                if (seen.add(entry.id)) entry,
          ];
        }
      } else if (id.startsWith("plan_")) {
        final parsed = ReadingPlanProgress.fromMap(data);

        if (parsed != null) progress[parsed.planId] = parsed;
      } else if (id.startsWith("custom_")) {
        final json = data["json"];

        if (json is! String) continue;

        try {
          final plan = ReadingPlanCodec.decode(json);

          custom[plan.id] = plan;
        } on ReadingPlanFormatException catch (e) {
          debugPrint("Eigener Leseplan $id ist unlesbar: $e");
        }
      }
    }

    // Ein integrierter Plan hat Vorrang vor einem gleichnamigen eigenen.
    for (final plan in _builtIn ?? const <ReadingPlan>[]) {
      custom.remove(plan.id);
    }

    _log = log;
    _progress = progress;
    _custom = custom;
  }

  void _saveProgress(ReadingPlanProgress progress) {
    _progress[progress.planId] = progress;
    notifyListeners();

    _run(_repository!.save("plan_${progress.planId}", progress.toMap()));
  }

  void _addEntry(BibleReadingEntry entry) {
    final date = today;
    final entries = _log[date] ?? const [];

    if (entries.any((e) => e.id == entry.id)) return;

    _log[date] = [...entries, entry];
    notifyListeners();

    _saveDay(date);
  }

  void _removeEntry(String entryId) {
    for (final date in _log.keys.toList()) {
      final entries = _log[date]!;

      if (!entries.any((e) => e.id == entryId)) continue;

      _log[date] = [
        for (final e in entries)
          if (e.id != entryId) e,
      ];

      _saveDay(date);
    }

    notifyListeners();
  }

  /// Schreibt nur den betroffenen Tag, damit Einträge anderer Geräte an
  /// anderen Tagen erhalten bleiben.
  void _saveDay(String date) {
    _run(
      _repository!.save("log_${date.substring(0, 4)}", {
        "days": {
          date: [for (final entry in _log[date]!) entry.toMap()],
        },
      }, merge: true),
    );
  }

  // Nicht auf den Server warten: Firestore behält die Schreibreihenfolge
  // bei und bestätigt offline erst später.
  void _run(Future<void> write) {
    write.then(
      (_) {},
      onError: (Object e) {
        debugPrint("Bibellese-Daten konnten nicht gespeichert werden: $e");

        if (!_saveFailed) {
          _saveFailed = true;
          notifyListeners();
        }
      },
    );
  }
}
