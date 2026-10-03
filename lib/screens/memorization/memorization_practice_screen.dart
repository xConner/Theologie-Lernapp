import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../info/app_info.dart';
import '../../models/memorization/memorization_text.dart';
import '../../models/prayer.dart';
import '../../services/memorization/hint_generator.dart';
import '../../services/memorization/memorization_repository.dart';
import '../../services/memorization/memorization_scheduler.dart';
import '../../services/memorization/memorization_session.dart';
import '../../services/memorization/text_evaluator.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import '../../widgets/memorization_widgets.dart';

/// Wie der Nutzer einen Abschnitt wiedergibt.
enum AnswerMode { typing, speaking, silent }

/// Eine Lernrunde: führt durch die Übungen einer [MemorizationSession].
///
/// Bewusst kein Quiz-Ablauf: Hilfestufe und Art der Wiedergabe lassen sich
/// jederzeit wechseln, die Rückmeldung zeigt die Abweichungen Wort für Wort.
class MemorizationPracticeScreen extends StatefulWidget {
  final MemorizationRepository repository;
  final List<PracticeUnit> units;

  /// Für Tests austauschbar.
  final SpeechRecognitionService? speech;
  final MemorizationScheduler? scheduler;

  const MemorizationPracticeScreen({
    super.key,
    required this.repository,
    required this.units,
    this.speech,
    this.scheduler,
  });

  @override
  State<MemorizationPracticeScreen> createState() =>
      _MemorizationPracticeScreenState();
}

