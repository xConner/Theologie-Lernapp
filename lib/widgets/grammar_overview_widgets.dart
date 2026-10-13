import 'package:flutter/material.dart';

import '../info/app_info.dart';
import '../services/greek/grammar/greek_declension.dart';
import '../theme/app_theme.dart';
import 'info_report.dart';
import 'settings_access.dart';

/// Gemeinsames Gerüst aller Seiten der Grammatikübersicht: App-Leiste mit
/// Info und Einstellungen, darunter der scrollbare, in der Breite begrenzte
/// Inhalt.
class GrammarTopicScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const GrammarTopicScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          InfoButton(module: AppModules.greekGrammarOverview),
          SettingsButton(),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ein Abschnitt einer Themenseite: Überschrift, optionale Erläuterung und
/// der Inhalt (in der Regel eine [GrammarTable]).
class GrammarSection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? child;

  const GrammarSection({
    super.key,
    required this.title,
    this.description,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final child = this.child;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),

          if (description != null) ...[
            const SizedBox(height: 4),
            GrammarNote(description),
          ],

          if (child != null) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// Erläuternder Fließtext in gedeckter Farbe.
class GrammarNote extends StatelessWidget {
  final String text;

  const GrammarNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
    );
  }
}

/// Aufzählung kurzer Merksätze oder Stichpunkte.
class GrammarBulletList extends StatelessWidget {
  final List<String> items;

  const GrammarBulletList(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("• $item", style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}

/// Lade- bzw. Fehlerzustand einer Themenseite, deren Daten erst geladen
/// werden.
class GrammarStatus extends StatelessWidget {
  final String? message;

  const GrammarStatus.loading({super.key}) : message = null;

  const GrammarStatus.error(String this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: message == null
            ? const CircularProgressIndicator()
            : Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Eine Zelle einer [GrammarTable]. Die Konstruktoren legen die Rolle fest,
/// damit Schriftgrößen und -gewichte auf allen Seiten gleich sind.
class GrammarCell extends StatelessWidget {
  final String text;
  final String? article;
  final String? _ending;
  final _GrammarCellKind _kind;

  /// Spaltenüberschrift bzw. Zwischenüberschrift („Singular“).
  const GrammarCell.header(this.text, {super.key})
    : _kind = _GrammarCellKind.header,
      article = null,
      _ending = null;

  /// Zeilenbeschriftung („Nom.“, „1. Sg.“).
  const GrammarCell.label(this.text, {super.key})
    : _kind = _GrammarCellKind.label,
      article = null,
      _ending = null;

  /// Griechische Form oder Endung.
  const GrammarCell.form(this.text, {super.key})
    : _kind = _GrammarCellKind.form,
      article = null,
      _ending = null;

  /// Deutscher Text (Bedeutung, Hinweis).
  const GrammarCell.text(this.text, {super.key})
    : _kind = _GrammarCellKind.text,
      article = null,
      _ending = null;

  /// Form mit abgesetzter, hervorgehobener Endung und Artikel davor:
  /// „τοῦ λόγ-ου“.
  const GrammarCell.ending(
    String stem,
    String ending, {
    super.key,
    this.article,
  }) : text = stem,
       _kind = _GrammarCellKind.form,
       _ending = ending;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );

  static const double formSize = 18;
  static const double labelSize = 14;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ending = _ending;
    final article = this.article;

    final Widget content;

    if (ending != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (article != null)
            SizedBox(
              width: 48,
              child: Text(article, style: const TextStyle(fontSize: formSize)),
            ),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: formSize),
              children: [
                TextSpan(text: "$text-"),
                TextSpan(
                  text: ending,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Text(
        text,
        style: switch (_kind) {
          _GrammarCellKind.header => const TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
          ),
          _GrammarCellKind.label => TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
          _GrammarCellKind.form => const TextStyle(
            fontSize: formSize,
            fontWeight: FontWeight.w600,
          ),
          _GrammarCellKind.text => const TextStyle(fontSize: 15),
        },
      );
    }

    return Padding(padding: padding, child: content);
  }
}

enum _GrammarCellKind { header, label, form, text }

/// Formentabelle der Grammatikübersicht. Füllt die verfügbare Breite; ist
/// der Bildschirm schmaler als der Inhalt, lässt sie sich waagerecht
/// scrollen, statt Formen umzubrechen.
class GrammarTable extends StatelessWidget {
  final List<List<Widget>> rows;

  /// Zeilen, die als Überschrift hinterlegt werden.
  final Set<int> headerRows;

  const GrammarTable({
    super.key,
    required this.rows,
    this.headerRows = const {0},
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final columns = rows.fold<int>(
      0,
      (count, row) => row.length > count ? row.length : count,
    );

    final radius = BorderRadius.circular(AppTheme.radiusSmall);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: ClipRRect(
              borderRadius: radius,
              child: Table(
                border: TableBorder.all(
                  color: colors.divider,
                  borderRadius: radius,
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
                children: [
                  for (var i = 0; i < rows.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: headerRows.contains(i)
                            ? colors.surfaceMuted
                            : colors.surface,
                      ),
                      children: [
                        ...rows[i],
                        for (var c = rows[i].length; c < columns; c++)
                          const SizedBox.shrink(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Vollständige Deklination eines dreigeschlechtigen Paradigmas (Adjektiv,
/// Partizip, Komparativ): je Numerus eine Überschriftenzeile, darunter die
/// Kasus.
class DeclensionParadigmTable extends StatelessWidget {
  final DeclensionParadigm paradigm;

  const DeclensionParadigmTable({super.key, required this.paradigm});

  static const List<(String, String)> _numbers = [
    ("Sg", "Singular"),
    ("Pl", "Plural"),
  ];

  static const Map<String, String> _caseLabels = {
    "Nominativ": "Nom.",
    "Genitiv": "Gen.",
    "Dativ": "Dat.",
    "Akkusativ": "Akk.",
  };

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[];
    final headerRows = <int>{};

    for (final (number, numberLabel) in _numbers) {
      headerRows.add(rows.length);

      rows.add([
        GrammarCell.header(numberLabel),
        for (final gender in declensionGenders) GrammarCell.header("$gender."),
      ]);

      for (final grammaticalCase in declensionCases) {
        rows.add([
          GrammarCell.label(_caseLabels[grammaticalCase] ?? grammaticalCase),
          for (final gender in declensionGenders)
            GrammarCell.form(
              paradigm.form(grammaticalCase, number, gender) ?? "",
            ),
        ]);
      }
    }

    return GrammarTable(rows: rows, headerRows: headerRows);
  }
}
