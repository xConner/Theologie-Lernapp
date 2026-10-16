import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'logic_text.dart';

/// Tastenreihe für logische Zeichen; fügt an der Cursorposition des
/// zuletzt gewählten Eingabefelds ein. Auf der Tastatur gehen auch:
/// ~ für ¬, & für ∧, v für ∨, -> für →, <-> für ↔.
class SymbolKeyboard extends StatelessWidget {
  final TextEditingController? controller;
  final bool predicateLogic;

  /// Zusätzliche Tasten (z. B. griechische Bezeichner im Beweiseditor).
  final List<String> extra;

  final VoidCallback? onChanged;

  const SymbolKeyboard({
    super.key,
    required this.controller,
    this.predicateLogic = false,
    this.extra = const [],
    this.onChanged,
  });

  static void insert(TextEditingController controller, String text) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      "¬", "∧", "∨", "→", "↔", "(", ")",
      if (predicateLogic) ...["∀", "∃", "x", "y"],
      ...extra,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in keys)
          SizedBox(
            width: 42,
            height: 38,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              onPressed: controller == null
                  ? null
                  : () {
                      insert(controller!, k);
                      onChanged?.call();
                    },
              child: Text(k, style: formulaStyle(context, fontSize: 17)),
            ),
          ),
        SizedBox(
          width: 42,
          height: 38,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: context.colors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            onPressed: controller == null
                ? null
                : () {
                    final c = controller!;
                    final sel = c.selection;
                    final pos = sel.isValid ? sel.start : c.text.length;
                    if (sel.isValid && !sel.isCollapsed) {
                      insert(c, "");
                    } else if (pos > 0) {
                      c.value = TextEditingValue(
                        text: c.text.replaceRange(pos - 1, pos, ""),
                        selection: TextSelection.collapsed(offset: pos - 1),
                      );
                    }
                    onChanged?.call();
                  },
            child: const Icon(Icons.backspace_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}
