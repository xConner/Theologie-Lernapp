import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notifications/notification_preferences.dart';
import '../theme/app_theme.dart';

/// Einstellungen für Push und E-Mail. Die In-App-Glocke ist davon
/// unabhängig: veröffentlichte Nachrichten erscheinen dort immer.
///
/// Bewusst ohne Optionen für Lernerinnerungen oder fällige Wiederholungen –
/// beides wird nicht versendet.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationPreferencesService service =
      NotificationPreferencesService();

  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  NotificationPreferences? preferences;
  bool loadFailed = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    final accountUid = uid;
    if (accountUid == null) return;

    setState(() => loadFailed = false);

    try {
      final loaded = await service.load(accountUid);
      if (!mounted) return;
      setState(() => preferences = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => loadFailed = true);
    }
  }

  /// Übernimmt die Änderung sofort in der Oberfläche; schlägt das Speichern
  /// fehl, wird der gespeicherte Stand neu geladen.
  void _update(NotificationPreferences next) {
    final accountUid = uid;
    if (accountUid == null) return;

    setState(() => preferences = next);

    final messenger = ScaffoldMessenger.of(context);

    service.save(accountUid, next).catchError((Object _) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Einstellung konnte nicht gespeichert werden."),
        ),
      );
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = preferences;

    return Scaffold(
      appBar: AppBar(title: const Text("Benachrichtigungen")),

      body: uid == null
          ? const _Message(
              "Benachrichtigungen lassen sich mit einem Konto einstellen.",
            )
          : loadFailed
          ? _Message(
              "Einstellungen konnten nicht geladen werden.",
              action: TextButton(
                onPressed: _load,
                child: const Text("Erneut versuchen"),
              ),
            )
          : prefs == null
          ? const Center(child: CircularProgressIndicator())
          : _buildSettings(context, prefs),
    );
  }

  Widget _buildSettings(BuildContext context, NotificationPreferences prefs) {
    final push = prefs.pushEnabled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle("Push-Benachrichtigungen"),

            const _SectionHint(
              "Push-Benachrichtigungen werden gerade eingerichtet. Deine "
              "Auswahl wird gespeichert und gilt, sobald der Versand startet.",
            ),

            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text("Push-Benachrichtigungen"),
                value: push,
                onChanged: (value) =>
                    _update(prefs.copyWith(pushEnabled: value)),
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.local_fire_department_outlined),
                    title: const Text("Streak-Erinnerungen"),
                    subtitle: const Text(
                      "Höchstens einmal am Tag je Lernbereich, wenn eine "
                      "laufende Streak heute noch nicht gesichert ist.",
                    ),
                    value: prefs.streakReminders,
                    onChanged: push
                        ? (value) =>
                              _update(prefs.copyWith(streakReminders: value))
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_outlined),
                    title: const Text("Neue Inhalte"),
                    subtitle: const Text(
                      "Z. B. neue Vokabeln, Perikopenfragen oder Trainer.",
                    ),
                    value: prefs.newContent,
                    onChanged: push
                        ? (value) => _update(prefs.copyWith(newContent: value))
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.info_outline_rounded),
                    title: const Text("Wichtige Systemnachrichten"),
                    subtitle: const Text(
                      "Wartungsarbeiten und relevante Störungen.",
                    ),
                    value: prefs.systemMessages,
                    onChanged: push
                        ? (value) =>
                              _update(prefs.copyWith(systemMessages: value))
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const _SectionTitle("E-Mail"),

            const _SectionHint(
              "Nur selten und bewusst versendet. E-Mails zu Passwort und "
              "Kontobestätigung erhältst du unabhängig davon.",
            ),

            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.mail_outline_rounded),
                title: const Text("Wichtige Nachrichten von theologie.app"),
                subtitle: const Text(
                  "Große Neuerungen und wichtige organisatorische "
                  "Informationen.",
                ),
                value: prefs.emailAnnouncements,
                onChanged: (value) =>
                    _update(prefs.copyWith(emailAnnouncements: value)),
              ),
            ),

            const SizedBox(height: 20),

            const _SectionHint(
              "Veröffentlichte Nachrichten findest du unabhängig von diesen "
              "Einstellungen immer unter der Glocke auf der Startseite.",
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String text;

  const _SectionHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;

  const _Message(this.text, {this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
