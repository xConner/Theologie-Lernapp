import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/models/history/history_course.dart';
import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/services/history/history_cards.dart';
import 'package:theologie_lernapp/services/history/history_course_loader.dart';

import '../church_history/church_history_test_data.dart';
import '../old_testament/old_testament_test_data.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

HistoryCourse churchHistoryCourse() => HistoryCourseLoader.churchHistory(
  loadChurchHistory(),
  readJson(HistoryCourseLoader.churchHistoryPath),
);

HistoryCourse oldTestamentCourse(OtCourseId course) =>
    HistoryCourseLoader.oldTestament(
      loadOldTestament().forCourse(course),
      readJson(HistoryCourseLoader.oldTestamentPath),
    );

/// Speicher im Arbeitsspeicher, der Schreibvorgänge mitschreibt.
class MemoryCardStore {
  final Map<String, LearningCard> saved = {};
  final List<List<String>> writes = [];
  final List<List<String>> resets = [];

  /// Verzögert jeden Schreibvorgang (Reihenfolge prüfen).
  Duration delay = Duration.zero;
  bool fail = false;

  HistoryCardStore get store => HistoryCardStore(
    load: () async => {
      for (final c in saved.values)
        c.id: LearningCard(
          id: c.id,
          stability: c.stability,
          difficulty: c.difficulty,
          lastReviewed: c.lastReviewed,
        ),
    },
    save: (cards) async {
      final list = cards.toList();
      await Future<void>.delayed(delay);
      if (fail) throw StateError("offline");
      writes.add([for (final c in list) c.id]);
      for (final c in list) {
        saved[c.id] = c;
      }
    },
    reset: (ids) async {
      final list = ids.toList();
      resets.add(list);
      for (final id in list) {
        saved.remove(id);
      }
    },
  );
}
