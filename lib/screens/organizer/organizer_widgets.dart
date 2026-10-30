import 'package:flutter/material.dart';

import '../../models/bible/bible_reference.dart';
import '../../models/organizer/organizer_items.dart';
import '../../services/bible/bible_reference_parser.dart';
import '../../services/greek/perikope_loader.dart';
import '../../services/notifications/app_deep_link.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/deep_link_navigator.dart';
import '../bible/bible_reader_screen.dart';
import '../pericope_quiz/bibelkunde_screen.dart';
import '../philosophy/philosophy_home_screen.dart';

/// Farbe einer Zuordnung im aktuellen Design.
Color areaColor(BuildContext context, OrgArea? area) {
  if (area == null) return context.colors.textSecondary;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final palette = dark ? OrgPalette.dark : OrgPalette.light;
  return Color(palette[area.color % palette.length]);
}

/// Kleiner Punkt + Name der Zuordnung.
class AreaLabel extends StatelessWidget {
  final OrgArea? area;
  final TextStyle? style;

  const AreaLabel({super.key, required this.area, this.style});

  @override
  Widget build(BuildContext context) {
    final a = area;
    if (a == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: areaColor(context, a),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            a.name,
            overflow: TextOverflow.ellipsis,
            style:
                style ??
                Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

/// Bereiche der App, die sich verknüpfen lassen (ohne geschützte
/// Vorlesungsunterlagen, deren Links nur mit Freigabe öffnen).
class OrgAppTargets {
  OrgAppTargets._();

  static const List<(String, String)> all = [
    ("bibelkunde", "Bibelkunde (Perikopen, Bücher lernen)"),
    (AppDeepLink.bible, "Bibel und Lesepläne"),
    (AppDeepLink.greek, "Altgriechisch"),
    (AppDeepLink.greekVocabulary, "Griechisch: Vokabeltrainer"),
    (AppDeepLink.greekGrammar, "Griechisch: Grammatiktrainer"),
    (AppDeepLink.latin, "Latein"),
    (AppDeepLink.latinVocabulary, "Latein: Vokabeltrainer"),
    ("philosophy", "Philosophie"),
    (AppDeepLink.logic, "Einführung in die Logik"),
    (AppDeepLink.churchHistory, "Kirchengeschichte"),
    (AppDeepLink.oldTestament, "Altes Testament / Bibelkunde-Übung"),
    (AppDeepLink.memorize, "Texte auswendig lernen"),
    (AppDeepLink.calendar, "Liturgischer Kalender"),
  ];

  static String label(String target) {
    for (final (t, l) in all) {
      if (t == target) return l;
    }
    return target;
  }
}

/// Öffnet eine Verknüpfung. Liefert false, wenn das Ziel nicht verfügbar
/// ist (z. B. gelöschte Notiz, keine Freigabe).
Future<bool> openOrgTarget(
  BuildContext context, {
  required String? uid,
  required String type,
  required String target,
  OrganizerController? controller,
  void Function(OrgItem item)? openItem,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void unavailable() => messenger.showSnackBar(
    const SnackBar(content: Text("Das verknüpfte Ziel ist nicht verfügbar.")),
  );

  switch (type) {
    case "bible":
      final ref = BibleReferenceParser.parse(target);
      if (ref == null) {
        unavailable();
        return false;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BibleReaderScreen(
            uid: uid,
            trackReading: true,
            passages: [BiblePassage(label: target, reference: ref)],
          ),
        ),
      );
      return true;
    case "task" || "event" || "note":
      final c = controller;
      final item = c == null
          ? null
          : switch (type) {
              "task" => c.task(target),
              "event" => c.event(target),
              _ => c.note(target),
            };
      if (item == null || openItem == null) {
        unavailable();
        return false;
      }
      openItem(item);
      return true;
    default:
      if (target == "bibelkunde") {
        final navigator = Navigator.of(context);
        final list = await PerikopeLoader.load();
        if (list.isEmpty) {
          unavailable();
          return false;
        }
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => BibelkundeScreen(perikopen: list, uid: uid),
          ),
        );
        return true;
      }
      if (target == "philosophy") {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PhilosophyHomeScreen(uid: uid),
          ),
        );
        return true;
      }
      final link = AppDeepLink.parse(target);
      if (link == null) {
        unavailable();
        return false;
      }
      if (!context.mounted) return false;
      final ok = await openDeepLink(context, link);
      if (!ok) unavailable();
      return ok;
  }
}

