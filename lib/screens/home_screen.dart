import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/greek/perikope_loader.dart';
import 'pericope_quiz/quiz_screen.dart';
import '../screens/liturgical_calendar_screen.dart';
import '../screens/greek/greek_home_screen.dart';

import '../models/greek/perikope.dart';
import 'hymn_screen.dart';

import 'confessions_screen.dart';

import 'latin/latin_home_screen.dart';

import 'settings_screen.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Perikope>? perikopen;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    _loadPerikopen();
  }

  Future<void> _loadPerikopen() async {
    try {
      final data = await PerikopeLoader.load();

      setState(() {
        perikopen = data;
        loading = false;
      });
    } catch (_) {
      setState(() {
        perikopen = [];
        loading = false;
      });
    }
  }

  void _openQuiz() {
    final list = perikopen;

    if (list == null || list.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keine Perikopen geladen")));

      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nicht eingeloggt")));

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(perikopen: list, uid: uid),
      ),
    );
  }

  void _openLiturgicalCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiturgicalCalendarScreen()),
    );
  }

  void _openGreek() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GreekHomeScreen()),
    );
  }

  void _openLatin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LatinHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Start"),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),

            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),

      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Willkommen",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Wähle einen Lernbereich",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openQuiz,
                          icon: const Icon(Icons.quiz_rounded),
                          label: const Text("Perikopenquiz"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openLiturgicalCalendar,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text("Liturgischer Kalender"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HymnScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.library_music_rounded),
                          label: const Text("Evangelisches Gesangbuch"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ConfessionsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text("Bekenntnisse"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openGreek,
                          icon: const Icon(Icons.translate_rounded),
                          label: const Text("Altgriechisch"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openLatin,
                          icon: const Icon(Icons.translate_rounded),
                          label: const Text("Latein"),
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
