import 'package:flutter/material.dart';

import '../../../services/greek/exam/exam_generator.dart';
import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../services/greek/exam/passage_finder.dart';
import '../../../theme/app_theme.dart';

/// Darstellung einer begründeten Absage: widersprüchliche Kriterien
/// getrennt von bloß zu engen Filtern, mit den aus den Daten ermittelten
/// Lockerungen. Die Begründungen stammen aus `PassageFinder`.
class ExamDiagnosisView extends StatelessWidget {
  final ExamNotPossible outcome;

  const ExamDiagnosisView({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final diagnosis = outcome.diagnosis;
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    final children = <Widget>[];

    void heading(String text) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(text, style: titleStyle),
        ),
      );
    }

    if (diagnosis.contradictions.isNotEmpty) {
      heading("Widersprüchliche Kriterien");
      children.addAll([
        for (final c in diagnosis.contradictions)
          Text("• ${c.message}", style: TextStyle(color: colors.error)),
        const Text(
          "Diese Kombination kann kein Text erfüllen; bitte eine der "
          "Anforderungen ändern.",
        ),
      ]);
    }

    if (diagnosis.failedForFixedPassage.isNotEmpty) {
      heading("Die gewählte Stelle erfüllt nicht alle Kriterien");
      children.addAll([
        for (final c in diagnosis.failedForFixedPassage)
          Text("• ${_failedLabel(c)}"),
      ]);
    }

    if (diagnosis.neverRequired.isNotEmpty) {
      heading("Erforderlich, aber in den gewählten Texten nicht belegt");
      children.add(
        Text(
          "${diagnosis.neverRequired.map((id) => "„${GrammarPhenomena.byId(id)?.label}“").join(", ")} "
          "kommt in keinem Abschnitt passender Länge sicher belegt vor.",
        ),
      );
    }

    if (diagnosis.suggestions.isNotEmpty) {
      heading("Zu enge Filter – mögliche Lockerungen");
      children.addAll([
        for (final s in diagnosis.suggestions) Text("• ${s.message}"),
      ]);
    }

    final unrestricted = outcome.unrestrictedMatches;

    if (unrestricted != null && unrestricted > 0) {
      heading("Weitere Bücher oder Textkorpora");
      children.add(
        Text(
          "Ohne Einschränkung auf Bücher bzw. Korpora gäbe es $unrestricted "
          "passende Abschnitte.",
        ),
      );
    }

    if (outcome.noAlternative) {
      children.add(
        const Text("Es gibt keinen anderen Text, der die Kriterien erfüllt."),
      );
    }

    if (children.isEmpty) {
      children.add(
        const Text(
          "Kein Abschnitt erfüllt alle Kriterien, und keine einzelne "
          "Lockerung würde genügen. Mehrere Filter gleichzeitig lockern.",
        ),
      );
    }

    return Column(
      key: const ValueKey("exam-diagnosis"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _failedLabel(SearchConstraint c) {
    final label = GrammarPhenomena.byId(c.phenomenonId ?? "")?.label;

    return switch (c.kind) {
      ConstraintKind.required => "„$label“ ist nicht sicher belegt.",
      ConstraintKind.excluded => "„$label“ kommt vor (oder ist möglich).",
      ConstraintKind.completeAnalysis =>
        "Nicht alle Wörter sind bestimmt; Ausschlüsse lassen sich nicht "
            "sicher prüfen.",
      ConstraintKind.notDone =>
        "Die Stelle ist als bearbeitet markiert (bearbeitete Texte sind "
            "ausgeschlossen).",
      ConstraintKind.hints => "Sie braucht mehr Vokabelhilfen als erlaubt.",
      ConstraintKind.length => "Die Länge passt nicht.",
    };
  }
}
