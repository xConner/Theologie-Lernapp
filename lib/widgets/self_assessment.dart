import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Selbsteinschätzung in den Trainern (Vokabeln, Grammatik, Perikopenquiz):
/// Die Antwort wird im Kopf abgerufen, die Lösung aufgedeckt und das eigene
/// Wissen bewertet – nach dem Vorbild von „Im Kopf“ unter „Texte auswendig
/// lernen“.
///
/// Hier liegen nur Auswahl, Ablauf und Oberfläche. Was eine Bewertung für
/// den Lernstand bedeutet, verbucht der jeweilige Trainer über dieselbe
/// Logik wie eine geprüfte Eingabe.

/// Wie der Nutzer eine Frage beantwortet.
enum AnswerMethod { typing, recall }

/// Merkt sich die Antwortmethode je Trainer auf dem Gerät (wie die
/// Schnelleingabe des Perikopenquiz).
class AnswerMethodPreference {
  static const String greekVocabulary = "greek_vocabulary";
  static const String greekGrammar = "greek_grammar";
  static const String latinVocabulary = "latin_vocabulary";
  static const String pericopeQuiz = "pericope_quiz";

  static String _key(String trainer) => "answer_method.$trainer";

  /// Ohne gespeicherte Wahl (oder ohne lokalen Speicher) wird getippt.
  static Future<AnswerMethod> load(String trainer) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString(_key(trainer)) == AnswerMethod.recall.name
          ? AnswerMethod.recall
          : AnswerMethod.typing;
    } catch (_) {
      return AnswerMethod.typing;
    }
  }

  static Future<void> save(String trainer, AnswerMethod method) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_key(trainer), method.name);
    } catch (_) {
      // Die Wahl gilt dann nur bis zum Schließen des Trainers.
    }
  }
}

/// Umschalter zwischen Eintippen und Selbsteinschätzung.
///
/// [onChanged] ist `null`, solange nicht gewechselt werden darf (Frage
/// bereits ausgewertet oder Lösung aufgedeckt).
class AnswerMethodSelector extends StatelessWidget {
  final AnswerMethod method;
  final ValueChanged<AnswerMethod>? onChanged;

  const AnswerMethodSelector({
    super.key,
    required this.method,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AnswerMethod>(
      key: const Key("answer_method"),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(
          value: AnswerMethod.typing,
          icon: Icon(Icons.keyboard_rounded),
          label: Text("Tippen"),
        ),
        ButtonSegment(
          value: AnswerMethod.recall,
          icon: Icon(Icons.self_improvement_rounded),
          label: Text("Im Kopf"),
        ),
      ],
      selected: {method},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) {
              if (selection.first != method) {
                onChanged!(selection.first);
              }
            },
    );
  }
}

/// Ein einzeln bewertbarer Teil der Lösung, z. B. „Kasus: Dativ“.
class SelfAssessmentPart {
  final String id;
  final String label;
  final String value;

  const SelfAssessmentPart({
    required this.id,
    required this.label,
    required this.value,
  });
}

/// Ergebnis einer Selbsteinschätzung.
class SelfAssessment {
  /// IDs der nicht gewussten Teile ([SelfAssessmentPanel.parts]); bei „Nicht
  /// gewusst“ alle.
  final Set<String> missed;

  /// Alles gewusst – entspricht einer richtigen Antwort.
  final bool knew;

  const SelfAssessment({required this.knew, this.missed = const {}});
}

/// Ob die Eingabetaste dem gerade fokussierten Eingabefeld gehört (z. B. der
/// Lernhilfe) und deshalb keine Trainer-Aktion auslösen darf.
bool textInputHasFocus() {
  // Der Fokusknoten eines Eingabefelds hängt unterhalb seines EditableText.
  final focused = FocusManager.instance.primaryFocus?.context;

  return focused != null &&
      (focused.widget is EditableText ||
          focused.findAncestorWidgetOfExactType<EditableText>() != null);
}