IconData linkIcon(String type) => switch (type) {
  "bible" => Icons.menu_book_rounded,
  "task" => Icons.check_circle_outline_rounded,
  "event" => Icons.event_rounded,
  "note" => Icons.sticky_note_2_outlined,
  _ => Icons.open_in_new_rounded,
};

/// Verknüpfungen als antippbare Chips (mit Entfernen, wenn [onRemove]).
class LinkChips extends StatelessWidget {
  final List<OrgLink> links;
  final void Function(OrgLink link) onOpen;
  final void Function(OrgLink link)? onRemove;

  const LinkChips({
    super.key,
    required this.links,
    required this.onOpen,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final l in links)
          InputChip(
            avatar: Icon(linkIcon(l.type), size: 18),
            label: Text(l.label, overflow: TextOverflow.ellipsis),
            onPressed: () => onOpen(l),
            onDeleted: onRemove == null ? null : () => onRemove!(l),
            deleteButtonTooltipMessage: "Verknüpfung entfernen",
          ),
      ],
    );
  }
}

/// Dialog: Verknüpfung hinzufügen (Bibelstelle, App-Bereich, Eintrag).
Future<OrgLink?> pickLink(
  BuildContext context,
  OrganizerController controller, {
  String? excludeId,
}) {
  return showModalBottomSheet<OrgLink>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LinkPicker(controller: controller, excludeId: excludeId),
  );
}

class _LinkPicker extends StatefulWidget {
  final OrganizerController controller;
  final String? excludeId;

  const _LinkPicker({required this.controller, this.excludeId});

