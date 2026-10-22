import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../info/app_info.dart';
import '../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../models/latin/vocabulary/latin_vocabulary_question.dart';
import '../../services/latin/vocabulary/latin_vocabulary_answer_checker.dart';
import '../../services/latin/vocabulary/latin_vocabulary_settings_service.dart';
import '../../widgets/answer_feedback_badge.dart';
import '../../widgets/info_report.dart';
import '../../widgets/self_assessment.dart';
import '../../widgets/settings_selection.dart';
import '../../widgets/trainer_widgets.dart';

/// Abfrage einer lateinischen Vokabel: Eingabefelder bzw.
/// Selbsteinschätzung, Auswertung, Lösung und Eselsbrücke.
///
/// Gemeinsam für den freien Vokabeltrainer und den Lernplan. Die Abfrage
/// verbucht nichts selbst: [onEvaluated] erhält jede Bewertung (der
/// Aufrufer ändert Lernstand, Statistik und Streak), [onNext] fordert die
/// nächste Aufgabe an. Je Vokabel eine eigene Instanz (Key mit der ID),
/// damit Eingaben nicht in die nächste Frage übernommen werden.
class LatinVocabularyAnswerView extends StatefulWidget {
  final LatinVocabularyEntry entry;

  /// Was zusätzlich zur Übersetzung abgefragt wird.
  final LatinVocabularySettings settings;

  final AnswerMethod method;

  final ValueChanged<AnswerMethod> onMethodChanged;

  /// Eine Bewertung: [firstEvaluation] ist nur bei der ersten Auswertung
  /// einer Frage gesetzt (doppeltes Enter zählt nicht doppelt).
  final void Function(bool correct, {required bool firstEvaluation})
  onEvaluated;

  final VoidCallback onNext;

  final String? mnemonic;

  final Future<void> Function(String? mnemonic) onSaveMnemonic;

  /// Zusätzliche Angaben für eine Fehlermeldung.
  final Map<String, String> extraReportDetails;

  const LatinVocabularyAnswerView({
    super.key,
    required this.entry,
    required this.settings,
    required this.method,
    required this.onMethodChanged,
    required this.onEvaluated,
    required this.onNext,
    required this.mnemonic,
    required this.onSaveMnemonic,
    this.extraReportDetails = const {},
  });

  @override
  State<LatinVocabularyAnswerView> createState() =>
      _LatinVocabularyAnswerViewState();
}

class _LatinVocabularyAnswerViewState extends State<LatinVocabularyAnswerView> {
  final FocusNode translationFocusNode = FocusNode();
  final FocusNode formFocusNode = FocusNode();
  final FocusNode genderFocusNode = FocusNode();

  final translationController = TextEditingController();
  final formController = TextEditingController();
  final genderController = TextEditingController();

  bool answered = false;
  bool correct = false;

  bool? translationCorrect;
  bool translationComplete = true;

  bool? formCorrect;
  bool? genderCorrect;

  // Selbsteinschätzung: Lösung aufgedeckt.
  bool revealed = false;

  final GlobalKey<SelfAssessmentPanelState> _assessmentKey = GlobalKey();

  LatinVocabularyEntry get entry => widget.entry;

  LatinVocabularySettings get settings => widget.settings;

  LatinVocabularyQuestion get q => LatinVocabularyQuestion(entry: entry);

  bool get _formFieldShown =>
      (q.hasVerbFormField && settings.includeVerbForm) ||
      (q.hasNounFormField && settings.includeNounForm) ||
      (q.hasAdjectiveFormsField && settings.includeAdjectiveForms);

  bool get _genderFieldShown => q.hasGenderField && settings.includeGender;

  @override
  void initState() {
    super.initState();

    HardwareKeyboard.instance.addHandler(_handleKey);

    _focusLater();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);

    translationFocusNode.dispose();
    formFocusNode.dispose();
    genderFocusNode.dispose();

    translationController.dispose();
    formController.dispose();
    genderController.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(LatinVocabularyAnswerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.method != widget.method) {
      if (widget.method == AnswerMethod.typing) {
        _focusLater();
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }
  }

