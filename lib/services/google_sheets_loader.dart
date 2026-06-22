import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/perikope.dart';
import '../models/occurrence.dart';

Future<List<Perikope>> loadPerikopen() async {
  const url =
      "https://script.google.com/macros/s/AKfycbzrN4tij_Yfg36Y85sMR1VrVNh1bv_D6Sd2QX1uQmPjTcWXrg6_fFWipolJTk9hwZCW/exec";

  final res = await http.get(Uri.parse(url));

  if (res.statusCode != 200) {
    throw Exception("Fehler beim Laden der Tabelle");
  }

  final data = jsonDecode(res.body);

  final Map<String, List<Occurrence>> grouped = {};
  final Map<String, String> titles = {};

  for (final row in data) {
    final id = row['id'].toString();
    final title = row['title'].toString();

    titles[id] = title;

    grouped.putIfAbsent(id, () => []);

    grouped[id]!.add(
      Occurrence(
        book: row['book'],
        ref: row['ref'],
        precision: row['precision'],
        required: row['required'].toString().trim().toLowerCase() == "true",
      ),
    );
  }

  return grouped.entries.map((e) {
    return Perikope(
      id: e.key,
      title: titles[e.key] ?? "",
      occurrences: e.value,
    );
  }).toList();
}

/// interne Builder-Klasse (nur Loader)
class PerikopeBuilder {
  final String id;
  final String title;
  final List<Occurrence> occurrences = [];

  PerikopeBuilder({required this.id, required this.title});

  Perikope build() {
    return Perikope(id: id, title: title, occurrences: occurrences);
  }
}
