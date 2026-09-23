import 'package:flutter/material.dart';

import '../services/quiz_sound_player.dart';
import '../services/quiz_sound_settings.dart';
import '../theme/app_theme.dart';
import 'account_security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final QuizSoundSettings soundSettings = QuizSoundSettings.instance;

  @override
  void initState() {
    super.initState();

    soundSettings.addListener(_onSoundSettingsChanged);
  }

  @override
  void dispose() {
    soundSettings.removeListener(_onSoundSettingsChanged);

    super.dispose();
  }

  void _onSoundSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = soundSettings.volume <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Einstellungen")),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_rounded),
              title: const Text("Konto & Sicherheit"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSecurityScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              "Antwort-Sounds",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              "Gilt für alle Trainer und Quizzes. Ob ein einzelner Sound "
              "abgespielt wird, lässt sich zusätzlich in den Einstellungen "
              "des jeweiligen Trainers festlegen.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: muted ? AppColors.textSecondary : AppColors.primary,
                  ),

                  const SizedBox(width: 8),

                  const Text("Lautstärke"),

                  Expanded(
                    child: Slider(
                      value: soundSettings.volume,
                      min: 0,
                      max: 1,
                      label: "${(soundSettings.volume * 100).round()}%",
                      onChanged: (value) => soundSettings.setVolume(value),
                      onChangeEnd: (_) =>
                          QuizSoundPlayer.instance.previewVolume(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