  void _focusLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Im Kopf wird nichts getippt: keine Bildschirmtastatur öffnen.
      if (mounted && widget.method == AnswerMethod.typing) {
        _focusFirstInputField();
      }
    });
  }

  bool _isTextFieldFocused() {
    return translationFocusNode.hasFocus ||
        FocusManager.instance.primaryFocus != null &&
            FocusManager.instance.primaryFocus!.context?.widget is EditableText;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return false;
    }

    // Enter gehört einem geöffneten Info-Blatt bzw. Meldeformular.
    if (infoReportOverlayOpen) {
      return false;
    }

    if (widget.method == AnswerMethod.recall && !answered) {
      return _assessmentKey.currentState?.handleEnter() ?? false;
    }

    // Enter gehört dem aktuell fokussierten Eingabefeld.
    if (_isTextFieldFocused()) {
      return false;
    }

    _submitOrNext();

    return true;
  }

  void _submitOrNext() {
    if (answered) {
      widget.onNext();
    } else {
      check();
    }
  }

  void _focusFirstInputField() {
    if (_formFieldShown) {
      formFocusNode.requestFocus();
      return;
    }

    if (_genderFieldShown) {
      genderFocusNode.requestFocus();
      return;
    }

    translationFocusNode.requestFocus();
  }

  void check() {
    if (widget.method != AnswerMethod.typing) {
      return;
    }

    final result = LatinVocabularyAnswerChecker.check(
      entry: entry,
      translationInput: translationController.text,
      formInput: formController.text,
      genderInput: genderController.text,
      checkVerbForm: q.hasVerbFormField && settings.includeVerbForm,
      checkNounForm: q.hasNounFormField && settings.includeNounForm,
      checkGender: _genderFieldShown,
      checkAdjectiveForms:
          q.hasAdjectiveFormsField && settings.includeAdjectiveForms,
      requireOnlyOneTranslation: settings.requireOnlyOneTranslation,
    );

    // Statistik und Streak nur einmal je Frage (auch bei doppeltem Enter).
    final firstEvaluation = !answered;

    setState(() {
      answered = true;
      correct = result.correct;
      translationCorrect = result.translationCorrect;
      translationComplete = result.translationComplete;
      formCorrect = result.formCorrect;
      genderCorrect = result.genderCorrect;
    });

    widget.onEvaluated(result.correct, firstEvaluation: firstEvaluation);
  }

  /// Selbsteinschätzung nach dem Aufdecken: zählt wie eine richtige bzw.
  /// falsche Antwort und führt direkt zur nächsten Frage.
  void assess(SelfAssessment assessment) {
    // Je aufgedeckter Lösung nur eine Bewertung.
    if (!revealed || answered) {
      return;
    }

    revealed = false;
    answered = true;

    widget.onEvaluated(assessment.knew, firstEvaluation: true);

    widget.onNext();
  }

  /// Vollständige Lösung für die Selbsteinschätzung.
  Widget _buildSolution() {
    return Column(
      children: [
        SelectableText(
          entry.translations.join(", "),
          key: const Key("vocabulary_translation_text"),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),

        if (entry.form != null || entry.gender != null)
          const SizedBox(height: 8),

        if (entry.form != null) Text("Form: ${entry.form}"),

        if (entry.gender != null) Text("Genus: ${entry.gender}"),
      ],
    );
  }

  Widget _buildMnemonic() {
    return MnemonicSection(
      key: ValueKey(entry.id),
      mnemonic: widget.mnemonic,
      onSave: widget.onSaveMnemonic,
    );
  }

  InputDecoration _decoration(String label, bool? result, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      enabledBorder: answerResultBorder(context, result),
      focusedBorder: answerResultBorder(context, result),
      disabledBorder: answerResultBorder(context, result),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          entry.lemma,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        AnswerMethodSelector(
          method: widget.method,
          onChanged: answered || revealed ? null : widget.onMethodChanged,
        ),

        const SizedBox(height: 20),

        if (widget.method == AnswerMethod.recall) ...[
          SelfAssessmentPanel(
            key: _assessmentKey,
            revealed: revealed,
            onReveal: () => setState(() => revealed = true),
            onAssess: assess,
            solutionBuilder: (_) => _buildSolution(),
          ),

          if (revealed) ...[const SizedBox(height: 16), _buildMnemonic()],
        ] else
          ..._buildTyping(),

        InfoReportFooter(
          module: AppModules.latinVocabulary,
          reportDetails: () => {
            "Eintrag": "${entry.lemma} (ID ${entry.id})",
            "Lektion": "${entry.lesson}",
            "Wortart": entry.type,
            ...widget.extraReportDetails,
            // Lösung erst nach dem Prüfen bzw. Aufdecken, damit das
            // Formular sie nicht verrät.
            if (answered || revealed)
              "Hinterlegte Übersetzung": entry.translations.join(", "),
            if (answered) "Eingabe": translationController.text,
          },
        ),
      ],
    );
  }

  List<Widget> _buildTyping() {
    final s = settings;

    return [
      if (_formFieldShown)
        TextField(
          controller: formController,
          focusNode: formFocusNode,
          key: ValueKey('form-${entry.id}'),
          onSubmitted: (_) => _submitOrNext(),
          enabled: !answered,
          decoration: _decoration(
            entry.type == "verb"
                ? "Form"
                : entry.type == "noun"
                ? "Zusatzform"
                : "Formen",
            formCorrect,
          ),
        ),

      if (_genderFieldShown) ...[
        const SizedBox(height: 12),

        TextField(
          controller: genderController,
          focusNode: genderFocusNode,
          key: ValueKey('gender-${entry.id}'),
          onSubmitted: (_) => _submitOrNext(),
          enabled: !answered,
          decoration: _decoration(
            "Genus",
            genderCorrect,
            hint: "z. B. m, f, n",
          ),
        ),
      ],

      const SizedBox(height: 15),

      TextField(
        controller: translationController,
        key: ValueKey('translation-${entry.id}'),
        onSubmitted: (_) => _submitOrNext(),
        enabled: !answered,
        focusNode: translationFocusNode,
        decoration: _decoration(
          "Übersetzung",
          translationCorrect,
          hint: "Mehrere Übersetzungen mit Komma trennen",
        ),
      ),

      const SizedBox(height: 20),

      if (answered)
        Column(
          children: [
            AnswerFeedbackBadge(
              correct: correct,
              label: correct ? "Richtig" : "Falsch",
            ),

            const SizedBox(height: 12),

            if (!correct ||
                !translationComplete ||
                !s.includeVerbForm ||
                !s.includeNounForm ||
                !s.includeGender ||
                !s.includeAdjectiveForms)
              Column(
                children: [
                  const Text(
                    "Korrekte Antworten:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  if (entry.form != null &&
                      (formCorrect == false ||
                          (entry.type == "verb" && !s.includeVerbForm) ||
                          (entry.type == "noun" && !s.includeNounForm) ||
                          (entry.type == "adjective" &&
                              !s.includeAdjectiveForms)))
                    Text("Form: ${entry.form}"),

                  if (entry.gender != null &&
                      (genderCorrect == false || !s.includeGender))
                    Text("Genus: ${entry.gender}"),

                  if (translationCorrect == false || !translationComplete)
                    Text("Übersetzung: ${entry.translations.join(", ")}"),
                ],
              ),

            const SizedBox(height: 16),

            _buildMnemonic(),
          ],
        ),

      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: answered ? widget.onNext : check,
          child: Text(answered ? "Weiter" : "Prüfen"),
        ),
      ),
    ];
  }
}

