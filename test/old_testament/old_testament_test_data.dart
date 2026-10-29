import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/old_testament/old_testament.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_loader.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File("${OldTestamentLoader.dir}/$path").readAsStringSync())
        as Map<String, dynamic>;

/// Rohdaten der Assets (zum gezielten Verändern in Tests).
({
  Map<String, dynamic> course,
  Map<String, dynamic> terms,
  List<Map<String, dynamic>> units,
})
oldTestamentJson() {
  final course = _read("course.json");
  return (
    course: course,
    terms: _read("terms.json"),
    units: [for (final f in course["units"] as List) _read(f as String)],
  );
}

OldTestamentData parseOldTestament(
  ({
    Map<String, dynamic> course,
    Map<String, dynamic> terms,
    List<Map<String, dynamic>> units,
  })
  json,
) => OldTestamentLoader.parse(
  course: json.course,
  terms: json.terms,
  units: json.units,
);

/// Die echten Inhalte der App, wie der Loader sie liest.
OldTestamentData loadOldTestament() => parseOldTestament(oldTestamentJson());

/// Eine weitere, ausgedachte Einheit (nur für Tests der Erweiterbarkeit).
Map<String, dynamic> fakeSecondUnit() => {
  "id": "unit.09",
  "number": 9,
  "title": "Testeinheit",
  "related": ["unit.01"],
  "slides": [
    {"number": 1, "title": "Test", "text": "Tora und Testfolie"},
  ],
  "terms": [
    {
      "term": "term.tora",
      "slides": [1],
      "text": "Tora erneut",
    },
  ],
  "questions": [
    {
      "id": "q.u09.test",
      "prompt": "Testfrage?",
      "answer": "A",
      "distractors": ["B", "C"],
      "explanation": "Weil A.",
      "slides": [1],
    },
  ],
};
