import 'package:flutter/material.dart';

import '../services/lecture_materials/lecture_materials.dart';

/// Zeigt [child] nur mit Freigabe der geschützten Vorlesungsunterlagen
/// (`LectureMaterials`). Ohne Freigabe – auch bei direktem Aufruf, nach
/// Entzug der Freigabe oder nach dem Abmelden – wird die Seite ohne Hinweis
/// geschlossen; angezeigt wird bis dahin nur eine leere Seite.
class LectureMaterialsGate extends StatelessWidget {
  final Widget child;

  /// false: immer [child] (Tests mit eingesetzten Daten).
  final bool enabled;

  const LectureMaterialsGate({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ListenableBuilder(
      listenable: LectureMaterials.instance,
      builder: (context, _) {
        if (LectureMaterials.instance.available) return child;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });

        return const Scaffold();
      },
    );
  }
}
