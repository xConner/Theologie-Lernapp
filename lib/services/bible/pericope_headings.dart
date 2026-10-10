import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/bible/bible_translation.dart';
import '../../models/greek/perikope.dart';
import 'bible_books.dart';
import 'versification_map.dart';

/// Die Perikopenüberschriften für den Bibel-Reader.
///
/// Einzige Quelle ist die Perikopenliste (`assets/perikopen.json`), aus der
/// auch das Quiz seine Fragen bildet: Jede Perikope steht mit ihrem Titel am
/// ersten Vers ihrer Stelle. Die Überschriften gehören damit zu keiner
/// Bibelausgabe und sind in allen Ausgaben dieselben.
///
/// Die Liste zählt Kapitel und Verse wie deutsche Bibelausgaben. Wo eine
/// Ausgabe anders zählt, wird der Anfangsvers übertragen, soweit das sicher
/// möglich ist (siehe [ListVersification]); sonst entfallen die
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

  // Buch → Kapitel → Anfangsvers → Perikopen in der Reihenfolge der Liste.
  final Map<String, Map<int, Map<int, List<Perikope>>>> _starts;

  const PericopeHeadings._(this._starts);

  static const PericopeHeadings empty = PericopeHeadings._({});

  /// Ordnet jede Perikope ihrem Anfangsvers zu. Hat eine Perikope mehrere
  /// Stellen, steht ihr Titel an jeder. Perikopen mit unbekanntem Buch
  /// werden übergangen, ebenso Einträge, deren Titel nur die Stelle
  /// wiederholt („Ex 3“): Sie sind Kapitelfragen des Quiz und keine
  /// Überschriften.
  factory PericopeHeadings.fromPerikopen(Iterable<Perikope> perikopen) {
    final starts = <String, Map<int, Map<int, List<Perikope>>>>{};

    for (final p in perikopen) {
      final book = BibleBooks.byAbbreviation(p.book);

      final title = p.title.trim();

      if (book == null || title.isEmpty || p.startChapter < 1) continue;

      if (_reference.hasMatch(title) && title.startsWith("${p.book} ")) {
        continue;
      }

      starts
          .putIfAbsent(book.id, () => {})
          .putIfAbsent(p.startChapter, () => {})
          // Ohne Versangabe beginnt die Perikope am Kapitelanfang.
          .putIfAbsent(p.startVerse < 1 ? 1 : p.startVerse, () => [])
          .add(p);
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

  /// Ob es die Stelle von [p] in der Zählung der Liste überhaupt gibt,
  /// gemessen an den deutsch gezählten Ausgaben [german]. Die Liste führt
  /// auch Stellen, die nur Ausgaben mit den Zusätzen zu Daniel und Ester
  /// kennen (z. B. Dan 3,24–50); in anderen Ausgaben steht unter derselben
  /// Versnummer ein anderer Text.
  static bool _exists(Perikope p, List<BibleBookInfo> german) {
    if (german.isEmpty) return true;

    return german.any(
      (book) =>
          p.startVerse <= book.verseCount(p.startChapter) &&
          p.endVerse <= book.verseCount(p.endChapter),
    );
  }

  /// Vers → Titel für ein Kapitel von [translation]: Jede Perikope steht
  /// an dem Vers, mit dem sie in dieser Ausgabe beginnt.
  ///
  /// Im Neuen Testament und in Ausgaben mit deutscher Zählung gelten die
  /// Stellen der Liste unmittelbar. Sonst überträgt [ListVersification]
  /// den Anfangsvers in die Zählung der Ausgabe – eine Perikope kann dabei
  /// in ein Nachbarkapitel fallen (1. Mose 32,1 der Liste ist in englischer
  /// Zählung 31,55). Was sich nicht sicher übertragen lässt, ergibt keine
  /// Überschrift, ebenso Perikopen, deren Stelle es in deutscher Zählung
  /// nicht gibt.
  ///
  /// Derselbe Titel am selben Vers erscheint nur einmal, verschiedene Titel
  /// am selben Vers bleiben alle erhalten.
  Map<int, List<String>> forChapter({
    required BibleTranslation translation,
    required List<BibleTranslation> translations,
    required String bookId,
    required int chapter,
  }) {
    final starts = _starts[bookId];

    final book = translation.book(bookId);

    if (starts == null || book == null || book.verseCount(chapter) == 0) {
      return const {};
    }

    final german = [
      for (final t in translations)
        if (t.versification == BibleVersification.german) ?t.book(bookId),
    ];

    final result = <int, List<String>>{};

    // Eine andere Zählung verschiebt höchstens ins Nachbarkapitel.
    for (int from = chapter - 1; from <= chapter + 1; from++) {
      for (final MapEntry(key: verse, value: perikopen)
          in (starts[from] ?? const <int, List<Perikope>>{}).entries) {
        final target = ListVersification.locate(
          translation: translation,
          translations: translations,
          bookId: bookId,
          chapter: from,
          verse: verse,
        );

        if (target == null || target.chapter != chapter) continue;

        for (final p in perikopen) {
          if (!_exists(p, german)) continue;

          final titles = result.putIfAbsent(target.verse, () => []);

          final title = p.title.trim();

          if (!titles.contains(title)) titles.add(title);
        }
      }
    }

    return result;
  }
}
