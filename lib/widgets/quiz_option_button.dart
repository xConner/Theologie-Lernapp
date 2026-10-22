import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Antwortmöglichkeit einer Auswahlfrage (Kirchengeschichte, Altes
/// Testament).
class QuizOptionButton extends StatelessWidget {
  final String text;

  /// null: neutral; true: richtige Antwort; false: falsch gewählt.
  final bool? state;
  final VoidCallback? onPressed;

  const QuizOptionButton({
    super.key,
    required this.text,
    required this.state,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final color = switch (state) {
      true => colors.success,
      false => colors.error,
      null => colors.divider,
    };

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: color, width: state == null ? 1 : 2),
        foregroundColor: colors.textPrimary,
        disabledForegroundColor: colors.textPrimary,
        backgroundColor: switch (state) {
          true => colors.successBackground,
          false => colors.errorBackground,
          null => null,
        },
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          if (state != null)
            Icon(
              state! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
            ),
        ],
      ),
    );
  }
}
