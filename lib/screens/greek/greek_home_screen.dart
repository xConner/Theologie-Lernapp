import 'package:flutter/material.dart';

import 'vocabulary_trainer_screen.dart';
import 'vocabulary_overview_screen.dart';
import 'grammar_overview_screen.dart';
import 'grammar_trainer_screen.dart';

import '../../theme/app_theme.dart';

class GreekHomeScreen extends StatelessWidget {
  const GreekHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Altgriechisch")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.translate_rounded, size: 32, color: AppColors.primary),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VocabularyTrainerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.style_rounded),
                    label: const Text("Vokabeltrainer"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VocabularyOverviewScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text("Vokabelübersicht"),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GrammarOverviewScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.rule_rounded),
                    label: const Text("Grammatikübersicht"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GreekGrammarTrainerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fitness_center_rounded),
                    label: const Text("Grammatiktrainer"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
