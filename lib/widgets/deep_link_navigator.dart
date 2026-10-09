import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/account_security_screen.dart';
import '../screens/bible/bible_home_screen.dart';
import '../screens/bible/reading_plan_detail_screen.dart';
import '../screens/confessions_screen.dart';
import '../screens/greek/grammar_trainer_screen.dart';
import '../screens/greek/greek_home_screen.dart';
import '../screens/greek/vocabulary_trainer_screen.dart';
import '../screens/hymn_screen.dart';
import '../screens/latin/latin_home_screen.dart';
import '../screens/latin/latin_vocabulary_trainer_screen.dart';
import '../screens/liturgical_calendar_screen.dart';
import '../screens/memorization/memorization_home_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/pericope_quiz/quiz_screen.dart';
import '../screens/prayers_screen.dart';
import '../screens/settings_screen.dart';
import '../services/bible/bible_reading_service.dart';
import '../services/greek/perikope_loader.dart';
import '../services/notifications/app_deep_link.dart';

Widget? _signedIn(Widget screen) {
  return FirebaseAuth.instance.currentUser == null ? null : screen;
}

/// Screen je App-Pfad (null = gerade nicht verfügbar).
final Map<String, Future<Widget?> Function()> _screens = {
  AppDeepLink.perikopen: () async {
    final list = await PerikopeLoader.load();
    if (list.isEmpty) return null;
    return QuizScreen(
      perikopen: list,
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
  },
  AppDeepLink.greek: () async => const GreekHomeScreen(),
  AppDeepLink.greekVocabulary: () async => const VocabularyTrainerScreen(),
  AppDeepLink.greekGrammar: () async => const GreekGrammarTrainerScreen(),
  AppDeepLink.latin: () async => const LatinHomeScreen(),
  AppDeepLink.latinVocabulary: () async => const LatinVocabularyTrainerScreen(),
  AppDeepLink.calendar: () async => const LiturgicalCalendarScreen(),
  AppDeepLink.hymns: () async => const HymnScreen(),
  AppDeepLink.confessions: () async => const ConfessionsScreen(),
  AppDeepLink.prayers: () async => const PrayersScreen(),
  AppDeepLink.memorize: () async => const MemorizationHomeScreen(),
  AppDeepLink.bible: () async =>
      BibleHomeScreen(uid: FirebaseAuth.instance.currentUser?.uid),
  AppDeepLink.settings: () async => const SettingsScreen(),
  AppDeepLink.notificationSettings: () async =>
      _signedIn(const NotificationSettingsScreen()),
  AppDeepLink.account: () async => _signedIn(const AccountSecurityScreen()),
};

/// Der Leseplan [planId], solange er begonnen ist; sonst (beendet, gelöscht,
/// anderes Konto) die Bibel-Startseite, damit ein alter Link nie ins Leere
/// führt.
Future<Widget> _readingPlan(String planId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final service = BibleReadingService.instance;

  await service.load(uid);

  final started =
      service.plan(planId) != null && service.progressOf(uid, planId) != null;

  return started
      ? ReadingPlanDetailScreen(uid: uid, planId: planId)
      : BibleHomeScreen(uid: uid);
}

/// Öffnet [link]. Liefert false, wenn das Ziel nicht geöffnet werden konnte.
Future<bool> openDeepLink(BuildContext context, AppDeepLink link) async {
  if (link.isExternal) {
    return launchUrl(
      Uri.parse(link.path),
      mode: LaunchMode.externalApplication,
    );
  }

  final navigator = Navigator.of(context);

  if (link.path == AppDeepLink.home) {
    navigator.popUntil((route) => route.isFirst);
    return true;
  }

  Widget? screen;

  try {
    final planId = link.planId;

    screen = planId != null
        ? await _readingPlan(planId)
        : await _screens[link.path]?.call();
  } catch (_) {
    screen = null;
  }

  if (screen == null || !navigator.mounted) return false;

  final target = screen;

  navigator.push(MaterialPageRoute(builder: (_) => target));

  return true;
}
