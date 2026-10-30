import 'book_catalog.dart';
import 'book_outline.dart';
import 'knowledge.dart';
import 'verse_precision.dart';

/// Lernaufgaben zur Grobgliederung (Ebene A) und zur Zuordnung der
/// Perikopen (Ebene B) – gebildet aus `assets/book_outlines.json` und der
/// Perikopenliste, damit Gliederung und Perikopen nie auseinanderlaufen.
///
/// Es sind gewöhnliche [KnowledgeQuestion]s mit
/// [KnowledgeSource.outline]: Sie nutzen dieselben Antwortformen, dieselben
/// Karten (`bible_knowledge`) und dieselbe Spaced Repetition wie die
/// Wissensfragen, gehören aber zum Schalter „Perikopen und Gliederung“.
///
/// IDs (`go.<buch>.…`) sind stabil, solange die IDs der Hauptabschnitte und
/// Abschnitte gleich bleiben – an ihnen hängt der Lernstand.
class OutlineQuestions {
  const OutlineQuestions._();

  /// So viele Zuordnungsaufgaben (Perikope → Hauptabschnitt) je Buch, jede
  /// mit anderen Perikopen.
  static const int assignmentSets = 3;

  /// Aufgaben für alle Bücher mit Grobgliederung.
  static KnowledgeBank build(BookOutlines outlines, BookCatalog catalog) {
    return KnowledgeBank(
      questions: [
        for (final outline in outlines.defined)
          if (outline.parts.length >= 3) ...ofBook(outline, catalog),
      ],
    );
  }

  static List<KnowledgeQuestion> ofBook(
    BookOutline outline,
    BookCatalog catalog,
  ) {
    final book = outline.book;
    final name = BookCatalog.nameOf(book);
    final parts = outline.parts;
    final prefix = "go.${book.toLowerCase()}";
    final session = outline.session;

    KnowledgeQuestion question({
      required String id,
      required KnowledgeFormat format,
      required String prompt,
      String? answer,
      List<String> accept = const [],
      List<String> items = const [],
      List<KnowledgePair> pairs = const [],
      String? explanation,
      KnowledgeRange? range,
      List<String> origin = const [],
    }) => KnowledgeQuestion(
      id: id,
      book: book,
      format: format,
      topic: KnowledgeTopic.structure,
      source: KnowledgeSource.outline,
      basis: KnowledgeBasis.slide,
      relevance: KnowledgeRelevance.focus,
      prompt: prompt,
      answer: answer,
      accept: accept,
      items: items,
      pairs: pairs,
      explanation: explanation,
      range: range,
      sessionId: session,
      origin: origin,
    );

    final allOrigins = {for (final p in parts) ...p.origin}.toList();

    final result = <KnowledgeQuestion>[
      question(
        id: "$prefix.teile.reihenfolge",
        format: KnowledgeFormat.order,
        prompt:
            "Bringe die Hauptabschnitte von $name in die Reihenfolge des "
            "Buches.",
        items: [for (final p in parts) p.title],
        origin: allOrigins,
      ),
      question(
        id: "$prefix.teile.kapitel",
        format: KnowledgeFormat.match,
        prompt: "Ordne die Hauptabschnitte von $name ihren Kapiteln zu.",
        pairs: [for (final p in parts) KnowledgePair(p.title, p.label)],
        origin: allOrigins,
      ),
      question(
        id: "$prefix.gliederung",
        format: KnowledgeFormat.reveal,
        prompt:
            "Gib die Grobgliederung von $name mit Kapiteln wieder – "
            "mit den Unterpunkten, die die Vorlesung nennt.",
        answer: _structureText(outline),
        origin: allOrigins,
      ),
    ];

    for (final part in parts) {
      final span = part.span;
      final range = span == null
          ? null
          : KnowledgeRange.parse("${span.start.text}-${span.end.text}");

      result.add(
        question(
          id: "$prefix.${part.id}.kapitel",
          format: KnowledgeFormat.input,
          prompt:
              "Welche Kapitel umfasst in $name der Hauptabschnitt "
              "„${part.title}“?",
          answer: "$book ${part.label}",
          accept: part.accept.isEmpty ? [part.label] : part.accept,
          explanation: part.summary,
          range: range,
          origin: part.origin,
        ),
      );

      result.add(
        question(
          id: "$prefix.${part.id}.titel",
          format: part.keywords.isEmpty
              ? KnowledgeFormat.reveal
              : KnowledgeFormat.input,
          prompt: "Wie heißt der Hauptabschnitt $book ${part.label}?",
          answer: part.title,
          accept: part.keywords,
          explanation: part.summary,
          range: range,
          origin: part.origin,
        ),
      );
    }

    for (final section in outline.sections) {
      if (!section.learn) continue;

      final part = outline.partOf(section);

      result.add(
        question(
          id: "$prefix.${section.id}.kapitel",
          format: KnowledgeFormat.input,
          prompt: "Wo steht in $name der Abschnitt „${section.title}“?",
          answer: "$book ${section.shortRange}",
          accept: [section.shortRange.replaceAll("–", "-"), ...section.accept],
          explanation: part == null
              ? null
              : "Teil des Hauptabschnitts „${part.title}“ (${part.label}).",
          range: KnowledgeRange.parse(
            "${section.start.text}-${section.end.text}",
          ),
          origin: section.origin,
        ),
      );
    }

    // Zuordnung der Feinperikopen: je Satz eine Perikope aus jedem
    // Hauptabschnitt, gleichmäßig über den Abschnitt verteilt. Der zweite
    // Satz nennt nur die Stelle, die anderen den Titel.
    final members = {
      for (final p in parts)
        p: [
          for (final pericope in catalog.pericopesOf(book))
            if (p.contains(pericope)) pericope,
        ],
    };

    for (int n = 0; n < assignmentSets; n++) {
      final byStelle = n == 1;
      final pairs = <KnowledgePair>[];

      for (final p in parts) {
        final list = members[p]!;

        if (list.isEmpty) continue;

        final pick =
            list[((n + 0.5) * list.length / assignmentSets).floor().clamp(
              0,
              list.length - 1,
            )];

        final left = byStelle
            ? ExpectedReference.of(pick.perikope, null).text
            : pick.title;

        if (pairs.any((e) => e.left == left)) continue;

        pairs.add(KnowledgePair(left, p.title));
      }

      if (pairs.length < 3) continue;

      result.add(
        question(
          id: "$prefix.zuordnung.${n + 1}",
          format: KnowledgeFormat.match,
          prompt: byStelle
              ? "Zu welchem Hauptabschnitt von $name gehören diese Stellen?"
              : "Zu welchem Hauptabschnitt von $name gehören diese "
                    "Perikopen?",
          pairs: pairs,
          origin: allOrigins,
        ),
      );
    }

    return result;
  }

  /// „1–18 Israel in Ägypten …“ mit eingerückten Unterpunkten.
  static String _structureText(BookOutline outline) {
    final lines = <String>[];

    for (final part in outline.parts) {
      lines.add("${part.label}  ${part.title}");

      for (final s in part.sections) {
        if (s.learn) lines.add("    ${s.shortRange}: ${s.title}");
      }
    }

    return lines.join("\n");
  }
}
