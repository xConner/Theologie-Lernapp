import 'package:flutter/material.dart';

import 'vocabulary_trainer_screen.dart';
import 'vocabulary_overview_screen.dart';
import 'grammar_overview_screen.dart';
import 'grammar_trainer_screen.dart';

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VocabularyTrainerScreen(),
                        ),
                      );
                    },
                    child: const Text("Vokabeltrainer"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VocabularyOverviewScreen(),
                        ),
                      );
                    },
                    child: const Text("Vokabelübersicht"),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GrammarOverviewScreen(),
                        ),
                      );
                    },
                    child: const Text("Grammatikübersicht"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GreekGrammarTrainerScreen(),
                        ),
                      );
                    },
                    child: const Text("Grammatiktrainer"),
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
