import 'package:flutter/material.dart';

import '../../models/greek/perikope.dart';
import '../../models/old_testament/old_testament.dart';
import '../../services/lecture_materials/lecture_materials.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_access.dart';
import '../../widgets/streak_widgets.dart';
import '../bible/course_reading_plan_screen.dart';
import '../old_testament/old_testament_home_screen.dart';
import 'books/books_overview_screen.dart';
import 'quiz_screen.dart';

/// Bereich „Bibelkunde“: Perikopenquiz (Endlos-Lernmodus) und „Bücher
/// systematisch lernen“ – beide mit denselben Perikopen und derselben Streak –
/// sowie die „Grundlagen der Bibelkunde“ (Übung Bibelkunde AT: Begriffe,
/// Kanon, Text, Entstehung). Die Grundlagen nutzen Inhalte und Lernstand
/// des Bereichs Altes Testament mit (`OtCourseId.bibelkunde`). Dazu der
/// Leseplan zur Übung: die Bibeltexte jeder Sitzung bis zu ihrem Termin.
///
/// Aufbau wie die übrigen Lernbereiche (z. B. Latein): Symbol, Streak-Karte,
/// je Funktion ein Knopf.
class BibelkundeScreen extends StatelessWidget {
  /// Leseplan zur Übung Bibelkunde AT (geschützte Vorlesungsunterlagen,
  /// `reading_plans/` in `LectureMaterials`).
  static const String readingPlanId = "course-bibelkunde-at-wise-2026";

  final List<Perikope> perikopen;

  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  const BibelkundeScreen({
    super.key,
    required this.perikopen,
    required this.uid,
  });

  void _open(BuildContext context, Widget screen) {
    if (perikopen.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keine Perikopen geladen")));

      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bibelkunde"),
        // Allgemeine Einstellungen; hier ist kein Lernbereich geöffnet, das
        // Zurücksetzen ist also ohne Neuladen möglich.
        actions: const [SettingsButton()],
      ),
      body: ListenableBuilder(
        listenable: LectureMaterials.instance,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 32,
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 20),

                  StreakDetailCard(uid: uid, track: StreakTrack.perikope),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey("bibelkunde-quiz"),
                      onPressed: () => _open(
                        context,
                        QuizScreen(perikopen: perikopen, uid: uid),
                      ),
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text("Perikopenquiz"),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Endlos-Lernmodus über die ausgewählten Bücher",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey("bibelkunde-books"),
                      onPressed: () => _open(
                        context,
                        BooksOverviewScreen(perikopen: perikopen, uid: uid),
                      ),
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: const Text("Bücher systematisch lernen"),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Ein Buch abschnittsweise lernen, mit Lernplan, "
                    "Wiederholungen und Prüfung",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  // Übung Bibelkunde AT: geschützte Vorlesungsunterlagen, nur
                  // mit Freigabe; sonst ohne Hinweis nicht vorhanden.
                  if (LectureMaterials.instance.available) ...[
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey("bibelkunde-basics"),
                        // Braucht keine Perikopen.
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OldTestamentHomeScreen(
                              course: OtCourseId.bibelkunde,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.school_outlined),
                        label: const Text("Grundlagen der Bibelkunde"),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Begriffe, Kanon, Text und Entstehung nach den Folien der "
                      "Übung, mit Lernmodus",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey("bibelkunde-reading-plan"),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseReadingPlanScreen(
                              uid: uid,
                              planId: readingPlanId,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.event_available_rounded),
                        label: const Text("Leseplan zur Übung"),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Die Bibeltexte jeder Sitzung bis zum Sitzungstermin lesen",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
