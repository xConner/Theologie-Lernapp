import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/history/history_course.dart';
import '../../services/history/history_trainer.dart';
import '../../theme/app_theme.dart';
import 'history_practice_screen.dart';
import 'history_widgets.dart';

/// Interaktiver Zeitstrahl: Überblick mit Zeiträumen, Personen (als
/// Balken ihrer Lebens- bzw. Wirkungszeit) und Ereignissen; ein Tipp auf
/// einen Zeitraum oder ein Jahrhundert zeigt die Einzelheiten.
///
/// Gegen Überladung: Filter nach Art und Spur, standardmäßig nur im
/// Lernpfad eingeführte Inhalte (umschaltbar, nichts ist gesperrt), und
/// zum Üben lassen sich die Jahreszahlen verdecken.
class HistoryTimelineScreen extends StatefulWidget {
  final HistoryTrainer trainer;
  final HistoryArea area;
  final String? uid;

  const HistoryTimelineScreen({
    super.key,
    required this.trainer,
    required this.area,
    this.uid,
  });

  @override
  State<HistoryTimelineScreen> createState() => _HistoryTimelineScreenState();
}

/// Ausschnitt der Detailansicht.
class _Range {
  final String label;
  final int from;
  final int to;
  final String? periodId;

  const _Range(this.label, this.from, this.to, {this.periodId});
}

class _HistoryTimelineScreenState extends State<HistoryTimelineScreen> {
  late bool onlyIntroduced;
  bool hideYears = false;
  Set<HistoryItemKind> kinds = {...HistoryItemKind.values};
  String? trackId;
  _Range? range;
  final Set<String> revealed = {};

  HistoryTrainer get trainer => widget.trainer;
  HistoryCourse get course => trainer.course;

  @override
  void initState() {
    super.initState();
    onlyIntroduced = course.items.any((i) => trainer.isIntroduced(i.id));
  }

  List<HistoryItem> get _visible => [
    for (final i in course.items)
      if (kinds.contains(i.kind) &&
          (trackId == null || i.trackId == trackId) &&
          (!onlyIntroduced || trainer.isIntroduced(i.id)))
        i,
  ];

  List<HistoryItem> get _dated =>
      sortChronologically(_visible.where((i) => i.dating != null));

  int get _hiddenCount => onlyIntroduced
      ? course.items
            .where(
              (i) =>
                  kinds.contains(i.kind) &&
                  (trackId == null || i.trackId == trackId) &&
                  !trainer.isIntroduced(i.id),
            )
            .length
      : 0;

