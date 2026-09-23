import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Zeigt das Ergebnis einer Quiz-Antwort (richtig/falsch) als dezentes,
/// farbiges Badge an. Rein visuelle Komponente ohne eigene Logik – der
/// aufrufende Screen entscheidet weiterhin, wann und mit welchem Text sie
/// angezeigt wird.
class AnswerFeedbackBadge extends StatelessWidget {
  final bool correct;
  final String label;

  const AnswerFeedbackBadge({
    super.key,
    required this.correct,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.success : AppColors.error;
    final background = correct
        ? AppColors.successBackground
        : AppColors.errorBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
