import 'dart:math';

import '../../algorithms/learning_selector.dart';
import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import 'book_catalog.dart';
import 'book_learning.dart';
import 'book_learning_status.dart';
import 'knowledge.dart';

/// Bildet eine Lerneinheit (Buch, Abschnitt, Kapitel) Schritt für Schritt
/// mit dem Auswahlverfahren des Perikopenquiz ([LearningSelector] und
/// [SpacedRepetition], unverändert):
///
///   Auswahlwert = Lernbedarf (aus `difficulty`) × Fälligkeit (Zeit seit
///   `lastReviewed` im Verhältnis zu `stability`), gewichtete Zufallswahl,
///   zuletzt gefragte Perikopen kurz gesperrt.
///
/// Nach jeder Antwort wird mit dem neuen Stand gewählt. Die Lernstufen
/// („Neu“, „In Bearbeitung“, „Sicher“) dienen nur der Anzeige; sie
/// schließen keine Perikope aus.
///
/// Zwei Ergänzungen für das Lernen ganzer Bücher:
///
///   * Neue Perikopen kommen aus einem Fenster der nächsten [newWindow]
///     noch nicht eingeführten Perikopen des Umfangs (in Buchreihenfolge),
///     innerhalb davon zufällig – nicht streng chronologisch, aber auch nicht
///     wahllos quer durchs Buch.
///   * Je Einheit höchstens [maxNew] neue Perikopen; jede wird erst
///     vorgestellt und einige Abfragen später abgefragt.
///   * Je Einheit wird jede Perikope einmal abgefragt; nach einer falschen
///     Antwort genau ein weiteres Mal (später, wegen der Sperre). So
///     wiederholt eine kleine Einheit nicht dieselben Perikopen bis zum Ende.
///     Die Länge ist höchstens [defaultQuestions] und höchstens so groß wie
///     der Vorrat an abfragbaren Perikopen.
///
/// Wissensfragen ([knowledgeScope], nur wenn eingeschaltet) kommen
/// zusätzlich hinzu: höchstens [knowledgeQuestions] je Einheit, davon
/// höchstens [maxNewKnowledge] neue, gleichmäßig zwischen die
/// Perikopenaufgaben verteilt. Ausgewählt wird mit demselben Verfahren
/// (eigener Sperrspeicher, eigene Karten); jede Frage einmal je Einheit.
class AdaptiveStudyQueue {
  final BookLearningState state;

  /// Umfang in Buchreihenfolge.
  final List<BookPericope> scope;

  /// Geplante Abfragen der Einheit (Einführungen zählen nicht).
  final int questions;

  final int maxNew;

  /// Neue Perikopen gleichmäßig über die Einheit verteilen und sicher
  /// einführen: Liegt ihr Anteil hinter dem geplanten zurück, kommt die
  /// nächste aus dem Fenster der neuen – fällige Wiederholungen verdrängen
  /// sie so nicht (Lernpfad nach Bibelleseplan). Ohne diese Vorgabe
  /// entscheidet allein die gewichtete Auswahl.
  final bool paceNew;

  /// Wissensfragen des Umfangs (leer = keine).
  final List<KnowledgeQuestion> knowledgeScope;

  /// Geplante Wissensfragen der Einheit.
  final int knowledgeQuestions;

  final int maxNewKnowledge;

  static const int defaultKnowledge = 5;
  static const int defaultNewKnowledge = 3;

  static const int defaultQuestions = 15;
  static const int newWindow = 10;

  /// So viele andere Aufgaben liegen zwischen Einführung und Abfrage.
  static const int introGap = 2;

  final LearningSelector selector;

  final Random _random;

  int _asked = 0;
  int _introduced = 0;

  final List<({BookPericope pericope, int wait})> _pending = [];

  AdaptiveStudyQueue({
    required this.state,
    required List<BookPericope> scope,
    int questions = defaultQuestions,
    required this.maxNew,
    this.paceNew = false,
    List<KnowledgeQuestion> knowledge = const [],
    int knowledgeQuestions = defaultKnowledge,
    this.maxNewKnowledge = defaultNewKnowledge,
    Random? random,
  }) : scope = List.unmodifiable(scope),
       questions = min(questions, _poolSize(state, scope, maxNew)),
       knowledgeScope = List.unmodifiable(knowledge.toSet()),
       knowledgeQuestions = min(
         knowledgeQuestions,
         _knowledgePool(state, knowledge.toSet(), maxNewKnowledge),
       ),
       _random = random ?? Random(),
       selector = LearningSelector(
         algorithm: SpacedRepetition(clock: state.clock),
         random: random,
       ),
       knowledgeSelector = LearningSelector(
         algorithm: SpacedRepetition(clock: state.clock),
         random: random,
       );