  @override
  State<_LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends State<_LinkPicker> {
  final TextEditingController _bible = TextEditingController();
  final TextEditingController _search = TextEditingController();
  String? _bibleError;

  @override
  void dispose() {
    _bible.dispose();
    _search.dispose();
    super.dispose();
  }

  void _addBible() {
    final ref = BibleReferenceParser.parse(_bible.text);
    if (ref == null) {
      setState(() => _bibleError = "Stelle nicht erkannt, z. B. „Gen 12,1-3“");
      return;
    }
    final label = BibleReferenceParser.format(ref);
    Navigator.pop(context, OrgLink(type: "bible", target: label, label: label));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final q = _search.text.trim().toLowerCase();
    bool hit(String s) => q.isEmpty || s.toLowerCase().contains(q);
    final items = <(String, String, String)>[
      for (final t in c.tasks)
        if (t.id != widget.excludeId && !t.done && hit(t.title))
          ("task", t.id, t.title),
      for (final e in c.events)
        if (e.id != widget.excludeId && hit(e.title))
          ("event", e.id, "${e.title} (${e.date.label(year: true)})"),
      for (final n in c.notesFor())
        if (n.id != widget.excludeId && hit(n.displayTitle))
          ("note", n.id, n.displayTitle),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text("Verknüpfen", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey("link-bible"),
              controller: _bible,
              decoration: InputDecoration(
                labelText: "Bibelstelle",
                hintText: "z. B. Gen 12,1-3",
                errorText: _bibleError,
                suffixIcon: IconButton(
                  tooltip: "Bibelstelle verknüpfen",
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _addBible,
                ),
              ),
              onSubmitted: (_) => _addBible(),
            ),
            const SizedBox(height: 16),
            Text(
              "Bereich der App",
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (target, label) in OrgAppTargets.all)
                  ActionChip(
                    label: Text(label),
                    onPressed: () => Navigator.pop(
                      context,
                      OrgLink(type: "app", target: target, label: label),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: "Aufgabe, Termin oder Notiz suchen",
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            for (final (type, id, label) in items.take(30))
              ListTile(
                dense: true,
                leading: Icon(linkIcon(type)),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(
                  context,
                  OrgLink(type: type, target: id, label: label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Auswahl der Zuordnung (mit „Neue Zuordnung“). Liefert null bei Abbruch,
/// "" für „keine“.
Future<String?> pickArea(
  BuildContext context,
  OrganizerController controller, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final study = [
        for (final a in controller.areas)
          if (a.group == OrgGroup.study) a,
      ];
      final private = [
        for (final a in controller.areas)
          if (a.group == OrgGroup.private) a,
      ];
      Widget tile(OrgArea a) => ListTile(
        dense: true,
        leading: Icon(Icons.circle, size: 14, color: areaColor(sheet, a)),
        title: Text(a.name),
        trailing: a.id == current ? const Icon(Icons.check_rounded) : null,
        onTap: () => Navigator.pop(sheet, a.id),
      );
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.block_rounded),
              title: const Text("Keine Zuordnung"),
              trailing: current == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(sheet, ""),
            ),
            const _SheetHeader("Studium"),
            for (final a in study) tile(a),
            const _SheetHeader("Privat"),
            for (final a in private) tile(a),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_rounded),
              title: const Text("Neue Zuordnung …"),
              onTap: () async {
                final created = await editAreaDialog(sheet, controller);
                if (created != null && sheet.mounted) {
                  Navigator.pop(sheet, created.id);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _SheetHeader extends StatelessWidget {
  final String text;

  const _SheetHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: context.colors.textSecondary),
    ),
  );
}

/// Neue bzw. geänderte Zuordnung (Lehrveranstaltung, Lebensbereich).
Future<OrgArea?> editAreaDialog(
  BuildContext context,
  OrganizerController controller, {
  OrgArea? area,
}) async {
  final name = TextEditingController(text: area?.name ?? "");
  var group = area?.group ?? OrgGroup.study;
  var color = area?.color ?? -1;
  String? appLink = area?.appLink;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(area == null ? "Neue Zuordnung" : "Zuordnung bearbeiten"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey("area-name"),
                controller: name,
                autofocus: area == null,
                decoration: const InputDecoration(
                  labelText: "Name",
                  hintText: "z. B. Seminar „Gottes Wort in deinem Ohr“",
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<OrgGroup>(
                segments: const [
                  ButtonSegment(value: OrgGroup.study, label: Text("Studium")),
                  ButtonSegment(value: OrgGroup.private, label: Text("Privat")),
                ],
                selected: {group},
                onSelectionChanged: (s) => setState(() => group = s.first),
              ),
              if (area != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 0; i < OrgPalette.size; i++)
                      InkWell(
                        onTap: () => setState(() => color = i),
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: areaColor(
                            dialog,
                            OrgArea(id: "", name: "", color: i),
                          ),
                          child: color == i
                              ? const Icon(Icons.check, size: 14)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: appLink,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Bereich der App (optional)",
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Keiner")),
                  for (final (target, label) in OrgAppTargets.all)
                    DropdownMenuItem(
                      value: target,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => appLink = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dialog, true);
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    ),
  );
  final text = name.text.trim();
  name.dispose();
  if (result != true || text.isEmpty) return null;
  if (area == null) {
    return controller.newArea(name: text, group: group, appLink: appLink);
  }
  final updated = area.copyWith(
    name: text,
    group: group,
    color: color < 0 ? area.color : color,
    appLink: appLink,
    clearAppLink: appLink == null,
  );
  await controller.saveArea(updated);
  return updated;
}

/// Datum wählen (eigenes Kalenderblatt, deutsch, Woche ab Montag).
Future<OrgDate?> pickDate(
  BuildContext context, {
  OrgDate? initial,
  required OrgDate today,
}) {
  return showDialog<OrgDate>(
    context: context,
    builder: (dialog) =>
        _DatePickerDialog(initial: initial ?? today, today: today),
  );
}

class _DatePickerDialog extends StatefulWidget {
  final OrgDate initial;
  final OrgDate today;

  const _DatePickerDialog({required this.initial, required this.today});

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late OrgDate month = widget.initial.startOfMonth;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: "Voriger Monat",
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => month = month.addMonths(-1)),
                ),
                Expanded(
                  child: Text(
                    "${OrgDate.monthNames[month.month - 1]} ${month.year}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: "Nächster Monat",
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => month = month.addMonths(1)),
                ),
              ],
            ),
            MonthGrid(
              month: month,
              today: widget.today,
              selected: widget.initial,
              compact: true,
              onTap: (d) => Navigator.pop(context, d),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, widget.today),
          child: const Text("Heute"),
        ),
      ],
    );
  }
}

