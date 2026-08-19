import 'package:flutter/material.dart';

import 'latin_vocabulary_trainer_screen.dart';
import 'latin_vocabulary_overview_screen.dart';

class LatinHomeScreen extends StatelessWidget {
  const LatinHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Latein")),
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
                          builder: (_) => const LatinVocabularyTrainerScreen(),
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
                          builder: (_) => const LatinVocabularyOverviewScreen(),
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
                    onPressed: null,
                    child: const Text("Grammatikübersicht"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
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
