import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/old_testament/old_testament.dart';
import '../../services/old_testament/old_testament_store.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/info_report.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/streak_widgets.dart';
import 'glossary_screen.dart';
import 'old_testament_progress_screen.dart';
import 'old_testament_quiz_screen.dart';
import 'old_testament_widgets.dart';
import 'unit_detail_screen.dart';

/// Lernbereich „Altes Testament“: Lernmodus, Fortschritt und die
/// Vorlesungseinheiten direkt auf der Startseite des Bereichs. Weitere
/// Zugänge (Fachbegriffe) erscheinen erst, wenn es Inhalte dafür gibt.
///
/// Mit [course] = [OtCourseId.bibelkunde] dieselbe Seite für die
/// „Grundlagen der Bibelkunde“ im Bereich Bibelkunde: Sitzungen der Übung
/// statt Vorlesungseinheiten, gemeinsamer Lernstand.
class OldTestamentHomeScreen extends StatelessWidget {
  final OtCourseId course;

  /// Nur für Tests: Daten und Speicher ohne Assets bzw. Anmeldung.
  final OldTestamentData? data;
  final OldTestamentStore? store;
  final String? uid;

  const OldTestamentHomeScreen({
    super.key,
    this.course = OtCourseId.lecture,
    this.data,
    this.store,
    this.uid,
  });

  static String titleOf(OtCourseId course) => switch (course) {
    OtCourseId.lecture => "Altes Testament",
    OtCourseId.bibelkunde => "Grundlagen der Bibelkunde",
  };

  @override
  Widget build(BuildContext context) {
    return OldTestamentDataBuilder(
      title: titleOf(course),
      course: course,
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
  final OldTestamentData data;
  final OldTestamentStore? store;
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
    final learnable = data.units.any((u) => u.hasLearningContent);
    final lecture = data.courseId == OtCourseId.lecture;

    return Scaffold(
      appBar: AppBar(
        title: Text(OldTestamentHomeScreen.titleOf(data.courseId)),
        actions: const [SettingsButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 32,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  data.course.subtitle,
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
                const SizedBox(height: 16),

                StreakDetailCard(uid: uid, track: StreakTrack.oldTestament),
                const SizedBox(height: 20),

                if (learnable) ...[
                  _button(
                    context,
                    key: "old-testament-learn",
                    icon: Icons.quiz_rounded,
                    label: "Lernmodus",
                    screen: () =>
                        OldTestamentQuizScreen(data: data, store: store),
                  ),
                  _button(
                    context,
                    key: "old-testament-progress",
                    icon: Icons.insights_rounded,
                    label: "Fortschritt",
                    screen: () =>
                        OldTestamentProgressScreen(data: data, store: store),
                  ),
                ],
                if (data.terms.isNotEmpty)
                  _button(
                    context,
                    key: "old-testament-glossary",
                    icon: Icons.label_outline_rounded,
                    label: "Fachbegriffe",
                    screen: () => GlossaryScreen(data: data),
                  ),

                ContentSectionTitle(
                  lecture ? "Vorlesungseinheiten" : "Sitzungen der Übung",
                ),
                if (data.units.isEmpty)
                  EmptyHint(
                    lecture
                        ? "Noch keine Vorlesungseinheit hinterlegt. Neue "
                              "Einheiten entstehen aus hochgeladenen "
                              "Vorlesungsfolien."
                        : "Noch keine Sitzung hinterlegt. Neue Sitzungen "
                              "entstehen aus hochgeladenen Folien der Übung.",
                  ),
                for (final u in data.units)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      key: ValueKey("unit-${u.id}"),
                      leading: CircleAvatar(child: Text("${u.number}")),
                      title: Text(u.title),
                      subtitle: Text(
                        [
                          ?u.scope,
                          if (u.slides.isNotEmpty) "${u.slides.length} Folien",
                        ].join(" · "),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _push(
                        context,
                        UnitDetailScreen(
                          data: data,
                          unitId: u.id,
                          store: store,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Text(
                  lecture
                      ? "Inhalte geben die Vorlesungsfolien wieder; "
                            "Erklärungen der App sind als „Ergänzung“ "
                            "gekennzeichnet."
                      : "Inhalte geben die Folien der Übung wieder; "
                            "Erklärungen der App sind als „Ergänzung“ "
                            "gekennzeichnet. Was die Vorlesung „Einführung in "
                            "das Alte Testament“ ebenso behandelt, steht nur "
                            "einmal in der App und hat einen gemeinsamen "
                            "Lernstand.",
                  textAlign: TextAlign.center,
                  style: secondary.copyWith(fontSize: 12.5),
                ),
                const InfoReportFooter(module: AppModules.oldTestament),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
