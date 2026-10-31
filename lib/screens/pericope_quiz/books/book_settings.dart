import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../quiz/books/book_learning_controller.dart';
import '../../../services/quiz_sound_settings.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/self_assessment.dart';
import '../../../widgets/settings_access.dart';
import '../../../widgets/trainer_widgets.dart';
import '../quick_entry_panel.dart';
import 'book_widgets.dart';

/// Zahnrad der Ansichten von „Bücher systematisch lernen“: derselbe
/// Einstellungsdialog wie bei den Trainern – Tab „Allgemein“ (globale
/// Einstellungen samt Zurücksetzen der Lernfortschritte) und Tab „Bücher
/// lernen“ (nur Optionen dieser Funktion).
///
/// Nach einem Zurücksetzen lädt [controller] die Lernstände neu, sodass
/// offene Ansichten und eine laufende Lerneinheit nichts Altes
/// zurückschreiben. [onClosed] meldet das Schließen (z. B. um geänderte
/// Optionen in eine laufende Einheit zu übernehmen).
class BookLearningSettingsButton extends StatelessWidget {
  final BookLearningController controller;
  final VoidCallback? onClosed;

  const BookLearningSettingsButton({
    super.key,
    required this.controller,
    this.onClosed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey("book-settings"),
      icon: const Icon(Icons.settings),
      tooltip: "Einstellungen",
      onPressed: () async {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => ModuleSettingsDialog(
            moduleLabel: "Bücher lernen",
            onProgressReset: controller.reload,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Einstellungen"),
                IconButton(
                  key: const ValueKey("book-settings-close"),
                  icon: const Icon(Icons.check),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            moduleSettings: BookLearningSettingsView(controller: controller),
          ),
        );

        onClosed?.call();
      },
    );
  }
}

/// Optionen von „Bücher systematisch lernen“. Bewusst wenige; Antwortform
/// und Schnelleingabe gelten zugleich im Perikopenquiz (gleiche gespeicherte
/// Wahl). Der Schalter für die Wissensfragen wird mit dem Konto gespeichert.
class BookLearningSettingsView extends StatefulWidget {
  /// Für den Schalter „Wissensfragen einbeziehen“; ohne ihn fehlt er.
  final BookLearningController? controller;

  const BookLearningSettingsView({super.key, this.controller});

  @override
  State<BookLearningSettingsView> createState() =>
      _BookLearningSettingsViewState();
}

class _BookLearningSettingsViewState extends State<BookLearningSettingsView> {
  AnswerMethod method = AnswerMethod.typing;

  bool quickEntry = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await AnswerMethodPreference.load(
      AnswerMethodPreference.pericopeQuiz,
    );

    bool q = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      q = prefs.getBool(QuickEntryPanel.preferenceKey) ?? false;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      method = m;
      quickEntry = q;
    });
  }

  Future<void> _setQuickEntry(bool value) async {
    setState(() => quickEntry = value);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(QuickEntryPanel.preferenceKey, value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text("Antwort", style: Theme.of(context).textTheme.titleSmall),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AnswerMethodSelector(
            method: method,
            onChanged: (m) {
              setState(() => method = m);
              AnswerMethodPreference.save(
                AnswerMethodPreference.pericopeQuiz,
                m,
              );
            },
          ),
        ),
        SwitchListTile(
          key: const ValueKey("book-settings-quick-entry"),
          contentPadding: EdgeInsets.zero,
          title: const Text("Schnelleingabe öffnen"),
          subtitle: const Text("Stelle durch Antippen statt Tippen eingeben"),
          value: quickEntry,
          onChanged: _setQuickEntry,
        ),
        if (widget.controller case final controller?)
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                SwitchListTile(
                  key: const ValueKey("book-settings-knowledge"),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Wissensfragen einbeziehen"),
                  subtitle: const Text(
                    "Inhaltliche Fragen zu Personen, Ereignissen und "
                    "Begriffen in Lerneinheiten und Wiederholungen. "
                    "Ausschalten löscht keinen Fortschritt.",
                  ),
                  value: controller.state.knowledgeEnabled,
                  onChanged: controller.setKnowledgeEnabled,
                ),
                SwitchListTile(
                  key: const ValueKey("book-settings-pericopes"),
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Perikopen und Gliederung einbeziehen"),
                  subtitle: const Text(
                    "Stellen der Perikopen und die Grobgliederung der "
                    "Bücher. Mindestens eine der beiden Lernarten bleibt "
                    "an.",
                  ),
                  value: controller.state.pericopesEnabled,
                  onChanged: controller.setPericopesEnabled,
                ),
              ],
            ),
          ),
        const SoundSettingsSection(module: SoundModule.pericopeQuiz),
        const SizedBox(height: 8),
        Text(
          "Lernstände zurücksetzen: im Tab „Allgemein“ unter "
          "„Einzelnen Lernbereich zurücksetzen“ → Perikopenkenntnisse.",
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const Text("Wie entsteht der Status?"),
            onPressed: () => showStatusRulesDialog(context),
          ),
        ),
      ],
    );
  }
}
