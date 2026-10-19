import 'package:flutter/material.dart';

import '../../info/app_info.dart';
import '../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../services/latin/vocabulary/latin_vocabulary_loader.dart';
import '../../theme/app_theme.dart';
import '../../utils/latin_normalization.dart';
import '../../widgets/info_report.dart';
import '../../widgets/settings_access.dart';

enum LatinVocabularySort { alphabet, step, type }

/// Reihenfolge der Wortarten in der Sortierung „Wortart“.
const Map<String, int> latinTypeOrder = {
  "noun": 0,
  "verb": 1,
  "adjective": 2,
  "pronoun": 3,
  "preposition": 4,
  "conjunction": 5,
  "adverb": 6,
  "particle": 7,
  "question_word": 8,
  "phrase": 9,
};

/// Anzeigename einer Wortart (Singular).
String latinTypeName(String type) {
  switch (type) {
    case "noun":
      return "Nomen";
    case "verb":
      return "Verb";
    case "adjective":
      return "Adjektiv";
    case "pronoun":
      return "Pronomen";
    case "preposition":
      return "Präposition";
    case "conjunction":
      return "Konjunktion";
    case "particle":
      return "Partikel";
    case "adverb":
      return "Adverb";
    case "question_word":
      return "Fragewort";
    case "phrase":
      return "Wendung";
    default:
      return type;
  }
}

/// Vokabelübersicht Latein. Liest dieselbe Vokabelliste wie der
/// Vokabeltrainer ([LatinVocabularyLoader]); neue Einträge erscheinen damit
/// automatisch in beiden Bereichen.
class LatinVocabularyOverviewScreen extends StatefulWidget {
  /// Für Tests: Vokabeln direkt übergeben statt aus den Assets zu laden.
  final Future<List<LatinVocabularyEntry>>? vocabulary;

  const LatinVocabularyOverviewScreen({super.key, this.vocabulary});

  @override
  State<LatinVocabularyOverviewScreen> createState() =>
      _LatinVocabularyOverviewScreenState();
}

class _LatinVocabularyOverviewScreenState
    extends State<LatinVocabularyOverviewScreen> {
  List<LatinVocabularyEntry> entries = [];

  bool loading = true;
  String? loadError;

  LatinVocabularySort sort = LatinVocabularySort.step;

  /// Gewählter Schritt; null = alle.
  int? stepFilter;

  String search = "";

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      entries = await (widget.vocabulary ?? LatinVocabularyLoader.load());
    } catch (e) {
      debugPrint("Lateinische Vokabeln konnten nicht geladen werden: $e");
      loadError = "Die Vokabeln konnten nicht geladen werden.";
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  List<int> get steps {
    return entries.map((e) => e.step).toSet().toList()..sort();
  }

  List<LatinVocabularyEntry> get filteredEntries {
    final query = latinSearchKey(search);

    final list = entries.where((entry) {
      if (stepFilter != null && entry.step != stepFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return latinSearchKey(entry.lemma).contains(query) ||
          (entry.form != null && latinSearchKey(entry.form!).contains(query)) ||
          entry.translations.any((t) => t.toLowerCase().contains(query));
    }).toList();

    list.sort(_compareEntries);

    return list;
  }

  int _compareLemma(LatinVocabularyEntry a, LatinVocabularyEntry b) {
    final byLemma = latinSearchKey(a.lemma).compareTo(latinSearchKey(b.lemma));

    return byLemma != 0 ? byLemma : a.id.compareTo(b.id);
  }

  int _compareEntries(LatinVocabularyEntry a, LatinVocabularyEntry b) {
    switch (sort) {
      case LatinVocabularySort.alphabet:
        return _compareLemma(a, b);

      case LatinVocabularySort.step:
        // Innerhalb eines Unter-Schritts die Reihenfolge der Liste (ID).
        final byStep = a.step.compareTo(b.step);
        if (byStep != 0) return byStep;

        final bySubstep = a.substep.compareTo(b.substep);
        if (bySubstep != 0) return bySubstep;

        return a.id.compareTo(b.id);

      case LatinVocabularySort.type:
        final byType = (latinTypeOrder[a.type] ?? 999).compareTo(
          latinTypeOrder[b.type] ?? 999,
        );

        return byType != 0 ? byType : _compareLemma(a, b);
    }
  }

  String _groupOf(LatinVocabularyEntry entry) {
    switch (sort) {
      case LatinVocabularySort.alphabet:
        final key = latinSearchKey(entry.lemma);
        return key.isEmpty ? "#" : key.substring(0, 1).toUpperCase();

      case LatinVocabularySort.step:
        return "Schritt ${entry.step}.${entry.substep}";

      case LatinVocabularySort.type:
        return latinTypeName(entry.type);
    }
  }

  Map<String, List<LatinVocabularyEntry>> get groupedEntries {
    final groups = <String, List<LatinVocabularyEntry>>{};

    for (final entry in filteredEntries) {
      groups.putIfAbsent(_groupOf(entry), () => []).add(entry);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;

    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(loadError!, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = _buildList(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein Vokabelübersicht"),
        actions: const [
          InfoButton(module: AppModules.latinVocabulary),
          SettingsButton(),
        ],
      ),
      body: body,
    );
  }

  Widget _buildList(BuildContext context) {
    final filtered = filteredEntries;
    final groups = groupedEntries;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const ValueKey("latin-vocabulary-search"),
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: "Lateinisch oder deutsch suchen …",
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                search = value;
              });
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<LatinVocabularySort>(
                  initialValue: sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Sortieren nach",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: LatinVocabularySort.step,
                      child: Text("Schritte"),
                    ),
                    DropdownMenuItem(
                      value: LatinVocabularySort.alphabet,
                      child: Text("Alphabet"),
                    ),
                    DropdownMenuItem(
                      value: LatinVocabularySort.type,
                      child: Text("Wortart"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      sort = value!;
                    });
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: stepFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Schritt",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Alle"),
                    ),
                    for (final step in steps)
                      DropdownMenuItem<int?>(
                        value: step,
                        child: Text("Schritt $step"),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      stepFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              filtered.length == entries.length
                  ? "${entries.length} Vokabeln"
                  : "${filtered.length} von ${entries.length} Vokabeln",
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("Keine passenden Vokabeln."))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final group in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          group.key,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final entry in group.value) _buildCard(entry),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Zusatzangaben wie im Trainer: die im jeweiligen Schritt verlangte Form
  /// und das Genus.
  String _details(LatinVocabularyEntry entry) {
    return [
      if (entry.form != null) entry.form!,
      if (entry.gender != null) "${entry.gender}.",
      if (entry.note != null) entry.note!,
    ].join(" • ");
  }

  Widget _buildCard(LatinVocabularyEntry entry) {
    final details = _details(entry);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                entry.lemma,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                details,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                entry.translations.join(", "),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                latinTypeName(entry.type),
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