  static int _end(HistoryItem i) => i.dating!.to ?? DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final dated = _dated;
    final selected = range;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Zeitstrahl"),
        actions: [
          IconButton(
            key: const ValueKey("timeline-hide-years"),
            tooltip: hideYears
                ? "Jahreszahlen zeigen"
                : "Jahreszahlen verdecken (üben)",
            icon: Icon(
              hideYears
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
            onPressed: () => setState(() {
              hideYears = !hideYears;
              revealed.clear();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ContentPage.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _filters(context),
                    const SizedBox(height: 12),
                    if (dated.isEmpty)
                      EmptyHint(
                        onlyIntroduced
                            ? "Noch keine eingeführten Inhalte mit Datierung. "
                                  "Schalte „Nur Eingeführtes“ aus, um alles "
                                  "zu sehen, oder beginne mit dem Lernpfad."
                            : "Keine datierten Inhalte für diese Auswahl.",
                      )
                    else if (selected == null)
                      ..._overview(context, dated)
                    else
                      ..._details(context, dated, selected),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final secondary = TextStyle(
      color: context.colors.textSecondary,
      fontSize: 12.5,
    );
    final usedKinds = {for (final i in course.items) i.kind};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              key: const ValueKey("timeline-only-introduced"),
              label: const Text("Nur Eingeführtes"),
              selected: onlyIntroduced,
              onSelected: (v) => setState(() => onlyIntroduced = v),
            ),
            for (final k in HistoryItemKind.values)
              if (usedKinds.contains(k))
                FilterChip(
                  key: ValueKey("timeline-kind-${k.name}"),
                  avatar: Icon(historyKindIcon(k), size: 16),
                  label: Text(k.plural),
                  selected: kinds.contains(k),
                  onSelected: (on) => setState(() {
                    kinds = {...kinds};
                    on ? kinds.add(k) : kinds.remove(k);
                  }),
                ),
          ],
        ),
        if (course.tracks.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Alle Spuren"),
                selected: trackId == null,
                onSelected: (_) => setState(() {
                  trackId = null;
                  range = null;
                }),
              ),
              for (final t in course.tracks)
                ChoiceChip(
                  key: ValueKey("timeline-track-${t.id}"),
                  label: Text(t.title),
                  selected: trackId == t.id,
                  onSelected: (_) => setState(() {
                    trackId = t.id;
                    range = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          [
            "○ ungefähr  ◌ umstritten",
            if (_hiddenCount > 0) "$_hiddenCount noch nicht eingeführt",
            if (hideYears) "Jahreszahlen verdeckt – antippen zum Aufdecken",
          ].join(" · "),
          style: secondary,
        ),
      ],
    );
  }

  List<Widget> _overview(BuildContext context, List<HistoryItem> dated) {
    final from = dated.map((i) => i.dating!.from).reduce(math.min);
    final to = dated.map(_end).reduce(math.max);

    final periods = [
      for (final p in dated)
        if (p.kind == HistoryItemKind.period) p,
    ];

    final centuries = <int, List<HistoryItem>>{};
    for (final i in dated) {
      if (i.kind == HistoryItemKind.period) continue;
      centuries.putIfAbsent(centuryOf(i.dating!.from), () => []).add(i);
    }
    final centuryKeys = centuries.keys.toList()..sort();

    return [
      Text("Überblick", style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _Axis(
        from: from,
        to: to,
        items: dated,
        hideYears: hideYears,
        introduced: trainer.isIntroduced,
        onTapYear: (year) {
          final hit = periods.where(
            (p) => p.dating!.from <= year && year <= _end(p),
          );
          if (hit.isNotEmpty) _openPeriod(hit.first, dated);
        },
      ),
      if (periods.isNotEmpty) ...[
        const ContentSectionTitle("Zeiträume"),
        for (final p in periods)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: ValueKey("timeline-period-${p.id}"),
              leading: Icon(historyKindIcon(p.kind)),
              title: Text(p.name),
              subtitle: Text(_dateText(p)),
              trailing: Text(
                "${_inPeriod(p, dated).length}",
                style: TextStyle(color: context.colors.textSecondary),
              ),
              onTap: () => _openPeriod(p, dated),
            ),
          ),
      ],
      if (centuryKeys.isNotEmpty) ...[
        const ContentSectionTitle("Nach Jahrhunderten"),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in centuryKeys)
              ActionChip(
                key: ValueKey("timeline-century-$c"),
                label: Text("${centuryLabel(c)} (${centuries[c]!.length})"),
                onPressed: () => setState(() {
                  final start = c < 0 ? c * 100 : (c - 1) * 100 + 1;
                  range = _Range(centuryLabel(c), start, start + 99);
                }),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const ValueKey("timeline-practice"),
        icon: const Icon(Icons.swap_vert_rounded),
        label: const Text("Reihenfolgen üben"),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryPracticeScreen(
              trainer: trainer,
              mode: HistoryMode.chronology,
              area: widget.area,
              uid: widget.uid,
            ),
          ),
        ).then((_) => setState(() {})),
      ),
    ];
  }

  List<HistoryItem> _inPeriod(HistoryItem period, List<HistoryItem> dated) => [
    for (final i in dated)
      if (i.id != period.id &&
          (i.periodId == period.id ||
              (i.periodId == null &&
                  i.dating!.from >= period.dating!.from &&
                  i.dating!.from <= _end(period))))
        i,
  ];

  void _openPeriod(HistoryItem period, List<HistoryItem> dated) {
    final members = _inPeriod(period, dated);
    final from = [
      period.dating!.from,
      for (final m in members) m.dating!.from,
    ].reduce(math.min);
    final to = [
      _end(period),
      for (final m in members) _end(m),
    ].reduce(math.max);
    setState(() {
      range = _Range(period.name, from, to, periodId: period.id);
    });
  }

  List<Widget> _details(
    BuildContext context,
    List<HistoryItem> dated,
    _Range r,
  ) {
    final items = [
      for (final i in dated)
        if (i.id != r.periodId &&
            (r.periodId != null
                ? _inPeriod(course.item(r.periodId!)!, dated).contains(i)
                : i.dating!.from <= r.to && _end(i) >= r.from))
          i,
    ];

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              r.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            key: const ValueKey("timeline-back"),
            icon: const Icon(Icons.zoom_out_rounded, size: 18),
            label: const Text("Überblick"),
            onPressed: () => setState(() => range = null),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (items.isNotEmpty)
        _Axis(
          from: math.min(
            r.from,
            items.map((i) => i.dating!.from).reduce(math.min),
          ),
          to: math.max(r.to, items.map(_end).reduce(math.max)),
          items: items,
          hideYears: hideYears,
          introduced: trainer.isIntroduced,
        ),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const EmptyHint("In diesem Ausschnitt gibt es keine Einträge.")
      else
        for (final i in items) _row(context, i, r),
    ];
  }

  String _dateText(HistoryItem i) {
    if (hideYears && !revealed.contains(i.id)) return "?";
    return i.dating!.label;
  }

  Widget _row(BuildContext context, HistoryItem item, _Range r) {
    final colors = context.colors;
    final dating = item.dating!;
    final actors = [
      for (final o in course.relatedOf(item.id))
        if (o.dating == null &&
            (o.kind == HistoryItemKind.person ||
                o.kind == HistoryItemKind.group))
          o,
    ];
    final span = math.max(1, r.to - r.from);
    final start = ((dating.from - r.from) / span).clamp(0.0, 1.0);
    final end = ((_end(item) - r.from) / span).clamp(0.0, 1.0);

    return InkWell(
      key: ValueKey("timeline-item-${item.id}"),
      onTap: () => showHistoryItemSheet(context, course, item, widget.area),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: InkWell(
                key: ValueKey("timeline-year-${item.id}"),
                onTap: hideYears && !revealed.contains(item.id)
                    ? () => setState(() => revealed.add(item.id))
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Text(
                    _dateText(item),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final left = start * w;
                      final width = math.max(6.0, (end - start) * w);
                      return SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: colors.divider.withValues(alpha: 0.4),
                              ),
                            ),
                            Positioned(
                              left: math.min(left, w - width),
                              width: width,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: dating.approx || dating.disputed
                                      ? colors.primary.withValues(alpha: 0.45)
                                      : colors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Tag(item.kind.label, icon: historyKindIcon(item.kind)),
                      if (dating.precisionHint != null &&
                          !(hideYears && !revealed.contains(item.id)))
                        Tag(dating.precisionHint!, color: colors.accent),
                      if (!trainer.isIntroduced(item.id))
                        Tag("noch nicht eingeführt"),
                      for (final a in actors)
                        Tag(a.name, icon: historyKindIcon(a.kind)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Waagerechte Achse mit Zeiträumen (Bänder), Personen (Balken) und
/// Ereignissen (Punkte; offen = ungefähr, gestrichelt = umstritten).
class _Axis extends StatelessWidget {
  final int from;
  final int to;
  final List<HistoryItem> items;
  final bool hideYears;
  final bool Function(String id) introduced;
  final void Function(int year)? onTapYear;

  const _Axis({
    required this.from,
    required this.to,
    required this.items,
    required this.hideYears,
    required this.introduced,
    this.onTapYear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lo = from;
    final hi = to <= from ? from + 1 : to;
    final pad = math.max(1, ((hi - lo) * 0.03).round());

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: const ValueKey("timeline-axis"),
          onTapUp: onTapYear == null
              ? null
              : (d) {
                  final year =
                      (lo - pad) +
                      (d.localPosition.dx / width) * ((hi + pad) - (lo - pad));
                  onTapYear!(year.round());
                },
          child: CustomPaint(
            size: Size(width, 96),
            painter: _AxisPainter(
              from: lo - pad,
              to: hi + pad,
              items: items,
              hideYears: hideYears,
              primary: colors.primary,
              accent: colors.accent,
              text: colors.textSecondary,
              line: colors.divider,
              surface: colors.surface,
            ),
          ),
        );
      },
    );
  }
}

class _AxisPainter extends CustomPainter {
  final int from;
  final int to;
  final List<HistoryItem> items;
  final bool hideYears;
  final Color primary;
  final Color accent;
  final Color text;
  final Color line;
  final Color surface;

  _AxisPainter({
    required this.from,
    required this.to,
    required this.items,
    required this.hideYears,
    required this.primary,
    required this.accent,
    required this.text,
    required this.line,
    required this.surface,
  });

  double _x(num year, Size size) => (year - from) / (to - from) * size.width;

  static String _yearLabel(int year) => year < 0
      ? "${-year} v. Chr."
      : year == 0
      ? "Zeitenwende"
      : "$year";

  @override
  void paint(Canvas canvas, Size size) {
    final axisY = size.height - 22;

    // Zeiträume als Bänder.
    final periods = [
      for (final i in items)
        if (i.kind == HistoryItemKind.period) i,
    ];
    for (var k = 0; k < periods.length; k++) {
      final p = periods[k];
      final rect = Rect.fromLTRB(
        _x(p.dating!.from, size),
        4.0 + (k % 2) * 8,
        _x(p.dating!.to ?? DateTime.now().year, size),
        18.0 + (k % 2) * 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = (k.isEven ? primary : accent).withValues(alpha: 0.25),
      );
    }

    // Personen als Balken.
    final persons = [
      for (final i in items)
        if (i.kind == HistoryItemKind.person) i,
    ];
    for (var k = 0; k < persons.length; k++) {
      final p = persons[k];
      final y = 36.0 + (k % 3) * 5;
      final x1 = _x(p.dating!.from, size);
      final x2 = math.max(x1 + 3, _x(p.dating!.to ?? p.dating!.from, size));
      canvas.drawLine(
        Offset(x1, y),
        Offset(x2, y),
        Paint()
          ..color = accent
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Achse.
    canvas.drawLine(
      Offset(0, axisY),
      Offset(size.width, axisY),
      Paint()
        ..color = line
        ..strokeWidth = 2,
    );

    // Ereignisse als Punkte.
    for (final e in items) {
      if (e.kind != HistoryItemKind.event) continue;
      final d = e.dating!;
      final x = _x((d.from + (d.to ?? d.from)) / 2, size);
      final open = d.approx || d.disputed;
      canvas.drawCircle(
        Offset(x, axisY - 10),
        4.5,
        Paint()
          ..color = open ? surface : primary
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, axisY - 10),
        4.5,
        Paint()
          ..color = d.disputed ? accent : primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.disputed ? 2.5 : 1.5,
      );
    }

    if (hideYears) return;

    // Beschriftung: etwa fünf runde Jahreszahlen.
    final span = to - from;
    const steps = [5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];
    final step = steps.firstWhere((s) => span / s <= 6, orElse: () => 1000);
    var tick = (from / step).ceil() * step;
    while (tick <= to) {
      final x = _x(tick, size);
      canvas.drawLine(
        Offset(x, axisY - 3),
        Offset(x, axisY + 3),
        Paint()
          ..color = text
          ..strokeWidth = 1,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: _yearLabel(tick),
          style: TextStyle(color: text, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (x - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(left, axisY + 5));
      tick += step;
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.from != from ||
      old.to != to ||
      old.items != items ||
      old.hideYears != hideYears ||
      old.primary != primary;
}
