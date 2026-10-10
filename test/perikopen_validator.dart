import 'package:theologie_lernapp/models/bible/bible_translation.dart';
import 'package:theologie_lernapp/services/bible/bible_books.dart';

/// Ein Befund der Prüfung: Datei, Datensatz und Stelle, dazu was nicht
/// stimmt.
class PericopeIssue {
  final String file;
  final String id;
  final String reference;

  /// Art des Befunds, z. B. `vers-fehlt`.
  final String code;

  final String message;

  const PericopeIssue({
    required this.file,
    required this.id,
    required this.reference,
    required this.code,
    required this.message,
  });

  @override
  String toString() => "$file: „$id“ ($reference) – $message [$code]";
}

/// Eine bewusst zugelassene Abweichung von einer Prüfregel.
class PericopeException {
  final String id;
  final String code;

  /// Warum der Datensatz trotzdem richtig ist.
  final String reason;

  const PericopeException(this.id, this.code, this.reason);
}

/// Prüft die Perikopenliste (`assets/perikopen.json`) gegen die Verszahlen
/// der integrierten Bibelausgaben.
///
/// Die Liste zählt deutsch (Einteilung der Einheitsübersetzung). Maßstab
/// sind deshalb die deutsch gezählten Ausgaben; für die Zusätze zu Daniel
/// und Ester, die keine deutsche Ausgabe enthält, zusätzlich die Vulgata.
/// Bei den Apokryphen lassen sich nur die Kapitel prüfen: Keine integrierte
/// Ausgabe zählt ihre Verse wie die Liste.
///
/// Fehler sind:
///
/// * `schema` – fehlende oder falsch belegte Felder;
/// * `buch` – unbekannte Buchabkürzung;
/// * `reihenfolge-in-stelle` – Anfang hinter dem Ende, Kapitel oder Vers
///   kleiner als 1;
/// * `kapitel-fehlt`, `vers-fehlt` – die Stelle gibt es in keiner
///   maßgeblichen Ausgabe;
/// * `doppelt` – dieselbe ID nennt im selben Buch zwei Stellen, die sich
///   überschneiden (widersprüchliche Angaben zu einer Stelle);
/// * `kapitelfrage` – ein Eintrag „Ex 3“ umfasst nicht genau sein Kapitel;
/// * `psalm` – ein Psalm endet vor seinem letzten Vers;
/// * `ueberschneidung` – eine Perikope beginnt mitten in der vorigen, ohne
///   ein Unterabschnitt von ihr zu sein, oder steht außerhalb der
///   Reihenfolge.
///
/// Ausdrücklich **keine** Fehler sind:
///
/// * Lücken zwischen zwei Perikopen – die Einteilung lässt einzelne Verse
///   (Buchüberschriften, Überleitungen) bewusst ohne eigene Perikope;
///   [gaps] listet sie nur auf;
/// * eine Perikope, die mit dem Vers beginnt, mit dem die vorige endet
///   (Grenze im Vers, z. B. Mk 6,6a/6b);
/// * ein Unterabschnitt, der am Anfang eines übergeordneten Abschnitts
///   einsetzt (Mt 5,1–7,29 und darin 5,3–12);
/// * dieselbe ID an mehreren Stellen (Parallelen), solange sie sich nicht
///   überschneiden.
class PericopeValidator {
  final String file;

  final List<BibleTranslation> translations;

  final List<PericopeException> exceptions;

  PericopeValidator({
    required this.translations,
    this.file = "assets/perikopen.json",
    this.exceptions = knownExceptions,
  });

  /// Zulässige Abweichungen in der ausgelieferten Liste.
  static const List<PericopeException> knownExceptions = [
    PericopeException(
      "die_zweite_volkszaehlung",
      "vers-fehlt",
      "Num 25,19 zählt nur die Einheitsübersetzung; die integrierten "
          "deutschen Ausgaben führen den Vers als 26,1.",
    ),
    PericopeException(
      "die_seligpreisungen",
      "ueberschneidung",
      "Unterabschnitt der Bergpredigt (Mt 5,1–7,29); Mt 5,1–2 leiten sie "
          "ein und haben keine eigene Perikope.",
    ),
    PericopeException(
      "der_friedenskoenig_und_sein_reich",
      "psalm",
      "Ps 72,20 ist die Schlussnotiz des zweiten Psalmenbuchs und gehört "
          "nicht zum Psalm.",
    ),
  ];

