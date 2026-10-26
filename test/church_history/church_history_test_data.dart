import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/church_history/church_history.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';

import '../lecture_materials_test_support.dart';

/// Rohdaten der geschützten Vorlesungsunterlagen (zum gezielten Verändern in
/// Tests; nur vorhanden, wenn [lectureMaterialsPresent]).
Map<String, Map<String, dynamic>> churchHistoryJson() => {
  for (final name in ["epochs", "themes", "entries", "lectures", "seminar"])
    name:
        jsonDecode(
              File(
                "$lectureMaterialsDir/church_history/$name.json",
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
};

ChurchHistoryData parseChurchHistory(Map<String, Map<String, dynamic>> json) {
  return ChurchHistoryLoader.parse(
    epochs: json["epochs"]!,
    themes: json["themes"]!,
    entries: json["entries"]!,
    lectures: json["lectures"]!,
    seminar: json["seminar"],
  );
}

/// Rohdaten ohne Proseminar (Stand vor dessen Aufnahme): ohne
/// `seminar.json` und ohne Fundstellen in dessen Material.
Map<String, Map<String, dynamic>> churchHistoryJsonWithoutSeminar() {
  final json = churchHistoryJson()..remove("seminar");
  for (final e in json["entries"]!["entries"] as List) {
    for (final n in (e as Map)["notes"] as List? ?? const []) {
      (n as Map).remove("ref");
    }
  }
  return json;
}

/// Die echten Inhalte der App, wie der Loader sie liest.
ChurchHistoryData loadChurchHistory() =>
    parseChurchHistory(churchHistoryJson());
