import '../../services/bible/bible_books.dart';
import 'bible_reference.dart';
import 'bible_translation.dart';

/// Eine Lesung eines Leseplans: ein ganzes Buch, ein Kapitel(bereich) oder
/// ein Versbereich – unabhängig von einer Bibelausgabe.
///
/// Geschrieben wird sie mit der USFM-Kennung des Buchs: `JOL`, `GEN 1`,
/// `GEN 1-3`, `JHN 3:16`, `JHN 3:16-21`, `GEN 1:1-2:3`
/// (siehe `docs/reading-plans.md`).
class PlanReading {
  /// Buchkennung nach USFM (siehe `BibleBooks`).
  final String bookId;

  /// `null` = das ganze Buch.
  final int? chapter;
  final int? verse;

  final int? endChapter;
  final int? endVerse;

  const PlanReading({
    required this.bookId,
    this.chapter,
    this.verse,
    this.endChapter,
    this.endVerse,
  });

  const PlanReading.book(this.bookId)
    : chapter = null,
      verse = null,
      endChapter = null,
      endVerse = null;

  static final RegExp _pattern = RegExp(
    r'^([1-4A-Z][A-Z0-9]{2})(?:\s+(\d+)(?::(\d+))?(?:-(\d+)(?::(\d+))?)?)?$',
  );

  /// Liest die Schreibweise des Planformats; `null` bei ungültiger Form
  /// (ob es die Stelle gibt, prüft [problemIn]).
  static PlanReading? parse(String input) {
    final match = _pattern.firstMatch(
      input.trim().replaceAll(RegExp(r'[–—−]'), '-'),
    );

    if (match == null) return null;

    int? number(int group) {
      final value = match.group(group);

      return value == null ? null : int.tryParse(value);
    }

    final bookId = match.group(1)!;
    final chapter = number(2);
    final verse = number(3);
    final end = number(4);
    final endVerse = number(5);

    if (chapter == null) return PlanReading.book(bookId);

    if (chapter < 1 || (verse != null && verse < 1)) return null;

    if (end == null) {
      return PlanReading(bookId: bookId, chapter: chapter, verse: verse);
    }

    if (end < 1) return null;

    if (verse == null) {
      // „1-3“: Kapitelbereich. „1-3:5“ wäre mehrdeutig.
      if (endVerse != null || end < chapter) return null;

      return PlanReading(
        bookId: bookId,
        chapter: chapter,
        endChapter: end == chapter ? null : end,
      );
    }

    if (endVerse == null) {
      // „3:16-21“: Ende im selben Kapitel.
      if (end < verse) return null;

      return PlanReading(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        endVerse: end == verse ? null : end,
      );
    }

    // „1:1-2:3“.
    if (endVerse < 1 || end < chapter || (end == chapter && endVerse < verse)) {
      return null;
    }

    return PlanReading(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      endChapter: end,
      endVerse: endVerse,
    );
  }

  /// Übernimmt eine im Reader übliche Stelle; `null` bei offenem Ende
  /// („4,35ff“), das ein Plan nicht ausdrücken kann.
  static PlanReading? fromReference(BibleReference reference) {
    if (reference.openEnd) return null;

    final verse = reference.verse;

    if (verse == null) {
      return PlanReading(
        bookId: reference.bookId,
        chapter: reference.chapter,
        endChapter: reference.spansChapters ? reference.endChapter : null,
      );
    }

    final endVerse = reference.endVerse ?? verse;

    if (reference.spansChapters) {
      return PlanReading(
        bookId: reference.bookId,
        chapter: reference.chapter,
        verse: verse,
        endChapter: reference.endChapter,
        endVerse: endVerse,
      );
    }

    return PlanReading(
      bookId: reference.bookId,
      chapter: reference.chapter,
      verse: verse,
      endVerse: endVerse == verse ? null : endVerse,
    );
  }

  bool get wholeBook => chapter == null;

  int get _lastChapter => endChapter ?? chapter ?? 1;

  /// Schreibweise des Planformats, z. B. `GEN 1-3`.
  String get key {
    final c = chapter;

    if (c == null) return bookId;

    final v = verse;

    if (v == null) {
      return endChapter == null ? "$bookId $c" : "$bookId $c-$endChapter";
    }

    if (endChapter != null) return "$bookId $c:$v-$endChapter:$endVerse";

    return endVerse == null ? "$bookId $c:$v" : "$bookId $c:$v-$endVerse";
  }

