import 'vocabulary_plan.dart';

/// Neue Vokabeln im freien Vokabeltrainer (Endlosmodus): Eine Vokabel, die
/// noch nie drankam, wird wie im Lernplan zuerst vorgestellt
/// ([IntroduceTask]) – ohne Abfrage, Bewertung oder Feedback – und erst
/// [VocabularyPlanSession.introGap] Fragen später abgefragt
/// ([RecallTask] mit `afterIntroduction`).
///
/// „Noch nie drangekommen“ heißt dasselbe wie im Lernplan: weder im Plan
/// eingeführt noch je beantwortet ([VocabularyPlanState.isIntroduced]).
/// Plan und Trainer teilen so Lernstand und Einführungen; was im Trainer
/// vorgestellt wurde, stellt der Plan nicht noch einmal vor und umgekehrt.
///
/// Die Auswahl der Vokabel bleibt beim Trainer ([next] bekommt sie als
/// Funktion); hier wird nur entschieden, ob vorgestellt oder abgefragt wird.
class TrainerIntroductions<E> {
  final VocabularyPlanState<E> state;

  /// Vorgestellte Vokabeln, die noch abgefragt werden; `wait` zählt die
  /// Fragen bis dahin herunter.
  final List<({E entry, int wait})> _pending = [];

  TrainerIntroductions(this.state);

  /// Vorgestellt, aber noch nicht abgefragt.
  List<E> get pending => [for (final p in _pending) p.entry];

  int _id(E entry) => state.entryIdOf(entry);

  /// Die nächste Aufgabe aus [pool] (den Vokabeln, die die Filter des
  /// Trainers zulassen) oder `null`, wenn der Pool leer ist.
  ///
  /// [select] wählt aus dem Pool wie bisher im Trainer. Eine neue Vokabel
  /// wird vorgestellt; die Einführung speichert der Aufrufer (wie in der
  /// Lerneinheit des Lernplans).
  PlanTask<E>? next({
    required List<E> pool,
    required E Function(List<E> pool) select,
  }) {
    final allowed = {for (final e in pool) _id(e)};

    // Durch geänderte Filter ausgeschlossene Vokabeln nicht mehr nachholen.
    _pending.removeWhere((p) => !allowed.contains(_id(p.entry)));

    for (var i = 0; i < _pending.length; i++) {
      _pending[i] = (entry: _pending[i].entry, wait: _pending[i].wait - 1);
    }

    if (_pending.isNotEmpty && _pending.first.wait <= 0) {
      return RecallTask<E>(_pending.removeAt(0).entry, afterIntroduction: true);
    }

    if (pool.isEmpty) return null;

    final chosen = select(pool);

    // Früher gewählt als vorgemerkt: jetzt abfragen, nicht noch einmal.
    final index = _pending.indexWhere((p) => _id(p.entry) == _id(chosen));

    if (index >= 0) {
      _pending.removeAt(index);

      return RecallTask<E>(chosen, afterIntroduction: true);
    }

    if (!state.isIntroduced(chosen)) {
      _pending.add((entry: chosen, wait: VocabularyPlanSession.introGap + 1));

      return IntroduceTask<E>(chosen);
    }

    return RecallTask<E>(chosen);
  }
}