  static const Set<String> _fields = {
    "id",
    "title",
    "book",
    "startChapter",
    "startVerse",
    "endChapter",
    "endVerse",
    "required",
    "precision",
  };

  // Kapitelangabe hinter der Buchabkürzung, z. B. „3“ (wie in
  // `PericopeHeadings`).
  static final RegExp _chapterTitle = RegExp(r'^\S+ (\d+)$');

  static String referenceOf(Map<String, dynamic> e) =>
      "${e["book"]} ${e["startChapter"]},${e["startVerse"]}–"
      "${e["endChapter"]},${e["endVerse"]}";

  /// Das Buch in den deutsch gezählten Ausgaben.
  List<BibleBookInfo> _german(String bookId) => [
    for (final t in translations)
      if (t.versification == BibleVersification.german) ?t.book(bookId),
  ];

  /// Die Ausgaben, an denen Stellen aus [bookId] gemessen werden.
  List<BibleBookInfo> _references(String bookId) {
    final german = _german(bookId);

    // Zusätze zu Daniel und Ester und die Apokryphen stehen nur in der
    // Vulgata in der Zählung der Liste.
    if (german.isEmpty || bookId == "DAN" || bookId == "EST") {
      return [
        ...german,
        for (final t in translations)
          if (t.versification == BibleVersification.vulgate) ?t.book(bookId),
      ];
    }

    return german;
  }

  bool _allowed(String id, String code) =>
      exceptions.any((e) => e.id == id && e.code == code);

  /// Alle Befunde zu [entries] (den Einträgen der JSON-Datei in ihrer
  /// Reihenfolge).
  List<PericopeIssue> validate(List<dynamic> entries) {
    final issues = <PericopeIssue>[];

    void report(Map<String, dynamic> e, String code, String message) {
      final id = "${e["id"]}";

      if (_allowed(id, code)) return;

      issues.add(
        PericopeIssue(
          file: file,
          id: id,
          reference: referenceOf(e),
          code: code,
          message: message,
        ),
      );
    }

    // Einträge mit gültigem Aufbau und bekannter, in sich stimmiger Stelle.
    final sound = <Map<String, dynamic>>[];

    for (final raw in entries) {
      if (raw is! Map) {
        issues.add(
          PericopeIssue(
            file: file,
            id: "?",
            reference: "$raw",
            code: "schema",
            message: "Der Eintrag ist kein Objekt.",
          ),
        );
        continue;
      }

      final e = Map<String, dynamic>.from(raw);

      final missing = _fields.difference(e.keys.toSet());
      final unknown = e.keys.toSet().difference(_fields);

      final numbers = [
        "startChapter",
        "startVerse",
        "endChapter",
        "endVerse",
      ].every((k) => e[k] is int);

      if (missing.isNotEmpty ||
          unknown.isNotEmpty ||
          !numbers ||
          e["id"] is! String ||
          (e["id"] as String).isEmpty ||
          e["title"] is! String ||
          (e["title"] as String).trim().isEmpty ||
          e["book"] is! String ||
          e["required"] is! bool ||
          !const ["chapter", "verse"].contains(e["precision"])) {
        report(
          e,
          "schema",
          "Felder fehlen oder sind falsch belegt"
              "${missing.isEmpty ? "" : " (fehlt: ${missing.join(", ")})"}"
              "${unknown.isEmpty ? "" : " (unbekannt: ${unknown.join(", ")})"}"
              ".",
        );
        continue;
      }

      final book = BibleBooks.byAbbreviation(e["book"]);

      if (book == null) {
        report(e, "buch", "Das Buch „${e["book"]}“ ist nicht bekannt.");
        continue;
      }

      final int startChapter = e["startChapter"];
      final int startVerse = e["startVerse"];
      final int endChapter = e["endChapter"];
      final int endVerse = e["endVerse"];

      if (startChapter < 1 ||
          startVerse < 1 ||
          endChapter < 1 ||
          endVerse < 1 ||
          endChapter < startChapter ||
          (endChapter == startChapter && endVerse < startVerse)) {
        report(
          e,
          "reihenfolge-in-stelle",
          "Der Anfang liegt hinter dem Ende, oder Kapitel bzw. Vers sind "
              "kleiner als 1.",
        );
        continue;
      }

      final references = _references(book.id);

      if (references.isEmpty) {
        report(
          e,
          "buch",
          "Keine Ausgabe enthält „${e["book"]}“; die Stelle lässt sich nicht "
              "prüfen.",
        );
        continue;
      }

      if (!references.any((r) => endChapter <= r.chapterCount)) {
        report(
          e,
          "kapitel-fehlt",
          "${e["book"]} hat kein Kapitel $endChapter "
              "(${references.map((r) => r.chapterCount).toSet().join(" bzw. ")} "
              "Kapitel).",
        );
        continue;
      }

      // Die Apokryphen zählt die Vulgata versweise anders als die Liste
      // (Tobit und Judit folgen dort einer anderen Textfassung). Ohne
      // deutsch gezählte Ausgabe sind nur die Kapitel prüfbar.
      final exists =
          _german(book.id).isEmpty ||
          references.any(
            (r) =>
                startVerse <= r.verseCount(startChapter) &&
                endVerse <= r.verseCount(endChapter),
          );

      if (!exists) {
        String counts(int chapter) => references
            .map((r) => r.verseCount(chapter))
            .where((n) => n > 0)
            .toSet()
            .join(" bzw. ");

        final bad = references.every((r) => endVerse > r.verseCount(endChapter))
            ? (chapter: endChapter, verse: endVerse)
            : (chapter: startChapter, verse: startVerse);

        report(
          e,
          "vers-fehlt",
          "Vers ${bad.verse} gibt es in ${e["book"]} ${bad.chapter} nicht "
              "(${counts(bad.chapter)} Verse).",
        );
        continue;
      }

      sound.add(e);
    }

    _checkDuplicates(sound, report);
    _checkWholeChapters(sound, report);
    _checkSequence(sound, report);

    return issues;
  }

