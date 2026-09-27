import 'package:flutter/foundation.dart';

import 'learning_statistics.dart';
import 'statistics_repository.dart';

/// Zentrale Statistik der Trainer. Trainer melden jede bewertete Antwort
/// ([recordAnswer]); die UI liest die letzten Tage über [lastSevenDays].
///
/// Aufbau wie beim StreakService: Die Daten des aktuellen Nutzers (uid,
/// null = Gast) werden geladen und im Speicher gehalten, alle Lade- und
/// Schreibvorgänge laufen nacheinander.
class LearningStatisticsService extends ChangeNotifier {
  LearningStatisticsService({
    StatisticsRepository Function(String? uid)? repositoryFor,
    DateTime Function()? clock,
  }) : _repositoryFor = repositoryFor ?? StatisticsRepository.forUser,
       _clock = clock ?? DateTime.now;

  static final LearningStatisticsService instance = LearningStatisticsService();

  final StatisticsRepository Function(String? uid) _repositoryFor;
  final DateTime Function() _clock;

  String? _uid;
  bool _loaded = false;
  StatisticsRepository? _repository;
  Map<String, TrainerDays> _days = {};

  Future<void> _queue = Future.value();

  /// Sind die Daten für [uid] geladen?
  bool isLoadedFor(String? uid) => _loaded && _uid == uid;

  /// Lädt die Daten für [uid] (null = Gast), falls noch nicht geschehen oder
  /// der Nutzer gewechselt hat. [refresh] lädt erneut (z. B. um Antworten von
  /// anderen Geräten zu übernehmen).
  Future<void> load(String? uid, {bool refresh = false}) {
    return _enqueue(() => _load(uid, refresh: refresh));
  }

  /// Die letzten sieben lokalen Kalendertage für [trainer], ältester zuerst,
  /// der letzte Eintrag ist heute. Leer (alle 0), solange die Daten für
  /// [uid] nicht geladen sind.
  List<DailyStatistics> lastSevenDays(String? uid, StatisticsTrainer trainer) {
    final days = isLoadedFor(uid) ? _days[trainer.id] : null;

    return StatisticsCalculator.lastDaysStatistics(days ?? const {}, _clock());
  }

  /// Zählt eine von der bestehenden Trainerlogik als richtig oder falsch
  /// bewertete Antwort. Fehler beim Laden oder Speichern beeinflussen den
  /// Trainer nie.
  Future<void> recordAnswer({
    required String? uid,
    required StatisticsTrainer trainer,
    required bool correct,
  }) {
    return _enqueue(() => _record(uid, trainer, correct));
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());

    _queue = result.then((_) {}, onError: (_) {});

    return result;
  }

  Future<void> _load(String? uid, {required bool refresh}) async {
    if (_loaded && _repository != null && _uid == uid && !refresh) {
      return;
    }

    if (_repository == null || _uid != uid) {
      _uid = uid;
      _loaded = false;
      _days = {};
      _repository = _repositoryFor(uid);
      notifyListeners();
    }

    try {
      _days = await _repository!.loadAll();
      _loaded = true;
    } catch (e) {
      debugPrint("Statistik konnte nicht geladen werden: $e");
    }

    notifyListeners();
  }

  Future<void> _record(
    String? uid,
    StatisticsTrainer trainer,
    bool correct,
  ) async {
    await _load(uid, refresh: false);

    final date = StatisticsCalculator.dateKey(_clock());

    if (isLoadedFor(uid)) {
      final days = _days.putIfAbsent(trainer.id, () => {});

      days[date] = (days[date] ?? DailyStatistics(date: date)).withAnswer(
        correct: correct,
      );

      notifyListeners();
    }

    // Auch ohne geladene Daten speichern: Das Hochzählen überschreibt nichts.
    // Nicht auf den Server warten (Firestore bestätigt offline erst später).
    _save(_repository!, trainer.id, date, correct);
  }

  Future<void> _save(
    StatisticsRepository repository,
    String trainerId,
    String date,
    bool correct,
  ) async {
    try {
      await repository.recordAnswer(trainerId, date, correct);
    } catch (e) {
      debugPrint("Statistik konnte nicht gespeichert werden: $e");
    }
  }
}
