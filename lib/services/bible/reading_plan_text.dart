import '../../models/bible/reading_plan.dart';
import 'bible_books.dart';
import 'bible_reference_parser.dart';
import 'reading_plan_codec.dart';

/// Eingabe eines eigenen Plans als Text: ein Tag je Zeile, mehrere Lesungen
/// durch Semikolon getrennt („Mk 1-2; Ps 1“).
class ReadingPlanText {
  ReadingPlanText._();

  // Nur ein Buchname, ggf. mit führender Ordnungszahl („1. Mose“, „Joel“).
  static final RegExp _bookOnly = RegExp(r"^(?:[1-4]\s*\.?\s*)?[^\d,;:]+$");

  /// Liest eine Lesung in der Schreibweise des Planformats („GEN 1-3“) oder
  /// wie bei der Stelleneingabe des Readers („Mk 4,35–41“, „Joel“).
  static PlanReading? parseReading(String input) {
    final text = input.trim();

    if (text.isEmpty) return null;

    final canonical = PlanReading.parse(text);

    if (canonical != null && BibleBooks.byId(canonical.bookId) != null) {
      return canonical;
    }

    if (_bookOnly.hasMatch(text)) {
      final bookId = BibleBooks.find(text);

      return bookId == null ? null : PlanReading.book(bookId);
    }

    final reference = BibleReferenceParser.parse(text);

    return reference == null ? null : PlanReading.fromReference(reference);
  }

  /// Baut aus der Eingabe eine Plandatei (als JSON-Map); leere Zeilen werden
  /// übergangen. Unlesbare Angaben stehen in `problems`.
  static ({Map<String, dynamic> json, List<String> problems}) build({
    required String id,
    required String name,
    required String description,
    required String days,
  }) {
    final problems = <String>[];
    final result = <List<String>>[];

    final lines = days
        .split("\n")
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      final number = result.length + 1;
      final readings = <String>[];

      for (final part in line.split(";")) {
        if (part.trim().isEmpty) continue;

        final reading = parseReading(part);

        if (reading == null) {
          problems.add(
            "Tag $number: „${part.trim()}“ ist keine lesbare Stellenangabe.",
          );
        } else {
          readings.add(reading.key);
        }
      }

      result.add(readings);
    }

    return (
      json: {
        "format": ReadingPlanCodec.format,
        "formatVersion": ReadingPlanCodec.formatVersion,
        "id": id,
        "name": name,
        "description": description,
        "language": "de",
        "category": "custom",
        "days": result,
      },
      problems: problems,
    );
  }

  /// Kennung für einen neu erstellten Plan: aus dem Namen und der Zeit,
  /// damit zwei Pläne gleichen Namens verschieden bleiben.
  static String newId(String name, DateTime now) {
    const replacements = {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"};

    var slug = name.toLowerCase();

    replacements.forEach((from, to) => slug = slug.replaceAll(from, to));

    slug = slug
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp(r"^-+|-+$"), "");

    if (slug.length > 30) slug = slug.substring(0, 30);

    final stamp = (now.millisecondsSinceEpoch ~/ 1000).toRadixString(36);

    return slug.isEmpty ? "plan-$stamp" : "plan-$slug-$stamp";
  }
}
