import '../models/greek/perikope.dart';

/// Eine (ggf. noch unvollständige) Bibelstelle, wie sie im Perikopenquiz
/// eingegeben wird: Buch, Kapitel(-bereich) und optional Vers(-bereich).
///
/// [text] ist die kanonische Schreibweise, gegen die das Quiz die Eingaben
/// vergleicht. Die Schnelleingabe erzeugt ihre Antworten ausschließlich
/// darüber, damit Textfeld und Schnelleingabe denselben Regeln folgen.
class PericopeReference {
  final String? book;

  final int? startChapter;
  final int? startVerse;
  final int? endChapter;
  final int? endVerse;

  const PericopeReference({
    this.book,
    this.startChapter,
    this.startVerse,
    this.endChapter,
    this.endVerse,
  });

  static const PericopeReference empty = PericopeReference();

  /// Die erwartete Antwort zu einer Perikope.
  factory PericopeReference.of(Perikope p) {
    final verses = p.precision != "chapter";

    return PericopeReference(
      book: p.book,
      startChapter: p.startChapter,
      startVerse: verses ? p.startVerse : null,
      endChapter: p.endChapter,
      endVerse: verses ? p.endVerse : null,
    );
  }

  static final RegExp _pattern = RegExp(
    r'^([A-Za-zÄÖÜäöü0-9]+)(?: (\d+)(?:,(\d+))?(?:-(\d+)(?:,(\d+))?)?)?$',
  );

  /// Liest eine Eingabe in kanonischer Schreibweise, auch unvollständig
  /// („Mk“, „Mk 10“). Alles andere ergibt `null`.
  static PericopeReference? parse(String input) {
    final match = _pattern.firstMatch(
      input.trim().replaceAll(RegExp(r'\s+'), ' '),
    );

    if (match == null) return null;

    int? number(int group) {
      final value = match.group(group);
      return value == null ? null : int.tryParse(value);
    }

    final startChapter = number(2);
    final startVerse = number(3);
    final end = number(4);
    final endVerse = number(5);

    if (startVerse == null) {
      // Kapitelgenau: „8“ oder „8-10“.
      if (endVerse != null) return null;

      return PericopeReference(
        book: match.group(1),
        startChapter: startChapter,
        endChapter: end,
      );
    }

    // Versgenau: „1,9“, „1,9-11“ oder „1,9-2,4“.
    return PericopeReference(
      book: match.group(1),
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: endVerse == null ? null : end,
      endVerse: endVerse ?? end,
    );
  }

  /// Kapitel-/Versangabe ohne Buch in der Schreibweise des Quiz.
  static String formatRange({
    required String precision,
    required int startChapter,
    required int startVerse,
    required int endChapter,
    required int endVerse,
  }) {
    if (precision == "chapter") {
      if (startChapter == endChapter) {
        return "$startChapter";
      }

      return "$startChapter-$endChapter";
    }

    if (startChapter == endChapter) {
      if (startVerse == endVerse) {
        return "$startChapter,$startVerse";
      }

      return "$startChapter,$startVerse-$endVerse";
    }

    return "$startChapter,$startVerse-$endChapter,$endVerse";
  }

  /// Kanonische Schreibweise, z.B. „Mk 8-10“ oder „Mk 1,9-11“.
  String get text {
    final book = this.book;
    final startChapter = this.startChapter;

    if (book == null) return "";
    if (startChapter == null) return book;

    final range = formatRange(
      precision: startVerse == null ? "chapter" : "verse",
      startChapter: startChapter,
      startVerse: startVerse ?? 0,
      endChapter: endChapter ?? startChapter,
      endVerse: endVerse ?? startVerse ?? 0,
    );

    return "$book $range";
  }

  /// Ob die Stelle für die Genauigkeit der Frage vollständig ist.
  bool isComplete(String precision) {
    if (book == null || startChapter == null) return false;

    return precision == "chapter" ? startVerse == null : startVerse != null;
  }

  @override
  bool operator ==(Object other) {
    return other is PericopeReference &&
        other.book == book &&
        other.startChapter == startChapter &&
        other.startVerse == startVerse &&
        other.endChapter == endChapter &&
        other.endVerse == endVerse;
  }

  @override
  int get hashCode =>
      Object.hash(book, startChapter, startVerse, endChapter, endVerse);
}
