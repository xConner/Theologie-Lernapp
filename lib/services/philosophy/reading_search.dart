import '../../models/philosophy/reading_text.dart';
import '../../utils/greek_normalization.dart';
import 'reading_repository.dart';

enum ReadingHitKind {
  greek("Griechisch"),
  german("Übersetzung"),
  note("Anmerkungen"),
  intro("Einleitung"),
  glossary("Glossar");

  final String label;

  const ReadingHitKind(this.label);
}

class ReadingHit {
  final ReadingHitKind kind;

  /// Stellenangabe bzw. Abschnitt („184a10“, „Einl. 2.3.1“).
  final String title;
  final String snippet;

  /// Ziel im Text (Satz) – bei Treffern in Text, Übersetzung, Anmerkungen.
  final String? sentenceId;
  final String? noteId;
  final String? introSection;
  final String? glossaryId;

  const ReadingHit({
    required this.kind,
    required this.title,
    required this.snippet,
    this.sentenceId,
    this.noteId,
    this.introSection,
    this.glossaryId,
  });
}

/// Volltextsuche im griechischen Text (ohne Akzente und Spiritus), in der
/// Übersetzung, in den Anmerkungen, in Einleitung und Glossar.
class ReadingSearch {
  static final RegExp _greekLetter = RegExp(r'[Ͱ-Ͽἀ-῿]');

  static String _normalizeGreek(String text) =>
      normalizeGreekForComparison(text.toLowerCase());

  static List<ReadingHit> search(
    ReadingText text,
    String query, {
    int limit = 300,
  }) {
    final q = query.trim();
    if (q.length < 2) return const [];
    final hits = <ReadingHit>[];
    final greekQuery = _greekLetter.hasMatch(q);

    void add(ReadingHit hit) {
      if (hits.length < limit) hits.add(hit);
    }

    if (greekQuery) {
      final nq = _normalizeGreek(q);
      for (final chapter in text.chapters) {
        for (final s in chapter.sentences) {
          final nt = _normalizeGreek(s.text);
          final i = nt.indexOf(nq);
          if (i >= 0) {
            add(ReadingHit(
              kind: ReadingHitKind.greek,
              title: s.id,
              snippet: _snippet(s.text, i, nq.length),
              sentenceId: s.id,
            ));
          }
        }
      }
    }

    final lq = q.toLowerCase();

    if (!greekQuery) {
      for (final chapter in text.chapters) {
        for (final unit in chapter.units) {
          for (final d in unit.german) {
            final i = d.text.toLowerCase().indexOf(lq);
            if (i >= 0) {
              add(ReadingHit(
                kind: ReadingHitKind.german,
                title: "${d.ref}",
                snippet: _snippet(d.text, i, lq.length),
                sentenceId: _sentenceFor(unit, d.ref),
              ));
            }
          }
        }
      }
    }

    // Anmerkungen, Einleitung und Glossar enthalten auch griechische Wörter.
    bool matches(String s) => greekQuery
        ? _normalizeGreek(s).contains(_normalizeGreek(q))
        : s.toLowerCase().contains(lq);

    int position(String s) => greekQuery
        ? _normalizeGreek(s).indexOf(_normalizeGreek(q))
        : s.toLowerCase().indexOf(lq);

    for (final note in text.allNotes) {
      if (!matches(note.text)) continue;
      final first = note.range == null
          ? note.unitId
          : text.sentenceAt(note.range!.from)?.id;
      add(ReadingHit(
        kind: ReadingHitKind.note,
        title: "${note.kind.label} ${note.refLabel}",
        snippet: _snippet(note.text, position(note.text), q.length),
        sentenceId: first,
        noteId: note.id,
      ));
    }

    for (final section in text.front.intro) {
      for (final block in section.blocks) {
        if (!matches(block.text)) continue;
        add(ReadingHit(
          kind: ReadingHitKind.intro,
          title: "Einl. ${section.id} ${section.title}",
          snippet: _snippet(block.text, position(block.text), q.length),
          introSection: section.id,
        ));
        break;
      }
    }

    for (final entry in text.front.glossary) {
      final hay = "${entry.term} ${entry.text}";
      if (!matches(hay)) continue;
      add(ReadingHit(
        kind: ReadingHitKind.glossary,
        title: entry.term,
        snippet: _snippet(entry.text, position(entry.text).clamp(0, 1 << 30), q.length),
        glossaryId: entry.id,
      ));
    }

    return hits;
  }

  /// Erster Satz des Abschnitts, der zur Marke der Übersetzung passt.
  static String _sentenceFor(ReadingUnit unit, BekkerRef ref) {
    GreekSentence best = unit.greek.first;
    for (final s in unit.greek) {
      if (s.ref <= ref) best = s;
    }
    return best.id;
  }

  static String _snippet(String text, int index, int length) {
    if (index < 0) {
      return text.length > 160 ? "${text.substring(0, 160)}…" : text;
    }
    final start = (index - 60).clamp(0, text.length);
    final end = (index + length + 90).clamp(0, text.length);
    return "${start > 0 ? "…" : ""}${text.substring(start, end)}"
        "${end < text.length ? "…" : ""}";
  }
}