  static (int, int) _start(Map<String, dynamic> e) =>
      (e["startChapter"] as int, e["startVerse"] as int);

  static (int, int) _end(Map<String, dynamic> e) =>
      (e["endChapter"] as int, e["endVerse"] as int);

  static int _compare((int, int) a, (int, int) b) =>
      a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);

  /// Kapitelfrage des Quiz („Ex 3“): das Kapitel, sonst `null`.
  static int? chapterQuestion(Map<String, dynamic> e) {
    final title = (e["title"] as String).trim();

    final match = _chapterTitle.firstMatch(title);

    if (match == null || !title.startsWith("${e["book"]} ")) return null;

    return int.parse(match.group(1)!);
  }

  void _checkDuplicates(
    List<Map<String, dynamic>> entries,
    void Function(Map<String, dynamic>, String, String) report,
  ) {
    final seen = <String, List<Map<String, dynamic>>>{};

    for (final e in entries) {
      final others = seen.putIfAbsent("${e["id"]}|${e["book"]}", () => []);

      for (final other in others) {
        if (_compare(_start(e), _end(other)) <= 0 &&
            _compare(_start(other), _end(e)) <= 0) {
          report(
            e,
            "doppelt",
            "Dieselbe ID nennt in ${e["book"]} bereits "
                "${referenceOf(other)}; die Stellen überschneiden sich.",
          );
          break;
        }
      }

      others.add(e);
    }
  }

  void _checkWholeChapters(
    List<Map<String, dynamic>> entries,
    void Function(Map<String, dynamic>, String, String) report,
  ) {
    for (final e in entries) {
      // Die Apokryphen zählt die Vulgata versweise anders als die Liste;
      // ohne deutsch gezählte Ausgabe lässt sich das Kapitelende nicht
      // prüfen.
      final german = _german(BibleBooks.byAbbreviation(e["book"])!.id);

      final chapter = chapterQuestion(e);

      final endsWithChapter =
          german.isEmpty ||
          german.any((r) => r.verseCount(e["endChapter"]) == e["endVerse"]);

      String verses(int chapter) =>
          german.map((r) => r.verseCount(chapter)).toSet().join(" bzw. ");

      if (chapter != null) {
        if (e["startChapter"] != chapter ||
            e["endChapter"] != chapter ||
            e["startVerse"] != 1 ||
            !endsWithChapter) {
          report(
            e,
            "kapitelfrage",
            "Der Titel nennt das Kapitel ${e["book"]} $chapter; die Stelle "
                "umfasst es nicht genau"
                "${german.isEmpty ? "" : " (Vers 1 bis ${verses(chapter)})"}.",
          );
        }

        continue;
      }

      if (e["book"] == "Ps" &&
          e["startChapter"] == e["endChapter"] &&
          e["startVerse"] == 1 &&
          !endsWithChapter) {
        report(
          e,
          "psalm",
          "Psalm ${e["startChapter"]} hat ${verses(e["endChapter"])} Verse; "
              "die Perikope endet mit Vers ${e["endVerse"]}.",
        );
      }
    }
  }

  /// Die Verse, die auf [position] folgen können: der nächste im Kapitel
  /// oder, am Kapitelende einer der Ausgaben [books], der erste des
  /// nächsten Kapitels.
  static Set<(int, int)> _next((int, int) position, List<BibleBookInfo> books) {
    return {
      (position.$1, position.$2 + 1),
      for (final book in books)
        if (position.$2 >= book.verseCount(position.$1)) (position.$1 + 1, 1),
    };
  }

  void _checkSequence(
    List<Map<String, dynamic>> entries,
    void Function(Map<String, dynamic>, String, String) report,
  ) {
    final previous = <String, Map<String, dynamic>>{};

    for (final e in entries) {
      // Kapitelfragen stehen neben der Einteilung, nicht in ihr.
      if (chapterQuestion(e) != null) continue;

      final before = previous[e["book"]];

      previous[e["book"]] = e;

      if (before == null) continue;

      final start = _start(e);

      // Anschluss, Lücke oder Grenze im Vers.
      if (_compare(start, _end(before)) >= 0) continue;

      final references = _references(BibleBooks.byAbbreviation(e["book"])!.id);

      // Unterabschnitt: liegt ganz im vorigen Abschnitt und setzt an
      // dessen Anfang ein (mit dem ersten oder zweiten Vers).
      final nested =
          _compare(start, _start(before)) >= 0 &&
          _compare(_end(e), _end(before)) <= 0 &&
          (start == _start(before) ||
              _next(_start(before), references).contains(start));

      if (nested) continue;

      report(
        e,
        "ueberschneidung",
        "Die Perikope beginnt innerhalb der vorigen "
            "(„${before["id"]}“, ${referenceOf(before)}), ohne deren "
            "Unterabschnitt zu sein oder an sie anzuschließen.",
      );
    }
  }

  /// Verse, die keine Perikope abdeckt, als Bereiche je Buch – zur
  /// Durchsicht, kein Fehler. Gemessen an der ersten deutsch gezählten
  /// Ausgabe; Bücher ohne eine solche fehlen.
  Map<String, List<String>> gaps(List<dynamic> entries) {
    final result = <String, List<String>>{};

    final byBook = <String, List<Map<String, dynamic>>>{};

    for (final raw in entries) {
      final e = Map<String, dynamic>.from(raw as Map);

      byBook.putIfAbsent(e["book"], () => []).add(e);
    }

    for (final MapEntry(key: abbreviation, value: list) in byBook.entries) {
      final id = BibleBooks.byAbbreviation(abbreviation)?.id;

      BibleBookInfo? book;

      for (final t in translations) {
        if (t.versification == BibleVersification.german && id != null) {
          book ??= t.book(id);
        }
      }

      if (book == null) continue;

      bool covered(int chapter, int verse) => list.any(
        (e) =>
            _compare(_start(e), (chapter, verse)) <= 0 &&
            _compare((chapter, verse), _end(e)) <= 0,
      );

      final open = <String>[];

      (int, int)? from;
      (int, int)? to;

      void close() {
        final first = from;
        final last = to;

        if (first == null || last == null) return;

        open.add(
          first == last
              ? "${first.$1},${first.$2}"
              : "${first.$1},${first.$2}–${last.$1},${last.$2}",
        );

        from = null;
      }

      for (int c = 1; c <= book.chapterCount; c++) {
        for (int v = 1; v <= book.verseCount(c); v++) {
          if (covered(c, v)) {
            close();
          } else {
            from ??= (c, v);
            to = (c, v);
          }
        }
      }

      close();

      if (open.isNotEmpty) result[abbreviation] = open;
    }

    return result;
  }
}
