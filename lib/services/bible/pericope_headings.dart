import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/bible/bible_translation.dart';
import '../../models/greek/perikope.dart';
import 'bible_books.dart';

/// Die Perikopenüberschriften für den Bibel-Reader.
///
/// Einzige Quelle ist die Perikopenliste (`assets/perikopen.json`), aus der
/// auch das Quiz seine Fragen bildet: Jede Perikope steht mit ihrem Titel am
/// ersten Vers ihrer Stelle. Die Überschriften gehören damit zu keiner
/// Bibelausgabe und sind in allen Ausgaben dieselben.
///
/// Die Liste zählt Kapitel und Verse wie deutsche Bibelausgaben. Zählungen
/// werden nicht umgerechnet: Wo eine Ausgabe anders zählt, entfallen die
/// Überschriften, statt an einer falschen Stelle zu stehen (siehe
/// [forChapter]).
class PericopeHeadings {
  /// Kennzeichnung bei jeder Überschrift.
  static const String label = "Perikopenüberschrift · theologie.app";

  /// Erklärung zur Herkunft.
  static const String explanation =
      "Die Perikopenüberschriften stammen aus dem Perikopen-Datensatz von "
      "theologie.app. Sie wurden unabhängig von der ausgewählten "
      "Bibelübersetzung erstellt und sind nicht Bestandteil des jeweiligen "
      "Bibeltextes.";

  // Buch → Kapitel → Anfangsvers → Titel in der Reihenfolge der Liste.
  final Map<String, Map<int, Map<int, List<String>>>> _starts;

  const PericopeHeadings._(this._starts);

  static const PericopeHeadings empty = PericopeHeadings._({});

  /// Ordnet jede Perikope ihrem Anfangsvers zu. Hat eine Perikope mehrere
  /// Stellen, steht ihr Titel an jeder; derselbe Titel am selben Vers
  /// erscheint nur einmal, verschiedene Titel am selben Vers bleiben alle
  /// erhalten. Perikopen mit unbekanntem Buch werden übergangen, ebenso
  /// Einträge, deren Titel nur die Stelle wiederholt („Ex 3“): Sie sind
  /// Kapitelfragen des Quiz und keine Überschriften.
  factory PericopeHeadings.fromPerikopen(Iterable<Perikope> perikopen) {
    final starts = <String, Map<int, Map<int, List<String>>>>{};

    for (final p in perikopen) {
      final book = BibleBooks.byAbbreviation(p.book);

      final title = p.title.trim();

      if (book == null || title.isEmpty || p.startChapter < 1) continue;

      if (_reference.hasMatch(title) && title.startsWith("${p.book} ")) {
        continue;
      }

      final titles = starts
          .putIfAbsent(book.id, () => {})
          .putIfAbsent(p.startChapter, () => {})
          // Ohne Versangabe beginnt die Perikope am Kapitelanfang.
          .putIfAbsent(p.startVerse < 1 ? 1 : p.startVerse, () => []);

      if (!titles.contains(title)) titles.add(title);
    }

    return PericopeHeadings._(starts);
  }

  // Kapitelangabe hinter der Buchabkürzung, z. B. „3“ oder „8-10“.
  static final RegExp _reference = RegExp(r'^\S+ \d+(-\d+)?$');

  static Future<PericopeHeadings>? _bundled;

  /// Die Überschriften aus der ausgelieferten Perikopenliste; wird einmal
  /// gelesen. [bundle] ist nur für Tests ersetzbar.
  static Future<PericopeHeadings> load({AssetBundle? bundle}) {
    if (bundle != null) return _read(bundle);

    return _bundled ??= _read(rootBundle);
  }

  static Future<PericopeHeadings> _read(AssetBundle bundle) async {
    final data = await bundle.loadString('assets/perikopen.json');

    return PericopeHeadings.fromPerikopen([
      for (final entry in jsonDecode(data) as List)
        Perikope.fromJson(Map<String, dynamic>.from(entry)),
    ]);
  }

  /// Ob die Liste in diesem Kapitel (in ihrer eigenen Zählung) Perikopen
  /// beginnen lässt.
  bool hasAny(String bookId, int chapter) {
    return _starts[bookId]?[chapter]?.isNotEmpty ?? false;
  }

  // Bücher, die eine Zählung durchgehend anders ordnet als die Liste.
  static const Map<BibleVersification, Set<String>> _reordered = {
    BibleVersification.lxx: {"PSA", "PRO", "JER"},
    BibleVersification.vulgate: {"PSA"},
  };

  /// Anfangsvers → Titel für ein Kapitel von [translation].
  ///
  /// Im Neuen Testament und in Ausgaben mit deutscher Zählung gelten die
  /// Stellen der Liste unmittelbar. Sonst wird das Kapitel mit einer
  /// deutsch gezählten Ausgabe aus [translations] verglichen: Nur wenn Buch
  /// und Kapitel gleich viele Kapitel bzw. Verse haben, gelten die Stellen
  /// als übertragbar. In englisch gezählten Psalmen (Überschrift in Vers 1)
  /// bleibt wenigstens der Psalmanfang zuverlässig. Alles andere ergibt
  /// keine Überschriften.
  Map<int, List<String>> forChapter({
    required BibleTranslation translation,
    required List<BibleTranslation> translations,
    required String bookId,
    required int chapter,
  }) {
    final starts = _starts[bookId]?[chapter];

    final book = translation.book(bookId);

    if (starts == null || book == null || book.verseCount(chapter) == 0) {
      return const {};
    }

    if (translation.versification == BibleVersification.german ||
        BibleBooks.byId(bookId)?.testament == BibleTestament.newTestament) {
      return starts;
    }

    if (_reordered[translation.versification]?.contains(bookId) ?? false) {
      return const {};
    }

    BibleBookInfo? reference;

    for (final other in translations) {
      if (other.versification == BibleVersification.german) {
        reference = other.book(bookId);

        if (reference != null) break;
      }
    }

    if (reference == null || reference.chapterCount != book.chapterCount) {
      return const {};
    }

    if (reference.verseCount(chapter) == book.verseCount(chapter)) {
      return starts;
    }

    if (translation.versification == BibleVersification.english &&
        bookId == "PSA" &&
        starts.containsKey(1)) {
      return {1: starts[1]!};
    }

    return const {};
  }
}
