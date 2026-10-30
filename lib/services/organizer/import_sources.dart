import 'package:flutter/foundation.dart';

import '../../models/church_history/church_history.dart';
import '../../models/organizer/organizer_items.dart';
import '../bible/bible_reading_service.dart';
import '../church_history/church_history_loader.dart';
import '../lecture_materials/lecture_materials.dart';
import 'org_dates.dart';
import 'organizer_controller.dart';
import 'seminar_import.dart';

/// Gespeicherte Angaben einer Quelle (Dokument `import` der Organisation).
class ImportSettings {
  final OrgTime? start;
  final OrgTime? end;
  final bool sessions;
  final String? areaId;

  /// Nur eingefügte Seminarpläne.
  final String? title;
  final String? text;
  final OrgDate? firstSession;
  final int intervalDays;

  const ImportSettings({
    this.start,
    this.end,
    this.sessions = true,
    this.areaId,
    this.title,
    this.text,
    this.firstSession,
    this.intervalDays = 7,
  });

  ImportSettings copyWith({
    OrgTime? start,
    OrgTime? end,
    bool clearTimes = false,
    bool? sessions,
    String? areaId,
    String? title,
    String? text,
    OrgDate? firstSession,
    bool clearFirst = false,
    int? intervalDays,
  }) => ImportSettings(
    start: clearTimes ? null : (start ?? this.start),
    end: clearTimes ? null : (end ?? this.end),
    sessions: sessions ?? this.sessions,
    areaId: areaId ?? this.areaId,
    title: title ?? this.title,
    text: text ?? this.text,
    firstSession: clearFirst ? null : (firstSession ?? this.firstSession),
    intervalDays: intervalDays ?? this.intervalDays,
  );

  Map<String, dynamic> toMap() => {
    "start": start?.key,
    "end": end?.key,
    "sessions": sessions,
    "areaId": areaId,
    "title": title,
    "text": text,
    "firstSession": firstSession?.key,
    "intervalDays": intervalDays,
  };

  static ImportSettings fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ImportSettings();
    final interval = map["intervalDays"];
    return ImportSettings(
      start: OrgTime.tryParse(map["start"]),
      end: OrgTime.tryParse(map["end"]),
      sessions: map["sessions"] != false,
      areaId: map["areaId"] is String ? map["areaId"] as String : null,
      title: map["title"] is String ? map["title"] as String : null,
      text: map["text"] is String ? map["text"] as String : null,
      firstSession: OrgDate.tryParse(map["firstSession"]),
      intervalDays: interval is num && interval >= 1 ? interval.toInt() : 7,
    );
  }
}

/// Ein übernehmbarer Seminarplan mit seinen Einstellungen.
class ImportSource {
  final String sourceId;
  final String title;
  final String subtitle;

  /// Eingefügter Text (bearbeitbar, löschbar).
  final bool isText;

  final ImportPlan Function(ImportSettings settings) build;

  const ImportSource({
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.build,
    this.isText = false,
  });
}

/// Alle Seminarpläne, die die App kennt: Proseminar und Leseplan zur Übung
/// (nur mit Freigabe der Vorlesungsunterlagen) und eingefügte Pläne.
class ImportSources {
  ImportSources._();

  static Future<List<ImportSource>> load(
    OrganizerController controller, {
    required String? uid,
    BibleReadingService? reading,
    LectureMaterials? materials,
    Future<ChurchHistoryData> Function()? churchHistory,
  }) async {
    final result = <ImportSource>[];
    final lectures = materials ?? LectureMaterials.instance;
    final today = controller.today;
    if (lectures.available) {
      try {
        final data = await (churchHistory ?? ChurchHistoryLoader.load)();
        final probe = ChurchHistorySeminarImport.plan(data, today: today);
        if (probe != null) {
          result.add(
            ImportSource(
              sourceId: probe.sourceId,
              title: probe.title,
              subtitle: probe.subtitle ?? "",
              build: (s) => ChurchHistorySeminarImport.plan(
                data,
                today: today,
                start: s.start,
                end: s.end,
                sessions: s.sessions,
              )!,
            ),
          );
        }
      } catch (e) {
        debugPrint("Proseminar nicht ladbar: $e");
      }
      try {
        final service = reading ?? BibleReadingService.instance;
        await service.load(uid);
        for (final plan in service.coursePlans) {
          result.add(
            ImportSource(
              sourceId: BibelkundeCourseImport.sourceIdOf(plan),
              title: plan.course,
              subtitle: [?plan.lecturer, ?plan.semester].join(" · "),
              build: (s) => BibelkundeCourseImport.plan(
                plan,
                start: s.start,
                end: s.end,
                sessions: s.sessions,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Lesepläne zu Lehrveranstaltungen nicht ladbar: $e");
      }
    }
    for (final data in controller.textImports) {
      final id = data["sourceId"] as String;
      final settings = ImportSettings.fromMap(data);
      result.add(textSource(id, settings, today));
    }
    return result;
  }

  static ImportSource textSource(
    String sourceId,
    ImportSettings settings,
    OrgDate today,
  ) => ImportSource(
    sourceId: sourceId,
    title: settings.title ?? "Seminarplan",
    subtitle: "Eingefügter Seminarplan",
    isText: true,
    build: (s) => ImportPlan(
      sourceId: sourceId,
      title: s.title ?? "Seminarplan",
      areaId: s.areaId ?? OrgIds.stable("area", sourceId),
      areaName: s.title ?? "Seminar",
      candidates: SeminarTextParser.parse(
        s.text ?? "",
        today: today,
        firstSession: s.firstSession,
        intervalDays: s.intervalDays,
        start: s.start,
        end: s.end,
        sessions: s.sessions,
      ),
    ),
  );

  /// Übernimmt bei Quellen mit „automatisch übernehmen“ Neues und
  /// Änderungen unberührter Einträge. Liefert die Anzahl.
  static Future<int> runAutomatic(
    OrganizerController controller,
    List<ImportSource> sources,
  ) async {
    var total = 0;
    for (final source in sources) {
      if (!controller.config.autoImports.contains(source.sourceId)) continue;
      final settings = ImportSettings.fromMap(
        controller.importSettings(source.sourceId),
      );
      final plan = source.build(settings);
      final diff = SeminarImporter.diff(
        plan,
        tasks: controller.rawTasks,
        events: controller.rawEvents,
        today: controller.today,
      );
      total += await SeminarImporter.applyAutomatic(
        controller,
        diff,
        areaId: settings.areaId,
      );
    }
    return total;
  }
}
