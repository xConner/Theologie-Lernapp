import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/logic/lesson_text.dart';
import '../../models/logic/logic_course.dart';
import '../../models/logic/logic_exercise.dart';

/// Lädt den Lernbereich „Einführung in die Logik“ aus `assets/logic/`.
class LogicCourseLoader {
  LogicCourseLoader._();

  static const String basePath = "assets/logic";

  static Future<LogicCourse>? _cache;

  static Future<LogicCourse> load({AssetBundle? bundle}) {
    if (bundle != null) return _load(bundle);
    return _cache ??= _load(rootBundle).catchError((Object e) {
      _cache = null;
      throw e;
    });
  }

  static Future<LogicCourse> _load(AssetBundle bundle) async {
    final json =
        jsonDecode(await bundle.loadString("$basePath/course.json"))
            as Map<String, dynamic>;

    Future<List<LessonSection>> text(String file, String prefix) async =>
        LessonTextParser.parse(
          await bundle.loadString("$basePath/lessons/$file"),
          idPrefix: prefix,
        );

    final lessons = <LogicLesson>[];

    for (final raw in json["lessons"] as List) {
      final l = raw as Map<String, dynamic>;
      final id = l["id"] as String;

      lessons.add(
        LogicLesson(
          id: id,
          number: l["number"] as int,
          title: l["title"] as String,
          chapter: l["chapter"] as String,
          goals: List<String>.from(l["goals"] as List),
          prerequisites: List<String>.from(l["prerequisites"] as List),
          pitfalls: List<String>.from(l["pitfalls"] as List),
          proofSystem: l["proofSystem"] as String?,
          generators: List<String>.from(l["generators"] as List),
          literature: List<String>.from((l["literature"] as List?) ?? const []),
          sections: await text(l["file"] as String, "$id.s"),
          exercises: [
            for (final e in l["exercises"] as List)
              LogicExercise.fromJson(e as Map<String, dynamic>),
          ],
        ),
      );
    }

    LogicMockExam? exam;
    final rawExam = json["exam"] as Map<String, dynamic>?;
    if (rawExam != null) {
      exam = LogicMockExam(
        title: rawExam["title"] as String,
        instructions: await text(rawExam["file"] as String, "exam.s"),
        proofSystem: rawExam["proofSystem"] as String,
        choose: rawExam["choose"] as int,
        minutes: rawExam["minutes"] as int,
        tasks: [
          for (final e in rawExam["tasks"] as List)
            LogicExercise.fromJson(e as Map<String, dynamic>),
        ],
      );
    }

    return LogicCourse(
      id: json["id"] as String,
      title: json["title"] as String,
      description: json["description"] as String,
      introduction: await text(json["intro"] as String, "intro.s"),
      lessons: lessons,
      exam: exam,
    );
  }
}
