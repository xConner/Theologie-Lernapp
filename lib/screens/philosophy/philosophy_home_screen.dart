import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'logic/logic_course_screen.dart';

/// Ein Lernbereich unter „Philosophie“. Weitere Module werden hier als
/// Eintrag in [PhilosophyHomeScreen.areas] ergänzt – ohne Umbau der
/// Navigation.
class PhilosophyArea {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(String? uid) builder;

  const PhilosophyArea({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

/// Bereich „Philosophie“ auf der Startseite.
class PhilosophyHomeScreen extends StatelessWidget {
  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  const PhilosophyHomeScreen({super.key, required this.uid});

  static final List<PhilosophyArea> areas = [
    PhilosophyArea(
      key: "logic-intro",
      title: "Einführung in die Logik",
      subtitle: "Aussagen- und Prädikatenlogik: Syntax, Semantik, Folgerung "
          "und formale Beweise",
      icon: Icons.account_tree_outlined,
      builder: (uid) => LogicCourseScreen(uid: uid),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Philosophie")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 32,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 20),
                for (final area in areas) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: ValueKey("philosophy-${area.key}"),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => area.builder(uid)),
                      ),
                      icon: Icon(area.icon),
                      label: Text(area.title),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    area.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
