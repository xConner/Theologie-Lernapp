import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/progress_data_service.dart';
import '../services/quiz_sound_player.dart';
import '../services/quiz_sound_settings.dart';
import '../services/theme_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/info_report.dart';
import '../widgets/learning_progress_dialogs.dart';
import '../widgets/settings_selection.dart';
import 'about_screen.dart';
import 'account_security_screen.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';

/// Globale App-Einstellungen als eigene Seite (z. B. über das Zahnrad eines
/// Screens ohne eigene Einstellungen, siehe `SettingsButton`).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Einstellungen")),
      body: const GeneralSettingsView(),
    );
  }
}

/// Die einzige Implementierung der globalen App-Einstellungen. Wird sowohl
/// von [SettingsScreen] als auch vom Tab „Allgemein“ in den
/// Einstellungsdialogen der Trainer (`SettingsTabs`) verwendet.
class GeneralSettingsView extends StatefulWidget {
  /// Aus einem laufenden Trainer heraus ist das Zurücksetzen deaktiviert:
  /// Der Trainer hält seine Lernkarten im Speicher und würde sie beim
  /// nächsten Antworten wieder zurückschreiben.
  final bool allowProgressReset;

  final EdgeInsetsGeometry padding;

  /// Ermöglicht Widget-Tests ohne initialisiertes Firebase.
  @visibleForTesting
  static User? Function() currentUser = () => FirebaseAuth.instance.currentUser;

  const GeneralSettingsView({
    super.key,
    this.allowProgressReset = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<GeneralSettingsView> createState() => _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends State<GeneralSettingsView> {
  final QuizSoundSettings soundSettings = QuizSoundSettings.instance;
  final ThemeSettings themeSettings = ThemeSettings.instance;

  static const Map<ThemeMode, String> _themeModeLabels = {
    ThemeMode.light: "Hell",
    ThemeMode.dark: "Dunkel",
    ThemeMode.system: "System",
  };

  bool resettingProgress = false;

  @override
  void initState() {
    super.initState();

    soundSettings.addListener(_onSettingsChanged);
    themeSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    soundSettings.removeListener(_onSettingsChanged);
    themeSettings.removeListener(_onSettingsChanged);

    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetProgress() async {
    if (!await confirmProgressReset(context)) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      resettingProgress = true;
    });

    try {
      // uid == null → lokaler Gast-Lernstand, sonst Firestore des Kontos.
      await ProgressDataService().resetProgress(
        GeneralSettingsView.currentUser()?.uid,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text("Lernfortschritte wurden zurückgesetzt.")),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Lernfortschritte konnten nicht zurückgesetzt werden."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          resettingProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = soundSettings.volume <= 0;
    final isGuest = GeneralSettingsView.currentUser() == null;

    return ListView(
      padding: widget.padding,
      children: [
        if (isGuest)
          Card(
            child: ListTile(
              leading: const Icon(Icons.login_rounded),
              title: const Text("Anmelden oder registrieren"),
              subtitle: const Text(
                "Als Gast werden Lernstände nur lokal in diesem Browser "
                "gespeichert.",
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          )
        else
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

        if (!isGuest)
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text("Benachrichtigungen"),
              subtitle: const Text("Push und E-Mail"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
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

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            "Gilt für alle Trainer und Quizzes. Ob ein einzelner Sound "
            "abgespielt wird, lässt sich zusätzlich in den Einstellungen "
            "des jeweiligen Trainers festlegen.",
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: muted
                      ? context.colors.textSecondary
                      : context.colors.primary,
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

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            "Lernfortschritte",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        Card(
          child: ListTile(
            leading: Icon(
              Icons.restart_alt_rounded,
              color: context.colors.error,
            ),
            title: const Text("Lernfortschritte zurücksetzen"),
            subtitle: Text(
              widget.allowProgressReset
                  ? "Vokabeln, Perikopen und Grammatik. Einstellungen "
                        "bleiben erhalten."
                  : "Nur außerhalb eines Trainers möglich, z. B. über die "
                        "Einstellungen der Startseite.",
            ),
            trailing: resettingProgress
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: widget.allowProgressReset,
            onTap: resettingProgress ? null : _resetProgress,
          ),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            "Erscheinungsbild",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleSelectChips(
                label: "Theme",
                options: _themeModeLabels.values.toList(),
                value: _themeModeLabels[themeSettings.themeMode],
                onChanged: (label) {
                  for (final entry in _themeModeLabels.entries) {
                    if (entry.value == label) {
                      themeSettings.setThemeMode(entry.key);
                    }
                  }
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            "Info & Hilfe",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text("Über die App"),
            subtitle: const Text("Quellen, KI-Unterstützung, Daten"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text("Fehler melden"),
            subtitle: const Text("Falscher Inhalt, falsche Quelle oder Bug"),
            onTap: () => showReportDialog(context),
          ),
        ),
      ],
    );
  }
}
