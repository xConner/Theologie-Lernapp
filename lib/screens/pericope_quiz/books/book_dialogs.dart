import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../quiz/books/book_plan.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_input.dart';

export '../../../utils/date_input.dart';

/// Ergebnis des Plan-Dialogs.
class PlanDialogResult {
  final BookPlan? plan;
  final bool remove;

  const PlanDialogResult.save(BookPlan this.plan) : remove = false;
  const PlanDialogResult.remove() : plan = null, remove = true;
}

Future<PlanDialogResult?> showPlanDialog(
  BuildContext context, {
  required String book,
  required String bookName,
  required BookPlan? current,
  required int remainingNew,
  required DateTime now,
}) {
  return showDialog<PlanDialogResult>(
    context: context,
    builder: (_) => _PlanDialog(
      book: book,
      bookName: bookName,
      current: current,
      remainingNew: remainingNew,
      now: now,
    ),
  );
}

class _PlanDialog extends StatefulWidget {
  final String book;
  final String bookName;
  final BookPlan? current;
  final int remainingNew;
  final DateTime now;

  const _PlanDialog({
    required this.book,
    required this.bookName,
    required this.current,
    required this.remainingNew,
    required this.now,
  });

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late int daily = widget.current?.dailyNew ?? BookPlan.defaultDailyNew;

  late final TextEditingController target = TextEditingController(
    text: widget.current?.targetDate == null
        ? ""
        : formatDate(widget.current!.targetDate!),
  );

  String? error;

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  DateTime? get _targetDate => parseDate(target.text);

  BookPlan _plan() {
    final plan = BookPlan(
      book: widget.book,
      dailyNew: daily,
      createdAt: widget.current?.createdAt ?? widget.now,
      targetDate: _targetDate,
      paused: widget.current?.paused ?? false,
    );

    return plan;
  }

  void _save() {
    if (target.text.trim().isNotEmpty) {
      final date = _targetDate;

      if (date == null) {
        setState(() => error = "Datum bitte als TT.MM.JJJJ angeben.");
        return;
      }

      if (date.isBefore(BookPlan.dayOf(widget.now))) {
        setState(() => error = "Das Zieldatum liegt in der Vergangenheit.");
        return;
      }
    }

    Navigator.pop(context, PlanDialogResult.save(_plan()));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan();

    final required = plan.requiredPerDay(widget.remainingNew, widget.now);

    final days = widget.remainingNew == 0
        ? 0
        : (widget.remainingNew / daily).ceil();

    return AlertDialog(
      title: Text("Lernplan: ${widget.bookName}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Noch ${widget.remainingNew} neue Perikopen. Fällige "
              "Wiederholungen kommen in jeder Lerneinheit zuerst.",
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text("Neue Perikopen pro Tag"),
            Row(
              children: [
                IconButton(
                  key: const ValueKey("plan-daily-minus"),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: daily > 1 ? () => setState(() => daily--) : null,
                ),
                Text(
                  "$daily",
                  key: const ValueKey("plan-daily"),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  key: const ValueKey("plan-daily-plus"),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: daily < BookPlan.maxDailyNew
                      ? () => setState(() => daily++)
                      : null,
                ),
              ],
            ),
            if (days > 0)
              Text(
                "So sind alle Perikopen in etwa $days Tagen eingeführt.",
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey("plan-target"),
              controller: target,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: "Zieldatum (optional)",
                hintText: "TT.MM.JJJJ",
                errorText: error,
              ),
              onChanged: (_) => setState(() => error = null),
            ),
            if (required != null && required > daily)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Für dieses Ziel sind $required neue Perikopen pro Tag "
                  "nötig; der Plan schlägt so viele vor.",
                  style: TextStyle(color: context.colors.accent),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            key: const ValueKey("plan-remove"),
            onPressed: () =>
                Navigator.pop(context, const PlanDialogResult.remove()),
            child: const Text("Plan löschen"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("plan-save"),
          onPressed: _save,
          child: const Text("Speichern"),
        ),
      ],
    );
  }
}

/// Kapitelbereich wählen; [wholeBook] bietet zusätzlich das ganze Buch an.
Future<(int, int)?> showChapterRangeDialog(
  BuildContext context, {
  required String title,
  required List<int> chapters,
  bool wholeBook = false,
  (int, int)? initial,
}) {
  return showDialog<(int, int)>(
    context: context,
    builder: (_) => _ChapterRangeDialog(
      title: title,
      chapters: chapters,
      wholeBook: wholeBook,
      initial: initial,
    ),
  );
}

class _ChapterRangeDialog extends StatefulWidget {
  final String title;
  final List<int> chapters;
  final bool wholeBook;
  final (int, int)? initial;

  const _ChapterRangeDialog({
    required this.title,
    required this.chapters,
    required this.wholeBook,
    required this.initial,
  });

  @override
  State<_ChapterRangeDialog> createState() => _ChapterRangeDialogState();
}

class _ChapterRangeDialogState extends State<_ChapterRangeDialog> {
  late int from = widget.initial?.$1 ?? widget.chapters.first;
  late int to = widget.initial?.$2 ?? widget.chapters.first;

  @override
  Widget build(BuildContext context) {
    Widget field(
      String label,
      int value,
      ValueChanged<int> onChanged,
      Key key,
    ) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            key: key,
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              for (final c in widget.chapters)
                DropdownMenuItem(value: c, child: Text("Kapitel $c")),
            ],
            onChanged: (v) {
              if (v != null) setState(() => onChanged(v));
            },
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field("Von", from, (v) {
            from = v;
            if (to < from) to = from;
          }, const ValueKey("range-from")),
          const SizedBox(height: 8),
          field("Bis", to, (v) {
            to = v;
            if (from > to) from = to;
          }, const ValueKey("range-to")),
        ],
      ),
      actions: [
        if (widget.wholeBook)
          TextButton(
            key: const ValueKey("range-whole-book"),
            onPressed: () => Navigator.pop(context, (
              widget.chapters.first,
              widget.chapters.last,
            )),
            child: const Text("Ganzes Buch"),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          key: const ValueKey("range-start"),
          onPressed: () => Navigator.pop(context, (from, to)),
          child: const Text("Starten"),
        ),
      ],
    );
  }
}
