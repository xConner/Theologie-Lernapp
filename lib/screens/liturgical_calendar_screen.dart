import 'package:flutter/material.dart';

import '../models/liturgical_day.dart';
import '../services/liturgical_calendar_loader.dart';

class LiturgicalCalendarScreen extends StatefulWidget {
  const LiturgicalCalendarScreen({super.key});

  @override
  State<LiturgicalCalendarScreen> createState() =>
      _LiturgicalCalendarScreenState();
}

class _LiturgicalCalendarScreenState extends State<LiturgicalCalendarScreen> {
  LiturgicalDay? day;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final calendar = await LiturgicalCalendarLoader.load();

      final today = DateTime.now();

      LiturgicalDay? selected;

      // zuerst heutigen Tag suchen
      for (final entry in calendar) {
        if (_sameDay(entry.date, today)) {
          selected = entry;
          break;
        }
      }

      // falls nicht vorhanden: nächster zukünftiger Eintrag
      selected ??= calendar.firstWhere(
        (entry) => entry.date.isAfter(today),
        orElse: () => calendar.last,
      );

      setState(() {
        day = selected;
        loading = false;
      });
    } catch (e) {
      setState(() {
        day = null;
        loading = false;
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (day == null) {
      return const Scaffold(body: Center(child: Text("Kein Eintrag gefunden")));
    }

    final d = day!;

    return Scaffold(
      appBar: AppBar(title: const Text("Liturgischer Kalender")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              d.displayTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              "${d.date.day}.${d.date.month}.${d.date.year}",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 8),

            Text("Liturgische Farbe: ${d.color}"),

            const Divider(height: 32),

            _section("Spruch", "${d.spruch.text}\n(${d.spruch.reference})"),

            _section("Psalm", d.psalm),

            _section("Lieder", d.songs.join("\n")),

            _section("Lesungen", """
Altes Testament:
${d.readings.oldTestament}

Epistel:
${d.readings.epistle}

${d.readings.hallelujah != null ? "Hallelujavers:\n${d.readings.hallelujah}\n\n" : ""}
Evangelium:
${d.readings.gospel}

Predigttext:
${d.readings.sermon}
"""),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
