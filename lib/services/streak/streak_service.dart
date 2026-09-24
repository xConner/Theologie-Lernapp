import 'package:flutter/foundation.dart';

import 'streak_repository.dart';
import 'streak_state.dart';
import 'streak_track.dart';

/// Zentrale Streak-Logik. Trainer melden nur richtige Antworten
/// ([recordCorrectAnswer]); die UI liest Stände über [snapshotFor].
///
/// Die Stände des aktuellen Nutzers (uid, null = Gast) werden einmal geladen
/// und im Speicher gehalten. Alle Lade- und Schreibvorgänge laufen
/// nacheinander, damit schnelle Antworten keine Zählungen verlieren.
/// Nach Erreichen des Tagesziels wird für den Track an diesem Tag nichts
/// mehr geschrieben.
class StreakService extends ChangeNotifier {
  StreakService({
    StreakRepository Function(String? uid)? repositoryFor,
    DateTime Function()? clock,
  }) : _repositoryFor = repositoryFor ?? StreakRepository.forUser,
       _clock = clock ?? DateTime.now;

  static final StreakService instance = StreakService();

  final StreakRepository Function(String? uid) _repositoryFor;
  final DateTime Function() _clock;

  String? _uid;
  bool _loaded = false;
  StreakRepository? _repository;
  Map<String, StreakState> _states = {};

  Future<void> _queue = Future.value();

  /// Lädt die Stände für [uid] (null = Gast), falls noch nicht geschehen
  /// oder der Nutzer gewechselt hat. [refresh] lädt erneut (z. B. um
  /// Fortschritte von anderen Geräten zu übernehmen).
  Future<void> load(String? uid, {bool refresh = false}) {
    return _enqueue(() => _load(uid, refresh: refresh));
  }

  /// Anzeige-Stand für [track]; leer, solange die Daten für [uid] nicht
  /// geladen sind (so werden nie Stände eines anderen Nutzers angezeigt).
  StreakSnapshot snapshotFor(String? uid, StreakTrack track) {
    final state = (_loaded && _uid == uid) ? _states[track.id] : null;

    return StreakCalculator.snapshot(
      state ?? StreakState(trackId: track.id),
      _clock(),
      dailyGoal: track.dailyGoal,
    );
  }

  /// Zählt eine von der bestehenden Trainerlogik als richtig bewertete
  /// Antwort für [track]. Liefert null, wenn nichts gezählt wurde (z. B.
  /// Daten nicht ladbar). Fehler beim Speichern beeinflussen den Trainer nie.
  Future<StreakUpdate?> recordCorrectAnswer({
    required String? uid,
    required StreakTrack track,
    required String source,
  }) {
    return _enqueue(() => _record(uid, track, source));
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
      _states = {};
      _repository = _repositoryFor(uid);
      notifyListeners();
    }

    try {
      _states = await _repository!.loadAll();
      _loaded = true;
    } catch (e) {
      // Ohne gelesene Daten wird nichts gezählt, damit vorhandene Streaks
      // nicht überschrieben werden. Beim nächsten Aufruf neuer Versuch.
      debugPrint("Streaks konnten nicht geladen werden: $e");
    }

    notifyListeners();
  }

  Future<StreakUpdate?> _record(
    String? uid,
    StreakTrack track,
    String source,
  ) async {
    await _load(uid, refresh: false);

    if (!_loaded || _uid != uid) {
      return null;
    }

    final update = StreakCalculator.record(
      _states[track.id] ?? StreakState(trackId: track.id),
      _clock(),
      source: source,
      dailyGoal: track.dailyGoal,
    );

    if (!update.changed) {
      return update;
    }

    _states[track.id] = update.state;
    notifyListeners();

    // Nicht auf den Server warten: Firestore behält die Schreibreihenfolge
    // bei und bestätigt offline erst später.
    _save(_repository!, update.state);

    return update;
  }

  Future<void> _save(StreakRepository repository, StreakState state) async {
    try {
      await repository.save(state);
    } catch (e) {
      debugPrint("Streak konnte nicht gespeichert werden: $e");
    }
  }
}
