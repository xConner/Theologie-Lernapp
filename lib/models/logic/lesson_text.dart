/// Lehrtext einer Lektion, gegliedert in Abschnitte und Blöcke.
///
/// Die Texte liegen als einfache Textdateien unter `assets/logic/lessons/`.
/// Format (eine Anweisung je Zeile, Leerzeile trennt Absätze):
///
/// ```text
/// # Abschnitt                     neuer Abschnitt
/// ## Zwischenüberschrift
/// Absatztext mit `p ∧ q` (Formel), **fett** und *kursiv*.
/// - Aufzählungspunkt
/// 1. nummerierter Punkt
/// ::: definition Definition 1.2 (Satz)   Kasten (definition, convention,
/// …                                       theorem, note, explanation,
/// :::                                     example, warning, rules)
/// @formula p ∧ q                  abgesetzte Formel
/// @text Γ ⊢ A                     abgesetzte Zeile (Metasprache, ohne Prüfung)
/// @table p → q                    Wahrheitstafel (wird berechnet)
/// @tree (p → q) ∧ ¬p              Syntaxbaum mit Operatoren
/// @tree-names (p → q) ∧ ¬p        Syntaxbaum mit Satztypen
/// @rule +K | X ⊢ A ; Y ⊢ B | X, Y ⊢ A ∧ B
/// @proof l4 | p ∧ q ⊢ q           Beweis (wird geprüft), Zeilen:
/// α | p ∧ q | A[V] | α            Bezeichner | Satz | Argument | Abh.
/// @end
/// @proof-partial …                unvollständiger Beweis (Illustration)
/// ```
library;

class LessonSection {
  final String id;
  final String title;
  final List<LessonBlock> blocks;

  const LessonSection({
    required this.id,
    required this.title,
    required this.blocks,
  });
}

sealed class LessonBlock {
  const LessonBlock();
}

class ParagraphBlock extends LessonBlock {
  /// Text mit Auszeichnungen (`Formel`, **fett**, *kursiv*).
  final String text;

  const ParagraphBlock(this.text);
}

class SubheadingBlock extends LessonBlock {
  final String text;

  const SubheadingBlock(this.text);
}

class ListBlock extends LessonBlock {
  final List<String> items;
  final bool ordered;

  const ListBlock(this.items, {this.ordered = false});
}

enum BoxKind {
  definition("Definition"),
  convention("Konvention"),
  theorem("Satz"),
  rules("Argumente"),
  note("Hinweis"),

  /// Ergänzende Erläuterung dieses Lernbereichs (über den Kursstoff hinaus).
  explanation("Erläuterung"),
  example("Beispiel"),
  warning("Achtung");

  final String label;

  const BoxKind(this.label);

  static BoxKind parse(String s) =>
      BoxKind.values.firstWhere((k) => k.name == s, orElse: () => BoxKind.note);
}

class BoxBlock extends LessonBlock {
  final BoxKind kind;
  final String title;
  final List<LessonBlock> children;

  const BoxBlock(this.kind, this.title, this.children);
}

/// Abgesetzte Formel (wird als Satz geprüft).
class FormulaBlock extends LessonBlock {
  final String formula;

  const FormulaBlock(this.formula);
}

/// Abgesetzte Zeile ohne Prüfung (z. B. Metasprache mit X, A, B).
class DisplayTextBlock extends LessonBlock {
  final String text;

  const DisplayTextBlock(this.text);
}

class TruthTableBlock extends LessonBlock {
  final String formula;

  const TruthTableBlock(this.formula);
}

class TreeBlock extends LessonBlock {
  final String formula;

  /// Satztypen statt Operatoren an den Knoten.
  final bool names;

  const TreeBlock(this.formula, {this.names = false});
}

/// Argument in Schreibweise mit Herleitungsstrich.
class RuleBlock extends LessonBlock {
  final String name;
  final List<String> premises;
  final String conclusion;

  const RuleBlock(this.name, this.premises, this.conclusion);
}

class ProofRow {
  final String label;
  final String formula;

  /// Argumentspalte wie im Kurs, z. B. „A[V]“, „-I(α, 1)“.
  final String justification;

  final String dependencies;

  const ProofRow(this.label, this.formula, this.justification, this.dependencies);
}

class ProofBlock extends LessonBlock {
  final String system;
  final String theorem;
  final List<ProofRow> rows;

  /// false: absichtlich unvollständiger oder scheiternder Beweis.
  final bool complete;

  const ProofBlock(this.system, this.theorem, this.rows, {this.complete = true});
}

/// Liest das Textformat der Lektionen.
class LessonTextParser {
  LessonTextParser._();

