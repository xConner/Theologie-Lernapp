import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft das Noten-Inventar (docs/hymn-scores) gegen den Liedbestand.
///
/// Das Inventar ist die Grundlage für eine spätere Notenintegration; die
/// Tests halten fest, dass es vollständig bleibt und kein Lied als frei
/// nutzbar führt, dessen Melodie oder Datei das nicht hergibt.
void main() {
  final hymns =
      jsonDecode(File("assets/eg_lieder.json").readAsStringSync())
          as List<dynamic>;
  final inventory =
      jsonDecode(
            File("docs/hymn-scores/eg_noten_inventar.json").readAsStringSync(),
          )
          as List<dynamic>;
  final snapshot =
      jsonDecode(
            File("docs/hymn-scores/quellen_snapshot.json").readAsStringSync(),
          )
          as Map<String, dynamic>;
  final commonsFiles =
      (snapshot["commons"] as Map<String, dynamic>)["files"]
          as Map<String, dynamic>;

  const statuses = {"gemeinfrei", "geschuetzt", "ungeklaert"};
  const freeFileLicenses = {"CC0", "Public domain"};

  test("Inventar enthält genau die Lieder des Bestands", () {
    expect(inventory.length, hymns.length);
    for (var i = 0; i < hymns.length; i++) {
      expect(inventory[i]["eg_nummer"], hymns[i]["id"]);
      expect(inventory[i]["titel"], hymns[i]["title"]);
      expect(inventory[i]["text_angabe"], hymns[i]["text"]);
      expect(inventory[i]["melodie_angabe"], hymns[i]["melody"]);
    }
  });

  test("Statusangaben sind gültig und begründet", () {
    for (final row in inventory) {
      final reason = "EG ${row["eg_nummer"]}";
      expect(statuses, contains(row["text_status"]), reason: reason);
      expect(statuses, contains(row["melodie_status"]), reason: reason);
      expect(row["melodie_begruendung"], isNotEmpty, reason: reason);
      expect(row["kategorie"], inInclusiveRange(1, 6), reason: reason);
      expect(row["nutzbarkeit"], isNotEmpty, reason: reason);
      expect(row["empfehlung"], isNotEmpty, reason: reason);
    }
  });

  test("Commons-Dateien stehen mit Prüfsumme im Quellen-Schnappschuss", () {
    for (final row in inventory) {
      for (final file in row["commons_dateien"] as List<dynamic>) {
        final source = commonsFiles[file["datei"]];
        expect(source, isNotNull, reason: "${file["datei"]}");
        expect(file["sha1"], source["sha1"]);
        expect(file["lizenz"], source["license"]);
      }
    }
  });

  test("frei integrierbar nur bei gemeinfreier Melodie und freier Datei", () {
    for (final row in inventory) {
      if (row["nutzbarkeit"] != "frei integrierbar") continue;
      final reason = "EG ${row["eg_nummer"]}";
      expect(row["melodie_status"], "gemeinfrei", reason: reason);
      final files = row["commons_dateien"] as List<dynamic>;
      expect(files, isNotEmpty, reason: reason);
      for (final file in files) {
        expect(freeFileLicenses, contains(file["lizenz"]), reason: reason);
      }
    }
  });

  // Der Projektinhaber hat die recherchierten Vorlagen freigegeben; auch
  // Lieder, deren Melodie die Recherche als geschützt oder ungeklärt führt,
  // dürfen Noten haben (aufgelistet in docs/hymn-scores/integration.md).
  // Fest bleibt: Jede Note stammt aus einer Vorlage, die das Inventar genau
  // diesem Lied zuordnet.
  test("Noten in den Lieddaten stammen nur aus Vorlagen des Inventars", () {
    for (var i = 0; i < hymns.length; i++) {
      final scores = hymns[i]["scores"] as List<dynamic>? ?? const [];
      if (scores.isEmpty) continue;

      final row = inventory[i];
      final reason = "EG ${row["eg_nummer"]}";

      final files = {
        for (final file in row["commons_dateien"] as List<dynamic>)
          file["datei"]: file,
      };
      for (final score in scores) {
        final source = score["source"] as Map<String, dynamic>;
        // Notensätze aus Wikipedia-Liedartikeln stehen nicht im Inventar
        // der Commons-Dateien; ihre Fassung ist über die Versionsnummer in
        // der Adresse festgehalten.
        if ((source["name"] as String).startsWith("Wikipedia")) {
          expect(source["url"], contains("oldid="), reason: reason);
          expect(source["license"], "CC BY-SA 4.0", reason: reason);
          continue;
        }
        final file = files[source["file"]];
        // Datei, Prüfsumme und Lizenz wie in der Recherche festgehalten.
        expect(file, isNotNull, reason: reason);
        expect(source["sha1"], file["sha1"], reason: reason);
        expect(source["license"], file["lizenz"], reason: reason);
        expect(source["match"], file["zuordnung"], reason: reason);
      }
    }
  });

  test("geschützte oder ungeklärte Melodien sind nie als nutzbar geführt", () {
    for (final row in inventory) {
      if (row["melodie_status"] == "gemeinfrei") continue;
      expect(
        row["nutzbarkeit"],
        anyOf(startsWith("nicht ohne Lizenz"), "ungeklärt"),
        reason: "EG ${row["eg_nummer"]}",
      );
    }
  });
}