  /// Deutsche Anzeige, z. B. „Gen 1–3“ oder „Joel“.
  String get label {
    final c = chapter;

    if (c == null) return BibleBooks.nameOf(bookId);

    final book = BibleBooks.abbreviationOf(bookId);
    final v = verse;

    if (v == null) {
      return endChapter == null ? "$book $c" : "$book $c–$endChapter";
    }

    if (endChapter != null) return "$book $c,$v–$endChapter,$endVerse";

    return endVerse == null ? "$book $c,$v" : "$book $c,$v–$endVerse";
  }

  /// Die Stelle für den Reader. Ein ganzes Buch beginnt bei Kapitel 1 und
  /// reicht so weit, wie die jeweilige Ausgabe zählt.
  BibleReference get reference {
    final c = chapter;

    if (c == null) {
      return BibleReference(bookId: bookId, chapter: 1, endChapter: 999);
    }

    return BibleReference(
      bookId: bookId,
      chapter: c,
      verse: verse,
      endChapter: endChapter,
      endVerse: verse == null ? null : (endVerse ?? verse),
    );
  }

  /// Warum es die Lesung in [translation] nicht gibt; `null`, wenn sie sich
  /// dort aufschlagen lässt.
  String? problemInTranslation(BibleTranslation translation) {
    final resolved = BibleBooks.resolveIn(translation, bookId);

    if (resolved == null) return "Das Buch $bookId fehlt.";

    final book = translation.book(resolved)!;
    final c = chapter;

    if (c == null) return null;

    final name = BibleBooks.nameOf(bookId);

    for (final number in {c, _lastChapter}) {
      if (number > book.chapterCount) {
        return "$name hat kein Kapitel $number.";
      }
    }

    final v = verse;

    if (v == null) return null;

    if (v > book.verseCount(c)) return "$name $c hat keinen Vers $v.";

    final last = endVerse ?? v;

    if (last > book.verseCount(_lastChapter)) {
      return "$name $_lastChapter hat keinen Vers $last.";
    }

    return null;
  }

  /// Warum die Lesung ungültig ist; `null`, wenn mindestens eine der
  /// [translations] sie enthält. Die Ausgaben zählen teilweise verschieden,
  /// deshalb genügt eine.
  String? problemIn(List<BibleTranslation> translations) {
    if (BibleBooks.byId(bookId) == null) {
      return "Unbekanntes Buch „$bookId“.";
    }

    String? first;

    for (final translation in translations) {
      if (BibleBooks.resolveIn(translation, bookId) == null) continue;

      final problem = problemInTranslation(translation);

      if (problem == null) return null;

      first ??= problem;
    }

    return first ?? "Keine Bibelausgabe der App enthält das Buch $bookId.";
  }

  /// Kapitel und Verse der Lesung nach der ersten der [translations], die
  /// sie enthält (für die Angabe des täglichen Umfangs).
  ({int chapters, int verses}) extentIn(List<BibleTranslation> translations) {
    for (final translation in translations) {
      if (problemInTranslation(translation) != null) continue;

      final book = translation.book(
        BibleBooks.resolveIn(translation, bookId)!,
      )!;

      final first = chapter ?? 1;
      final last = chapter == null ? book.chapterCount : _lastChapter;

      var verses = 0;

      for (var c = first; c <= last; c++) {
        verses += book.verseCount(c);
      }

      final v = verse;

      if (v != null) {
        verses -= v - 1;
        verses -= book.verseCount(last) - (endVerse ?? v);
      }

      return (chapters: last - first + 1, verses: verses);
    }

    return (chapters: 0, verses: 0);
  }

  @override
  bool operator ==(Object other) => other is PlanReading && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// Ein Tag eines Leseplans mit seinen Lesungen.
class ReadingPlanDay {
  /// Optionale Überschrift, z. B. „Bergpredigt“.
  final String? title;

  final List<PlanReading> readings;

  const ReadingPlanDay({required this.readings, this.title});
}

/// Wie anspruchsvoll ein Plan nach eigener Angabe ist.
enum ReadingPlanDifficulty {
  easy("Einstieg"),
  moderate("Moderat"),
  demanding("Anspruchsvoll"),
  intensive("Sehr intensiv"),
  extreme("Extrem");

  final String label;

  const ReadingPlanDifficulty(this.label);

  static ReadingPlanDifficulty? parse(Object? value) {
    for (final d in values) {
      if (d.name == value) return d;
    }

    return null;
  }
}

/// Täglicher Umfang eines Plans.
class ReadingPlanExtent {
  final int chapters;
  final int verses;
  final int days;

