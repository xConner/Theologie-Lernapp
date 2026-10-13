import 'package:flutter/material.dart';

import '../../../services/greek/grammar/pronoun_paradigms.dart';
import '../../../widgets/grammar_overview_widgets.dart';
import '../../../widgets/pronoun_paradigm_view.dart';

class PronounsScreen extends StatefulWidget {
  /// Paradigmen für Tests; sonst werden sie aus den Assets geladen.
  final Future<PronounParadigms>? paradigms;

  const PronounsScreen({super.key, this.paradigms});

  @override
  State<PronounsScreen> createState() => _PronounsScreenState();
}

class _PronounsScreenState extends State<PronounsScreen> {
  late final Future<PronounParadigms> _paradigms =
      widget.paradigms ?? PronounParadigms.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PronounParadigms>(
      future: _paradigms,
      builder: (context, snapshot) {
        final paradigms = snapshot.data;

        return GrammarTopicScaffold(
          title: "Pronomen",
          children: [
            if (snapshot.hasError)
              const GrammarStatus.error(
                "Die Pronomen konnten nicht geladen werden.",
              )
            else if (paradigms == null)
              const GrammarStatus.loading()
            else
              for (final paradigm in paradigms.all)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      paradigm.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(paradigm.kindLabel),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [PronounParadigmView(paradigm: paradigm)],
                  ),
                ),
          ],
        );
      },
    );
  }
}
