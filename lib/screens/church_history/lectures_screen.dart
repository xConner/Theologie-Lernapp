import 'package:flutter/material.dart';

import '../../models/church_history/church_history.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../theme/app_theme.dart';
import 'church_history_quiz_screen.dart';
import 'church_history_widgets.dart';
import 'lecture_detail_screen.dart';
import 'themes_screen.dart';

/// Die Veranstaltungen: Vorlesung mit Folien und Gliederung, Proseminar mit
/// Sitzungen, Prüfungshinweisen, Literatur und Material. Gibt es nur eine
/// Veranstaltung, entfallen die Tabs.
class LecturesScreen extends StatelessWidget {
  final ChurchHistoryData data;

  /// Tab beim Öffnen.
  final CourseKind initialKind;

  const LecturesScreen({
    super.key,
    required this.data,
    this.initialKind = CourseKind.lecture,
  });

  void _open(BuildContext context, String lectureId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LectureDetailScreen(data: data, lectureId: lectureId),
      ),
    );
  }

  void _learn(BuildContext context, LearningScope scope) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChurchHistoryQuizScreen(
          data: data,
          mode: QuizMode.knowledge,
          scope: scope,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = data.courses;

    if (courses.length == 1) {
      return ChurchHistoryPage(
        title: "Vorlesungen",
        children: _course(context, courses.single),
      );
    }

    final initial = courses.indexWhere((c) => c.kind == initialKind);

    return DefaultTabController(
      length: courses.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Veranstaltungen"),
          bottom: TabBar(
            tabs: [
              for (final c in courses)
                Tab(key: ValueKey("course-tab-${c.id}"), text: c.kind.label),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              for (final c in courses)
                ChurchHistoryBody(children: _course(context, c)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _course(BuildContext context, Course course) =>
      course.kind == CourseKind.lecture
      ? _lecture(context, course)
      : _seminar(context, course);

  Widget _header(BuildContext context, Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(course.title, style: Theme.of(context).textTheme.titleLarge),
        Text(
          course.subtitle,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ],
    );
  }

  List<Widget> _lecture(BuildContext context, Course course) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = TextStyle(color: context.colors.textSecondary);
    final lectures = data.unitsOfCourse(course.id);

    return [
      _header(context, course),

      const SectionTitle("Vorlesungen mit Folien"),
      if (lectures.isEmpty)
        const EmptyHint("Noch keine Vorlesungsfolien hinterlegt."),
      for (final l in lectures)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: ValueKey("lecture-${l.id}"),
            leading: CircleAvatar(child: Text("${l.number}")),
            title: Text(l.title),
            subtitle: Text(
              "${l.slides.length} Folien · ${l.entryIds.length} Einträge · "
              "${l.questions.length + l.lists.length} Lernaufgaben",
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _open(context, l.id),
          ),
        ),
      if (lectures.length > 1) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey("learn-all-lectures"),
          icon: const Icon(Icons.replay_rounded),
          label: const Text("Alle bisherigen Vorlesungen wiederholen"),
          onPressed: () => _learn(context, LearningScope.allLectures),
        ),
      ],

      const SectionTitle("Gliederung der Vorlesung"),
      Text(
        "Nach den Folien 6 und 7. Themen mit Folien lassen sich öffnen; "
        "für die übrigen sind noch keine Folien hinterlegt.",
        style: secondary,
      ),
      for (final part in course.outline) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(
            "${part.part}. ${part.title}",
            style: textTheme.titleMedium,
          ),
        ),
        for (final topic in part.topics) _topic(context, topic),
      ],
    ];
  }

  Widget _topic(BuildContext context, OutlineTopic topic) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final lectureId = topic.lectureId;
    final theme = topic.themeId == null ? null : data.theme(topic.themeId!);

    return ListTile(
      key: ValueKey("topic-${topic.number}-${topic.title}"),
      dense: true,
      leading: Text(
        "${topic.number}.",
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: lectureId == null ? context.colors.textSecondary : null,
        ),
      ),
      title: Text(topic.title, style: lectureId == null ? secondary : null),
      subtitle: Text(
        [
          lectureId == null
              ? "noch keine Folien"
              : data.lecture(lectureId)!.label,
          if (theme != null) "Verwandter Stoff im Thema „${theme.title}“",
        ].join(" · "),
      ),
      trailing: lectureId == null && theme == null
          ? null
          : const Icon(Icons.chevron_right_rounded),
      onTap: lectureId != null
          ? () => _open(context, lectureId)
          : theme == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ThemeDetailScreen(data: data, themeId: theme.id),
              ),
            ),
    );
  }

  List<Widget> _seminar(BuildContext context, Course course) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final sessions = data.unitsOfCourse(course.id);

    return [
      _header(context, course),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey("learn-seminar"),
        icon: const Icon(Icons.quiz_rounded),
        label: const Text("Proseminarstoff lernen"),
        onPressed: () => _learn(context, LearningScope.seminar),
      ),

      const SectionTitle("Sitzungen"),
      Text(
        "Nach dem Seminarplan. Fragen und Merklisten gibt es zu den Sitzungen, "
        "deren Stoff im Material greifbar ist.",
        style: secondary,
      ),
      for (final s in sessions)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: ValueKey("lecture-${s.id}"),
            leading: CircleAvatar(child: Text("${s.number}")),
            title: Text(s.title),
            subtitle: Text(
              [
                ?s.date,
                if (s.entryIds.isNotEmpty) "${s.entryIds.length} Einträge",
                if (s.questions.isNotEmpty || s.lists.isNotEmpty)
                  "${s.questions.length + s.lists.length} Lernaufgaben",
              ].join(" · "),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _open(context, s.id),
          ),
        ),

      if (course.sections.isNotEmpty) ...[
        const SectionTitle("Prüfung, Formalia und Literatur"),
        for (final section in course.sections)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ExpansionTile(
              key: ValueKey("course-section-${section.title}"),
              title: Text(section.title),
              subtitle: section.ref == null
                  ? null
                  : Text(data.materialLabel(section.ref!) ?? ""),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final point in section.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• $point"),
                  ),
                if (section.supplement != null)
                  SupplementBox(
                    section.supplement!,
                    label: SupplementBox.labelFor(course.kind),
                  ),
              ],
            ),
          ),
      ],

      if (course.materials.isNotEmpty) ...[
        const SectionTitle("Material"),
        Text(
          "Die Dokumente selbst liegen nicht in der App. Fundstellen wie "
          "„Schwartz 1939, S. 7“ beziehen sich auf diese Liste.",
          style: secondary,
        ),
        for (final m in course.materials)
          ListTile(
            key: ValueKey("material-${m.id}"),
            leading: const Icon(Icons.description_outlined),
            title: Text(m.title),
            subtitle: Text("${m.category} · ${m.description}"),
          ),
      ],
    ];
  }
}
