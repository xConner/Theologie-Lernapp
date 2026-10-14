import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/timetable/course_catalog.dart';

/// Ein angebotenes Semester.
class SemesterOption {
  final String id;
  final String label;

  const SemesterOption(this.id, this.label);

  @override
  bool operator ==(Object other) => other is SemesterOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Woher ein geladener Katalog stammt.
enum CatalogOrigin {
  /// Gerade vom Server geladen.
  network,

  /// Gespeicherter Stand auf dem Gerät (Server nicht erreichbar).
  offlineCache,

  /// Synthetische Testdaten (nur Tests und Entwicklungsmodus).
  synthetic,
}

class CatalogLoad {
  final CourseCatalog catalog;
  final CatalogOrigin origin;

  /// Zeitpunkt, zu dem der Server die Daten bei der Quelle abgerufen hat.
  final DateTime? updatedAt;

  /// Der Server konnte die Quelle zuletzt nicht erreichen und liefert einen
  /// älteren Stand.
  final bool sourceStale;

  /// Fehler der Aktualisierung, falls ein gespeicherter Stand gezeigt wird.
  final Object? refreshError;

  const CatalogLoad({
    required this.catalog,
    required this.origin,
    this.updatedAt,
    this.sourceStale = false,
    this.refreshError,
  });
}

/// Quelle des Veranstaltungskatalogs. Die App kennt nur diese Schnittstelle
/// und das quellneutrale Format ([CourseCatalog]).
abstract class CourseCatalogSource {
  /// Angebotene Semester (laufendes und nächstes).
  Future<List<SemesterOption>> semesters();

  Future<CatalogLoad> load(String semesterId);
}

/// Server antwortet, aber nicht wie erwartet (verständliche Meldung).
class CatalogUnavailableException implements Exception {
  final String message;

  const CatalogUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Letzter erfolgreich geladener Stand je Semester (shared_preferences;
/// Web: localStorage). Enthält nur öffentliche Katalogdaten, keine
/// persönlichen Einträge.
class CatalogOfflineCache {
  static const String _prefix = "catalog.v1.";
  static const String semestersKey = "${_prefix}semesters";

  static String catalogKey(String semesterId) => "$_prefix$semesterId";

  Future<void> saveSemesters(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(semestersKey, json);
  }

  Future<String?> readSemesters() async =>
      (await SharedPreferences.getInstance()).getString(semestersKey);

  Future<void> saveCatalog(String semesterId, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(catalogKey(semesterId), json);
  }

  Future<String?> readCatalog(String semesterId) async =>
      (await SharedPreferences.getInstance()).getString(catalogKey(semesterId));

  /// Gespeicherte Kataloge nicht mehr angebotener Semester entfernen.
  Future<void> keepOnly(Iterable<String> semesterIds) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {for (final id in semesterIds) catalogKey(id), semestersKey};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix) && !keep.contains(key)) {
        await prefs.remove(key);
      }
    }
  }
}

/// Produktive Quelle: `GET /api/catalog` (UnivIS der CAU, aufbereitet und
/// zwischengespeichert auf dem Server).
class ApiCourseCatalogSource implements CourseCatalogSource {
  static const String productionBaseUrl = "https://www.theologie.app";
  static const Duration timeout = Duration(seconds: 25);

  final http.Client client;
  final String baseUrl;
  final CatalogOfflineCache cache;

  ApiCourseCatalogSource({
    http.Client? client,
    String? baseUrl,
    CatalogOfflineCache? cache,
  }) : client = client ?? http.Client(),
       baseUrl = baseUrl ?? defaultBaseUrl(),
       cache = cache ?? CatalogOfflineCache();

