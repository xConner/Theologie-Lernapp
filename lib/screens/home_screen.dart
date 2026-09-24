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
import '../services/local_learning_store.dart';
import '../services/progress_data_service.dart';
import '../widgets/learning_progress_dialogs.dart';
import '../widgets/sign_out_confirmation.dart';
import '../widgets/streak_widgets.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Perikope>? perikopen;

  bool loading = true;

  // null = Gastmodus. AuthGate baut HomeScreen bei jedem Nutzerwechsel neu auf.
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  bool get isGuest => uid == null;

  @override
  void initState() {
    super.initState();

    _loadPerikopen();

    if (!isGuest) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerGuestDataTransfer(),
      );
    }
  }

  /// Bietet nach Login/Registrierung an, lokale Gast-Lernstände ins Konto zu
  /// übernehmen – nur wenn es lokale Daten gibt und das Konto selbst noch
  /// keine Lerndaten hat (bestehende Kontodaten werden nie überschrieben).
  Future<void> _offerGuestDataTransfer() async {
    final accountUid = uid;
    if (accountUid == null) return;

    final local = LocalLearningStore.instance;
    final progressData = ProgressDataService();

    try {
      if (!await local.hasGuestData()) return;
      if (await local.isTransferDeclined(accountUid)) return;
      if (await progressData.accountHasLearningData(accountUid)) return;
    } catch (_) {
      // Im Zweifel nichts anbieten und Kontodaten unverändert lassen.
      return;
    }

    if (!mounted) return;

    final accepted = await askGuestDataTransfer(context);

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != accountUid) {
      return;
    }

    if (!accepted) {
      await local.markTransferDeclined(accountUid);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      await progressData.transferGuestData(accountUid);

      messenger.showSnackBar(
        const SnackBar(content: Text("Lernfortschritte wurden übernommen.")),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Die Lernfortschritte konnten nicht übernommen werden.",
          ),
        ),
      );
    }
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

          if (isGuest)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: "Anmelden",

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),

              onPressed: () async {
                if (!await confirmSignOut(context)) return;
                await FirebaseAuth.instance.signOut();
              },
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

                      if (isGuest) ...[
                        const SizedBox(height: 8),

                        Text(
                          "Gastmodus: Deine Lernstände werden nur lokal in "
                          "diesem Browser gespeichert.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],

                      const SizedBox(height: 28),

                      StreakSummary(uid: uid),

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
