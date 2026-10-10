import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notifications/notification_preferences.dart';
import '../services/notifications/push_platform.dart';
import '../services/notifications/push_service.dart';
import '../theme/app_theme.dart';

/// Einstellungen für Push und E-Mail. Die In-App-Glocke ist davon
/// unabhängig: veröffentlichte Nachrichten erscheinen dort immer.
///
/// Die Berechtigung des Browsers wird erst angefragt, wenn der Nutzer Push
/// hier einschaltet. Ohne Push bleiben alle Erinnerungen in der App
/// (Streak-Anzeige, Glocke) unverändert nutzbar.
class NotificationSettingsScreen extends StatefulWidget {
  // Nur für Tests ersetzbar.
  final String? uid;
  final NotificationPreferencesService? service;
  final PushService? push;

  const NotificationSettingsScreen({
    super.key,
    this.uid,
    this.service,
    this.push,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final NotificationPreferencesService service =
      widget.service ?? NotificationPreferencesService();

  late final PushService push = widget.push ?? PushService.instance;

  late final String? uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;

  NotificationPreferences? preferences;
  PushDeviceState? deviceState;
  bool loadFailed = false;

  /// Ein-/Ausschalten oder Testversand läuft.
  bool busy = false;

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
      final state = await push.deviceState(accountUid);
      if (!mounted) return;
      setState(() {
        preferences = loaded;
        deviceState = state;
      });
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

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setPush(NotificationPreferences prefs, bool enabled) async {
    final accountUid = uid;
    if (accountUid == null || busy) return;

    setState(() => busy = true);

    try {
      if (enabled) {
        // Ohne vorheriges Warten, damit der Browser die Berechtigungsabfrage
        // dem Klick zuordnet.
        final state = await push.enable(accountUid);
        if (!mounted) return;

        setState(() => deviceState = state);

        if (state == PushDeviceState.on) {
          _update(prefs.copyWith(pushEnabled: true));
        } else if (state == PushDeviceState.blocked) {
          _showMessage("Benachrichtigungen wurden nicht erlaubt.");
        }
      } else {
        final others = await push.disable(accountUid);
        if (!mounted) return;

        setState(() => deviceState = PushDeviceState.off);

        // Das Konto bleibt eingeschaltet, solange ein anderes Gerät Push
        // empfängt.
        if (!others) _update(prefs.copyWith(pushEnabled: false));
      }
    } catch (_) {
      if (!mounted) return;

      if (enabled && push.isBrave) {
        _showBraveHelp();
      } else {
        _showMessage(
          "Push-Benachrichtigungen konnten nicht eingerichtet werden. Bitte "
          "versuche es später erneut.",
        );
      }

      final state = await push.deviceState(accountUid);
      if (mounted) setState(() => deviceState = state);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickTime(NotificationPreferences prefs) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: prefs.reminderMinutes ~/ 60,
        minute: prefs.reminderMinutes % 60,
      ),
      helpText: "Uhrzeit der täglichen Erinnerung",
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    _update(prefs.copyWith(reminderMinutes: picked.hour * 60 + picked.minute));
  }

  Future<void> _sendTest() async {
    if (busy) return;

    setState(() => busy = true);

    final sent = await push.sendTest();

    if (!mounted) return;

    setState(() => busy = false);

    _showMessage(
      sent == null
          ? "Die Testbenachrichtigung konnte nicht gesendet werden."
          : sent == 0
          ? "Kein Gerät erreicht. Schalte Push auf diesem Gerät aus und "
                "wieder ein."
          : "Testbenachrichtigung gesendet. Sie sollte gleich erscheinen.",
    );
  }

  /// Brave schaltet den Push-Dienst erst auf Wunsch des Nutzers ein; bis
  /// dahin scheitert das Abonnieren.
  void _showBraveHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Push in Brave einschalten"),
        content: const Text(
          "Brave stellt Push-Benachrichtigungen erst zu, wenn du es dort "
          "erlaubst:\n\n"
          "1. Öffne brave://settings/privacy.\n"
          "2. Schalte „Google-Dienste für Push-Nachrichten verwenden“ ein.\n"
          "3. Starte Brave neu und schalte Push hier erneut ein.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Schließen"),
          ),
        ],
      ),
    );
  }

  void _showPermissionHelp() {
    final steps = switch (push.device) {
      PushDevice.ios =>
        "Öffne die Einstellungen deines iPhones oder iPads → "
            "„Mitteilungen“ → „Theologie“ und erlaube oder sperre dort die "
            "Mitteilungen.",
      PushDevice.android =>
        "Tippe im Browser neben der Adresse auf das Schloss- bzw. "
            "Einstellungssymbol → „Berechtigungen“ → „Benachrichtigungen“. "
            "Bei der installierten App: App-Symbol lange drücken → "
            "„App-Info“ → „Benachrichtigungen“.",
      PushDevice.desktop =>
        "Klicke im Browser links neben der Adresse auf das Schloss- bzw. "
            "Einstellungssymbol und ändere dort „Benachrichtigungen“. "
            "Zusätzlich muss dein Betriebssystem Mitteilungen des Browsers "
            "zulassen.",
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Berechtigung verwalten"),
        content: Text(
          "Ob theologie.app Benachrichtigungen anzeigen darf, legst du in "
          "deinem Browser bzw. Gerät fest – die App kann das nicht selbst "
          "ändern.\n\n$steps\n\nLade die Seite danach neu.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Schließen"),
          ),
        ],
      ),
    );
  }

  static String _time(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, "0");
    final minute = (minutes % 60).toString().padLeft(2, "0");

    return "$hour:$minute Uhr";
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

  /// Hinweis zum Zustand auf diesem Gerät: (Symbol, Text).
  (IconData, String) _status(PushDeviceState state, {required bool account}) {
    return switch (state) {
      PushDeviceState.on => (
        Icons.check_circle_outline_rounded,
        "Auf diesem Gerät eingeschaltet und vom Browser erlaubt.",
      ),
      PushDeviceState.off =>
        // Für das Konto eingeschaltet, also auf einem anderen Gerät.
        account
            ? (
                Icons.devices_other_outlined,
                "Auf diesem Gerät ausgeschaltet. Ein anderes Gerät deines "
                    "Kontos empfängt weiterhin Push-Benachrichtigungen.",
              )
            : (
                Icons.notifications_off_outlined,
                "Auf diesem Gerät ausgeschaltet. Beim Einschalten fragt "
                    "dein Browser, ob theologie.app Benachrichtigungen "
                    "anzeigen darf.",
              ),
      PushDeviceState.blocked => (
        Icons.block_rounded,
        "Benachrichtigungen sind für theologie.app in diesem Browser bzw. "
            "auf diesem Gerät gesperrt. Erlaube sie über „Berechtigung "
            "verwalten“ und lade die Seite neu.",
      ),
      PushDeviceState.needsHomeScreen => (
        Icons.add_to_home_screen_rounded,
        "Auf iPhone und iPad gibt es Push-Benachrichtigungen nur für "
            "Web-Apps auf dem Home-Bildschirm (ab iOS 16.4): Tippe in "
            "Safari auf „Teilen“ → „Zum Home-Bildschirm“, öffne "
            "theologie.app von dort und schalte Push dann hier ein.",
      ),
      PushDeviceState.unsupported => (
        Icons.info_outline_rounded,
        "Dieser Browser unterstützt keine Push-Benachrichtigungen. Streaks "
            "und Nachrichten siehst du weiterhin in der App.",
      ),
      PushDeviceState.notConfigured => (
        Icons.info_outline_rounded,
        "Push-Benachrichtigungen werden gerade eingerichtet. Deine Auswahl "
            "wird gespeichert und gilt, sobald der Versand startet.",
      ),
    };
  }

  Widget _buildSettings(BuildContext context, NotificationPreferences prefs) {
    final state = deviceState ?? PushDeviceState.off;
    final onThisDevice = state == PushDeviceState.on;

    // Push lässt sich nur dort einschalten, wo das Gerät es kann.
    final canSwitch = !busy && (onThisDevice || state == PushDeviceState.off);

    // Uhrzeit und Kategorien gelten für das Konto, also für alle Geräte.
    final push = prefs.pushEnabled;

    final (statusIcon, statusText) = _status(state, account: push);

    Widget category({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required NotificationPreferences Function(bool) change,
    }) {
      return SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: push ? (value) => _update(change(value)) : null,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle("Push-Benachrichtigungen"),

            const _SectionHint(
              "Erinnerungen, die auch ankommen, wenn theologie.app nicht "
              "geöffnet ist.",
            ),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text("Push auf diesem Gerät"),
                    value: onThisDevice,
                    onChanged: canSwitch
                        ? (value) => _setPush(prefs, value)
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(statusIcon),
                    title: Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (state != PushDeviceState.unsupported &&
                      state != PushDeviceState.needsHomeScreen) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text("Berechtigung verwalten"),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showPermissionHelp,
                    ),
                  ],
                  if (onThisDevice) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.send_outlined),
                      title: const Text("Testbenachrichtigung senden"),
                      enabled: !busy,
                      onTap: _sendTest,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            const _SectionTitle("Tägliche Erinnerung"),

            const _SectionHint(
              "Höchstens eine Benachrichtigung am Tag – und nur, wenn zur "
              "gewählten Uhrzeit noch etwas offen ist. Bereiche, die du "
              "länger als zwei Wochen nicht genutzt hast, pausieren von "
              "selbst.",
            ),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text("Uhrzeit"),
                    subtitle: const Text(
                      "Die Erinnerung kann einige Minuten später eintreffen.",
                    ),
                    trailing: Text(
                      _time(prefs.reminderMinutes),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    enabled: push,
                    onTap: () => _pickTime(prefs),
                  ),
                  const Divider(height: 1),
                  category(
                    icon: Icons.menu_book_outlined,
                    title: "Bibellese",
                    subtitle: "Wenn du heute noch keine Lesung bestätigt hast.",
                    value: prefs.bibleReading,
                    change: (value) => prefs.copyWith(bibleReading: value),
                  ),
                  const Divider(height: 1),
                  category(
                    icon: Icons.event_note_outlined,
                    title: "Bibelleseplan",
                    subtitle:
                        "Wenn die Tageslektüre eines laufenden Plans noch "
                        "offen ist.",
                    value: prefs.readingPlan,
                    change: (value) => prefs.copyWith(readingPlan: value),
                  ),
                  const Divider(height: 1),
                  category(
                    icon: Icons.psychology_outlined,
                    title: "Texte auswendig lernen",
                    subtitle: "Wenn du heute noch nicht geübt hast.",
                    value: prefs.memorization,
                    change: (value) => prefs.copyWith(memorization: value),
                  ),
                  const Divider(height: 1),
                  category(
                    icon: Icons.local_fire_department_outlined,
                    title: "Sprachtrainer und Perikopenquiz",
                    subtitle:
                        "Wenn das Tagesziel in Altgriechisch, Latein oder im "
                        "Perikopenquiz noch offen ist.",
                    value: prefs.trainers,
                    change: (value) => prefs.copyWith(trainers: value),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const _SectionTitle("Mitteilungen"),

            Card(
              child: Column(
                children: [
                  category(
                    icon: Icons.auto_awesome_outlined,
                    title: "Neue Inhalte",
                    subtitle:
                        "Z. B. neue Vokabeln, Perikopenfragen oder Trainer.",
                    value: prefs.newContent,
                    change: (value) => prefs.copyWith(newContent: value),
                  ),
                  const Divider(height: 1),
                  category(
                    icon: Icons.info_outline_rounded,
                    title: "Wichtige Systemnachrichten",
                    subtitle: "Wartungsarbeiten und relevante Störungen.",
                    value: prefs.systemMessages,
                    change: (value) => prefs.copyWith(systemMessages: value),
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
      child: Text(text, style: TextStyle(color: context.colors.textSecondary)),
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
              style: TextStyle(color: context.colors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