  final LearningSelector knowledgeSelector;

  static int _knowledgePool(
    BookLearningState state,
    Set<KnowledgeQuestion> scope,
    int maxNew,
  ) {
    int started = 0, fresh = 0;

    for (final q in scope) {
      if (state.knowledgeStatusOf(q).level == LearningLevel.fresh) {
        fresh++;
      } else {
        started++;
      }
    }

    return started + min(fresh, max(0, maxNew));
  }

  int _knowledgeAsked = 0;
  int _knowledgeNew = 0;
  final Set<String> _knowledgeDone = {};

  int get knowledgeAsked => _knowledgeAsked;

  /// Alle geplanten Abfragen: Perikopen und Wissensfragen.
  int get totalQuestions => questions + knowledgeQuestions;

  /// Bisher ausgegebene geplante Abfragen.
  int get totalAsked => _asked + _knowledgeAsked;

  /// Ist jetzt eine Wissensfrage dran? Verteilt sie gleichmäßig: Sie
  /// folgt, sobald ihr Anteil hinter dem der Perikopenaufgaben liegt.
  bool _knowledgeTurn() {
    if (_knowledgeAsked >= knowledgeQuestions) return false;
    if (questions == 0 || _asked >= questions) return true;

    return _knowledgeAsked * questions < _asked * knowledgeQuestions;
  }

  KnowledgeTask? _nextKnowledge() {
    final candidates = [
      for (final q in knowledgeScope)
        if (!_knowledgeDone.contains(q.id) &&
            (state.knowledgeStatusOf(q).level != LearningLevel.fresh ||
                _knowledgeNew < maxNewKnowledge))
          q,
    ];

    if (candidates.isEmpty) return null;

    // Neue Fragen in der Reihenfolge des Buchs bevorzugen: nur die ersten
    // [newWindow] neuen stehen zur Wahl (wie bei den Perikopen).
    final fresh = [
      for (final q in candidates)
        if (state.knowledgeStatusOf(q).level == LearningLevel.fresh) q,
    ];
    final window = fresh.take(newWindow).toSet();

    final pool = [
      for (final q in candidates)
        if (state.knowledgeStatusOf(q).level != LearningLevel.fresh ||
            window.contains(q))
          q,
    ];

    final chosen = knowledgeSelector.select(
      candidates: pool,
      idOf: (q) => q.id,
      cards: {for (final q in pool) q.id: state.knowledgeSelectionCardOf(q)},
    )!;

    if (state.knowledgeStatusOf(chosen).level == LearningLevel.fresh) {
      _knowledgeNew++;
    }

    _knowledgeDone.add(chosen.id);
    _knowledgeAsked++;
    _lastWasRetry = false;

    return KnowledgeTask.of(chosen, _random);
  }

  /// Abfragbare Perikopen zu Beginn: alle bereits begonnenen und so viele
  /// neue, wie eingeführt werden dürfen.
  static int _poolSize(
    BookLearningState state,
    List<BookPericope> scope,
    int maxNew,
  ) {
    int started = 0, fresh = 0;

    for (final p in scope) {
      if (state.statusOf(p).level == LearningLevel.fresh) {
        fresh++;
      } else {
        started++;
      }
    }

    return started + min(fresh, max(0, maxNew));
  }

  final Map<String, int> _askCount = {};

  /// Ob die Perikope in dieser Einheit noch abgefragt werden darf.
  bool _askable(BookPericope p) {
    final count = _askCount[p.key] ?? 0;

    if (count == 0) return true;
    if (count >= 2) return false;

    // Einmal gefragt: nur nach einer falschen Antwort noch einmal.
    final card = state.cardOf(p);
    final wrong = card?.lastWrong;
    final reviewed = card?.lastReviewed;

    return wrong != null &&
        reviewed != null &&
        !wrong.isBefore(reviewed.subtract(const Duration(seconds: 1)));
  }

  int get asked => _asked;

  int get introduced => _introduced;

  bool _isFresh(BookPericope p) =>
      state.statusOf(p).level == LearningLevel.fresh;

