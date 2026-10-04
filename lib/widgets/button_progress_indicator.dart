import 'package:flutter/material.dart';

/// Ladeanzeige innerhalb eines Buttons. Übernimmt die Vordergrundfarbe des
/// Buttons und bleibt damit in jedem Theme und auch auf einem gesperrten
/// Button sichtbar.
class ButtonProgressIndicator extends StatelessWidget {
  const ButtonProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
      ),
    );
  }
}
