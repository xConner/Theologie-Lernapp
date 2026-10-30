import 'package:flutter/foundation.dart';

import '../bible/bible_reading_service.dart';
import '../bible/course_reading_schedule.dart';
import 'org_dates.dart';

/// Heutiges Pensum eines Leseplans zur Lehrveranstaltung als Aufgabe.
///
/// Wird nicht gespeichert, sondern bei jeder Anzeige aus dem tatsächlichen
/// Lesefortschritt berechnet: Sie gilt als erledigt, sobald alle Kapitel im
/// Leseplan (oder im Reader) als gelesen markiert sind. Umgekehrt markiert
/// sie selbst nie ein Kapitel – deshalb gibt es weder Duplikate noch
/// widersprüchliche Stände, und der Leseplan bleibt allein maßgeblich.
class ReadingTask {
  final String planId;
  final String planName;

  /// Heutiges Pensum bzw. (bei [overdue]) Offenes vergangener Sitzungen.
  final List<ScheduledPiece> pieces;
  final bool overdue;

  /// Sitzung, für die gelesen wird (z. B. „Sitzung 3: Exodus; Levitikus“).
  final String? session;

  const ReadingTask({
    required this.planId,
    required this.planName,
    required this.pieces,
    this.overdue = false,
    this.session,
  });

  String get key => "$planId:${overdue ? "overdue" : "today"}";

  bool get done => pieces.every((p) => p.done);

  int get doneCount => pieces.where((p) => p.done).length;

  /// „Gen 12, Gen 13, Gen 14“ → kompakt, höchstens vier Stücke.
  String get piecesLabel {
    final labels = [for (final p in pieces) p.label];
    if (labels.length <= 4) return labels.join(", ");
    return "${labels.take(3).join(", ")} … ${labels.last} (${labels.length} Stücke)";
  }

  String get title =>
      overdue ? "Nachholen: $piecesLabel" : "Lesen: $piecesLabel";
}

/// Liefert die Leseaufgaben eines Tages.
abstract class ReadingTaskSource implements Listenable {
  List<ReadingTask> tasks(OrgDate today);
}

/// Leseaufgaben aus den begonnenen (nicht pausierten) Leseplänen zu
/// Lehrveranstaltungen des [BibleReadingService].
class CourseReadingTaskSource extends ChangeNotifier
    implements ReadingTaskSource {
  final String? uid;
  final BibleReadingService service;

  CourseReadingTaskSource({required this.uid, BibleReadingService? service})
    : service = service ?? BibleReadingService.instance {
    this.service.addListener(notifyListeners);
  }

  /// Lädt Fortschritt und Verszahlen (einmalig; [refresh] holt Stände
  /// anderer Geräte).
  Future<void> load({bool refresh = false}) async {
    try {
      await service.load(uid, refresh: refresh);
      await service.loadCourseExtent();
    } catch (e) {
      debugPrint("Leseaufgaben nicht ladbar: $e");
    }
    notifyListeners();
  }

  @override
  void dispose() {
    service.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<ReadingTask> tasks(OrgDate today) {
    final result = <ReadingTask>[];
    for (final (plan, progress) in service.startedCoursePlans(uid)) {
      if (progress.paused) continue;
      final schedule = service.courseSchedule(uid, plan.id);
      if (schedule == null) continue;
      result.addAll(fromSchedule(plan.id, plan.name, schedule));
    }
    return result;
  }

  /// Aufgaben eines berechneten Plans (rein, für Tests).
  static List<ReadingTask> fromSchedule(
    String planId,
    String planName,
    CourseSchedule schedule,
  ) {
    final result = <ReadingTask>[];
    final overdue = schedule.overdue;
    if (overdue.isNotEmpty) {
      result.add(
        ReadingTask(
          planId: planId,
          planName: planName,
          pieces: overdue,
          overdue: true,
        ),
      );
    }
    final today = schedule.todayPieces;
    if (today.isNotEmpty) {
      final session = schedule.session(today.first.sessionId)?.session;
      result.add(
        ReadingTask(
          planId: planId,
          planName: planName,
          pieces: today,
          session: session == null
              ? null
              : "Sitzung ${session.number}: ${session.topic}",
        ),
      );
    }
    return result;
  }
}
