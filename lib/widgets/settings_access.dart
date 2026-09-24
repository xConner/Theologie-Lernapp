import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

/// Einheitlicher Einstellungszugang der App:
///
/// * Screens ohne eigene Einstellungen zeigen [SettingsButton] – das Zahnrad
///   öffnet direkt die globalen Einstellungen ([SettingsScreen]).
/// * Screens mit eigenen Einstellungen behalten ihr Zahnrad und ihren Dialog;
///   dieser zeigt über [ModuleSettingsDialog] bzw. [SettingsTabs] zusätzlich
///   den Tab „Allgemein“ mit denselben globalen Einstellungen
///   ([GeneralSettingsView]).

/// Zahnrad für die AppBar eines Screens ohne eigene Einstellungen.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      tooltip: "Einstellungen",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
    );
  }
}

/// Tabs „Allgemein“ und [moduleLabel] für den Einstellungsdialog eines
/// Screens mit eigenen Einstellungen. Der screenspezifische Tab ist beim
/// Öffnen ausgewählt. Beide Tabs bleiben beim Wechseln erhalten, sodass
/// ungespeicherte Änderungen im Modul-Tab nicht verloren gehen.
///
/// Muss eine begrenzte Höhe erhalten (z. B. über `Expanded` oder `SizedBox`).
class SettingsTabs extends StatefulWidget {
  final String moduleLabel;
  final Widget moduleSettings;

  const SettingsTabs({
    super.key,
    required this.moduleLabel,
    required this.moduleSettings,
  });

  static const int generalTab = 0;
  static const int moduleTab = 1;

  @override
  State<SettingsTabs> createState() => _SettingsTabsState();
}

class _SettingsTabsState extends State<SettingsTabs>
    with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(
    length: 2,
    vsync: this,
    initialIndex: SettingsTabs.moduleTab,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: controller,
          tabs: [
            const Tab(text: "Allgemein"),
            Tab(text: widget.moduleLabel),
          ],
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return IndexedStack(
                index: controller.index,
                sizing: StackFit.expand,
                children: [
                  const GeneralSettingsView(
                    allowProgressReset: false,
                    padding: EdgeInsets.zero,
                  ),
                  widget.moduleSettings,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Ersatz für das bisherige `AlertDialog` der Trainer-Einstellungen: gleicher
/// Titel (inkl. Bestätigen-Button), der bisherige Inhalt landet unverändert im
/// Tab [moduleLabel].
class ModuleSettingsDialog extends StatelessWidget {
  final Widget title;
  final String moduleLabel;
  final Widget moduleSettings;

  const ModuleSettingsDialog({
    super.key,
    required this.title,
    required this.moduleLabel,
    required this.moduleSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SettingsTabs(
          moduleLabel: moduleLabel,
          moduleSettings: moduleSettings,
        ),
      ),
    );
  }
}
