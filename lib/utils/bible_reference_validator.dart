class BibleReferenceValidator {
  static final RegExp _bookRegex = RegExp(r'^[A-Za-zÄÖÜäöü0-9]+$');
  static final RegExp _chapterRegex = RegExp(r'^\d+$');
  static final RegExp _verseRegex = RegExp(r'^\d+$');

  static const Set<String> validBooks = {
    "Gen",
    "Ex",
    "Lev",
    "Num",
    "Dtn",
    "Jos",
    "Ri",
    "Rut",
    "1Sam",
    "2Sam",
    "1Kön",
    "2Kön",
    "1Chr",
    "2Chr",
    "Esr",
    "Neh",
    "Est",
    "Ijob",
    "Ps",
    "Spr",
    "Koh",
    "Hld",
    "Jes",
    "Jer",
    "Klgl",
    "Ez",
    "Dan",
    "Hos",
    "Joel",
    "Am",
    "Obd",
    "Jona",
    "Mi",
    "Nah",
    "Hab",
    "Zef",
    "Hag",
    "Sach",
    "Mal",
    "Mt",
    "Mk",
    "Lk",
    "Joh",
    "Apg",
    "Röm",
    "1Kor",
    "2Kor",
    "Gal",
    "Eph",
    "Phil",
    "Kol",
    "1Thess",
    "2Thess",
    "1Tim",
    "2Tim",
    "Tit",
    "Phlm",
    "Hebr",
    "Jak",
    "1Petr",
    "2Petr",
    "1Joh",
    "2Joh",
    "3Joh",
    "Jud",
    "Offb",
  };

  static String? validateBook(String input) {
    final cleaned = input.trim();

    if (cleaned.isEmpty) return null;

    final match = RegExp(r'^([A-Za-zÄÖÜäöü0-9]+)').firstMatch(cleaned);

    if (match == null) return null;

    final book = match.group(1)!;

    if (!validBooks.contains(book)) {
      return "$book ist keine gültige Abkürzung";
    }

    return null;
  }

  static bool isValid(String input, String precision) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return false;

    final match = RegExp(r'^([A-Za-zÄÖÜäöü0-9]+)\s*(.*)$').firstMatch(cleaned);

    if (match == null) return false;

    final ref = match.group(2)!.trim();

    if (precision == "chapter") {
      return _validateChapter(ref);
    }

    return _validateVerse(ref);
  }

  static bool _validateChapter(String input) {
    final range = input.split("-");
    if (range.length > 2) return false;

    for (final p in range) {
      if (!_chapterRegex.hasMatch(p.trim())) return false;
    }

    return true;
  }

  static bool _validateVerse(String input) {
    final range = input.split("-");
    if (range.length > 2) return false;

    for (final p in range) {
      if (!_validateSingleVerse(p.trim())) return false;
    }

    return true;
  }

  static bool _validateSingleVerse(String input) {
    final parts = input.split(",");
    if (parts.length != 2) return false;

    final chapter = parts[0].trim();
    final verse = parts[1].trim();

    if (!_chapterRegex.hasMatch(chapter)) return false;

    if (verse.contains("-")) {
      final v = verse.split("-");
      if (v.length != 2) return false;

      return _verseRegex.hasMatch(v[0]) && _verseRegex.hasMatch(v[1]);
    }

    return _verseRegex.hasMatch(verse);
  }
}
