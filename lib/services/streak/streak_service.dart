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
///
/// Fehlende oder nicht ladbare Daten setzen nie eine Streak zurück: Es wird
/// erst gespeichert, wenn der gespeicherte Stand gelesen wurde.
class StreakService extends ChangeNotifier {
  StreakService({
    StreakRepository Function(String? uid)? repositoryFor,
    DateTime Function()? clock,
  }) : _repositoryFor = repositoryFor ?? StreakRepository.forUser,
       _clock = clock ?? DateTime.now;

  static final StreakService instance = StreakService();

  final StreakRepository Function(String? uid) _repositoryFor;
  final DateTime Function() _clock;

  /// Spätestens nach dieser Zeit (und an jedem neuen Kalendertag) lädt
  /// [recordCorrectAnswer] den gespeicherten Stand erneut, bevor gezählt
  /// wird. So setzt ein lange geöffneter Tab nicht mit veralteten Daten eine
  /// auf einem anderen Gerät fortgeführte Streak zurück.
  static const Duration maxStateAge = Duration(minutes: 15);

  /// Nach einem fehlgeschlagenen Laden versucht [recordCorrectAnswer] es
  /// frühestens nach dieser Zeit erneut (offline nicht bei jeder Antwort).
  static const Duration retryDelay = Duration(seconds: 30);

  String? _uid;
  bool _loaded = false;
  StreakRepository? _repository;
  Map<String, StreakState> _states = {};

  DateTime? _loadedAt;
  DateTime? _failedAt;

  /// Richtige Antworten, die gezählt wurden, solange die gespeicherten
  /// Stände nicht geladen werden konnten. Sie werden nach dem nächsten
  /// erfolgreichen Laden mit ihrem ursprünglichen Zeitpunkt nachgetragen.
  final List<_PendingAnswer> _pendingAnswers = [];

  Future<void> _queue = Future.value();

  /// Lädt die Stände für [uid] (null = Gast), falls noch nicht geschehen
  /// oder der Nutzer gewechselt hat. [refresh] lädt erneut (z. B. um
  /// Fortschritte von anderen Geräten zu übernehmen); dabei wird nie ein
  /// weiter fortgeschrittener Stand durch einen älteren ersetzt.
  Future<void> load(String? uid, {bool refresh = false}) {
    return _enqueue(() => _load(uid, refresh: refresh));
  }

  /// Verwirft alle Stände im Arbeitsspeicher (nicht den Speicher), damit
  /// Tests mit dem gemeinsamen [instance] unabhängig voneinander starten.
  @visibleForTesting
  void resetForTesting() {
    _uid = null;
    _loaded = false;
    _repository = null;
    _states = {};
    _loadedAt = null;
    _failedAt = null;
    _pendingAnswers.clear();
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
  /// Antwort für [track]. Liefert null, wenn (noch) nichts gezählt werden
  /// konnte, weil die gespeicherten Stände nicht ladbar sind; die Antwort
  /// wird dann nach dem nächsten erfolgreichen Laden nachgetragen. Fehler
  /// beim Speichern beeinflussen den Trainer nie.
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
      _loadedAt = null;
      _failedAt = null;
      _pendingAnswers.removeWhere((answer) => answer.uid != uid);
      _repository = _repositoryFor(uid);
      notifyListeners();
    }

    final repository = _repository!;

    final Map<String, StreakState> stored;

    try {
      stored = await repository.loadAll();
    } catch (e) {
      // Ohne gelesene Daten wird nichts gespeichert, damit vorhandene
      // Streaks nicht überschrieben werden. Bereits geladene Stände bleiben
      // erhalten. Beim nächsten Aufruf neuer Versuch.
      _failedAt = _clock();
      debugPrint("Streaks konnten nicht geladen werden: $e");
      notifyListeners();
      return;
    }

    final merged = <String, StreakState>{...stored};

    // Beim erneuten Laden gewinnt je Track der weiter fortgeschrittene Stand,
    // sodass verspätet bestätigte oder fehlgeschlagene Schreibvorgänge nicht
    // verloren gehen. Ist der eigene Stand neuer, wird er erneut gespeichert.
    final dirty = <String>{};

    if (_loaded) {
      for (final entry in _states.entries) {
        final remote = stored[entry.key];
        final state = remote == null
            ? entry.value
            : StreakCalculator.merge(entry.value, remote);

        merged[entry.key] = state;

        if (remote == null ||
            StreakCalculator.compareProgress(state, remote) > 0 ||
            state.longestStreak > remote.longestStreak) {
          dirty.add(entry.key);
        }
      }
    }

    _states = merged;
    _loaded = true;
    _loadedAt = _clock();
    _failedAt = null;

    dirty.addAll(_replayPendingAnswers());

    for (final trackId in dirty) {
      _save(repository, _states[trackId]!);
    }

    notifyListeners();
  }

  /// Trägt offline gezählte Antworten nach; liefert die geänderten Tracks.
  Set<String> _replayPendingAnswers() {
    final changed = <String>{};

    for (final answer in _pendingAnswers) {
      final update = StreakCalculator.record(
        _states[answer.track.id] ?? StreakState(trackId: answer.track.id),
        answer.time,
        source: answer.source,
        dailyGoal: answer.track.dailyGoal,
      );

      if (update.changed) {
        _states[answer.track.id] = update.state;
        changed.add(answer.track.id);
      }
    }

    _pendingAnswers.clear();

    return changed;
  }

  /// Muss vor dem Zählen (erneut) geladen werden? Nach einem
  /// fehlgeschlagenen Versuch erst wieder nach [retryDelay].
  bool _shouldLoad(String? uid, DateTime now) {
    if (_repository == null || _uid != uid) return true;

    final failedAt = _failedAt;

    if (failedAt != null && now.difference(failedAt).abs() < retryDelay) {
      return false;
    }

    final loadedAt = _loadedAt;

    if (!_loaded || loadedAt == null) return true;

    return StreakCalculator.dateKey(loadedAt) !=
            StreakCalculator.dateKey(now) ||
        now.difference(loadedAt).abs() >= maxStateAge;
  }

  Future<StreakUpdate?> _record(
    String? uid,
    StreakTrack track,
    String source,
  ) async {
    final now = _clock();

    if (_shouldLoad(uid, now)) {
      await _load(uid, refresh: true);
    }

    if (!_loaded || _uid != uid) {
      _addPendingAnswer(_PendingAnswer(uid, track, source, now));

      return null;
    }

    final update = StreakCalculator.record(
      _states[track.id] ?? StreakState(trackId: track.id),
      now,
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

  /// Merkt sich eine Antwort zum Nachtragen. Mehr als das Tagesziel je
  /// Track und Tag ändert nichts mehr und wird daher nicht gespeichert.
  void _addPendingAnswer(_PendingAnswer answer) {
    final day = StreakCalculator.dateKey(answer.time);

    final sameDay = _pendingAnswers.where(
      (a) =>
          a.uid == answer.uid &&
          a.track.id == answer.track.id &&
          StreakCalculator.dateKey(a.time) == day,
    );

    if (sameDay.length < answer.track.dailyGoal) {
      _pendingAnswers.add(answer);
    }
  }

  Future<void> _save(StreakRepository repository, StreakState state) async {
    try {
      await repository.save(state);
    } catch (e) {
      debugPrint("Streak konnte nicht gespeichert werden: $e");
    }
  }
}

class _PendingAnswer {
  final String? uid;
  final StreakTrack track;
  final String source;
  final DateTime time;

  const _PendingAnswer(this.uid, this.track, this.source, this.time);
}