/// Monatsblatt (Mo–So) mit optionalen Markierungen je Tag.
class MonthGrid extends StatelessWidget {
  final OrgDate month;
  final OrgDate today;
  final OrgDate? selected;
  final void Function(OrgDate day) onTap;

  /// Farben der Punkte je Tag (Termine).
  final Map<OrgDate, List<Color>> marks;

  /// Tage mit Prüfung/Abgabe (umrandet).
  final Set<OrgDate> important;
  final bool compact;

  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.onTap,
    this.selected,
    this.marks = const {},
    this.important = const {},
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final first = month.startOfMonth;
    final start = first.startOfWeek;
    final days = month.daysInMonth;
    final weeks = ((first.weekday - 1 + days) / 7).ceil();
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final w in OrgDate.weekdayShort)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: text.labelSmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = start.addDays(w * 7 + i);
                      final inMonth = day.month == month.month;
                      final isToday = day == today;
                      final isSelected = day == selected;
                      final dots = marks[day] ?? const [];
                      return InkWell(
                        key: ValueKey("day-${day.key}"),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onTap(day),
                        child: Container(
                          height: compact ? 40 : 52,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: 0.16)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            border: important.contains(day)
                                ? Border.all(color: colors.error, width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: Text(
                                  "${day.day}",
                                  style: text.bodyMedium?.copyWith(
                                    color: isToday
                                        ? colors.onPrimary
                                        : inMonth
                                        ? colors.textPrimary
                                        : colors.textSecondary.withValues(
                                            alpha: 0.5,
                                          ),
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : null,
                                  ),
                                ),
                              ),
                              if (dots.isNotEmpty)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final c in dots.take(4))
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Uhrzeit wählen: Eingabe „HH:MM“ oder eine der üblichen Anfangszeiten
/// (Kieler Raster).
Future<OrgTime?> pickTime(
  BuildContext context, {
  OrgTime? initial,
  String title = "Uhrzeit",
}) {
  final controller = TextEditingController(text: initial?.key ?? "");
  return showDialog<OrgTime>(
    context: context,
    builder: (dialog) {
      String? error;
      return StatefulBuilder(
        builder: (dialog, setState) {
          void submit() {
            final t = OrgTime.tryParse(controller.text);
            if (t == null) {
              setState(() => error = "Bitte als HH:MM eingeben");
              return;
            }
            Navigator.pop(dialog, t);
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey("time-input"),
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    hintText: "z. B. 10:15",
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in const [
                      "08:15",
                      "10:15",
                      "12:15",
                      "14:15",
                      "16:15",
                      "18:15",
                      "09:45",
                      "11:45",
                      "13:45",
                      "15:45",
                      "17:45",
                      "19:45",
                    ])
                      ActionChip(
                        label: Text(t),
                        onPressed: () =>
                            Navigator.pop(dialog, OrgTime.tryParse(t)),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text("Abbrechen"),
              ),
              FilledButton(onPressed: submit, child: const Text("OK")),
            ],
          );
        },
      );
    },
  );
}

/// Hinweis „Nicht gespeichert“, wenn ein Schreibvorgang scheiterte.
class SaveFailedBanner extends StatelessWidget {
  final OrganizerController controller;

  const SaveFailedBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.saveFailed) return const SizedBox.shrink();
    return Material(
      color: context.colors.errorBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: context.colors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Eine Änderung konnte nicht gespeichert werden. Sie bleibt auf "
                "diesem Gerät sichtbar, bis die Verbindung wieder besteht.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abschnittsüberschrift in Listen.
class OrgSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final Color? color;

  const OrgSectionTitle(this.text, {super.key, this.trailing, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color ?? context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Leerer Zustand einer Liste.
class OrgEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const OrgEmpty({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      children: [
        Icon(icon, size: 40, color: context.colors.textSecondary),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}