class _MemorizationPracticeScreenState
    extends State<MemorizationPracticeScreen> {
  static const String _speechNoticeKey = "memorization.speechNoticeAccepted";

  static const HintGenerator _hints = HintGenerator();
  static const MemorizationTextEvaluator _evaluator =
      MemorizationTextEvaluator();

  late final MemorizationScheduler scheduler =
      widget.scheduler ?? MemorizationScheduler();

  late final SpeechRecognitionService speech =
      widget.speech ?? PlatformSpeechRecognitionService();

  late final MemorizationSession session = MemorizationSession(
    scheduler: scheduler,
    cards: widget.repository.cards,
    units: widget.units,
  );

  final TextEditingController _input = TextEditingController();

  /// Die angezeigte Übung (nach der Auswertung bereits aus der Runde
  /// entnommen).
  PracticeUnit? _unit;

  late HintLevel _level;
  late HintPrompt _prompt;

  AnswerMode _mode = AnswerMode.typing;

  // Auswertung der aktuellen Übung; null = noch nicht ausgewertet.
  EvaluationResult? _result;
  RecallOutcome? _outcome;
  List<int> _asked = const [];
  bool _spoken = false;

  bool _revealed = false;

  // Spracherkennung
  bool _speechReady = false;
  bool _speechBusy = false;
  bool _speechStarting = false;
  bool _listening = false;
  String? _speechProblem;
  String _transcript = "";
  String _partial = "";

  /// Macht Ergebnisse eines früheren Zuhörens ungültig (Übungswechsel).
  int _listenToken = 0;

  bool _saveErrorShown = false;

  @override
  void initState() {
    super.initState();

    _showCurrent();
  }

  @override
  void dispose() {
    _listenToken++;
    speech.cancel();
    _input.dispose();

    super.dispose();
  }

  // ==========================
  // ABLAUF
  // ==========================

  void _showCurrent() {
    final unit = session.current;

    _unit = unit;
    _result = null;
    _outcome = null;
    _revealed = false;
    _transcript = "";
    _partial = "";
    _input.clear();

    if (unit != null) {
      _level = unit.level;
      _makePrompt();
    }
  }

  void _makePrompt() {
    final unit = _unit!;

    // Die Lücken wechseln von Versuch zu Versuch.
    final variant =
        widget.repository.cards[unit.segments.first.id]?.attempts ?? 0;

    _prompt = _hints.build(
      [for (final segment in unit.segments) segment.text],
      _level,
      variant: variant,
    );
  }

  void _setLevel(HintLevel level) {
    if (_result != null || level == _level) return;

    _stopListening();

    setState(() {
      _level = level;
      _revealed = false;
      _transcript = "";
      _partial = "";
      _input.clear();
      _makePrompt();
    });
  }

  Future<void> _setMode(AnswerMode mode) async {
    if (mode == _mode) return;

    _stopListening();

    setState(() {
      _mode = mode;
      _revealed = false;
    });

    if (mode == AnswerMode.speaking) {
      await _prepareSpeech();
    }
  }

  void _next() {
    _stopListening();

    setState(_showCurrent);
  }

  /// Verbucht das Ergebnis und speichert die geänderten Lernstände.
  void _complete(RecallOutcome outcome, Set<int> errorSegments) {
    final changed = session.complete(
      practiced: _level,
      outcome: outcome,
      errorSegments: errorSegments,
    );

    widget.repository.saveCards(changed).catchError((Object _) {
      if (!mounted || _saveErrorShown) return;

      _saveErrorShown = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Der Lernstand konnte nicht gespeichert werden. Du kannst "
            "weiterüben; der Fortschritt dieser Runde geht eventuell "
            "verloren.",
          ),
        ),
      );
    });
  }

  void _confirmRead() {
    _complete(RecallOutcome.correct, const {});
    _next();
  }

  // ==========================
  // AUSWERTUNG
  // ==========================

  void _check(String input, {required bool spoken}) {
    final unit = _unit!;

    // Getippte Lückenaufgaben fragen nur die fehlenden Wörter ab; gesprochen
    // wird immer der ganze Abschnitt.
    final onlyGaps = _level.hasGaps && !spoken;

    final asked = onlyGaps
        ? _prompt.hidden
        : [for (var i = 0; i < _prompt.words.length; i++) i];

    final result = _evaluator.evaluateWords(
      target: [for (final i in asked) _prompt.words[i].raw],
      input: input,
      spoken: spoken,
    );

    final errorSegments = {
      for (final index in result.errorTargetIndices)
        unit.from + _prompt.words[asked[index]].segment,
    };

    _complete(result.outcome, errorSegments);

    setState(() {
      _result = result;
      _outcome = result.outcome;
      _asked = asked;
      _spoken = spoken;
    });
  }

  void _selfAssess(RecallOutcome outcome) {
    final unit = _unit!;

    // Ohne Vergleich lässt sich ein Fehler keinem Abschnitt zuordnen: „Fast“
    // belastet keinen einzelnen, „Nicht gewusst“ alle.
    final errorSegments = outcome == RecallOutcome.incorrect
        ? {for (var i = unit.from; i <= unit.to; i++) i}
        : <int>{};

    _complete(outcome, errorSegments);
    _next();
  }

  // ==========================
  // SPRACHERKENNUNG
  // ==========================

  Future<void> _prepareSpeech() async {
    if (_speechReady || _speechBusy) return;

    _speechBusy = true;

    String? problem;

    try {
      if (!await _confirmSpeechNotice()) {
        _speechBusy = false;

        if (!mounted) return;

        setState(() => _mode = AnswerMode.typing);
        return;
      }

      if (!mounted) return;

      // Ladeanzeige erst nach dem Hinweis, während das Mikrofon freigegeben
      // wird.
      setState(() {
        _speechStarting = true;
        _speechProblem = null;
      });

      if (!await speech.initialize()) {
        problem =
            "Die Spracherkennung ist auf diesem Gerät bzw. in diesem "
            "Browser nicht verfügbar oder das Mikrofon wurde nicht "
            "freigegeben. Du kannst den Abschnitt tippen oder im Kopf "
            "aufsagen.";
      }
    } catch (_) {
      problem = "Die Spracherkennung konnte nicht gestartet werden.";
    }

    _speechBusy = false;

    if (!mounted) return;

    setState(() {
      _speechStarting = false;
      _speechReady = problem == null;
      _speechProblem = problem;
    });
  }

  /// Einmaliger Hinweis vor der ersten Nutzung (wird lokal gemerkt).
  Future<bool> _confirmSpeechNotice() async {
    SharedPreferences? prefs;

    try {
      prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(_speechNoticeKey) ?? false) return true;
    } catch (_) {
      // Ohne lokalen Speicher wird jedes Mal gefragt.
    }

    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aufsagen mit Spracherkennung"),
        content: const SingleChildScrollView(
          child: Text(
            "Die App nutzt die Spracherkennung deines Geräts bzw. Browsers. "
            "Sie speichert keine Aufnahme und erhält nur den erkannten "
            "Text; dieser wird auf deinem Gerät mit dem Lerntext "
            "verglichen und danach verworfen.\n\n"
            "Je nach Gerät oder Browser kann die Erkennung selbst bei "
            "dessen Anbieter stattfinden (z. B. Google oder Apple). Dabei "
            "wird das Gesprochene dorthin übertragen. Wenn du das nicht "
            "möchtest, nutze „Tippen“ oder „Im Kopf“.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Einverstanden"),
          ),
        ],
      ),
    );

    if (accepted != true) return false;

    try {
      await prefs?.setBool(_speechNoticeKey, true);
    } catch (_) {
      // Der Hinweis erscheint dann beim nächsten Mal erneut.
    }

    return true;
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await speech.stop();
      return;
    }

    final unit = _unit!;
    final token = ++_listenToken;

    bool current() => mounted && token == _listenToken;

    try {
      if (!await speech.supportsLanguage(unit.text.languageCode)) {
        if (!current()) return;

        setState(() {
          _speechProblem =
              "Für ${PrayerLanguages.name(unit.text.languageCode)} bietet "
              "dieses Gerät keine Spracherkennung. Du kannst den Abschnitt "
              "tippen oder im Kopf aufsagen.";
        });
        return;
      }

      if (!current()) return;

      setState(() {
        _listening = true;
        _speechProblem = null;
        _partial = "";
      });

      final text = await speech.listen(
        languageCode: unit.text.languageCode,
        onPartial: (partial) {
          if (current()) setState(() => _partial = partial);
        },
      );

      if (!current()) return;

      setState(() {
        _listening = false;
        _partial = "";
        // Nach einer Sprechpause kann weitergesprochen werden.
        _transcript = [
          _transcript,
          text.trim(),
        ].where((part) => part.isNotEmpty).join(" ");
      });
    } catch (_) {
      if (!current()) return;

      setState(() {
        _listening = false;
        _partial = "";
        _speechProblem =
            "Die Spracherkennung wurde unterbrochen. Prüfe die "
            "Mikrofon-Freigabe und versuche es erneut.";
      });
    }
  }

  void _stopListening() {
    _listenToken++;

    if (_listening) {
      _listening = false;
      speech.cancel();
    }
  }

  // ==========================
  // OBERFLÄCHE
  // ==========================

  String _unitLabel(PracticeUnit unit) {
    final total = unit.text.segments.length;

    switch (unit.kind) {
      case UnitKind.segment:
        return total == 1
            ? "Ganzer Text"
            : "Abschnitt ${unit.from + 1} von $total";
      case UnitKind.chain:
        return "Abschnitte ${unit.from + 1}–${unit.to + 1} verbinden";
      case UnitKind.full:
        return "Ganzer Text";
    }
  }

  /// Woran die Wiedergabe anschließt, wenn der Text selbst kaum zu sehen ist.
  String? _cue(PracticeUnit unit) {
    if (_level.index < HintLevel.firstLetters.index) return null;
    if (unit.kind == UnitKind.full) return null;
    if (unit.from == 0) return "Beginn des Textes";

    final previous = unit.text.segments[unit.from - 1].text
        .replaceAll("\n", " ")
        .split(" ");

    final tail = previous.length > 7
        ? "… ${previous.skip(previous.length - 7).join(" ")}"
        : previous.join(" ");

    return "Zuvor: $tail";
  }

  Widget _buildLevelChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final level in HintLevel.values)
          ChoiceChip(
            key: Key("memorize_level_${level.name}"),
            label: Text(level.label),
            selected: _level == level,
            onSelected: _result != null ? null : (_) => _setLevel(level),
          ),
      ],
    );
  }

  Widget _buildPrompt(PracticeUnit unit) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    final cue = _cue(unit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cue != null) ...[
              Text(cue, style: secondary),
              const SizedBox(height: 10),
            ],

            if (_level == HintLevel.free)
              Text(
                unit.kind == UnitKind.full
                    ? "Gib den ganzen Text auswendig wieder."
                    : "Gib den Abschnitt auswendig wieder.",
                style: secondary,
              )
            else
              Text(
                _prompt.display,
                key: const Key("memorize_prompt"),
                style: const TextStyle(fontSize: 19, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<AnswerMode>(
      key: const Key("memorize_mode"),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: AnswerMode.typing,
          icon: Icon(Icons.keyboard_rounded),
          label: Text("Tippen"),
        ),
        ButtonSegment(
          value: AnswerMode.speaking,
          icon: Icon(Icons.mic_rounded),
          label: Text("Sprechen"),
        ),
        ButtonSegment(
          value: AnswerMode.silent,
          icon: Icon(Icons.self_improvement_rounded),
          label: Text("Im Kopf"),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) => _setMode(selection.first),
    );
  }

  Widget _buildTyping() {
    final gaps = _level.hasGaps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key("memorize_input"),
          controller: _input,
          minLines: gaps ? 1 : 3,
          maxLines: null,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: gaps
                ? "Fehlende Wörter der Reihe nach"
                : "Auswendig schreiben",
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 12),

        ElevatedButton(
          key: const Key("memorize_check"),
          onPressed: _input.text.trim().isEmpty
              ? null
              : () => _check(_input.text, spoken: false),
          child: const Text("Vergleichen"),
        ),
      ],
    );
  }

  Widget _buildSpeaking() {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    if (_speechStarting) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_speechReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_speechProblem != null) Text(_speechProblem!, style: secondary),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _prepareSpeech,
            child: const Text("Spracherkennung einschalten"),
          ),
        ],
      );
    }

    final heard = [
      _transcript,
      _partial,
    ].where((part) => part.isNotEmpty).join(" ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: IconButton.filled(
            key: const Key("memorize_mic"),
            iconSize: 36,
            padding: const EdgeInsets.all(18),
            tooltip: _listening ? "Aufsagen beenden" : "Aufsagen starten",
            style: IconButton.styleFrom(
              backgroundColor: _listening ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
            onPressed: _toggleListening,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _listening
              ? "Ich höre zu …"
              : _transcript.isEmpty
              ? "Tippe auf das Mikrofon und sage den Abschnitt auf."
              : "Du kannst weitersprechen oder vergleichen.",
          textAlign: TextAlign.center,
          style: secondary,
        ),

        if (_speechProblem != null) ...[
          const SizedBox(height: 8),
          Text(_speechProblem!, textAlign: TextAlign.center, style: secondary),
        ],

        if (heard.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Semantics(
              liveRegion: true,
              label: "Erkannter Text",
              child: Text(heard, key: const Key("memorize_transcript")),
            ),
          ),
        ],

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _transcript.isEmpty || _listening
                    ? null
                    : () => setState(() => _transcript = ""),
                child: const Text("Neu aufsagen"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key("memorize_check"),
                onPressed: _transcript.isEmpty || _listening
                    ? null
                    : () => _check(_transcript, spoken: true),
                child: const Text("Vergleichen"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSilent(PracticeUnit unit) {
    if (!_revealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Sage den Abschnitt für dich auf und decke ihn dann auf.",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key("memorize_reveal"),
            onPressed: () => setState(() => _revealed = true),
            child: const Text("Aufdecken"),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          unit.text.textOf(unit.from, unit.to),
          style: const TextStyle(fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text("Wie gut war es?", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _selfAssess(RecallOutcome.incorrect),
              child: const Text("Nicht gewusst"),
            ),
            OutlinedButton(
              onPressed: () => _selfAssess(RecallOutcome.almost),
              child: const Text("Fast"),
            ),
            ElevatedButton(
              key: const Key("memorize_knew"),
              onPressed: () => _selfAssess(RecallOutcome.correct),
              child: const Text("Wortgetreu"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedback(PracticeUnit unit) {
    final result = _result!;
    final outcome = _outcome!;

    final (title, color, background, icon) = switch (outcome) {
      RecallOutcome.correct => (
        "Wortgetreu",
        AppColors.success,
        AppColors.successBackground,
        Icons.check_circle_rounded,
      ),
      RecallOutcome.almost => (
        "Fast – kleine Abweichungen",
        AppColors.accent,
        AppColors.surfaceMuted,
        Icons.info_rounded,
      ),
      RecallOutcome.incorrect => (
        "Noch nicht sicher",
        AppColors.error,
        AppColors.errorBackground,
        Icons.replay_rounded,
      ),
    };

    final messages = result.messages(spoken: _spoken);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key("memorize_feedback"),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                for (final message in messages) ...[
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (!result.isEmptyInput)
          AlignmentView(prompt: _prompt, result: result, asked: _asked)
        else
          Text(
            unit.text.textOf(unit.from, unit.to),
            style: const TextStyle(fontSize: 18, height: 1.6),
          ),

        const SizedBox(height: 20),

        ElevatedButton(
          key: const Key("memorize_next"),
          onPressed: _next,
          child: Text(session.isFinished ? "Abschließen" : "Weiter"),
        ),
      ],
    );
  }

  Widget _buildExercise(PracticeUnit unit) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(unit.text.title, style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 4),

        Text(
          "${_unitLabel(unit)} · "
          "${PrayerLanguages.name(unit.text.languageCode)}",
          key: const Key("memorize_unit"),
          style: secondary,
        ),

        const SizedBox(height: 16),

        _buildLevelChips(),

        const SizedBox(height: 12),

        if (_result != null)
          _buildFeedback(unit)
        else ...[
          _buildPrompt(unit),

          const SizedBox(height: 16),

          if (_level == HintLevel.read)
            ElevatedButton(
              key: const Key("memorize_read_done"),
              onPressed: _confirmRead,
              child: const Text("Gelesen – weiter"),
            )
          else ...[
            _buildModeSelector(),

            const SizedBox(height: 16),

            switch (_mode) {
              AnswerMode.typing => _buildTyping(),
              AnswerMode.speaking => _buildSpeaking(),
              AnswerMode.silent => _buildSilent(unit),
            },
          ],

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                session.skip();
                _next();
              },
              child: const Text("Überspringen"),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary() {
    final texts = <MemorizationText>{for (final unit in widget.units) unit.text};

    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Für jetzt geschafft",
          key: const Key("memorize_summary"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),

        const SizedBox(height: 4),

        Text(
          session.touched.isEmpty
              ? "In dieser Runde wurde nichts geübt."
              : "Diese Abschnitte hast du geübt. Sie kommen zur passenden "
                    "Zeit wieder.",
          style: secondary,
        ),

        for (final text in texts)
          if (text.segments.any((s) => session.touched.contains(s.id))) ...[
            const SizedBox(height: 20),

            Text(text.title, style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 4),

            for (final segment in text.segments)
              if (session.touched.contains(segment.id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: SegmentStatusIcon(
                    scheduler.status(widget.repository.cards[segment.id]),
                  ),
                  title: Text(
                    segment.text.replaceAll("\n", " "),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    scheduler.status(widget.repository.cards[segment.id]).label,
                  ),
                ),
          ],

        const SizedBox(height: 24),

        ElevatedButton(
          key: const Key("memorize_done"),
          onPressed: () => Navigator.pop(context),
          child: const Text("Fertig"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Auswendig lernen"),
        actions: [
          InfoButton(
            module: AppModules.memorization,
            reportDetails: () => {
              if (unit != null) ...{
                "Text": "${unit.text.workTitle} (${unit.text.id})",
                "Übung": "${_unitLabel(unit)}, ${_level.label}",
              },
            },
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: unit == null ? _buildSummary() : _buildExercise(unit),
          ),
        ),
      ),
    );
  }
}
