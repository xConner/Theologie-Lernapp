import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/philosophy/reading_text.dart';
import '../../models/philosophy/reading_work.dart';
import 'private_edition_store.dart';

/// Lädt Werkverzeichnis und Texte des Lesebereichs: ausgelieferte Ausgaben
/// aus `assets/philosophy/`, private Ausgaben aus dem [PrivateEditionStore].
class ReadingRepository {
  final AssetBundle? bundle;

  ReadingRepository({this.bundle});

  static const String catalogAsset = "assets/philosophy/works.json";

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<List<ReadingWork>>? _works;
  final Map<String, Future<ReadingText>> _bundled = {};

  Future<List<ReadingWork>> works() {
    return _works ??= _assets.loadString(catalogAsset, cache: false).then((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      return [
        for (final w in json["works"] as List)
          ReadingWork.fromJson(w as Map<String, dynamic>),
      ];
    });
  }

  Future<ReadingWork> work(String id) async {
    for (final w in await works()) {
      if (w.id == id) return w;
    }
    throw StateError("Unbekanntes Werk: $id");
  }

  /// Text einer mitgelieferten Ausgabe.
  Future<ReadingText> bundled(ReadingWork work, ReadingEdition edition) {
    assert(edition.kind == EditionKind.bundled);
    return _bundled["${work.id}/${edition.id}"] ??= () async {
      final books = <ReadingBook>[];
      for (final n in edition.books) {
        final raw = await _assets.loadString(
          "${edition.path}/book-$n.json",
          cache: false,
        );
        books.add(ReadingBook.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      }
      return ReadingText(work: work, edition: edition, books: books);
    }();
  }

  /// Text einer privaten Ausgabe, falls importiert.
  Future<ReadingText?> private(
    ReadingWork work,
    ReadingEdition edition,
    PrivateEditionStore store,
  ) async {
    final data = await store.load(edition.id);
    if (data == null) return null;
    return ReadingText.fromEditionJson(work, edition, data);
  }

  /// Formenindex des Werks (siehe `tool/philosophy/build_form_index.dart`).
  Future<Map<String, dynamic>?> forms(ReadingWork work) async {
    final path = work.formsAsset;
    if (path == null) return null;
    try {
      return jsonDecode(await _assets.loadString(path, cache: false))
          as Map<String, dynamic>;
    } on FlutterError {
      return null;
    }
  }

  Future<List<SeminarSession>> seminar(ReadingWork work) async {
    final path = work.seminarAsset;
    if (path == null) return const [];
    final json =
        jsonDecode(await _assets.loadString(path, cache: false))
            as Map<String, dynamic>;
    return [
      for (final s in json["sessions"] as List)
        SeminarSession.fromJson(s as Map<String, dynamic>),
    ];
  }
}

/// Ein geladener Text (eine Ausgabe eines Werks) mit den Verknüpfungen
/// zwischen Sätzen, Anmerkungen und Einleitung.
class ReadingText {
  final ReadingWork work;
  final ReadingEdition edition;
  final List<ReadingBook> books;
  final EditionFront front;

  ReadingText({
    required this.work,
    required this.edition,
    required this.books,
    this.front = EditionFront.empty,
  }) {
    for (final book in books) {
      for (final chapter in book.chapters) {
        _chapters.add(chapter);
        for (final unit in chapter.units) {
          _unitById[unit.id] = unit;
          _chapterOfUnit[unit.id] = chapter;
          for (final s in unit.greek) {
            _sentenceById[s.id] = s;
            _unitOfSentence[s.id] = unit;
          }
        }
      }
      for (final note in book.notes) {
        _bookOfNote[note.id] = book.number;
      }
    }
  }

  /// Liest eine private Ausgabe (Format von
  /// `tool/philosophy/import_heinemann_physics.py`).
  factory ReadingText.fromEditionJson(
    ReadingWork work,
    ReadingEdition edition,
    Map<String, dynamic> json,
  ) {
    return ReadingText(
      work: work,
      edition: edition,
      books: [
        for (final b in json["books"] as List)
          ReadingBook.fromJson(b as Map<String, dynamic>),
      ],
      front: EditionFront.fromJson(json),
    );
  }

  final List<ReadingChapter> _chapters = [];
  final Map<String, ReadingUnit> _unitById = {};
  final Map<String, ReadingChapter> _chapterOfUnit = {};
  final Map<String, GreekSentence> _sentenceById = {};
  final Map<String, ReadingUnit> _unitOfSentence = {};
  final Map<String, int> _bookOfNote = {};

  List<ReadingChapter> get chapters => _chapters;

  bool get hasGerman => edition.hasGerman;

