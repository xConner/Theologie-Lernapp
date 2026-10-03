import 'package:flutter/material.dart';

import '../../../info/app_info.dart';
import '../../../services/greek/grammar/pronoun_paradigms.dart';
import '../../../widgets/info_report.dart';
import '../../../widgets/pronoun_paradigm_view.dart';
import '../../../widgets/settings_access.dart';

class PronounsScreen extends StatefulWidget {
  const PronounsScreen({super.key});

  @override
  State<PronounsScreen> createState() => _PronounsScreenState();
}

class _PronounsScreenState extends State<PronounsScreen> {
  late final Future<PronounParadigms> _paradigms = PronounParadigms.load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pronomen"),
        actions: const [
          InfoButton(module: AppModules.greekGrammarOverview),
          SettingsButton(),
        ],
      ),

      body: FutureBuilder<PronounParadigms>(
        future: _paradigms,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Die Pronomen konnten nicht geladen werden."),
            );
          }

          final paradigms = snapshot.data;

          if (paradigms == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),

              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final paradigm in paradigms.all)
                    ExpansionTile(
                      title: Text(
                        paradigm.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(paradigm.kindLabel),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [PronounParadigmView(paradigm: paradigm)],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
