import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../algorithms/daily_new_plan.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_plan.dart';
import '../../../services/greek/vocabulary/vocabulary_settings_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';
import '../../../widgets/settings_selection.dart';

/// Ergebnis des Plan-Dialogs.
class GreekPlanDialogResult {
  final GreekVocabularyPlan? plan;

  const GreekPlanDialogResult.save(GreekVocabularyPlan this.plan);
  const GreekPlanDialogResult.end() : plan = null;

  bool get ended => plan == null;
}

/// Lernplan beginnen oder ändern: neue Vokabeln pro Tag, Zieldatum,
/// Lernschritte und Pause. Änderungen betreffen nur die Planung; Lernstände
/// und bisherige Einführungen bleiben.
///
/// [remainingNewOf] zählt die noch nicht eingeführten Vokabeln der
/// gewählten Lernschritte.
Future<GreekPlanDialogResult?> showGreekPlanDialog(
  BuildContext context, {
  required GreekVocabularyPlan? current,
  required List<int> steps,
  required int Function(Set<int> disabledSteps) remainingNewOf,
  required DateTime now,
}) {
  return showDialog<GreekPlanDialogResult>(
    context: context,
    builder: (_) => _GreekPlanDialog(
      current: current,
      steps: steps,
      remainingNewOf: remainingNewOf,
      now: now,
    ),
  );
}

class _GreekPlanDialog extends StatefulWidget {
  final GreekVocabularyPlan? current;
  final List<int> steps;
  final int Function(Set<int> disabledSteps) remainingNewOf;
  final DateTime now;

  const _GreekPlanDialog({
    required this.current,
    required this.steps,
    required this.remainingNewOf,
    required this.now,
  });

  @override
  State<_GreekPlanDialog> createState() => _GreekPlanDialogState();
}

class _GreekPlanDialogState extends State<_GreekPlanDialog> {
  late int daily =
      widget.current?.dailyNew ?? GreekVocabularyPlan.defaultDailyNew;

  late bool paused = widget.current?.paused ?? false;

  // Nur Lernschritte, die es gibt: Abgewählte, später entfernte Schritte
  // bleiben gespeichert, stören hier aber nicht.
  late final Set<int> disabled = {...?widget.current?.disabledSteps};

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

  GreekVocabularyPlan _plan() {
    return GreekVocabularyPlan(
      dailyNew: daily,
      createdAt: widget.current?.createdAt ?? widget.now,
      targetDate: parseDate(target.text),
      paused: paused,
      disabledSteps: {...disabled},
    );
  }

  bool get _noStep => widget.steps.every(disabled.contains);

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

    Navigator.pop(context, GreekPlanDialogResult.save(_plan()));
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
            key: const ValueKey("greek-plan-end-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Beenden"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, const GreekPlanDialogResult.end());
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
                    key: const ValueKey("greek-plan-daily-minus"),
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: daily > 1 ? () => setState(() => daily--) : null,
                  ),
                  Text(
                    "$daily",
                    key: const ValueKey("greek-plan-daily"),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey("greek-plan-daily-plus"),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: daily < GreekVocabularyPlan.maxDailyNew
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
                key: const ValueKey("greek-plan-target"),
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
                title: "Lernschritte",
                hint:
                    "Der Plan führt die Vokabeln der gewählten Lernschritte "
                    "der Reihe nach ein.",
                options: widget.steps,
                isSelected: (step) => !disabled.contains(step),
                labelOf: VocabularySettings.stepLabel,
                emptyError: "Mindestens ein Lernschritt muss ausgewählt sein.",
                onToggleAll: () => setState(() {
                  if (disabled.isEmpty) {
                    disabled.addAll(widget.steps);
                  } else {
                    disabled.clear();
                  }
                }),
                onChanged: (step, value) => setState(() {
                  if (value) {
                    disabled.remove(step);
                  } else {
                    disabled.add(step);
                  }
                }),
              ),
              if (_editing)
                SwitchListTile(
                  key: const ValueKey("greek-plan-paused"),
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
            key: const ValueKey("greek-plan-end"),
            onPressed: _end,
            child: const Text("Plan beenden"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("greek-plan-save"),
          onPressed: _noStep ? null : _save,
          child: Text(_editing ? "Speichern" : "Beginnen"),
        ),
      ],
    );
  }
}
