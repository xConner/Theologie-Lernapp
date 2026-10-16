import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'book_catalog.dart';

/// Eine Stelle als Abschnittsgrenze: Kapitel, optional mit Vers.
///
/// Als Anfang bedeutet ein fehlender Vers „ab Vers 1“, als Ende „bis zum
/// Kapitelende“. So lassen sich Abschnitte kapitel- oder versgenau abgrenzen.
class OutlinePosition {
  final int chapter;
  final int? verse;

  const OutlinePosition(this.chapter, [this.verse]);

  /// Liest „5“ oder „6,6“; sonst `null`.
  static OutlinePosition? parse(Object? raw) {
    if (raw is num) {
      return raw >= 1 ? OutlinePosition(raw.toInt()) : null;
    }

    if (raw is! String) return null;

    final match = RegExp(r'^\s*(\d+)\s*(?:,\s*(\d+))?\s*$').firstMatch(raw);

    if (match == null) return null;

    final chapter = int.parse(match.group(1)!);
    final verse = match.group(2) == null ? null : int.parse(match.group(2)!);

    if (chapter < 1 || (verse != null && verse < 1)) return null;

    return OutlinePosition(chapter, verse);
  }

  String get text => verse == null ? "$chapter" : "$chapter,$verse";

  int get _startKey => chapter * 10000 + (verse ?? 0);
  int get _endKey => chapter * 10000 + (verse ?? 9999);
}

/// Ein Lernabschnitt eines Buchs, z. B. „Wirken in Galiläa“.
class OutlineSection {
  /// Eindeutig innerhalb der Gliederungen; Grundlage für spätere Verweise.
  final String id;

  final String book;

  final String title;

  final OutlinePosition start;
  final OutlinePosition end;

  /// Nur für den Sammelabschnitt „Weitere Perikopen“: die Perikopen
  /// ([BookPericope.key]), die keinem hinterlegten Abschnitt angehören.
  final Set<String>? members;

  const OutlineSection({
    required this.id,
    required this.book,
    required this.title,
    required this.start,
    required this.end,
    this.members,
  });

  /// Ob eine Stelle, die bei [chapter],[verse] beginnt, in den Abschnitt
  /// fällt. Perikopen werden nach ihrem Anfang zugeordnet, damit jede genau
  /// in einen Abschnitt kommt, auch wenn sie über die Grenze hinausreicht.
  bool containsStart(int chapter, int verse) {
    final key = chapter * 10000 + verse;

    return key >= start._startKey && key <= end._endKey;
  }

  bool contains(BookPericope p) {
    if (p.book != book) return false;

    final keys = members;

    if (keys != null) return keys.contains(p.key);

    return containsStart(p.perikope.startChapter, p.perikope.startVerse);
  }

  /// Bereich in Quiz-Schreibweise, z. B. „1,14–3,6“ oder „Kapitel 11–13“.
  String get rangeText {
    if (start.verse == null && end.verse == null) {
      return start.chapter == end.chapter
          ? "Kapitel ${start.chapter}"
          : "Kapitel ${start.chapter}–${end.chapter}";
    }

    return "${start.text}–${end.text}";
  }
}

/// Die Gliederung eines Buchs: Abschnitte in Lernreihenfolge.
class BookOutline {
  final String book;

  final List<OutlineSection> sections;

  /// Aus `assets/book_outlines.json` als vorläufig gekennzeichnet.
  final bool provisional;

  /// Ohne hinterlegte Gliederung automatisch nach Kapiteln gebildet.
  final bool automatic;

  /// Herkunft bzw. Hinweis aus den Daten.
  final String? note;

  const BookOutline({
    required this.book,
    required this.sections,
    this.provisional = false,
    this.automatic = false,
    this.note,
  });
}

/// Alle hinterlegten Buchgliederungen.
///
/// Die Gliederungen stehen zentral in `assets/book_outlines.json` und lassen
/// sich dort ergänzen oder austauschen, ohne den Lernmodus zu ändern:
///
/// ```json
/// {"books": {"Mk": {"provisional": true, "note": "…", "sections": [
///   {"id": "mk-1", "title": "…", "start": "1,1", "end": "1,13"}, …]}}}
/// ```
///
/// `start`/`end` sind „Kapitel“ oder „Kapitel,Vers“ (deutsche Zählung der
/// Perikopenliste). Für Bücher ohne Eintrag bildet [outlineFor] eine
/// automatische Gliederung nach Kapiteln.
class BookOutlines {
  static const String asset = "assets/book_outlines.json";

  final Map<String, BookOutline> _defined;

  const BookOutlines(this._defined);

  static const BookOutlines empty = BookOutlines({});

