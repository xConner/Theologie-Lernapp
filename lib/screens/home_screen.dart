import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/greek/perikope_loader.dart';
import 'pericope_quiz/bibelkunde_screen.dart';
import '../screens/liturgical_calendar_screen.dart';
import '../screens/greek/greek_home_screen.dart';

import '../models/greek/perikope.dart';
import 'hymnals_screen.dart';
import 'bible/bible_home_screen.dart';
import 'apocrypha/apocrypha_home_screen.dart';

import 'confessions_screen.dart';
import 'fathers/fathers_home_screen.dart';
import 'prayers_screen.dart';
import 'memorization/memorization_home_screen.dart';

import 'church_history/church_history_home_screen.dart';
import 'old_testament/old_testament_home_screen.dart';
import 'latin/latin_home_screen.dart';
import 'philosophy/philosophy_home_screen.dart';
import 'study/study_organization_screen.dart';

import 'settings_screen.dart';

import '../theme/app_theme.dart';
import '../services/lecture_materials/lecture_materials.dart';
import '../services/local_learning_store.dart';
import '../services/notifications/app_deep_link.dart';
import '../services/notifications/notification_service.dart';
import '../services/notifications/push_service.dart';
import '../services/organizer/organizer_store.dart';
import '../services/progress_data_service.dart';
import '../services/streak/streak_track.dart';
import '../services/timetable/timetable_migration.dart';
import '../widgets/deep_link_navigator.dart';
import '../widgets/learning_progress_dialogs.dart';
import '../widgets/notification_bell.dart';
import '../widgets/site_footer.dart';
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

  StreamSubscription<String>? _pushLinks;

  @override
  void initState() {
    super.initState();

    _loadPerikopen();

    // Bereiche aus geschützten Vorlesungsunterlagen erscheinen erst, wenn
    // der Server die Freigabe bestätigt hat.
    LectureMaterials.instance.addListener(_lectureMaterialsChanged);

    // Glocke für den aktuellen Nutzer (bzw. Gast) beobachten.
    NotificationService.instance.attach(uid);

    // Angetippte Push-Benachrichtigungen: bei laufender App und beim Start.
    final push = PushService.instance;

    _pushLinks = push.links.listen(_openPushLink);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final link = push.takeLaunchLink();

      if (link != null) _openPushLink(link);
    });

    final accountUid = uid;

    if (accountUid != null) {
      push.sync(accountUid);

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerGuestDataTransfer(),
      );

      _migrateGuestTimetable(accountUid);
      _migrateGuestOrganizer(accountUid);
    }
  }

  /// Übernimmt einen lokal gespeicherten Gast-Stundenplan ins Konto
  /// (ohne Duplikate, ohne vorhandene Einträge zu verändern; lokal erst nach
  /// Bestätigung gelöscht). Scheitert es, bleibt alles lokal und der nächste
  /// Start versucht es erneut.
  Future<void> _migrateGuestTimetable(String accountUid) async {
    try {
      final result = await TimetableGuestMigration.forUser(
        accountUid,
      ).runOnce(accountUid);

      if (!mounted || result.copied == 0) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.copied == 1
                ? "1 Veranstaltung aus dem Gast-Stundenplan übernommen."
                : "${result.copied} Veranstaltungen aus dem Gast-Stundenplan "
                      "übernommen.",
          ),
        ),
      );
    } catch (_) {
      // Lokale Daten bleiben erhalten; erneuter Versuch beim nächsten Start.
    }
  }

  /// Übernimmt Aufgaben, Termine und Notizen aus dem Gastmodus ins Konto
  /// (vorhandene Einträge bleiben unverändert).
  Future<void> _migrateGuestOrganizer(String accountUid) async {
    try {
      final copied = await OrganizerGuestMigration.forUser(accountUid).run();
      if (!mounted || copied == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copied == 1
                ? "1 Eintrag der Studiumsorganisation aus dem Gastmodus "
                      "übernommen."
                : "$copied Einträge der Studiumsorganisation aus dem "
                      "Gastmodus übernommen.",
          ),
        ),
      );
    } catch (_) {
      // Lokale Daten bleiben erhalten; erneuter Versuch beim nächsten Start.
    }
  }

  void _lectureMaterialsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pushLinks?.cancel();
    LectureMaterials.instance.removeListener(_lectureMaterialsChanged);

    super.dispose();
  }

  /// Öffnet den Bereich, auf den eine Push-Benachrichtigung verweist.
  /// Unbekannte Links führen nirgendwohin; die App bleibt, wo sie ist.
  void _openPushLink(String raw) {
    final link = AppDeepLink.parse(raw);

    if (!mounted || link == null || link.isExternal) return;

    openDeepLink(context, link);
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

      if (!mounted) return;

      setState(() {
        perikopen = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        perikopen = [];
        loading = false;
      });
    }
  }

  /// Bereich „Bibelkunde“: Perikopenquiz und „Bücher systematisch lernen“.
  void _openBibelkunde() {
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
        builder: (_) => BibelkundeScreen(perikopen: list, uid: uid),
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
          const NotificationBellButton(),

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
                await PushService.instance.signOut(uid);
                await FirebaseAuth.instance.signOut();
              },
            ),
        ],
      ),

      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : SiteFooterScrollView(
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
                      Image.asset(
                        "assets/images/lutherrose.png",
                        height: 96,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: "Lutherrose",
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
                          color: context.colors.textSecondary,
                        ),
                      ),

                      if (isGuest) ...[
                        const SizedBox(height: 8),

                        Text(
                          "Gastmodus: Deine Lernstände werden nur lokal in "
                          "diesem Browser gespeichert.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],

                      const SizedBox(height: 28),

                      StreakSummary(
                        uid: uid,
                        tracks: [
                          for (final track in StreakTrack.all)
                            if (LectureMaterials.instance.showsArea(track.id))
                              track,
                        ],
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const ValueKey("open-bibelkunde"),
                          onPressed: _openBibelkunde,
                          icon: const Icon(Icons.quiz_rounded),
                          label: const Text("Bibelkunde"),
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
                                builder: (_) => BibleHomeScreen(uid: uid),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_stories_rounded),
                          label: const Text("Bibel"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const ValueKey("open-apocrypha"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ApocryphaHomeScreen(uid: uid),
                              ),
                            );
                          },
                          icon: const Icon(Icons.collections_bookmark_rounded),
                          label: const Text(
                            "Apokryphen & außerkanonische Schriften",
                          ),
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
                                builder: (_) => const HymnalsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.library_music_rounded),
                          label: const Text("Gesangbücher"),
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
                          key: const ValueKey("open-fathers"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FathersHomeScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_edu_rounded),
                          label: const Text("Kirchenväter & Schriften"),
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
                                builder: (_) => const PrayersScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.volunteer_activism_rounded),
                          label: const Text("Gebete"),
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
                                builder: (_) => const MemorizationHomeScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.psychology_alt_rounded),
                          label: const Text("Texte auswendig lernen"),
                        ),
                      ),

                      // Nur mit Freigabe der Vorlesungsunterlagen; sonst
                      // ohne jeden Hinweis nicht vorhanden.
                      if (LectureMaterials.instance.available) ...[
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const ValueKey("open-church-history"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ChurchHistoryHomeScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.account_balance_rounded),
                            label: const Text("Kirchengeschichte"),
                          ),
                        ),
                      ],

                      // Nur mit Freigabe der Vorlesungsunterlagen; sonst
                      // ohne jeden Hinweis nicht vorhanden.
                      if (LectureMaterials.instance.available) ...[
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const ValueKey("open-old-testament"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const OldTestamentHomeScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.auto_stories_rounded),
                            label: const Text("Altes Testament"),
                          ),
                        ),
                      ],

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

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const ValueKey("open-philosophy"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PhilosophyHomeScreen(uid: uid),
                              ),
                            );
                          },
                          icon: const Icon(Icons.school_outlined),
                          label: const Text("Philosophie"),
                        ),
                      ),

                      const SizedBox(height: 16),

                      StudyOrganizationButton(uid: uid),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
