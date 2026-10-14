import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/timetable/course_catalog.dart';

/// Quelle des Veranstaltungskatalogs. Die App kennt nur diese Schnittstelle
/// und das quellneutrale Format ([CourseCatalog]); eine spätere Anbindung an
/// UnivIS (über einen Server-Endpunkt auf Basis von `api/_lib/catalog`) oder
/// an HISinOne ist eine weitere Implementierung.
abstract class CourseCatalogSource {
  Future<CourseCatalog> load();
}

/// SYNTHETISCHE Testdaten aus den Assets (erzeugt von
/// `tool/timetable/build_synthetic_catalog.mjs`). Bis zur Klärung der
/// Nutzungsrechte die einzige Quelle; echte UnivIS-Daten werden weder
/// abgerufen noch mitgeliefert.
class SyntheticCourseCatalogSource implements CourseCatalogSource {
  static const String asset = "assets/timetable/synthetic_catalog.json";

  final AssetBundle bundle;

  SyntheticCourseCatalogSource({AssetBundle? bundle})
    : bundle = bundle ?? rootBundle;

  @override
  Future<CourseCatalog> load() async {
    final decoded = jsonDecode(await bundle.loadString(asset));
    if (decoded is! Map) {
      throw const CatalogFormatException("Katalog ist kein JSON-Objekt");
    }
    final catalog = CourseCatalog.fromJson(Map<String, dynamic>.from(decoded));
    if (!catalog.synthetic) {
      // Schutz gegen versehentlich eingespielte echte Daten.
      throw const CatalogFormatException(
        "Asset ist nicht als synthetisch markiert",
      );
    }
    return catalog;
  }
}
