import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../algorithms/daily_new_plan.dart';
import '../../../models/latin/vocabulary/latin_vocabulary_plan.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import '../../../widgets/settings_selection.dart';

/// Ergebnis des Plan-Dialogs.
class LatinPlanDialogResult {
  final LatinVocabularyPlan? plan;

  const LatinPlanDialogResult.save(LatinVocabularyPlan this.plan);
  const LatinPlanDialogResult.end() : plan = null;

  bool get ended => plan == null;
}

/// Lernplan beginnen oder ändern: neue Vokabeln pro Tag, Zieldatum,
/// Lektionen und Pause. Änderungen betreffen nur die Planung; Lernstände
/// und bisherige Einführungen bleiben.
///
/// [remainingNewOf] zählt die noch nicht eingeführten Vokabeln der
/// gewählten Lektionen.
Future<LatinPlanDialogResult?> showLatinPlanDialog(
  BuildContext context, {
  required LatinVocabularyPlan? current,
  required List<int> lessons,
  required int Function(Set<int> disabledLessons) remainingNewOf,
  required DateTime now,
}) {
  return showDialog<LatinPlanDialogResult>(
    context: context,
    builder: (_) => _LatinPlanDialog(
      current: current,
      lessons: lessons,
      remainingNewOf: remainingNewOf,
      now: now,
    ),
  );
}

class _LatinPlanDialog extends StatefulWidget {
  final LatinVocabularyPlan? current;
  final List<int> lessons;
  final int Function(Set<int> disabledLessons) remainingNewOf;
  final DateTime now;

  const _LatinPlanDialog({
    required this.current,
    required this.lessons,
    required this.remainingNewOf,
    required this.now,
  });

  @override
  State<_LatinPlanDialog> createState() => _LatinPlanDialogState();
}

class _LatinPlanDialogState extends State<_LatinPlanDialog> {
  late int daily =
      widget.current?.dailyNew ?? LatinVocabularyPlan.defaultDailyNew;

  late bool paused = widget.current?.paused ?? false;

  // Nur Lektionen, die es gibt: Abgewählte, später entfernte Lektionen
  // bleiben gespeichert, stören hier aber nicht.
  late final Set<int> disabled = {...?widget.current?.disabledLessons};

  late final TextEditingController target = TextEditingController(
    text: widget.current?.targetDate == null
        ? ""
        : formatDate(widget.current!.targetDate!),
  );

  String? error;

  bool get _editing => widget.current != null;

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  LatinVocabularyPlan _plan() {
    return LatinVocabularyPlan(
      dailyNew: daily,
      createdAt: widget.current?.createdAt ?? widget.now,
      targetDate: parseDate(target.text),
      paused: paused,
      disabledLessons: {...disabled},
    );
  }

  bool get _noLesson => widget.lessons.every(disabled.contains);

  void _save() {
    if (target.text.trim().isNotEmpty) {
      final date = parseDate(target.text);

      if (date == null) {
        setState(() => error = "Datum bitte als TT.MM.JJJJ angeben.");
        return;
      }

      if (date.isBefore(DailyNewPlan.dayOf(widget.now))) {
        setState(() => error = "Das Zieldatum liegt in der Vergangenheit.");
        return;
      }
    }

    Navigator.pop(context, LatinPlanDialogResult.save(_plan()));
  }

  Future<void> _end() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lernplan beenden?"),
        content: const Text(
          "Der Plan schlägt danach keine neuen Vokabeln mehr vor. Gelernte "
          "Vokabeln und Lernstände bleiben erhalten; ein neuer Plan setzt "
          "dort fort.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            key: const ValueKey("latin-plan-end-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Beenden"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, const LatinPlanDialogResult.end());
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan();

    final remaining = widget.remainingNewOf(disabled);

    final required = plan.requiredPerDay(remaining, widget.now);

    final days = remaining == 0 ? 0 : (remaining / daily).ceil();

    final secondary = TextStyle(
      color: context.colors.textSecondary,
      fontSize: 12.5,
    );

    return AlertDialog(
      title: Text(_editing ? "Lernplan ändern" : "Lernplan beginnen"),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Noch $remaining Vokabeln sind nicht eingeführt. Fällige "
                "Wiederholungen kommen in jeder Lerneinheit dazu.",
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text("Neue Vokabeln pro Tag"),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey("latin-plan-daily-minus"),
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: daily > 1 ? () => setState(() => daily--) : null,
                  ),
                  Text(
                    "$daily",
                    key: const ValueKey("latin-plan-daily"),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey("latin-plan-daily-plus"),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: daily < LatinVocabularyPlan.maxDailyNew
                        ? () => setState(() => daily++)
                        : null,
                  ),
                ],
              ),
              if (days > 0)
                Text(
                  "So sind alle Vokabeln in etwa $days Tagen eingeführt.",
                  style: secondary,
                ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey("latin-plan-target"),
                controller: target,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: "Zieldatum (optional)",
                  hintText: "TT.MM.JJJJ",
                  errorText: error,
                ),
                onChanged: (_) => setState(() => error = null),
              ),
              if (required != null && required > daily)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Für dieses Ziel sind $required neue Vokabeln pro Tag "
                    "nötig; der Plan schlägt so viele vor.",
                    style: TextStyle(color: context.colors.accent),
                  ),
                ),
              const SizedBox(height: 8),
              MultiSelectSection<int>(
                title: "Lektionen",
                hint:
                    "Der Plan führt die Vokabeln der gewählten Lektionen der "
                    "Reihe nach ein. Später ergänzte Lektionen gehören "
                    "automatisch dazu.",
                options: widget.lessons,
                isSelected: (lesson) => !disabled.contains(lesson),
                labelOf: (lesson) => "Lektion $lesson",
                emptyError: "Mindestens eine Lektion muss ausgewählt sein.",
                onToggleAll: () => setState(() {
                  if (disabled.isEmpty) {
                    disabled.addAll(widget.lessons);
                  } else {
                    disabled.clear();
                  }
                }),
                onChanged: (lesson, value) => setState(() {
                  if (value) {
                    disabled.remove(lesson);
                  } else {
                    disabled.add(lesson);
                  }
                }),
              ),
              if (_editing)
                SwitchListTile(
                  key: const ValueKey("latin-plan-paused"),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Plan pausieren"),
                  subtitle: const Text(
                    "Keine neuen Vokabeln; Wiederholungen bleiben möglich.",
                  ),
                  value: paused,
                  onChanged: (value) => setState(() => paused = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_editing)
          TextButton(
            key: const ValueKey("latin-plan-end"),
            onPressed: _end,
            child: const Text("Plan beenden"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("latin-plan-save"),
          onPressed: _noLesson ? null : _save,
          child: Text(_editing ? "Speichern" : "Beginnen"),
        ),
      ],
    );
  }
}
