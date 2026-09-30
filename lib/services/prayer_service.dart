import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/prayer.dart';

class PrayerService {
  static const String assetPath = 'assets/prayers.json';

  /// Standardmäßig das App-Bundle; Tests können ein eigenes Bundle übergeben.
  final AssetBundle bundle;

  PrayerService({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<List<Prayer>> loadPrayers() async {
    final String jsonString = await bundle.loadString(assetPath);

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((item) => Prayer.fromJson(item)).toList();
  }
}

/// Suche und Tag-Filter der Gebetsliste.
///
/// Suchlogik:
/// * Die Eingabe wird an Leerzeichen in Suchbegriffe zerlegt; ein Gebet
///   passt, wenn **jeder** Begriff gefunden wird (UND-Verknüpfung).
/// * Durchsucht werden Titel in allen Sprachen, Tags (ID, Anzeigename und
///   feste Synonyme aus [PrayerTags.searchAliases]), Gattung, Tradition und
///   Autor – nicht der Gebetstext selbst, damit z. B.
///   „Herr“ nicht fast jedes Gebet liefert.
/// * Groß-/Kleinschreibung wird ignoriert; ä/ö/ü/ß entsprechen ae/oe/ue/ss.
/// * Leere Suche ohne Tag liefert alle Gebete in der Reihenfolge der Daten.
/// * [tag] filtert zusätzlich exakt auf eine Tag-ID; unbekannte Tags ergeben
///   eine leere Liste.
class PrayerSearch {
  PrayerSearch._();

  static List<Prayer> filter(
    List<Prayer> prayers, {
    String query = "",
    String? tag,
  }) {
    final terms = normalize(
      query,
    ).split(RegExp(r"\s+")).where((t) => t.isNotEmpty).toList();

    return prayers.where((prayer) {
      if (tag != null && !prayer.tags.contains(tag)) return false;
      if (terms.isEmpty) return true;

      final haystack = _searchText(prayer);

      return terms.every(haystack.contains);
    }).toList();
  }

  static String _searchText(Prayer prayer) {
    return normalize(
      [
        ...prayer.title.values,
        ...prayer.tags,
        ...prayer.tags.map(PrayerTags.label),
        for (final tag in prayer.tags) ...?PrayerTags.searchAliases[tag],
        PrayerTypes.label(prayer.type),
        PrayerTraditions.label(prayer.tradition),
        prayer.author ?? "",
      ].join(" "),
    );
  }

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll("ä", "ae")
        .replaceAll("ö", "oe")
        .replaceAll("ü", "ue")
        .replaceAll("ß", "ss")
        .trim();
  }
}
