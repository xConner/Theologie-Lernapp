import '../../models/church_history/church_history.dart';

/// Art eines Suchtreffers; die Oberfläche zeigt sie als Kennzeichnung an.
enum SearchHitKind {
  person("Person"),
  event("Ereignis"),
  term("Begriff"),
  source("Quelle"),
  epoch("Epoche"),
  lecture("Vorlesung"),
  slide("Folie");

  final String label;

  const SearchHitKind(this.label);

  static SearchHitKind ofEntry(EntryType type) => switch (type) {
    EntryType.person => person,
    EntryType.event => event,
    EntryType.term => term,
    EntryType.source => source,
  };
}

class SearchHit {
  final SearchHitKind kind;
  final String title;

  /// Kurzer Kontext (Datierung, Fundstelle).
  final String subtitle;

  /// Eintrag, Epoche oder Vorlesung, die der Treffer öffnet.
  final String targetId;

  /// Bei Folientreffern: die Folie.
  final int? slide;

  final int score;

  const SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.targetId,
    this.slide,
    required this.score,
  });
}

/// Suche über alle Inhaltstypen. Groß-/Kleinschreibung, Umlaute (ä = ae)
/// und typografische Zeichen spielen keine Rolle; Jahreszahlen finden
/// Ereignisse, deren Datierung das Jahr einschließt („250“ findet die
/// Decische Verfolgung 249–251).
class ChurchHistorySearch {
  final ChurchHistoryData data;

  const ChurchHistorySearch(this.data);

  static String normalize(String text) {
    var t = text.toLowerCase();

    const replacements = {
      "ä": "ae",
      "ö": "oe",
      "ü": "ue",
      "ß": "ss",
      "é": "e",
      "è": "e",
      "ī": "i",
      "ā": "a",
      "ō": "o",
      "ē": "e",
      "ū": "u",
    };

    replacements.forEach((from, to) => t = t.replaceAll(from, to));

    return t
        .replaceAll(RegExp(r'[„“"‚‘’\-–—/()«»]'), " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
  }

  List<SearchHit> search(String query) {
    final q = normalize(query);
    if (q.isEmpty) return const [];

    final terms = q.split(" ");
    final year = int.tryParse(q);

    final hits = <SearchHit>[];

    int score(String title, List<String> fields) {
      final t = normalize(title);
      if (t == q) return 100;
      if (t.startsWith(q)) return 80;
      if (terms.every(t.contains)) return 60;

      final all = normalize(fields.join(" "));
      if (terms.every(all.contains)) return 30;

      return 0;
    }

    for (final e in data.entries) {
      var s = score(e.name, [
        ...e.aliases,
        e.category ?? "",
        e.summary,
        e.significance,
        e.dating?.label ?? "",
        ...e.references,
      ]);

      final dating = e.dating;
      if (year != null &&
          dating != null &&
          year >= dating.earliest &&
          year <= dating.latest) {
        // Exakte Treffer vor Treffern innerhalb der Unschärfe.
        s = s < 70 ? (year >= dating.from && year <= dating.end ? 70 : 50) : s;
      }

      if (s > 0) {
        hits.add(
          SearchHit(
            kind: SearchHitKind.ofEntry(e.type),
            title: e.name,
            subtitle: [?e.dating?.label, ?e.category].join(" · "),
            targetId: e.id,
            score: s,
          ),
        );
      }
    }

    for (final epoch in data.epochs) {
      var s = score(epoch.title, [epoch.characterization, epoch.summary]);
      if (year != null &&
          year >= epoch.dating.from &&
          year <= epoch.dating.end) {
        s = s < 40 ? 40 : s;
      }
      if (s > 0) {
        hits.add(
          SearchHit(
            kind: SearchHitKind.epoch,
            title: epoch.title,
            subtitle: epoch.dating.label,
            targetId: epoch.id,
            score: s,
          ),
        );
      }
    }

    for (final l in data.lectures) {
      final s = score("${l.label} ${l.title}", [
        l.title,
        for (final section in l.sections) section.title,
      ]);
      if (s > 0) {
        hits.add(
          SearchHit(
            kind: SearchHitKind.lecture,
            title: "${l.label}: ${l.title}",
            subtitle: "${l.slides.length} Folien",
            targetId: l.id,
            score: s,
          ),
        );
      }

      for (final slide in l.slides) {
        final text = normalize(slide.text);
        if (terms.every(text.contains)) {
          hits.add(
            SearchHit(
              kind: SearchHitKind.slide,
              title: "Folie ${slide.number}: ${slide.title}",
              subtitle: _excerpt(slide.text, terms.first),
              targetId: l.id,
              slide: slide.number,
              score: 20,
            ),
          );
        }
      }
    }

    hits.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final k = a.kind.index.compareTo(b.kind.index);
      if (k != 0) return k;
      return a.title.compareTo(b.title);
    });

    return hits;
  }

  /// Zeile der Folie, die den Suchbegriff enthält.
  static String _excerpt(String text, String term) {
    for (final line in text.split("\n")) {
      if (normalize(line).contains(term)) return line.trim();
    }
    return text.split("\n").first;
  }
}
