import 'package:flutter/material.dart';

import '../../models/greek/perikope.dart';
import '../../services/streak/streak_track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/streak_widgets.dart';
import 'books/books_overview_screen.dart';
import 'quiz_screen.dart';

/// Bereich „Bibelkunde“: Perikopenquiz (Endlos-Lernmodus) und „Bücher
/// systematisch lernen“ – beide mit denselben Perikopen und derselben Streak.
///
/// Aufbau wie die übrigen Lernbereiche (z. B. Latein): Symbol, Streak-Karte,
/// je Funktion ein Knopf.
class BibelkundeScreen extends StatelessWidget {
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
      appBar: AppBar(title: const Text("Bibelkunde")),
      body: Center(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
