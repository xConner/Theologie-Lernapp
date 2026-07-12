import 'package:flutter/material.dart';

class GreekKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const GreekKeyboard({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<GreekKeyboard> createState() => _GreekKeyboardState();
}

class _GreekKeyboardState extends State<GreekKeyboard> {
  bool uppercase = false;

  bool roughBreathing = false;
  bool smoothBreathing = false;

  String? accent;

  bool iotaSubscript = false;

  final List<String> lowerLetters = [
    "α",
    "β",
    "γ",
    "δ",
    "ε",
    "ζ",
    "η",
    "θ",
    "ι",
    "κ",
    "λ",
    "μ",
    "ν",
    "ξ",
    "ο",
    "π",
    "ρ",
    "σ",
    "τ",
    "υ",
    "φ",
    "χ",
    "ψ",
    "ω",
  ];

  final List<String> upperLetters = [
    "Α",
    "Β",
    "Γ",
    "Δ",
    "Ε",
    "Ζ",
    "Η",
    "Θ",
    "Ι",
    "Κ",
    "Λ",
    "Μ",
    "Ν",
    "Ξ",
    "Ο",
    "Π",
    "Ρ",
    "Σ",
    "Τ",
    "Υ",
    "Φ",
    "Χ",
    "Ψ",
    "Ω",
  ];

  void insertCharacter(String character) {
    final text = widget.controller.text;

    final selection = widget.controller.selection;

    final start = selection.start < 0 ? text.length : selection.start;

    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, character);

    widget.controller.value = TextEditingValue(
      text: newText,

      selection: TextSelection.collapsed(offset: start + character.length),
    );

    widget.onChanged();
  }

  void insertLetter(String letter) {
    insertCharacter(letter);

    setState(() {
      roughBreathing = false;
      smoothBreathing = false;
      accent = null;
      iotaSubscript = false;
    });
  }

  void modifyLastCharacter() {
    final text = widget.controller.text;

    if (text.isEmpty) {
      return;
    }

    final chars = text.characters.toList();

    final last = chars.removeLast();

    final result = composeGreek(last);

    chars.add(result);

    widget.controller.value = TextEditingValue(
      text: chars.join(),

      selection: TextSelection.collapsed(offset: chars.join().length),
    );

    widget.onChanged();
  }

  String composeGreek(String letter) {
    String result = letter;

    if (smoothBreathing) {
      result += "\u0313";
    }

    if (roughBreathing) {
      result += "\u0314";
    }

    if (accent != null) {
      result += accent!;
    }

    if (iotaSubscript) {
      result += "\u0345";
    }

    return result;
  }

  void deleteCharacter() {
    final text = widget.controller.text;

    if (text.isEmpty) {
      return;
    }

    widget.controller.value = TextEditingValue(
      text: text.characters
          .toList()
          .sublist(0, text.characters.length - 1)
          .join(),

      selection: TextSelection.collapsed(offset: text.characters.length - 1),
    );

    widget.onChanged();
  }

  Widget keyButton(String text, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),

        child: ElevatedButton(
          onPressed: onPressed,

          child: Text(text, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget buildRow(List<Widget> children) {
    return Row(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final letters = uppercase ? upperLetters : lowerLetters;

    return Container(
      padding: const EdgeInsets.all(8),

      color: Theme.of(context).colorScheme.surfaceContainerHighest,

      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: letters.map((letter) {
                  return SizedBox(
                    width: (constraints.maxWidth - 7 * 4) / 8,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),

                      onPressed: () {
                        insertLetter(letter);
                      },

                      child: Text(letter, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 8),

          buildRow([
            keyButton("⇧", () {
              setState(() {
                uppercase = !uppercase;
              });
            }),

            keyButton("᾿", () {
              setState(() {
                smoothBreathing = true;
                roughBreathing = false;
              });

              modifyLastCharacter();
            }),

            keyButton("῾", () {
              setState(() {
                roughBreathing = true;
                smoothBreathing = false;
              });

              modifyLastCharacter();
            }),
          ]),

          buildRow([
            keyButton("´", () {
              setState(() {
                accent = "\u0301";
              });

              modifyLastCharacter();
            }),

            keyButton("`", () {
              setState(() {
                accent = "\u0300";
              });

              modifyLastCharacter();
            }),

            keyButton("῀", () {
              setState(() {
                accent = "\u0342";
              });

              modifyLastCharacter();
            }),

            keyButton("ͅ", () {
              setState(() {
                iotaSubscript = !iotaSubscript;
              });

              modifyLastCharacter();
            }),
          ]),

          buildRow([
            keyButton("Leer", () {
              insertCharacter(" ");
            }),

            keyButton("⌫", deleteCharacter),
          ]),
        ],
      ),
    );
  }
}
