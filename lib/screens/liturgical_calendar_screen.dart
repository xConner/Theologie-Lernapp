import 'package:flutter/material.dart';

import '../models/liturgical_event.dart';
import '../models/liturgical_day.dart';
import '../services/liturgical_calendar_loader.dart';

class LiturgicalCalendarScreen extends StatefulWidget {
  const LiturgicalCalendarScreen({super.key});

  @override
  State<LiturgicalCalendarScreen> createState() =>
      _LiturgicalCalendarScreenState();
}

class _LiturgicalCalendarScreenState extends State<LiturgicalCalendarScreen> {
  List<LiturgicalEvent> events = [];

  bool loading = true;

  int currentIndex = 0;

  String? selectedVariant;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await LiturgicalCalendarLoader.load();

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
      appBar: AppBar(title: const Text("Liturgischer Kalender")),

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
                                border: Border.all(color: Colors.black26),
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
                  "${day.spruch.text}\n\n(${day.spruch.reference})",
                ),

                _section("Psalm", day.psalm),

                _section("Lieder", day.songs.join("\n")),

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
                        ),

                        _readingTile("Epistel", day.readings.epistle),

                        if (day.readings.hallelujah != null)
                          _readingTile(
                            "Hallelujavers",
                            day.readings.hallelujah!,
                          ),

                        _readingTile("Evangelium", day.readings.gospel),

                        _readingTile("Predigttext", day.readings.sermon),
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

  Widget _section(String title, String content) {
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

            Text(content, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _readingTile(String title, String reference) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(reference, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
