import '../local_learning_store.dart';
import '../quiz_documents.dart';

/// Zuletzt gelesene Stelle eines Werks.
class ReadingPosition {
  final String workId;
  final String versionId;
  final String unitId;
  final DateTime updated;

  const ReadingPosition({
    required this.workId,
    required this.versionId,
    required this.unitId,
    required this.updated,
  });

  Map<String, Object?> toJson() => {
    "v": versionId,
    "u": unitId,
    "t": updated.millisecondsSinceEpoch,
  };

  static ReadingPosition? fromJson(String workId, Object? json) {
    if (json is! Map || json["v"] is! String || json["u"] is! String) {
      return null;
    }
    return ReadingPosition(
      workId: workId,
      versionId: json["v"] as String,
      unitId: json["u"] as String,
      updated: DateTime.fromMillisecondsSinceEpoch(
        (json["t"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Lesezeichen auf einem Vers bzw. Absatz einer Fassung. Gespeichert wird
/// nur die Stelle, nie der Text.
class ApocryphaBookmark {
  final String versionId;
  final String unitId;

  /// Nummer des Verses/Absatzes, sonst `#<Index>`.
  final String block;
  final DateTime added;

  const ApocryphaBookmark({
    required this.versionId,
    required this.unitId,
    required this.block,
    required this.added,
  });

  String get key => keyOf(versionId, unitId, block);

  static String keyOf(String versionId, String unitId, String block) =>
      "$versionId|$unitId|$block";

  /// Werkkennung: Fassungskennungen beginnen mit `<werk>.`.
  String get workId => versionId.split(".").first;

  static ApocryphaBookmark? fromJson(String key, Object? json) {
    final parts = key.split("|");
    if (parts.length != 3 || json is! Map) return null;
    return ApocryphaBookmark(
      versionId: parts[0],
      unitId: parts[1],
      block: parts[2],
      added: DateTime.fromMillisecondsSinceEpoch(
        (json["t"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class ApocryphaUserState {
  final Map<String, ReadingPosition> positions;
  final Map<String, DateTime> favorites;
  final Map<String, ApocryphaBookmark> bookmarks;

  /// Zuletzt gewählte Fassung und Vergleichsfassung je Werk.
  final Map<String, String> versions;
  final Map<String, String> parallels;
  final double textScale;

  const ApocryphaUserState({
    this.positions = const {},
    this.favorites = const {},
    this.bookmarks = const {},
    this.versions = const {},
    this.parallels = const {},
    this.textScale = 1.0,
  });

  /// Zuletzt gelesene Werke, neueste zuerst.
  List<ReadingPosition> get recent =>
      positions.values.toList()..sort((a, b) => b.updated.compareTo(a.updated));

  List<ApocryphaBookmark> get bookmarkList =>
      bookmarks.values.toList()..sort((a, b) => b.added.compareTo(a.added));

  bool isFavorite(String workId) => favorites.containsKey(workId);
}

/// Persönliche Daten des Bereichs (Leseposition, Merkliste, Lesezeichen,
/// Ansicht) im Dokument `quiz_settings/apocrypha_reading` (Konto) bzw. lokal
/// (Gast). Persönliche Inhalte, kein Lernfortschritt. Alle Änderungen sind
/// Merges einzelner Einträge.
class ApocryphaUserData {
  final QuizDocuments documents;

  ApocryphaUserData(this.documents);

  factory ApocryphaUserData.forUser(String? uid) =>
      ApocryphaUserData(QuizDocuments.forUser(uid));

  static const String document = LocalLearningStore.apocryphaReading;

  static Map<String, Object?> _map(Object? field) => {
    if (field is Map)
      for (final e in field.entries)
        if (e.key is String) e.key as String: e.value,
  };

  Future<ApocryphaUserState> load() async {
    final doc = await documents.load(document);
    final settings = _map(doc["settings"]);
    return ApocryphaUserState(
      positions: {
        for (final e in _map(doc["positions"]).entries)
          e.key: ?ReadingPosition.fromJson(e.key, e.value),
      },
      favorites: {
        for (final e in _map(doc["favorites"]).entries)
          if (e.value is num)
            e.key: DateTime.fromMillisecondsSinceEpoch(
              (e.value as num).toInt(),
            ),
      },
      bookmarks: {
        for (final e in _map(doc["bookmarks"]).entries)
          e.key: ?ApocryphaBookmark.fromJson(e.key, e.value),
      },
      versions: {
        for (final e in _map(doc["versions"]).entries)
          if (e.value is String) e.key: e.value as String,
      },
      parallels: {
        for (final e in _map(doc["parallels"]).entries)
          if (e.value is String) e.key: e.value as String,
      },
      textScale: ((settings["scale"] as num?)?.toDouble() ?? 1.0).clamp(
        0.8,
        1.6,
      ),
    );
  }

  Future<void> setPosition(ReadingPosition position) => documents.mergeEntries(
    document,
    "positions",
    {position.workId: position.toJson()},
  );

  Future<void> removePosition(String workId) =>
      documents.mergeEntries(document, "positions", {workId: null});

  Future<void> setFavorite(String workId, bool favorite) =>
      documents.mergeEntries(document, "favorites", {
        workId: favorite ? DateTime.now().millisecondsSinceEpoch : null,
      });

  Future<void> setBookmark(ApocryphaBookmark bookmark, bool set) =>
      documents.mergeEntries(document, "bookmarks", {
        bookmark.key: set ? {"t": bookmark.added.millisecondsSinceEpoch} : null,
      });

  Future<void> setVersion(String workId, String versionId) =>
      documents.mergeEntries(document, "versions", {workId: versionId});

  /// Vergleichsfassung; null schaltet den Vergleich aus.
  Future<void> setParallel(String workId, String? versionId) =>
      documents.mergeEntries(document, "parallels", {workId: versionId});

  Future<void> setTextScale(double scale) =>
      documents.mergeEntries(document, "settings", {"scale": scale});
}