  /// Verse des umfangreichsten Tages.
  final int maxVersesPerDay;

  const ReadingPlanExtent({
    required this.chapters,
    required this.verses,
    required this.days,
    required this.maxVersesPerDay,
  });

  /// Grobe Lesegeschwindigkeit: Die ganze Bibel (rund 31 000 Verse) braucht
  /// still gelesen etwa 60 Stunden.
  static const double versesPerMinute = 9;

  double get chaptersPerDay => days == 0 ? 0 : chapters / days;

  int get minutesPerDay =>
      days == 0 ? 0 : (verses / days / versesPerMinute).round();

  int get maxMinutesPerDay => (maxVersesPerDay / versesPerMinute).round();

  /// Ab hier warnt die App vor dem Start ausdrücklich.
  bool get isIntensive => minutesPerDay >= 30;

  bool get isExtreme => minutesPerDay >= 75;

  static String formatMinutes(int minutes) {
    if (minutes < 60) return "ca. ${minutes < 1 ? 1 : minutes} Min.";

    final hours = minutes / 60;
    final rounded = (hours * 2).round() / 2;

    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1).replaceAll(".", ",");

    return "ca. $text Std.";
  }

  String get chaptersPerDayText {
    final value = chaptersPerDay;

    if (value >= 10) return "${value.round()}";

    final text = value.toStringAsFixed(1).replaceAll(".", ",");

    return text.endsWith(",0") ? text.substring(0, text.length - 2) : text;
  }

  /// Z. B. „Ø 3,3 Kapitel · ca. 9 Min. am Tag“.
  String get summary =>
      "Ø $chaptersPerDayText Kapitel · ${formatMinutes(minutesPerDay)} am Tag";
}

/// Ein Bibelleseplan: Tage mit Lesungen, unabhängig von einer Ausgabe.
///
/// Integrierte Pläne liegen unter `assets/reading_plans/`, eigene werden im
/// selben Format importiert (`ReadingPlanCodec`, `docs/reading-plans.md`).
class ReadingPlan {
  /// Stabile Kennung; an ihr hängt der gespeicherte Fortschritt.
  final String id;

  final String name;
  final String description;

  /// Sprache von Name und Beschreibung (`de`, `en`, …).
  final String language;

  /// Frei wählbar; bekannte Werte siehe [categoryLabels].
  final String? category;

  final ReadingPlanDifficulty? difficulty;

  final String? sourceName;
  final String? sourceUrl;
  final String? sourceNote;

  /// Lizenz bzw. Nutzungsbedingungen des Plans (nicht des Bibeltexts).
  final String? license;

  final List<ReadingPlanDay> days;

  /// Mit der App ausgeliefert (nicht löschbar).
  final bool builtIn;

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.days,
    this.description = "",
    this.language = "de",
    this.category,
    this.difficulty,
    this.sourceName,
    this.sourceUrl,
    this.sourceNote,
    this.license,
    this.builtIn = false,
  });

  static const Map<String, String> categoryLabels = {
    "whole-bible": "Ganze Bibel",
    "old-testament": "Altes Testament",
    "new-testament": "Neues Testament",
    "gospels": "Evangelien",
    "psalms": "Psalmen",
    "topical": "Thema",
    "custom": "Eigener Plan",
  };

  String? get categoryLabel {
    final value = category;

    return value == null ? null : categoryLabels[value] ?? value;
  }

  int get dayCount => days.length;

  int get readingCount {
    var count = 0;

    for (final day in days) {
      count += day.readings.length;
    }

    return count;
  }

  /// Lesungen von Tag [day] (ab 1); leer, wenn es den Tag nicht gibt.
  List<PlanReading> readingsOn(int day) {
    return day < 1 || day > days.length ? const [] : days[day - 1].readings;
  }

  ReadingPlanExtent extentIn(List<BibleTranslation> translations) {
    var chapters = 0;
    var verses = 0;
    var maxVerses = 0;

    for (final day in days) {
      var dayVerses = 0;

      for (final reading in day.readings) {
        final extent = reading.extentIn(translations);

        chapters += extent.chapters;
        dayVerses += extent.verses;
      }

      verses += dayVerses;

      if (dayVerses > maxVerses) maxVerses = dayVerses;
    }

    return ReadingPlanExtent(
      chapters: chapters,
      verses: verses,
      days: days.length,
      maxVersesPerDay: maxVerses,
    );
  }
}
