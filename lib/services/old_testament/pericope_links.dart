import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/greek/perikope.dart';
import '../../models/old_testament/old_testament.dart';
import '../../quiz/books/book_catalog.dart';

/// Verbindet Bibelstellen der Folien ([PassageRef.pericopeKeys]) mit den
/// Perikopen der Perikopenliste (`assets/perikopen.json`).
///
/// Die Liste wird nur gelesen: Titel, Grenzen und IDs bleiben, wie sie
/// sind. Persönliche Änderungen (`pericope_overrides`) gelten hier nicht;
/// sie betreffen das Quiz, nicht diese Verweise.
class OtPericopeLinks {
  final Map<String, Perikope> _byKey;

  const OtPericopeLinks._(this._byKey);

  static const OtPericopeLinks empty = OtPericopeLinks._({});

  factory OtPericopeLinks.fromPerikopen(Iterable<Perikope> perikopen) =>
      OtPericopeLinks._({for (final p in perikopen) BookPericope.keyOf(p): p});

  static Future<OtPericopeLinks>? _bundled;

  /// Einmal je App-Start gelesen; [bundle] nur für Tests.
  static Future<OtPericopeLinks> load({AssetBundle? bundle}) {
    if (bundle != null) return _read(bundle);
    return _bundled ??= _read(rootBundle);
  }

  static Future<OtPericopeLinks> _read(AssetBundle bundle) async {
    final data = await bundle.loadString("assets/perikopen.json");
    return OtPericopeLinks.fromPerikopen([
      for (final entry in jsonDecode(data) as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ]);
  }

  Perikope? byKey(String key) => _byKey[key];

  /// Die zugeordneten Perikopen in der Reihenfolge der Daten; unbekannte
  /// Verweise entfallen.
  List<Perikope> of(PassageRef passage) => [
    for (final k in passage.pericopeKeys) ?_byKey[k],
  ];

  /// Stelle einer Perikope wie im Perikopenquiz, z. B. „Gen 4,1-16“.
  static String rangeOf(Perikope p) {
    final start = "${p.book} ${p.startChapter},${p.startVerse}";
    return p.endChapter == p.startChapter
        ? "$start-${p.endVerse}"
        : "$start-${p.endChapter},${p.endVerse}";
  }
}