  ReadingBook? book(int number) {
    for (final b in books) {
      if (b.number == number) return b;
    }
    return null;
  }

  ReadingChapter? chapter(String id) {
    for (final c in _chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  ReadingUnit? unit(String id) => _unitById[id];

  GreekSentence? sentence(String id) => _sentenceById[id];

  ReadingUnit? unitOfSentence(String sentenceId) =>
      _unitOfSentence[sentenceId];

  ReadingChapter? chapterOfUnit(String unitId) => _chapterOfUnit[unitId];

  ReadingChapter? chapterOfSentence(String sentenceId) {
    final unit = _unitOfSentence[sentenceId];
    return unit == null ? null : _chapterOfUnit[unit.id];
  }

  int indexOfChapter(ReadingChapter chapter) => _chapters.indexOf(chapter);

  /// Kapitel, das die Stelle enthält (bzw. das letzte davor).
  ReadingChapter? chapterAt(BekkerRef ref) {
    ReadingChapter? found;
    for (final c in _chapters) {
      if (c.units.first.ref <= ref) found = c;
    }
    return found;
  }

  /// Satz, in dem die Stelle liegt (bzw. der letzte, der davor beginnt).
  GreekSentence? sentenceAt(BekkerRef ref) {
    GreekSentence? found;
    for (final c in _chapters) {
      for (final s in c.sentences) {
        if (s.ref <= ref) {
          found = s;
        } else {
          return found;
        }
      }
    }
    return found;
  }

  /// Ein Satz zu einer gespeicherten Kennung – auch aus einer anderen
  /// Ausgabe (gleiche Bekker-Stelle bzw. nächstgelegener Satz).
  GreekSentence? resolveSentence(String id) {
    final direct = _sentenceById[id];
    if (direct != null) return direct;
    final ref = BekkerRef.tryParse(id.split(".").first);
    return ref == null ? null : sentenceAt(ref);
  }

  // ---------------------------------------------------------------------------
  // Anmerkungen
  // ---------------------------------------------------------------------------

  /// Anmerkungen eines Satzes: alle Anmerkungen des Buchs, deren
  /// Zeilenbereich den Satz berührt, und Fußnoten zur Übersetzung des
  /// Abschnitts. Reihenfolge: Textkritik, Anmerkungen, Fußnoten.
  List<EditionNote> notesForSentence(GreekSentence sentence) {
    final chapter = chapterOfSentence(sentence.id);
    final book = chapter == null ? null : this.book(chapter.book);
    if (book == null) return const [];
    final unit = _unitOfSentence[sentence.id];
    final result = <EditionNote>[
      for (final n in book.notes)
        if (n.range != null && n.range!.overlaps(sentence.range)) n,
      for (final n in book.notes)
        if (n.kind == EditionNoteKind.translator &&
            n.unitId != null &&
            n.unitId == unit?.id &&
            unit?.greek.first.id == sentence.id)
          n,
    ];
    result.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return result;
  }

  List<EditionNote> notesForUnit(ReadingUnit unit) {
    final seen = <String>{};
    return [
      for (final s in unit.greek)
        for (final n in notesForSentence(s))
          if (seen.add(n.id)) n,
    ];
  }

  /// Wie viele Anmerkungen je Art ein Satz hat (für die dezente Markierung
  /// im Lesetext).
  bool hasTextCritical(GreekSentence s) => notesForSentence(
    s,
  ).any((n) => n.kind == EditionNoteKind.textCritical);

  List<EditionNote> get allNotes => [for (final b in books) ...b.notes];

  EditionNote? note(String id) {
    for (final b in books) {
      for (final n in b.notes) {
        if (n.id == id) return n;
      }
    }
    return null;
  }

  /// Anmerkung des Herausgebers, auf die „Anm. zu …“ verweist.
  EditionNote? editorNoteAt(BekkerRef ref) {
    EditionNote? containing;
    for (final b in books) {
      for (final n in b.notes) {
        if (n.kind != EditionNoteKind.editor || n.range == null) continue;
        if (n.range!.from == ref) return n;
        if (containing == null && n.range!.contains(ref)) containing = n;
      }
    }
    return containing;
  }

  /// Abschnitte der Einleitung, die die Stelle des Satzes ausdrücklich
  /// zitieren („Phys. I 1, 184a14–16“).
  List<IntroCitation> citationsFor(GreekSentence sentence) => [
    for (final c in front.citations)
      if (c.range.overlaps(sentence.range)) c,
  ];

  /// Sätze im Bereich (für den Sprung aus einer Anmerkung zum Text).
  List<GreekSentence> sentencesIn(BekkerRange range) => [
    for (final c in _chapters)
      for (final s in c.sentences)
        if (s.range.overlaps(range)) s,
  ];
}
