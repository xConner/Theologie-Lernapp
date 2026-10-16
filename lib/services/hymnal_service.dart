import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/hymn.dart';
import '../models/hymnal.dart';
import 'hymn_search.dart';

/// Alle Gesangbücher und Liedsammlungen mit ihren Liedern.
///
/// Lässt sich eine Sammlung nicht laden, fehlen nur ihre Lieder; der Fehler
/// steht in [failed], die übrigen Sammlungen bleiben nutzbar.
class HymnalLibrary {
  final List<HymnalGroup> groups;
  final List<Hymnal> hymnals;
  final Map<String, List<Hymn>> hymnsByCollection;

  /// Sammlungen, deren Lieder nicht geladen werden konnten.
  final Set<String> failed;

  late final HymnSearchIndex index = HymnSearchIndex(
    allHymns,
    order: {for (final (i, hymnal) in hymnals.indexed) hymnal.id: i},
  );

  late final Map<String, List<Hymn>> _byWork = () {
    final result = <String, List<Hymn>>{};
    for (final hymn in allHymns) {
      if (hymn.workId.isNotEmpty) {
        result.putIfAbsent(hymn.workId, () => []).add(hymn);
      }
    }
    return result;
  }();

  HymnalLibrary({
    required this.groups,
    required this.hymnals,
    required this.hymnsByCollection,
    this.failed = const {},
  });

  List<Hymn> get allHymns => [
    for (final hymnal in hymnals) ...hymnsOf(hymnal.id),
  ];

  List<Hymn> hymnsOf(String hymnalId) =>
      hymnsByCollection[hymnalId] ?? const [];

  Hymnal? hymnal(String id) {
    for (final hymnal in hymnals) {
      if (hymnal.id == id) return hymnal;
    }
    return null;
  }

  Hymnal? hymnalOf(Hymn hymn) => hymnal(hymn.collectionId);

  List<Hymnal> inGroup(String group, [HymnalPart? part]) => [
    for (final hymnal in hymnals)
      if (hymnal.group == group && (part == null || hymnal.part == part))
        hymnal,
  ];

  /// Die anderen Fassungen desselben Liedes in weiteren Sammlungen (gleiche
  /// [Hymn.workId]); jede Fassung bleibt ein eigener Eintrag.
  List<Hymn> versionsOf(Hymn hymn) => [
    for (final other in _byWork[hymn.workId] ?? const <Hymn>[])
      if (other.key != hymn.key) other,
  ];

  /// Hinweis, warum ein Lied keinen Text zeigt.
  String lyricsNoteOf(Hymn hymn) {
    if (hymn.lyricsNote.isNotEmpty) return hymn.lyricsNote;
    final note = hymnalOf(hymn)?.lyricsNote ?? '';
    return note.isNotEmpty ? note : defaultLyricsNote;
  }

  static const String defaultLyricsNote =
      "Liedtext aus urheberrechtlichen Gründen nicht verfügbar.";
}

/// Lädt den Katalog `assets/hymnals/catalog.json` und die Lieder jeder
/// Sammlung aus dem App-Bundle.
class HymnalService {
  static const String catalogAsset = 'assets/hymnals/catalog.json';

  final AssetBundle bundle;

  HymnalService({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  static Future<HymnalLibrary>? _shared;

  /// Einmal geladen für die ganze App; nach einem Fehler beim nächsten
  /// Aufruf erneut.
  static Future<HymnalLibrary> shared() {
    return _shared ??= HymnalService().load().catchError((Object error) {
      _shared = null;
      throw error;
    });
  }

  /// Wirft nur, wenn der Katalog selbst fehlt oder unlesbar ist.
  Future<HymnalLibrary> load() async {
    final catalog =
        json.decode(await bundle.loadString(catalogAsset))
            as Map<String, dynamic>;

    final groups = (catalog['groups'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HymnalGroup.fromJson)
        .toList();
    final hymnals = (catalog['hymnals'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Hymnal.fromJson)
        .toList();

    final hymns = <String, List<Hymn>>{};
    final failed = <String>{};

    await Future.wait([
      for (final hymnal in hymnals)
        if (hymnal.asset != null)
          _loadHymns(
            hymnal,
          ).then((loaded) => hymns[hymnal.id] = loaded).catchError((Object _) {
            failed.add(hymnal.id);
            return const <Hymn>[];
          }),
    ]);

    return HymnalLibrary(
      groups: groups,
      hymnals: hymnals,
      hymnsByCollection: hymns,
      failed: failed,
    );
  }

  Future<List<Hymn>> _loadHymns(Hymnal hymnal) async {
    final data = json.decode(await bundle.loadString(hymnal.asset!)) as List;

    return [
      for (final entry in data.whereType<Map<String, dynamic>>())
        Hymn.fromJson(
          entry,
          collectionId: hymnal.id,
          numberPrefix: hymnal.numberPrefix,
        ),
    ];
  }
}
