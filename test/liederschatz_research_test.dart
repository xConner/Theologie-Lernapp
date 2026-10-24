import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft die Recherchedaten zum Geistlichen Liederschatz (docs/liederschatz).
///
/// Die Daten gehören nicht zur App. Die Tests halten fest, dass jede Nummer
/// des Buchs genau einmal belegt ist, die Dateien zueinander passen und kein
/// Eintrag als lizenziert oder in der App nutzbar gilt.
void main() {
  List<dynamic> load(String name) =>
      jsonDecode(File("docs/liederschatz/$name").readAsStringSync())
          as List<dynamic>;

  final songs = load("lieder.json");
  final texts = load("textquellen.json");
  final scores = load("notenquellen.json");
  final rights = load("rechte.json");
  final review = load("pruefstatus.json");
  final ids = songs.map((s) => s["id"] as String).toList();

  const statuses = {
    "verified_match",
    "text_found",
    "notation_found",
    "complete_notation_found",
    "license_verified",
    "rights_review_required",
    "not_found",
  };

  test("Nummern 1 bis 1300 sind vollständig, IDs eindeutig", () {
    expect(ids.toSet().length, ids.length);
    expect(songs.map((s) => s["nummer"]).toSet(), {
      for (var n = 1; n <= 1300; n++) n,
    });
    for (final song in songs) {
      expect(
        song["id"],
        matches(RegExp(r"^gls_bg\.\d{4}[a-h]?$")),
        reason: "${song["id"]}",
      );
      expect(song["titel"], isNotEmpty, reason: "${song["id"]}");
      expect(
        song["liedseite"],
        startsWith("https://www.evangeliums.net/lieder/lied_"),
      );
    }
  });

  test("Text, Rechte und Prüfstatus decken jeden Eintrag genau einmal ab", () {
    for (final rows in [texts, rights, review]) {
      expect(rows.map((r) => r["lied"]).toList(), ids);
    }
    for (final candidate in scores) {
      expect(ids, contains(candidate["lied"]));
      expect(candidate["andere_ausgabe"], isTrue);
    }
  });

  test("Statuswerte sind gültig und belegt", () {
    final withScores = {
      for (final c in scores)
        if ((c["fundstelle"] ?? "") != "") c["lied"],
    };
    for (var i = 0; i < review.length; i++) {
      final row = review[i];
      final status = (row["status"] as List<dynamic>).toSet();
      expect(statuses.containsAll(status), isTrue, reason: "${row["lied"]}");
      expect(status, contains("rights_review_required"));
      expect(status, isNot(contains("license_verified")));
      expect(status, isNot(contains("complete_notation_found")));
      expect(
        status.contains("text_found"),
        texts[i]["text_angezeigt"],
        reason: "${row["lied"]}",
      );
      expect(
        status.contains("notation_found"),
        withScores.contains(row["lied"]),
        reason: "${row["lied"]}",
      );
    }
  });

  test("Nichts ist lizenziert oder für die App freigegeben", () {
    for (final row in rights) {
      expect(row["lizenz"], isNull, reason: "${row["lied"]}");
      expect(row["in_app_erlaubt"], isFalse, reason: "${row["lied"]}");
    }
  });

  test("Das Berliner Werk von 1832 bleibt ein eigener Katalogeintrag", () {
    final bibliography =
        jsonDecode(
              File("docs/liederschatz/bibliografie.json").readAsStringSync(),
            )
            as Map<String, dynamic>;
    final works = bibliography["werke"] as List<dynamic>;
    final meant = works.where((w) => w["gemeint"] == true);
    expect(meant.map((w) => w["id"]).toList(), ["gls_bg"]);
    expect(works.map((w) => w["id"]), contains("gls_berlin1832"));
  });
}
