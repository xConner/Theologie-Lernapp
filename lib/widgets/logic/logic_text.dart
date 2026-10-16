import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Schrift für logische Zeichen (gebündelte Teilmenge von DejaVu Sans), damit
/// ¬ ∧ ∨ → ↔ ∀ ∃ ⊢ ⊨ auf allen Plattformen gleich aussehen.
const String logicFontFamily = "LogicSymbols";

TextStyle formulaStyle(BuildContext context, {double? fontSize, FontWeight? weight}) =>
    TextStyle(
      fontFamily: logicFontFamily,
      fontSize: fontSize ?? 15.5,
      fontWeight: weight,
      color: context.colors.textPrimary,
      height: 1.45,
    );

/// Eine Formel bzw. metasprachliche Zeile in der Formelschrift.
class FormulaText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final TextAlign textAlign;
  final FontWeight? weight;
  final Color? color;

  const FormulaText(
    this.text, {
    super.key,
    this.fontSize,
    this.textAlign = TextAlign.start,
    this.weight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: formulaStyle(context, fontSize: fontSize, weight: weight)
          .copyWith(color: color),
    );
  }
}

/// Fließtext mit Auszeichnungen: `Formel`, **fett**, *kursiv*.
class LogicText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const LogicText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  static final RegExp _token = RegExp(r"`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*");

  static List<InlineSpan> spans(BuildContext context, String text, TextStyle base) {
    final result = <InlineSpan>[];
    var last = 0;

    for (final m in _token.allMatches(text)) {
      if (m.start > last) {
        result.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        result.add(
          TextSpan(
            text: m.group(1),
            style: TextStyle(
              fontFamily: logicFontFamily,
              fontSize: (base.fontSize ?? 15) * 0.98,
              color: context.colors.primary,
            ),
          ),
        );
      } else if (m.group(2) != null) {
        result.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        result.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      last = m.end;
    }

    if (last < text.length) result.add(TextSpan(text: text.substring(last)));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    return Text.rich(
      TextSpan(
        style: base,
        children: spans(context, text, base),
      ),
      textAlign: textAlign,
    );
  }
}

/// Horizontal scrollbar, wenn der Inhalt breiter als der Bildschirm ist
/// (lange Formeln, Tafeln und Beweise auf kleinen Geräten).
class HorizontalOverflow extends StatelessWidget {
  final Widget child;

  const HorizontalOverflow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: child,
        ),
      ),
    );
  }
}
