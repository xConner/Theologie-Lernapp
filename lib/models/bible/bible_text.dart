/// Anmerkung der Ausgabe zu einer Stelle im Vers.
class BibleNote {
  /// Position im Verstext, an der das Anmerkungszeichen steht.
  final int offset;

  final String text;

  const BibleNote(this.offset, this.text);
}

/// Umbruch vor einem Vers, wie ihn die Quelle vorgibt.
enum BibleBreak { none, paragraph, line, indentedLine }

/// Ein Eintrag eines Kapitels: Vers, Zwischenüberschrift oder Überschrift
/// eines Psalms außerhalb der Verszählung.
sealed class BibleItem {
  const BibleItem();
}

class BibleHeading extends BibleItem {
  final String text;

  /// 1 = Hauptüberschrift, 2 = untergeordnet.
  final int level;

  const BibleHeading(this.text, this.level);
}

class BibleDescription extends BibleItem {
  final String text;

  const BibleDescription(this.text);
}

class BibleVerse extends BibleItem {
  final int number;

  /// Bezeichnung der Quelle, wenn sie keine reine Zahl ist (z. B. „22a“).
  final String? label;

  /// Unveränderter Wortlaut. `\n` ist ein Zeilenumbruch der Quelle, `\n\t`
  /// eine eingerückte Zeile.
  final String text;

  final BibleBreak breakBefore;

  /// Leerzeile vor dem Vers (Strophengrenze).
  final bool gapBefore;

  /// Der Vers setzt denselben Vers nach einer Zwischenüberschrift fort.
  final bool continuation;

  final List<BibleNote> notes;

  const BibleVerse({
    required this.number,
    required this.text,
    this.label,
    this.breakBefore = BibleBreak.none,
    this.gapBefore = false,
    this.continuation = false,
    this.notes = const [],
  });

  String get displayNumber => label ?? "$number";
}

class BibleChapter {
  final int number;
  final List<BibleItem> items;

  const BibleChapter(this.number, this.items);

  Iterable<BibleVerse> get verses => items.whereType<BibleVerse>();

  bool get isEmpty => verses.isEmpty;

  bool hasVerse(int number) => verses.any((v) => v.number == number);
}

/// Der vollständige Text eines Buchs in einer Ausgabe.
class BibleBookText {
  final String bookId;
  final List<BibleChapter> chapters;

  const BibleBookText(this.bookId, this.chapters);

  BibleChapter? chapter(int number) {
    if (number < 1 || number > chapters.length) return null;

    return chapters[number - 1];
  }

  /// Liest das Format der Buchdateien unter `assets/bible/<Ausgabe>/`
  /// (beschrieben in `tool/bible_import/usfm.py`).
  factory BibleBookText.fromJson(Map<String, dynamic> json) {
    final chapters = <BibleChapter>[];

    for (final raw in json["chapters"] as List) {
      final items = <BibleItem>[];

      for (final entry in raw as List) {
        final item = entry as Map<String, dynamic>;

        if (item.containsKey("v")) {
          items.add(
            BibleVerse(
              number: item["v"],
              text: item["t"],
              label: item["l"],
              breakBefore: BibleBreak.values[item["b"] ?? 0],
              gapBefore: item["g"] == 1,
              continuation: item["c"] == 1,
              notes: [
                for (final n in item["f"] as List? ?? const [])
                  BibleNote(n[0], n[1]),
              ],
            ),
          );
        } else if (item.containsKey("h")) {
          items.add(BibleHeading(item["h"], item["l"] ?? 1));
        } else if (item.containsKey("d")) {
          items.add(BibleDescription(item["d"]));
        }
      }

      chapters.add(BibleChapter(chapters.length + 1, items));
    }

    return BibleBookText(json["id"], chapters);
  }
}
