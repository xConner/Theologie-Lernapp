import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../models/liturgical_event.dart';
import '../models/liturgical_day.dart';
import '../services/bible/bible_repository.dart';
import '../services/bible/liturgical_reference_parser.dart';
import '../services/bible/pericope_headings.dart';
import '../services/hymn_reference_parser.dart';
import '../services/hymn_service.dart';
import '../services/liturgical_calendar_loader.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_access.dart';
import '../info/app_info.dart';
import '../widgets/info_report.dart';
import 'bible/bible_reader_screen.dart';
import 'hymn_detail_screen.dart';

class LiturgicalCalendarScreen extends StatefulWidget {
  // Nur für Tests ersetzbar; standardmäßig die ausgelieferten Daten.
  final Future<List<LiturgicalDay>> Function()? loadDays;

  final BibleRepository? bibleRepository;

  final PericopeHeadings? pericopeHeadings;

  // Nur für Tests ersetzbar; standardmäßig das ausgelieferte Gesangbuch.
  final Future<List<Hymn>> Function()? loadHymns;

  const LiturgicalCalendarScreen({
    super.key,
    this.loadDays,
    this.bibleRepository,
    this.pericopeHeadings,
    this.loadHymns,
  });

  @override
  State<LiturgicalCalendarScreen> createState() =>
      _LiturgicalCalendarScreenState();
}

class _LiturgicalCalendarScreenState extends State<LiturgicalCalendarScreen> {
  List<LiturgicalEvent> events = [];

  bool loading = true;

  int currentIndex = 0;

  String? selectedVariant;

