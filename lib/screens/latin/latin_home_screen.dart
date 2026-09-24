import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'latin_vocabulary_trainer_screen.dart';
import 'latin_vocabulary_overview_screen.dart';

import '../../theme/app_theme.dart';
import '../../services/streak/streak_track.dart';
import '../../widgets/streak_widgets.dart';
import '../../widgets/settings_access.dart';

class LatinHomeScreen extends StatelessWidget {
  const LatinHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein"),
        actions: const [SettingsButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.translate_rounded, size: 32, color: AppColors.primary),
                const SizedBox(height: 20),

                StreakDetailCard(
                  uid: FirebaseAuth.instance.currentUser?.uid,
                  track: StreakTrack.latin,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LatinVocabularyTrainerScreen(),
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
                          builder: (_) => const LatinVocabularyOverviewScreen(),
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
                    onPressed: null,
                    icon: const Icon(Icons.rule_rounded),
                    label: const Text("Grammatikübersicht"),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null,
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