  static List<LessonSection> parse(String source, {String idPrefix = "s"}) {
    final sections = <LessonSection>[];
    var title = "";
    var blocks = <LessonBlock>[];

    void flushSection() {
      if (blocks.isEmpty && title.isEmpty) return;
      sections.add(
        LessonSection(
          id: "$idPrefix${sections.length + 1}",
          title: title,
          blocks: blocks,
        ),
      );
      blocks = <LessonBlock>[];
    }

    final lines = source.replaceAll("\r\n", "\n").split("\n");
    var i = 0;

    List<LessonBlock> parseBlocks(bool Function(String line) stop) {
      final result = <LessonBlock>[];
      final paragraph = <String>[];
      List<String>? list;
      var ordered = false;

      void flushParagraph() {
        if (paragraph.isNotEmpty) {
          result.add(ParagraphBlock(paragraph.join(" ")));
          paragraph.clear();
        }
        if (list != null) {
          result.add(ListBlock(list!, ordered: ordered));
          list = null;
        }
      }

      while (i < lines.length) {
        final raw = lines[i];
        final line = raw.trimRight();
        final t = line.trim();

        if (stop(t)) break;

        i++;

        if (t.isEmpty) {
          flushParagraph();
          continue;
        }

        if (t.startsWith("## ")) {
          flushParagraph();
          result.add(SubheadingBlock(t.substring(3).trim()));
          continue;
        }

        final bullet = RegExp(r"^- (.*)$").firstMatch(t);
        final number = RegExp(r"^\d+\. (.*)$").firstMatch(t);

        if (bullet != null || number != null) {
          if (paragraph.isNotEmpty) {
            result.add(ParagraphBlock(paragraph.join(" ")));
            paragraph.clear();
          }
          final isOrdered = number != null;
          if (list != null && ordered != isOrdered) {
            result.add(ListBlock(list!, ordered: ordered));
            list = null;
          }
          list ??= [];
          ordered = isOrdered;
          list!.add((bullet ?? number)!.group(1)!.trim());
          continue;
        }

        if (list != null && raw.startsWith("  ")) {
          // Fortsetzung eines Aufzählungspunkts.
          list![list!.length - 1] = "${list!.last} $t";
          continue;
        }

        if (t.startsWith(":::")) {
          flushParagraph();
          final header = t.substring(3).trim();
          final space = header.indexOf(" ");
          final kind = space < 0 ? header : header.substring(0, space);
          final boxTitle = space < 0 ? "" : header.substring(space + 1).trim();
          final children = parseBlocks((l) => l == ":::");
          i++; // schließendes :::
          result.add(BoxBlock(BoxKind.parse(kind), boxTitle, children));
          continue;
        }

        if (t.startsWith("@")) {
          flushParagraph();
          final space = t.indexOf(" ");
          final directive = space < 0 ? t.substring(1) : t.substring(1, space);
          final arg = space < 0 ? "" : t.substring(space + 1).trim();

          switch (directive) {
            case "formula":
              result.add(FormulaBlock(arg));
            case "text":
              result.add(DisplayTextBlock(arg));
            case "table":
              result.add(TruthTableBlock(arg));
            case "tree":
              result.add(TreeBlock(arg));
            case "tree-names":
              result.add(TreeBlock(arg, names: true));
            case "rule":
              final parts = arg.split("|").map((s) => s.trim()).toList();
              result.add(
                RuleBlock(
                  parts[0],
                  parts[1].isEmpty
                      ? const []
                      : parts[1].split(";").map((s) => s.trim()).toList(),
                  parts[2],
                ),
              );
            case "proof":
            case "proof-partial":
              final parts = arg.split("|").map((s) => s.trim()).toList();
              final rows = <ProofRow>[];
              while (i < lines.length && lines[i].trim() != "@end") {
                final cells = lines[i].split("|").map((s) => s.trim()).toList();
                if (cells.length >= 3) {
                  rows.add(
                    ProofRow(
                      cells[0],
                      cells[1],
                      cells[2],
                      cells.length > 3 ? cells[3] : "",
                    ),
                  );
                }
                i++;
              }
              i++; // @end
              result.add(
                ProofBlock(
                  parts[0],
                  parts.length > 1 ? parts[1] : "",
                  rows,
                  complete: directive == "proof",
                ),
              );
            default:
              throw FormatException("Unbekannte Anweisung @$directive");
          }
          continue;
        }

        if (list != null) {
          result.add(ListBlock(list!, ordered: ordered));
          list = null;
        }
        paragraph.add(t);
      }

      flushParagraph();
      return result;
    }

    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.startsWith("# ")) {
        flushSection();
        title = t.substring(2).trim();
        i++;
        continue;
      }
      blocks.addAll(parseBlocks((l) => l.startsWith("# ")));
    }

    flushSection();
    return sections;
  }
}