/// Einstellungsabschnitt „Abfrage“: was zusätzlich zur Übersetzung
/// eingegeben werden muss. Gemeinsam für Vokabeltrainer und Lernplan.
class LatinQuerySettingsSection extends StatelessWidget {
  final LatinVocabularySettings settings;

  final ValueChanged<LatinVocabularySettings> onChanged;

  const LatinQuerySettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: "Abfrage",
      hint: "Legt fest, was zusätzlich zur Übersetzung eingegeben werden muss.",
      child: SettingsSwitchGroup(
        children: [
          SwitchListTile(
            title: const Text("Verbform abfragen"),
            subtitle: const Text("Bei Verben"),
            value: settings.includeVerbForm,
            onChanged: (value) =>
                onChanged(settings.copyWith(includeVerbForm: value)),
          ),

          SwitchListTile(
            title: const Text("Nomenform abfragen"),
            subtitle: const Text("Bei Nomen"),
            value: settings.includeNounForm,
            onChanged: (value) =>
                onChanged(settings.copyWith(includeNounForm: value)),
          ),

          SwitchListTile(
            title: const Text("Genus abfragen"),
            subtitle: const Text("Bei Nomen"),
            value: settings.includeGender,
            onChanged: (value) =>
                onChanged(settings.copyWith(includeGender: value)),
          ),

          SwitchListTile(
            title: const Text("Adjektivformen abfragen"),
            subtitle: const Text("Bei Adjektiven"),
            value: settings.includeAdjectiveForms,
            onChanged: (value) =>
                onChanged(settings.copyWith(includeAdjectiveForms: value)),
          ),

          SwitchListTile(
            title: const Text("Eine richtige Übersetzung reicht (empfohlen)"),
            subtitle: const Text(
              "Sonst müssen alle Übersetzungen genannt werden.",
            ),
            value: settings.requireOnlyOneTranslation,
            onChanged: (value) =>
                onChanged(settings.copyWith(requireOnlyOneTranslation: value)),
          ),
        ],
      ),
    );
  }
}