  /// Die nächste Aufgabe oder `null`, wenn die Einheit vorbei ist.
  StudyTask? next() {
    for (int i = 0; i < _pending.length; i++) {
      _pending[i] = (
        pericope: _pending[i].pericope,
        wait: _pending[i].wait - 1,
      );
    }

    final left = questions - _asked;

    // Wissensfragen gleichmäßig dazwischen – nicht direkt vor einer fälligen
    // Abfrage einer gerade eingeführten Perikope.
    final introDue =
        _pending.isNotEmpty &&
        (_pending.first.wait <= 0 || left <= _pending.length);

    if (!introDue && _knowledgeTurn()) {
      final task = _nextKnowledge();

      if (task != null) return task;
    }

    // Eingeführte Perikopen nach kurzer Pause abfragen – spätestens, wenn
    // nur noch so viele Abfragen übrig sind.
    if (_pending.isNotEmpty &&
        (_pending.first.wait <= 0 || left <= _pending.length)) {
      return _ask(_pending.removeAt(0).pericope, afterIntroduction: true);
    }

    // Geplante Abfragen erledigt: nur noch Wiederholungen nach Fehlern.
    final retriesOnly = left <= 0;

    final pending = {for (final e in _pending) e.pericope};

    final window = <BookPericope>{};

    if (!retriesOnly && _introduced < maxNew && left > _pending.length) {
      for (final p in scope) {
        if (window.length >= newWindow) break;
        // Schon in dieser Einheit vorgestellt: nicht noch einmal.
        if (_isFresh(p) &&
            !pending.contains(p) &&
            !_askCount.containsKey(p.key)) {
          window.add(p);
        }
      }
    }

    // Neue Perikopen im Rückstand gegenüber ihrem Anteil: jetzt eine neue.
    if (paceNew && window.isNotEmpty && _newBehind()) {
      final chosen = selector.select(
        candidates: window.toList(),
        idOf: (p) => p.key,
        cards: {for (final p in window) p.key: state.selectionCardOf(p)},
      )!;

      _introduced++;
      _lastWasRetry = false;
      _pending.add((pericope: chosen, wait: introGap + 1));

      return IntroduceTask(chosen);
    }

    final candidates = [
      for (final p in scope)
        if (!pending.contains(p) &&
            _askable(p) &&
            (retriesOnly
                ? (_askCount[p.key] ?? 0) > 0
                : (!_isFresh(p) || window.contains(p))))
          p,
    ];

    if (candidates.isEmpty) {
      if (_pending.isNotEmpty) {
        return _ask(_pending.removeAt(0).pericope, afterIntroduction: true);
      }

      // Keine Perikope mehr: übrige geplante Wissensfragen.
      return _knowledgeAsked < knowledgeQuestions ? _nextKnowledge() : null;
    }

    final cards = <String, LearningCard>{
      for (final p in candidates) p.key: state.selectionCardOf(p),
    };

    final chosen = selector.select(
      candidates: candidates,
      idOf: (p) => p.key,
      cards: cards,
    )!;

    if (_isFresh(chosen)) {
      _introduced++;
      _lastWasRetry = false;
      _pending.add((pericope: chosen, wait: introGap + 1));

      return IntroduceTask(chosen);
    }

    return _ask(chosen);
  }

  // Abfragen direkt nach einer Einführung (siehe [paceNew]).
  int _introAsks = 0;

  /// Liegt der Anteil neuer Perikopen hinter dem geplanten? Verglichen wird
  /// mit den übrigen Abfragen (Wiederholungen): Bei 15 Abfragen und 7 neuen
  /// kommt nach etwa jeder achten Wiederholung eine siebte neue.
  bool _newBehind() {
    final reviews = questions - maxNew;

    if (reviews <= 0) return true;

    return _introduced * reviews <= (_asked - _introAsks) * maxNew;
  }

  /// Die zuletzt ausgegebene Abfrage wiederholt eine falsch beantwortete
  /// Perikope (zählt nicht zu den geplanten [questions]).
  bool get lastWasRetry => _lastWasRetry;

  bool _lastWasRetry = false;

  StudyTask _ask(BookPericope p, {bool afterIntroduction = false}) {
    final count = _askCount[p.key] ?? 0;

    _lastWasRetry = count > 0;

    if (!_lastWasRetry) _asked++;

    if (afterIntroduction && count == 0) _introAsks++;

    _askCount[p.key] = count + 1;
    selector.markAsked(p.key);

    // Häufig falsch beantwortete Perikopen gelegentlich im Vergleich mit
    // ihren Nachbarn – dieselbe Karte, andere Aufgabenform.
    if (!afterIntroduction &&
        state.statusOf(p).difficult &&
        _random.nextInt(3) == 0) {
      return StudyPlanner(state, random: _random).compareOrRecall(p);
    }

    return RecallTask(p, afterIntroduction: afterIntroduction);
  }
}
