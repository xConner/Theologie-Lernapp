import 'package:flutter/material.dart';

class QuizSettingsSheet extends StatefulWidget {
  final Set<String> selected;
  final void Function(Set<String>) onChanged;

  const QuizSettingsSheet({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<QuizSettingsSheet> createState() => _QuizSettingsSheetState();
}

class _QuizSettingsSheetState extends State<QuizSettingsSheet> {
  late Set<String> selected;

  final at = {
    "Gen",
    "Ex",
    "Lev",
    "Num",
    "Dtn",
    "Jos",
    "Ri",
    "Rut",
    "1Sam",
    "2Sam",
    "1Kön",
    "2Kön",
    "1Chr",
    "2Chr",
    "Esr",
    "Neh",
    "Est",
    "Ijob",
    "Ps",
    "Spr",
    "Koh",
    "Hld",
    "Jes",
    "Jer",
    "Klgl",
    "Ez",
    "Dan",
    "Hos",
    "Joel",
    "Am",
    "Obd",
    "Jona",
    "Mi",
    "Nah",
    "Hab",
    "Zef",
    "Hag",
    "Sach",
    "Mal",
  };

  final nt = {
    "Mt",
    "Mk",
    "Lk",
    "Joh",
    "Apg",
    "Röm",
    "1Kor",
    "2Kor",
    "Gal",
    "Eph",
    "Phil",
    "Kol",
    "1Thess",
    "2Thess",
    "1Tim",
    "2Tim",
    "Tit",
    "Phlm",
    "Hebr",
    "Jak",
    "1Petr",
    "2Petr",
    "1Joh",
    "2Joh",
    "3Joh",
    "Jud",
    "Offb",
  };

  @override
  void initState() {
    super.initState();
    selected = {...widget.selected};
  }

  bool get isInvalid => selected.isEmpty;

  bool get allSelected => selected.containsAll({...at, ...nt});

  void toggleAll() {
    setState(() {
      selected = allSelected ? <String>{} : {...at, ...nt};
    });
    widget.onChanged(selected);
  }

  void toggleGroup(Set<String> group) {
    setState(() {
      final all = group.every(selected.contains);

      if (all) {
        selected.removeAll(group);
      } else {
        selected.addAll(group);
      }
    });

    widget.onChanged(selected);
  }

  void toggleBook(String b) {
    setState(() {
      if (selected.contains(b)) {
        selected.remove(b);
      } else {
        selected.add(b);
      }
    });

    widget.onChanged(selected);
  }

  Widget _listColumn(List<String> books) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        children: books.map((b) {
          return SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(child: Text(b, style: const TextStyle(fontSize: 12))),
                Transform.scale(
                  scale: 0.85,
                  child: Checkbox(
                    value: selected.contains(b),
                    onChanged: (_) => toggleBook(b),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _group(String title, Set<String> books) {
    final all = books.every(selected.contains);
    final list = books.toList();
    final mid = (list.length / 2).ceil();

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Checkbox(value: all, onChanged: (_) => toggleGroup(books)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                _listColumn(list.sublist(0, mid)),
                const SizedBox(width: 8),
                _listColumn(list.sublist(mid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isInvalid ? Colors.red : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 750,
          height: 600,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Quiz Einstellungen",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: isInvalid
                          ? null
                          : () => Navigator.pop(context, selected),
                    ),
                  ],
                ),

                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Alle auswählen"),
                  value: allSelected,
                  onChanged: (_) => toggleAll(),
                ),

                if (isInvalid)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Mindestens 1 Buch muss ausgewählt sein",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const Divider(),

                Expanded(
                  child: Row(
                    children: [
                      _group("Altes Testament", at),
                      const SizedBox(width: 12),
                      _group("Neues Testament", nt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
