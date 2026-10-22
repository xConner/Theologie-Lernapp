import 'package:flutter/material.dart';

import '../../models/old_testament/old_testament.dart';
import '../../theme/app_theme.dart';
import 'old_testament_widgets.dart';

/// Alle Fachbegriffe der Einheiten mit Filter, je mit Herkunft.
class GlossaryScreen extends StatefulWidget {
  final OldTestamentData data;

  const GlossaryScreen({super.key, required this.data});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String query = "";

  bool _matches(Term t) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      t.name,
      ?t.hebrew,
      ?t.transliteration,
      ...t.aliases,
      t.definition,
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final terms = widget.data.sortedTerms.where(_matches).toList();

    return ChurchHistoryPage(
      title: "Fachbegriffe",
      children: [
        TextField(
          key: const ValueKey("glossary-filter"),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: "Begriff oder Erklärung filtern",
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 8),
        Text(
          "${terms.length} von ${widget.data.terms.length} Begriffen",
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        if (terms.isEmpty) const EmptyHint("Kein Begriff passt zum Filter."),
        for (final t in terms) TermCard(data: widget.data, term: t),
      ],
    );
  }
}
