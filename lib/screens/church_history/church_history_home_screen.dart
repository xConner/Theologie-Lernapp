import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../services/church_history/church_history_store.dart';
import '../../services/lecture_materials/lecture_materials.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/streak_widgets.dart';
import 'church_history_progress_screen.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'entries_screen.dart';
import 'epochs_screen.dart';
import 'lectures_screen.dart';
import 'search_screen.dart';
import 'themes_screen.dart';

/// Lernbereich „Kirchengeschichte“: zwei Lernmodi, darunter die Zugänge
/// zum Stoff (Veranstaltungen, Epochen, Nachschlagen, Themen) und die
/// Suche.
class ChurchHistoryHomeScreen extends StatelessWidget {
  /// Nur für Tests: Daten und Speicher ohne Assets bzw. Anmeldung.
  final ChurchHistoryData? data;
  final ChurchHistoryStore? store;

  /// Mit eingesetztem [store] gilt dieser Nutzer (Tests ohne Firebase),
  /// sonst der angemeldete.
  final String? uid;

  const ChurchHistoryHomeScreen({super.key, this.data, this.store, this.uid});

  @override
  Widget build(BuildContext context) {
    return ChurchHistoryDataBuilder(
      title: "Kirchengeschichte",
      data: data,
      builder: (context, data) => _Home(
        data: data,
        store: store,
        uid: store == null ? FirebaseAuth.instance.currentUser?.uid : uid,
      ),
    );
  }
}

class _Home extends StatelessWidget {
  final ChurchHistoryData data;
  final ChurchHistoryStore? store;
  final String? uid;

  const _Home({required this.data, this.store, this.uid});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _button(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String label,
    required Widget Function() screen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: ValueKey(key),
          onPressed: () => _push(context, screen()),
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kirchengeschichte"),
        actions: [
          IconButton(
            key: const ValueKey("church-history-open-search"),
            icon: const Icon(Icons.search_rounded),
            tooltip: "Suche",
            onPressed: () =>
                _push(context, ChurchHistorySearchScreen(data: data)),
          ),
          const SettingsButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  size: 32,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    for (final c in data.courses)
                      c.kind == CourseKind.lecture && c.lecturer != null
                          ? "${c.title} (${c.lecturer})"
                          : "${c.kind.label}: ${c.title}",
                  ].join("\n"),
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
                const SizedBox(height: 16),

                StreakDetailCard(uid: uid, track: StreakTrack.churchHistory),
                const SizedBox(height: 20),

                _button(
                  context,
                  key: "church-history-quiz",
                  icon: Icons.quiz_rounded,
                  label: "Wissensquiz",
                  screen: () => ChurchHistoryQuizScreen(
                    data: data,
                    mode: QuizMode.knowledge,
                    store: store,
                  ),
                ),
                _button(
                  context,
                  key: "church-history-chronology",
                  icon: Icons.swap_vert_rounded,
                  label: "Chronologietrainer",
                  screen: () => ChurchHistoryQuizScreen(
                    data: data,
                    mode: QuizMode.chronology,
                    store: store,
                  ),
                ),

                const SizedBox(height: 8),

                _button(
                  context,
                  key: "church-history-lectures",
                  icon: Icons.school_outlined,
                  label: data.seminar == null
                      ? "Vorlesungen und Folien"
                      : "Vorlesung und Proseminar",
                  screen: () => LecturesScreen(data: data),
                ),
                _button(
                  context,
                  key: "church-history-epochs",
                  icon: Icons.timeline_rounded,
                  label: "Epochen und Zeitleiste",
                  screen: () => EpochsScreen(data: data),
                ),
                _button(
                  context,
                  key: "church-history-entries",
                  icon: Icons.menu_book_rounded,
                  label: "Personen, Ereignisse, Begriffe",
                  screen: () => EntriesScreen(data: data),
                ),
                _button(
                  context,
                  key: "church-history-themes",
                  icon: Icons.hub_outlined,
                  label: "Themen",
                  screen: () => ThemesScreen(data: data),
                ),
                _button(
                  context,
                  key: "church-history-progress",
                  icon: Icons.insights_rounded,
                  label: "Fortschritt",
                  screen: () =>
                      ChurchHistoryProgressScreen(data: data, store: store),
                ),

                const SizedBox(height: 4),
                Text(
                  data.seminar == null
                      ? "Inhalte der Vorlesungen sind mit „VL“ gekennzeichnet, "
                            "Ergänzungen der App als „Ergänzung“."
                      : "Jeder Eintrag zeigt, ob er aus der Vorlesung, dem "
                            "Proseminar oder beiden stammt; Ergänzungen der App "
                            "heißen „Ergänzung“.",
                  textAlign: TextAlign.center,
                  style: secondary.copyWith(fontSize: 12.5),
                ),
                InfoReportFooter(
                  module: LectureMaterials.instance.moduleInfo(
                    AppModules.churchHistory,
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