  /// Im Web dieselbe Herkunft (Produktion und Vercel-Vorschau), sonst die
  /// Produktion.
  static String defaultBaseUrl() {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == "theologie.app" ||
          host.endsWith(".theologie.app") ||
          host.endsWith(".vercel.app")) {
        return Uri.base.origin;
      }
    }
    return productionBaseUrl;
  }

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final uri = Uri.parse(
      "$baseUrl/api/catalog",
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await client
        .get(uri, headers: const {"Accept": "application/json"})
        .timeout(timeout);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const CatalogUnavailableException(
        "Der Server hat keine gültigen Katalogdaten geliefert.",
      );
    }
    if (response.statusCode != 200 || decoded is! Map) {
      final message = decoded is Map && decoded["error"] is String
          ? decoded["error"] as String
          : "Der Veranstaltungskatalog ist derzeit nicht verfügbar.";
      throw CatalogUnavailableException(message);
    }
    return Map<String, dynamic>.from(decoded);
  }

  static List<SemesterOption> _parseSemesters(Map<String, dynamic> json) => [
    if (json["semesters"] is List)
      for (final s in json["semesters"] as List)
        if (s is Map && s["id"] is String)
          SemesterOption(
            s["id"] as String,
            s["label"] is String ? s["label"] as String : s["id"] as String,
          ),
  ];

  @override
  Future<List<SemesterOption>> semesters() async {
    try {
      final json = await _get(const {});
      final result = _parseSemesters(json);
      await cache.saveSemesters(jsonEncode(json));
      await cache.keepOnly(result.map((s) => s.id));
      return result;
    } catch (e) {
      final stored = await cache.readSemesters();
      if (stored != null) {
        try {
          return _parseSemesters(Map<String, dynamic>.from(jsonDecode(stored)));
        } catch (_) {
          // Defekter Speicher: wie nicht vorhanden.
        }
      }
      rethrow;
    }
  }

  static CatalogLoad _fromJson(
    Map<String, dynamic> json,
    CatalogOrigin origin, {
    Object? refreshError,
  }) {
    if (json["synthetic"] == true) {
      // Synthetische Daten dürfen nie als echte erscheinen.
      throw const CatalogFormatException("Server lieferte synthetische Daten");
    }
    final catalog = CourseCatalog.fromJson(json);
    final cacheInfo = json["cache"] is Map ? json["cache"] as Map : const {};
    return CatalogLoad(
      catalog: catalog,
      origin: origin,
      updatedAt:
          DateTime.tryParse("${cacheInfo["fetchedAt"] ?? ""}") ??
          catalog.provenance.fetchedAt,
      sourceStale: cacheInfo["state"] == "stale",
      refreshError: refreshError,
    );
  }

  @override
  Future<CatalogLoad> load(String semesterId) async {
    try {
      final json = await _get({"semester": semesterId});
      final load = _fromJson(json, CatalogOrigin.network);
      if (load.catalog.semester.id != semesterId) {
        throw const CatalogFormatException("Falsches Semester geliefert");
      }
      await cache.saveCatalog(semesterId, jsonEncode(json));
      return load;
    } catch (e) {
      final stored = await cache.readCatalog(semesterId);
      if (stored != null) {
        try {
          final decoded = jsonDecode(stored);
          if (decoded is Map) {
            return _fromJson(
              Map<String, dynamic>.from(decoded),
              CatalogOrigin.offlineCache,
              refreshError: e,
            );
          }
        } catch (_) {
          // Defekter Speicher: wie nicht vorhanden.
        }
      }
      if (e is TimeoutException || e is http.ClientException) {
        throw const CatalogUnavailableException(
          "Keine Verbindung zum Server. Bitte Internetverbindung prüfen.",
        );
      }
      rethrow;
    }
  }
}

/// SYNTHETISCHE Testdaten aus den Assets (erzeugt von
/// `tool/timetable/build_synthetic_catalog.mjs`). Nur für Tests und den
/// ausdrücklichen Entwicklungsmodus (`--dart-define=TIMETABLE_SYNTHETIC=true`);
/// jede Ansicht kennzeichnet sie.
class SyntheticCourseCatalogSource implements CourseCatalogSource {
  static const String asset = "assets/timetable/synthetic_catalog.json";

  final AssetBundle bundle;

  SyntheticCourseCatalogSource({AssetBundle? bundle})
    : bundle = bundle ?? rootBundle;

  Future<CourseCatalog> _read() async {
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

  @override
  Future<List<SemesterOption>> semesters() async {
    final catalog = await _read();
    return [SemesterOption(catalog.semester.id, catalog.semester.label)];
  }

  @override
  Future<CatalogLoad> load(String semesterId) async {
    final catalog = await _read();
    if (catalog.semester.id != semesterId) {
      throw const CatalogUnavailableException(
        "Für dieses Semester gibt es keine Testdaten.",
      );
    }
    return CatalogLoad(
      catalog: catalog,
      origin: CatalogOrigin.synthetic,
      updatedAt: catalog.provenance.fetchedAt,
    );
  }
}
