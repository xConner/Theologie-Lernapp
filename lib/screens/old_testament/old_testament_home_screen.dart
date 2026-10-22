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
class OldTestamentHomeScreen extends StatelessWidget {
  /// Nur für Tests: Daten und Speicher ohne Assets bzw. Anmeldung.
  final OldTestamentData? data;
  final OldTestamentStore? store;
  final String? uid;

  const OldTestamentHomeScreen({super.key, this.data, this.store, this.uid});

  @override
  Widget build(BuildContext context) {
    return OldTestamentDataBuilder(
      title: "Altes Testament",
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Altes Testament"),
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

                const ContentSectionTitle("Vorlesungseinheiten"),
                if (data.units.isEmpty)
                  const EmptyHint(
                    "Noch keine Vorlesungseinheit hinterlegt. Neue Einheiten "
                    "entstehen aus hochgeladenen Vorlesungsfolien.",
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
                  "Inhalte geben die Vorlesungsfolien wieder; Erklärungen "
                  "der App sind als „Ergänzung“ gekennzeichnet.",
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
