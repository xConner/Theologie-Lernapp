import 'package:flutter/material.dart';

import '../../models/greek/greek_vocabulary_entry.dart';
import '../../services/greek/greek_vocabulary_loader.dart';

import '../../widgets/greek_keyboard.dart';

enum VocabularySort { alphabet, step, type }

const Map<String, int> typeOrder = {
  "noun": 0,
  "verb": 1,
  "adjective": 2,
  "pronoun": 3,
  "participle": 4,
  "preposition": 5,
  "conjunction": 6,
  "particle": 7,
  "adverb": 8,
  "question_word": 9,
  "phrase": 10,
};

const Map<String, int> greekAlphabetOrder = {
  "α": 1,
  "β": 2,
  "γ": 3,
  "δ": 4,
  "ε": 5,
  "ζ": 6,
  "η": 7,
  "θ": 8,
  "ι": 9,
  "κ": 10,
  "λ": 11,
  "μ": 12,
  "ν": 13,
  "ξ": 14,
  "ο": 15,
  "π": 16,
  "ρ": 17,
  "σ": 18,
  "τ": 19,
  "υ": 20,
  "φ": 21,
  "χ": 22,
  "ψ": 23,
  "ω": 24,
};

class VocabularyOverviewScreen extends StatefulWidget {
  const VocabularyOverviewScreen({super.key});

  @override
  State<VocabularyOverviewScreen> createState() =>
      _VocabularyOverviewScreenState();
}

class _VocabularyOverviewScreenState extends State<VocabularyOverviewScreen> {
  List<GreekVocabularyEntry> entries = [];

  bool loading = true;

  VocabularySort sort = VocabularySort.alphabet;

  String search = "";

  final TextEditingController searchController = TextEditingController();

  bool showGreekKeyboard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    entries = await GreekVocabularyLoader.load();

