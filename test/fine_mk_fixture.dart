import 'dart:convert';
import 'dart:io';

import 'package:theologie_lernapp/models/greek/perikope.dart';

/// Die Perikopenliste mit der feinen Markus-Gliederung bis 31.10.2026
/// (`test/fixtures/perikopen_mk_fein.json`, 96 Perikopen) statt der
/// gröberen seit 1.11.2026.
///
/// Für Tests der Lernlogik, die viele kleine Perikopen eines Buchs und
/// mehrfach vorkommende IDs brauchen. Die Daten selbst prüfen
/// `perikopen_data_test` und `perikopen_optional_merge_test`.
List<Perikope> withFineMarkus(List<Perikope> list) {
  final fine = [
    for (final e
        in jsonDecode(
              File("test/fixtures/perikopen_mk_fein.json").readAsStringSync(),
            )
            as List)
      Perikope.fromJson(Map<String, dynamic>.from(e)),
  ];
  final at = list.indexWhere((p) => p.book == "Mk");
  return [
    ...list.take(at),
    ...fine,
    ...list.skip(at).where((p) => p.book != "Mk"),
  ];
}
