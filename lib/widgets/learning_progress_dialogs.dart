import 'package:flutter/material.dart';

import '../services/lecture_materials/lecture_materials.dart';
import '../services/progress_reset.dart';

/// Fragt nach der Anmeldung, ob die als Gast gesammelten Lernstände ins Konto
/// übernommen werden sollen. true = übernehmen, false = ohne Fortschritte.
Future<bool> askGuestDataTransfer(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Deine bisherigen Lernfortschritte übernehmen?"),
      content: const Text(
        "Du hast bereits als Gast gelernt. Möchtest du deine Lernstände und "
        "gespeicherten Lerneinstellungen in dein Konto übernehmen?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Ohne Fortschritte starten"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text("Übernehmen"),
        ),
      ],
    ),
  );

  return accepted ?? false;
}

/// Bestätigung vor dem Zurücksetzen von Lernfortschritten. Ohne Angaben
/// die bisherige Abfrage für alle Lernfortschritte; für Teilbereiche
/// benennen [title] und [message] genau, was gelöscht wird.
Future<bool> confirmProgressReset(
  BuildContext context, {
  String title = "Lernfortschritte zurücksetzen?",
  String message =
      "Deine bisherigen Lernstände und Wiederholungsdaten, einschließlich "
      "Schwierigkeits-/Stabilitätswerten und Lernzeitpunkten, werden "
      "zurückgesetzt. Dieser Vorgang kann nicht rückgängig gemacht werden.\n\n"
      "Deine Einstellungen und eigenen Eselsbrücken bleiben erhalten.",
  String confirmLabel = "Zurücksetzen",
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          key: const ValueKey("reset-cancel"),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("reset-confirm"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Bestätigungstext für einen einzelnen Lernbereich.
String areaResetMessage(ProgressArea area) {
  return "Betroffen: ${area.scopeDescription}\n\n"
      "Alle anderen Lernbereiche, deine Einstellungen und eigenen "
      "Eselsbrücken bleiben erhalten. Dieser Vorgang kann nicht rückgängig "
      "gemacht werden.";
}

/// Auswahl des Lernbereichs, der zurückgesetzt werden soll.
Future<ProgressArea?> pickProgressArea(BuildContext context) {
  return showDialog<ProgressArea>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text("Welchen Lernbereich zurücksetzen?"),
      children: [
        for (final area in ProgressArea.values)
          // Bereiche aus geschützten Vorlesungsunterlagen nur mit Freigabe.
          if (area.documents.every(LectureMaterials.instance.showsArea))
            SimpleDialogOption(
              key: ValueKey("reset-area-${area.name}"),
              onPressed: () => Navigator.of(dialogContext).pop(area),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(area.label),
              ),
            ),
      ],
    ),
  );
}

/// Perikopenkenntnisse: alle Bücher (Ergebnis `""`) oder ein Buch
/// (Abkürzung der Perikopenliste); `null` = abgebrochen.
Future<String?> pickPericopeScope(
  BuildContext context, {
  required List<String> books,
  required String Function(String book) nameOf,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PericopeScopeDialog(books: books, nameOf: nameOf),
  );
}

class _PericopeScopeDialog extends StatefulWidget {
  final List<String> books;
  final String Function(String book) nameOf;

  const _PericopeScopeDialog({required this.books, required this.nameOf});

  @override
  State<_PericopeScopeDialog> createState() => _PericopeScopeDialogState();
}

class _PericopeScopeDialogState extends State<_PericopeScopeDialog> {
  bool singleBook = true;

  String? book;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Perikopenkenntnisse zurücksetzen"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<bool>(
            groupValue: singleBook,
            onChanged: (v) => setState(() => singleBook = v ?? true),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  key: ValueKey("pericope-scope-book"),
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text("Nur ein Bibelbuch"),
                ),
                RadioListTile<bool>(
                  key: ValueKey("pericope-scope-all"),
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text("Alle Bibelbücher"),
                ),
              ],
            ),
          ),
          if (singleBook)
            InputDecorator(
              decoration: const InputDecoration(labelText: "Bibelbuch"),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey("pericope-scope-dropdown"),
                  value: book,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text("Buch wählen"),
                  items: [
                    for (final b in widget.books)
                      DropdownMenuItem(value: b, child: Text(widget.nameOf(b))),
                  ],
                  onChanged: (v) => setState(() => book = v),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("pericope-scope-next"),
          onPressed: singleBook && book == null
              ? null
              : () => Navigator.pop(context, singleBook ? book : ""),
          child: const Text("Weiter"),
        ),
      ],
    );
  }
}

/// Bestätigung für ein Bibelbuch. Nennt, was betroffen ist, und fragt bei
/// Karten, die das Perikopenquiz gemeinsam mit anderen Büchern führt, ob
/// diese mit zurückgesetzt werden. Ergebnis: `null` = abgebrochen, sonst
/// ob gemeinsame Karten einbezogen werden.
Future<bool?> confirmPericopeBookReset(
  BuildContext context, {
  required String bookName,
  required PericopeBookResetPlan plan,
  required String Function(String book) nameOf,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) =>
        _BookResetDialog(bookName: bookName, plan: plan, nameOf: nameOf),
  );
}

class _BookResetDialog extends StatefulWidget {
  final String bookName;
  final PericopeBookResetPlan plan;
  final String Function(String book) nameOf;

  const _BookResetDialog({
    required this.bookName,
    required this.plan,
    required this.nameOf,
  });

  @override
  State<_BookResetDialog> createState() => _BookResetDialogState();
}

class _BookResetDialogState extends State<_BookResetDialog> {
  bool includeShared = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    final shared = plan.sharedIds.length;

    final others = (plan.otherBooks.toList()..sort())
        .map(widget.nameOf)
        .join(", ");

    final quizCount = plan.exclusiveIds.length + (includeShared ? shared : 0);

    final bookCount = plan.bookEntries;

    return AlertDialog(
      title: Text("Perikopenkenntnisse für ${widget.bookName} zurücksetzen?"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Betroffen sind nur Perikopen aus ${widget.bookName}:\n"
              "• Perikopenquiz: $quizCount Lernstände werden gelöscht\n"
              "• Bücher systematisch lernen: $bookCount Perikopen beginnen "
              "neu",
              key: const ValueKey("book-reset-summary"),
            ),
            if (shared > 0) ...[
              const SizedBox(height: 12),
              Text(
                "$shared Perikopen führt das Perikopenquiz gemeinsam mit "
                "anderen Büchern ($others), z. B. Parallelstellen. Ihre "
                "Lernstände bleiben sonst erhalten; beim Buchlernen beginnen "
                "sie für ${widget.bookName} trotzdem neu.",
              ),
              SwitchListTile(
                key: const ValueKey("book-reset-shared"),
                contentPadding: EdgeInsets.zero,
                title: const Text("Gemeinsame Lernstände auch zurücksetzen"),
                subtitle: Text("Betrifft dann auch $others."),
                value: includeShared,
                onChanged: (v) => setState(() => includeShared = v),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              "Andere Bücher, Verspräzisierungen, Lernpläne, Einstellungen "
              "und Eselsbrücken bleiben erhalten. Dieser Vorgang kann nicht "
              "rückgängig gemacht werden.",
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey("reset-cancel"),
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("reset-confirm"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, includeShared),
          child: const Text("Zurücksetzen"),
        ),
      ],
    );
  }
}