    setState(() {
      loading = false;
    });
  }

  List<GreekVocabularyEntry> get filteredEntries {
    final list = entries.where((entry) {
      if (search.isEmpty) {
        return true;
      }

      final s = normalizeGreek(search);

      return normalizeGreek(entry.lemma).contains(s) ||
          entry.translations.any((t) => t.toLowerCase().contains(s));
    }).toList();

    list.sort(_compareEntries);

    return list;
  }

  int _compareEntries(GreekVocabularyEntry a, GreekVocabularyEntry b) {
    switch (sort) {
      case VocabularySort.alphabet:
        return _compareGreek(a.lemma, b.lemma);

      case VocabularySort.step:
        final stepCompare = a.step.compareTo(b.step);

        if (stepCompare != 0) {
          return stepCompare;
        }

        return _compareGreek(a.lemma, b.lemma);

      case VocabularySort.type:
        final typeCompare = (typeOrder[a.type] ?? 999).compareTo(
          typeOrder[b.type] ?? 999,
        );

        if (typeCompare != 0) {
          return typeCompare;
        }

        return _compareGreek(a.lemma, b.lemma);
    }
  }

  int _compareGreek(String a, String b) {
    final aClean = normalizeGreek(a);
    final bClean = normalizeGreek(b);

    final length = aClean.length < bClean.length
        ? aClean.length
        : bClean.length;

    for (int i = 0; i < length; i++) {
      final aChar = aClean[i];
      final bChar = bClean[i];

      final aValue = greekAlphabetOrder[aChar] ?? 999;
      final bValue = greekAlphabetOrder[bChar] ?? 999;

      if (aValue != bValue) {
        return aValue.compareTo(bValue);
      }
    }

    return aClean.length.compareTo(bClean.length);
  }

  Map<String, List<GreekVocabularyEntry>> get groupedEntries {
    final Map<String, List<GreekVocabularyEntry>> groups = {};

    for (final entry in filteredEntries) {
      String key;

      switch (sort) {
        case VocabularySort.alphabet:
          final normalized = normalizeGreek(entry.lemma);

          key = normalized.substring(0, 1).toUpperCase();

          break;

        case VocabularySort.step:
          key = "Schritt ${entry.step}";

          break;

        case VocabularySort.type:
          key = _typeName(entry.type);

          break;
      }

      groups.putIfAbsent(key, () => []);

      groups[key]!.add(entry);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = groupedEntries;

    return Scaffold(
      appBar: AppBar(title: const Text("Vokabelübersicht")),

      body: Column(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),

                child: TextField(
                  controller: searchController,

                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),

                    suffixIcon: IconButton(
                      icon: const Icon(Icons.keyboard),

                      onPressed: () {
                        setState(() {
                          showGreekKeyboard = !showGreekKeyboard;
                        });
                      },
                    ),

                    hintText: "Vokabel suchen...",
                    border: const OutlineInputBorder(),
                  ),

                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                ),
              ),

              if (showGreekKeyboard)
                GreekKeyboard(
                  controller: searchController,
                  onChanged: () {
                    setState(() {
                      search = searchController.text;
                    });
                  },
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: DropdownButtonFormField<VocabularySort>(
              value: sort,

              decoration: const InputDecoration(
                labelText: "Sortieren nach",
                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: VocabularySort.alphabet,
                  child: Text("Alphabet"),
                ),

                DropdownMenuItem(
                  value: VocabularySort.step,
                  child: Text("Schritte"),
                ),

                DropdownMenuItem(
                  value: VocabularySort.type,
                  child: Text("Typ"),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  sort = value!;
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: groups.entries.map((group) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
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

                    ...group.value.map((entry) => _buildCard(entry)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(GreekVocabularyEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            // Grundform
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

            // Zusatzinfos (Artikel/Genitiv/Aorist)
            Expanded(
              flex: 4,
              child: Text(
                [
                  if (entry.genitive != null) entry.genitive!,
                  if (entry.article != null) entry.article!,
                  if (entry.aorist != null) "Aorist: ${entry.aorist}",
                  if (entry.note != null) entry.note!,
                ].join(" • "),
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            // Übersetzung
            Expanded(
              flex: 4,
              child: Text(
                entry.translations.join(", "),
                style: const TextStyle(fontSize: 15),
              ),
            ),

            // Typ
            SizedBox(
              width: 90,
              child: Text(
                _typeName(entry.type),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeName(String type) {
    switch (type) {
      case "noun":
        return "Nomen";

      case "verb":
        return "Verb";

      case "adjective":
        return "Adjektiv";

      case "pronoun":
        return "Pronomen";

      case "participle":
        return "Partizip";

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
        return "Redewendung";

      default:
        return type;
    }
  }

  String normalizeGreek(String text) {
    return text
        .toLowerCase()
        // Final-Sigma vereinheitlichen
        .replaceAll('ς', 'σ')
        // vorkomponierte polytonische Zeichen zerlegen
        .split('')
        .map((char) {
          const greekBase = {
            'ἀ': 'α',
            'ἁ': 'α',
            'ἂ': 'α',
            'ἃ': 'α',
            'ἄ': 'α',
            'ἅ': 'α',
            'ἆ': 'α',
            'ἇ': 'α',

            'ἐ': 'ε',
            'ἑ': 'ε',
            'ἒ': 'ε',
            'ἓ': 'ε',
            'ἔ': 'ε',
            'ἕ': 'ε',

            'ἠ': 'η',
            'ἡ': 'η',
            'ἤ': 'η',
            'ἥ': 'η',

            'ἰ': 'ι',
            'ἱ': 'ι',
            'ἴ': 'ι',
            'ἵ': 'ι',

            'ὀ': 'ο',
            'ὁ': 'ο',
            'ὂ': 'ο',
            'ὃ': 'ο',
            'ὄ': 'ο',
            'ὅ': 'ο',

            'ὐ': 'υ',
            'ὑ': 'υ',
            'ὒ': 'υ',
            'ὓ': 'υ',
            'ὔ': 'υ',
            'ὕ': 'υ',

            'ὠ': 'ω',
            'ὡ': 'ω',
            'ὢ': 'ω',
            'ὣ': 'ω',
            'ὤ': 'ω',
            'ὥ': 'ω',
            'ὦ': 'ω',
            'ὧ': 'ω',

            'ῤ': 'ρ',
            'ῥ': 'ρ',
          };

          return greekBase[char] ?? char;
        })
        // kombinierte Akzente/Hauche entfernen
        .join()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }
}