  /// Die Lieder des Gesangbuchs nach Nummer; leer, solange sie nicht geladen
  /// sind.
  Map<int, Hymn> hymns = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadHymns();
  }

  Future<void> _loadHymns() async {
    try {
      final data = await (widget.loadHymns ?? HymnService().loadHymns)();

      if (!mounted) return;

      setState(() {
        hymns = {for (final hymn in data) hymn.id: hymn};
      });
    } catch (e) {
      // Ohne Gesangbuch bleiben die Lieder schlichter Text.
    }
  }

  Future<void> _load() async {
    try {
      final data = await (widget.loadDays ?? LiturgicalCalendarLoader.load)();

      final Map<String, List<LiturgicalDay>> groups = {};

      for (final day in data) {
        final key =
            "${day.date.year}-${day.date.month}-${day.date.day}-${day.title}";

        groups.putIfAbsent(key, () => []);
        groups[key]!.add(day);
      }

      events = groups.values.map((variants) {
        return LiturgicalEvent(
          date: variants.first.date,
          title: variants.first.title,
          variants: variants,
        );
      }).toList();

      final today = DateTime.now();

      currentIndex = events.indexWhere(
        (event) =>
            event.date.year == today.year &&
            event.date.month == today.month &&
            event.date.day == today.day,
      );

      if (currentIndex == -1) {
        currentIndex = events.indexWhere(
          (event) => !event.date.isBefore(
            DateTime(today.year, today.month, today.day),
          ),
        );
      }

      if (currentIndex == -1) {
        currentIndex = events.length - 1;
      }

      selectedVariant = currentVariants.first.variant;

      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  List<LiturgicalDay> get currentVariants => events[currentIndex].variants;

  LiturgicalDay get currentDay {
    if (currentVariants.length == 1) {
      return currentVariants.first;
    }

    if (selectedVariant == null) {
      return currentVariants.first;
    }

    return currentVariants.firstWhere(
      (e) => e.variant == selectedVariant,
      orElse: () => currentVariants.first,
    );
  }

  void previous() {
    if (currentIndex == 0) return;

    setState(() {
      currentIndex--;
      selectedVariant = currentVariants.first.variant;
    });
  }

  void next() {
    if (currentIndex >= events.length - 1) return;

    setState(() {
      currentIndex++;
      selectedVariant = currentVariants.first.variant;
    });
  }

  Color liturgicalColor(String color) {
    switch (color) {
      case "grün":
        return Colors.green;
      case "rot":
        return Colors.red;
      case "violett":
        return Colors.deepPurple;
      case "weiß":
        return Colors.white;
      case "schwarz":
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime d) {
    const months = [
      "",
      "Januar",
      "Februar",
      "März",
      "April",
      "Mai",
      "Juni",
      "Juli",
      "August",
      "September",
      "Oktober",
      "November",
      "Dezember",
    ];

    return "${d.day}. ${months[d.month]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (events.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Keine Kalenderdaten gefunden.")),
      );
    }

    final day = currentDay;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Liturgischer Kalender"),
        actions: [
          InfoButton(
            module: AppModules.calendar,
            reportDetails: () => {
              "Tag": "${formatDate(day.date)} – ${day.title}",
              if (day.variant != null) "Variante": day.variant!,
            },
          ),
          const SettingsButton(),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: currentIndex == 0 ? null : previous,
                      icon: const Icon(Icons.chevron_left),
                    ),

                    Expanded(
                      child: Center(
                        child: Text(
                          formatDate(day.date),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: currentIndex == events.length - 1
                          ? null
                          : next,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Center(
                          child: Text(
                            events[currentIndex].title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        if (day.info != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              day.info!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        if (currentVariants.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),

                            child: DropdownButton<String>(
                              value: selectedVariant,

                              isExpanded: true,

                              items: currentVariants
                                  .where((e) => e.variant != null)
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.variant,
                                      child: Text(e.variant!),
                                    ),
                                  )
                                  .toList(),

                              onChanged: (value) {
                                setState(() {
                                  selectedVariant = value;
                                });
                              },
                            ),
                          ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            Container(
                              width: 22,
                              height: 22,

                              decoration: BoxDecoration(
                                color: liturgicalColor(day.color),
                                border: Border.all(
                                  color: context.colors.textSecondary,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Text(day.color),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _section(
                  "Spruch",
                  day.spruch.text,
                  reference: day.spruch.reference,
                  id: "spruch",
                ),

                _section("Psalm", null, reference: day.psalm, id: "psalm"),

                _songsSection(day.songs),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          "Lesungen",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        _readingTile(
                          "Altes Testament",
                          day.readings.oldTestament,
                          "old-testament",
                        ),

                        _readingTile(
                          "Epistel",
                          day.readings.epistle,
                          "epistle",
                        ),

                        if (day.readings.hallelujah != null)
                          _readingTile(
                            "Hallelujavers",
                            day.readings.hallelujah!,
                            "hallelujah",
                          ),

                        _readingTile(
                          "Evangelium",
                          day.readings.gospel,
                          "gospel",
                        ),

                        _readingTile(
                          "Predigttext",
                          day.readings.sermon,
                          "sermon",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Öffnet [reference] im Bibel-Reader. Nennt die Angabe mehrere Stellen
  /// („;“ bzw. „oder“), sind dort alle erreichbar.
  void _openReference(String title, String reference) {
    final passages = LiturgicalReferenceParser.parse(reference);

    if (passages.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          passages: passages,
          passageTitle: "${events[currentIndex].title} · $title",
          repository: widget.bibleRepository,
          pericopeHeadings: widget.pericopeHeadings,
        ),
      ),
    );
  }

  /// Eine Stellenangabe; lässt sie sich lesen, führt Antippen in den
  /// Bibel-Reader.
  Widget _reference(String title, String reference, String id) {
    const style = TextStyle(fontSize: 16);

    if (LiturgicalReferenceParser.parse(reference).isEmpty) {
      return Text(reference, style: style);
    }

    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      key: ValueKey("calendar-reference-$id"),
      onTap: () => _openReference(title, reference),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Flexible(
              child: Text(reference, style: style.copyWith(color: color)),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: "Im Bibel-Reader öffnen",
              child: Icon(Icons.menu_book_outlined, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _openHymn(Hymn hymn) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HymnDetailScreen(hymn: hymn)),
    );
  }

  /// Eine Liedangabe; steht das Lied im Gesangbuch, führt Antippen in die
  /// Liedansicht. Nennt die Angabe mehrere Nummern, bekommt jede eine Zeile.
  List<Widget> _song(String song) {
    const style = TextStyle(fontSize: 16);

    final numbers = HymnReferenceParser.parse(song);

    if (numbers.isEmpty || numbers.any((n) => !hymns.containsKey(n))) {
      return [Text(song, style: style)];
    }

    final color = Theme.of(context).colorScheme.primary;
    final title = song.substring(song.indexOf(":") + 1).trim();

    return [
      for (final number in numbers)
        InkWell(
          key: ValueKey("calendar-hymn-$number"),
          onTap: () => _openHymn(hymns[number]!),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    numbers.length == 1 ? song : "EG $number: $title",
                    style: style.copyWith(color: color),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: "Im Gesangbuch öffnen",
                  child: Icon(
                    Icons.music_note_outlined,
                    size: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _songsSection(List<String> songs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 1),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Lieder",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            for (final song in songs) ..._song(song),
          ],
        ),
      ),
    );
  }

  Widget _section(
    String title,
    String? content, {
    String? reference,
    String? id,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 1),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (content != null)
              Text(content, style: const TextStyle(fontSize: 16)),

            if (content != null && reference != null)
              const SizedBox(height: 12),

            if (reference != null) _reference(title, reference, id!),
          ],
        ),
      ),
    );
  }

  Widget _readingTile(String title, String reference, String id) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          _reference(title, reference, id),
        ],
      ),
    );
  }
}