/// Ablauf der Selbsteinschätzung: erst „Lösung anzeigen“, dann die Lösung
/// mit „Nicht gewusst“ / „Gewusst“.
///
/// Der Trainer hält [revealed] und setzt es mit jeder neuen Frage zurück.
/// Je aufgedeckter Lösung meldet das Panel höchstens eine Bewertung.
///
/// Mit [parts] lassen sich einzelne Teile als nicht gewusst markieren; aus
/// „Gewusst“ wird dann „Teilweise gewusst“.
class SelfAssessmentPanel extends StatefulWidget {
  final bool revealed;

  /// `null`, solange die Frage noch nicht bereit ist.
  final VoidCallback? onReveal;

  final ValueChanged<SelfAssessment> onAssess;

  /// Die Lösung; wird erst nach dem Aufdecken gebaut.
  final WidgetBuilder solutionBuilder;

  final List<SelfAssessmentPart> parts;

  final String hint;

  const SelfAssessmentPanel({
    super.key,
    required this.revealed,
    required this.onReveal,
    required this.onAssess,
    required this.solutionBuilder,
    this.parts = const [],
    this.hint = "Rufe die Antwort im Kopf ab und decke dann die Lösung auf.",
  });

  @override
  State<SelfAssessmentPanel> createState() => SelfAssessmentPanelState();
}

class SelfAssessmentPanelState extends State<SelfAssessmentPanel> {
  final Set<String> _missed = {};

  bool _assessed = false;

  @override
  void didUpdateWidget(SelfAssessmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Neue Frage: Markierungen und Sperre der vorherigen verwerfen.
    if (!widget.revealed) {
      _missed.clear();
      _assessed = false;
    }
  }

  /// Eingabetaste: deckt auf bzw. bewertet mit dem aktuellen Stand der
  /// Markierungen. `false`, wenn die Taste nicht dem Panel gehört.
  bool handleEnter() {
    if (textInputHasFocus() || _ownControlHasFocus()) {
      return false;
    }

    if (!widget.revealed) {
      if (widget.onReveal == null) {
        return false;
      }

      widget.onReveal!();
      return true;
    }

    _confirm();
    return true;
  }

  // Ein fokussierter Knopf des Panels löst mit Enter bereits selbst aus.
  bool _ownControlHasFocus() {
    final focused = FocusManager.instance.primaryFocus?.context;

    return focused != null &&
        focused.findAncestorStateOfType<SelfAssessmentPanelState>() == this;
  }

  void _assess(SelfAssessment assessment) {
    if (!widget.revealed || _assessed) {
      return;
    }

    _assessed = true;

    widget.onAssess(assessment);
  }

  void _confirm() {
    _assess(SelfAssessment(knew: _missed.isEmpty, missed: {..._missed}));
  }

  void _reject() {
    _assess(
      SelfAssessment(
        knew: false,
        missed: {for (final part in widget.parts) part.id},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);

    if (!widget.revealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.hint, textAlign: TextAlign.center, style: secondary),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key("self_assessment_reveal"),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text("Lösung anzeigen"),
            onPressed: widget.onReveal,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key("self_assessment_solution"),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Semantics(
            liveRegion: true,
            label: "Lösung",
            child: widget.solutionBuilder(context),
          ),
        ),

        if (widget.parts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Tippe an, was du nicht wusstest:",
            textAlign: TextAlign.center,
            style: secondary,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final part in widget.parts) _buildPart(context, part),
            ],
          ),
        ],

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key("self_assessment_missed"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
                onPressed: _reject,
                child: const Text("Nicht gewusst", textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key("self_assessment_knew"),
                onPressed: _confirm,
                child: Text(
                  _missed.isEmpty ? "Gewusst" : "Teilweise gewusst",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPart(BuildContext context, SelfAssessmentPart part) {
    final missed = _missed.contains(part.id);

    return Semantics(
      label: missed ? "Nicht gewusst" : null,
      child: FilterChip(
        key: Key("self_assessment_part_${part.id}"),
        showCheckmark: false,
        avatar: missed
            ? Icon(Icons.close_rounded, size: 18, color: context.colors.error)
            : null,
        label: Text("${part.label}: ${part.value}"),
        selected: missed,
        selectedColor: context.colors.errorBackground,
        onSelected: (value) {
          setState(() {
            if (value) {
              _missed.add(part.id);
            } else {
              _missed.remove(part.id);
            }
          });
        },
      ),
    );
  }
}