  bool hasDefined(String book) => _defined.containsKey(book);

  /// Liest die Datei. Ungültige Abschnitte (fehlende Felder, Ende vor
  /// Anfang, doppelte IDs) werden übergangen und protokolliert, damit ein
  /// Fehler in einem Buch die übrigen nicht verhindert.
  factory BookOutlines.fromJson(Map<String, dynamic> json) {
    final result = <String, BookOutline>{};

    final ids = <String>{};

    final books = json["books"];

    if (books is! Map) return BookOutlines.empty;

    for (final entry in books.entries) {
      final book = entry.key.toString();
      final raw = entry.value;

      if (raw is! Map || raw["sections"] is! List) continue;

      final sections = <OutlineSection>[];

      for (final s in raw["sections"] as List) {
        if (s is! Map) continue;

        final id = s["id"];
        final title = s["title"];
        final start = OutlinePosition.parse(s["start"]);
        final end = OutlinePosition.parse(s["end"]);

        if (id is! String ||
            id.isEmpty ||
            title is! String ||
            start == null ||
            end == null ||
            end._endKey < start._startKey ||
            !ids.add(id)) {
          debugPrint("Ungültiger Gliederungsabschnitt in $book: $s");
          continue;
        }

        sections.add(
          OutlineSection(
            id: id,
            book: book,
            title: title,
            start: start,
            end: end,
          ),
        );
      }

      if (sections.isEmpty) continue;

      result[book] = BookOutline(
        book: book,
        sections: sections,
        provisional: raw["provisional"] == true,
        note: raw["note"] is String ? raw["note"] as String : null,
      );
    }

    return BookOutlines(result);
  }

  /// Lädt die Gliederungen; fehlt die Datei oder ist sie defekt, gibt es nur
  /// automatische Gliederungen.
  static Future<BookOutlines> load({AssetBundle? bundle}) async {
    try {
      final data = await (bundle ?? rootBundle).loadString(asset);

      return BookOutlines.fromJson(
        Map<String, dynamic>.from(jsonDecode(data) as Map),
      );
    } catch (e) {
      debugPrint("Buchgliederungen nicht geladen: $e");
      return BookOutlines.empty;
    }
  }

  /// Gliederung für [book]: die hinterlegte, ergänzt um einen Abschnitt für
  /// Perikopen, die keinem Abschnitt zugeordnet sind; sonst automatisch.
  BookOutline outlineFor(BookCatalog catalog, String book) {
    final defined = _defined[book];

    if (defined == null) return automatic(catalog, book);

    final pericopes = catalog.pericopesOf(book);

    final uncovered = pericopes
        .where((p) => !defined.sections.any((s) => s.contains(p)))
        .toList();

    if (uncovered.isEmpty) return defined;

    return BookOutline(
      book: book,
      provisional: defined.provisional,
      note: defined.note,
      sections: [
        ...defined.sections,
        OutlineSection(
          id: "$book-uncovered",
          book: book,
          title: "Weitere Perikopen",
          start: OutlinePosition(uncovered.first.chapter),
          end: OutlinePosition(uncovered.last.chapter),
          members: {for (final p in uncovered) p.key},
        ),
      ],
    );
  }

  /// Ungefähr so viele Perikopen fasst ein automatischer Abschnitt.
  static const int automaticSize = 10;

  /// Automatische Gliederung: aufeinanderfolgende ganze Kapitel, bis ein
  /// Abschnitt etwa [automaticSize] Perikopen hat. Keine inhaltliche
  /// Aussage – nur handliche Lerneinheiten in Buchreihenfolge.
  static BookOutline automatic(BookCatalog catalog, String book) {
    final chapters = catalog.chaptersOf(book);

    final sections = <OutlineSection>[];

    int? from;
    int count = 0;

    void close(int to) {
      sections.add(
        OutlineSection(
          id: "$book-auto-$from",
          book: book,
          title: from == to ? "Kapitel $from" : "Kapitel $from–$to",
          start: OutlinePosition(from!),
          end: OutlinePosition(to),
        ),
      );
      from = null;
      count = 0;
    }

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];

      from ??= chapter;
      count += catalog.inChapters(book, chapter, chapter).length;

      final last = i == chapters.length - 1;

      if (count >= automaticSize || last) close(chapter);
    }

    return BookOutline(book: book, sections: sections, automatic: true);
  }
}

/// Perikopen eines Abschnitts in Buchreihenfolge.
List<BookPericope> pericopesOfSection(
  BookCatalog catalog,
  OutlineSection section,
) {
  return [
    for (final p in catalog.pericopesOf(section.book))
      if (section.contains(p)) p,
  ];
}
