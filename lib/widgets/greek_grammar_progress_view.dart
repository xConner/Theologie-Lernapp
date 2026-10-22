import 'package:flutter/material.dart';

import '../algorithms/grammar_learning.dart';
import '../theme/app_theme.dart';

/// Fortschritt des Griechisch-Grammatiktrainers: Lernbedarf je geübtem
/// Merkmal (Tempus, Kasus, Person …), gruppiert nach Wortart, und die
/// Merkmale mit dem größten Lernbedarf.
///
/// Grundlage sind allein die Merkmalskarten von [GrammarLearning]
/// (`dim.<Wortart>.<Merkmal>.<Wert>`); es wird nichts zusätzlich gespeichert.
/// Noch nie gefragte Werte erscheinen nicht. Die Einstufung folgt
/// [GrammarLearning.need], also derselben Größe, die die Auswahl im Trainer
/// gewichtet.
class GreekGrammarProgressView extends StatelessWidget {
  final ScrollController? controller;
  final GrammarLearning learning;

  const GreekGrammarProgressView({
    super.key,
    this.controller,
    required this.learning,
  });

  static const Map<String, String> typeLabels = {
    "noun": "Substantive",
    "verb": "Verben",
    "participle": "Partizipien",
    "pronoun": "Pronomen",
    "comparison": "Steigerung",
  };

  static const Map<String, String> dimensionLabels = {
    "case": "Kasus",
    "number": "Numerus",
    "gender": "Genus",
    "mood": "Modus",
    "tense": "Tempus",
    "voice": "Genus verbi",
    "person": "Person",
    "degree": "Steigerungsstufe",
  };

  /// Zerlegt eine Merkmalskarte in (Wortart, Merkmal, Wert); null für
  /// Grundform-Karten und unbekannte Merkmale (z. B. „form“ der Steigerung,
  /// das je Adjektiv gilt).
  static (String, String, String)? parse(String id) {
    final parts = id.split(".");

    if (parts.length != 4 || parts[0] != "dim") return null;
    if (!typeLabels.containsKey(parts[1])) return null;
    if (!dimensionLabels.containsKey(parts[2])) return null;

    // Personen sind als „1-Sg“ gespeichert (Punkt entfernt).
    final value = parts[2] == "person"
        ? parts[3].replaceFirst("-", ". ")
        : parts[3].replaceAll("-", " ");

    return (parts[1], parts[2], value);
  }

  /// Lesbare Bezeichnung, z. B. „Verben – Tempus: Aorist“.
  static String? label(String id) {
    final parsed = parse(id);
    if (parsed == null) return null;

    final (type, dimension, value) = parsed;
    return "${typeLabels[type]} – ${dimensionLabels[dimension]}: $value";
  }

  /// Einstufung des Lernbedarfs (0,5 … 2,0, neutral 1).
  static String needLabel(double need) {
    if (need >= 1.2) return "viel zu üben";
    if (need <= 0.8) return "sicher";
    return "im Aufbau";
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    // Wortart → Merkmal → [(Wert, Lernbedarf)]
    final grouped = <String, Map<String, List<(String, double)>>>{};

    for (final id in learning.cards.keys) {
      final parsed = parse(id);
      if (parsed == null) continue;

      final (type, dimension, value) = parsed;
      grouped.putIfAbsent(type, () => {}).putIfAbsent(dimension, () => []).add((
        value,
        learning.need(id),
      ));
    }

    final weak = [
      for (final card in learning.cards.values)
        if (parse(card.id) != null && card.difficulty > 5)
          (card.id, learning.need(card.id)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text("Fortschritt", style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Lernbedarf je geübtem Merkmal. Was dir schwerfällt, kommt im "
          "Trainer häufiger dran; sicher Gewusstes nähert sich mit der Zeit "
          "wieder dem Normalwert.",
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text("Am meisten zu üben", style: textTheme.titleMedium),
        const SizedBox(height: 6),
        if (weak.isEmpty)
          Text(
            "Noch keine Schwachstellen erkannt.",
            key: const ValueKey("greek-grammar-no-weak"),
            style: TextStyle(color: colors.textSecondary),
          )
        else
          for (final (id, _) in weak.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("• ${label(id)}"),
            ),
        if (grouped.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "Noch nichts geübt.",
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        for (final type in typeLabels.keys)
          if (grouped[type] case final dimensions?) ...[
            const SizedBox(height: 16),
            Text(typeLabels[type]!, style: textTheme.titleMedium),
            for (final dimension in dimensionLabels.keys)
              if (dimensions[dimension] case final values?)
                _DimensionCard(
                  title: dimensionLabels[dimension]!,
                  values: values..sort((a, b) => a.$1.compareTo(b.$1)),
                ),
          ],
      ],
    );
  }
}

class _DimensionCard extends StatelessWidget {
  final String title;
  final List<(String, double)> values;

  const _DimensionCard({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final (value, need) in values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(value)),
                    Expanded(
                      flex: 2,
                      // Voll = sicher (Lernbedarf 0,5), leer = 2,0.
                      child: LinearProgressIndicator(
                        value: ((2 - need) / 1.5).clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        GreekGrammarProgressView.needLabel(need),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
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
