import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/church_history/church_history.dart';
import 'package:theologie_lernapp/services/church_history/church_history_loader.dart';

/// Rohdaten der Assets (zum gezielten Verändern in Tests).
Map<String, Map<String, dynamic>> churchHistoryJson() => {
  for (final name in ["epochs", "themes", "entries", "lectures"])
    name:
        jsonDecode(File("assets/church_history/$name.json").readAsStringSync())
            as Map<String, dynamic>,
};

ChurchHistoryData parseChurchHistory(Map<String, Map<String, dynamic>> json) {
  return ChurchHistoryLoader.parse(
    epochs: json["epochs"]!,
    themes: json["themes"]!,
    entries: json["entries"]!,
    lectures: json["lectures"]!,
  );
}

/// Die echten Inhalte der App, wie der Loader sie liest.
ChurchHistoryData loadChurchHistory() =>
    parseChurchHistory(churchHistoryJson());
