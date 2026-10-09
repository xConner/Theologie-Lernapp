import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/bible/bible_text.dart';
import '../../models/bible/bible_translation.dart';

/// Herkunft der Bibeltexte, wie sie der Reader braucht: die verfügbaren
/// Ausgaben und der Text eines Buchs.
///
/// Der Reader kennt nur diese Schnittstelle. Eine weitere Quelle (z. B.
/// nachladbare Ausgaben oder ein Dienst) implementiert sie und wird dem
/// `BibleRepository` übergeben; Darstellung, Suche und Stellenauflösung
/// bleiben unverändert.
abstract class BibleTextSource {
  /// Die tatsächlich verfügbaren Ausgaben in Anzeigereihenfolge.
  Future<List<BibleTranslation>> loadTranslations();

  Future<BibleBookText> loadBook(String translationId, String bookId);
}

/// Die mit der App ausgelieferten Texte unter `assets/bible/` – ohne
/// Internetverbindung lesbar. Je Ausgabe ein Verzeichnis, je Buch eine
/// Datei, damit beim Lesen nur das aufgeschlagene Buch geladen wird.
class AssetBibleTextSource implements BibleTextSource {
  static const String root = "assets/bible";

  /// Nur für Tests ersetzbar; standardmäßig das Bundle der App.
  final AssetBundle? bundle;

  const AssetBibleTextSource({this.bundle});

  AssetBundle get _assets => bundle ?? rootBundle;

  @override
  Future<List<BibleTranslation>> loadTranslations() async {
    final data = await _assets.loadString("$root/translations.json");

    final json = jsonDecode(data) as Map<String, dynamic>;

    return [
      for (final t in json["translations"] as List)
        BibleTranslation.fromJson(Map<String, dynamic>.from(t)),
    ];
  }

  @override
  Future<BibleBookText> loadBook(String translationId, String bookId) async {
    // Nicht im Asset-Cache halten: Das Repository behält die geparsten
    // Bücher, der Rohtext würde nur doppelt Speicher belegen.
    final data = await _assets.loadString(
      "$root/$translationId/$bookId.json",
      cache: false,
    );

    return BibleBookText.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}
