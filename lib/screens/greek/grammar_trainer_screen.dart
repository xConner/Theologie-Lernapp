import 'package:flutter/material.dart';

class GreekGrammarTrainerScreen extends StatefulWidget {
  const GreekGrammarTrainerScreen({super.key});

  @override
  State<GreekGrammarTrainerScreen> createState() =>
      _GreekGrammarTrainerScreenState();
}

class _GreekGrammarTrainerScreenState extends State<GreekGrammarTrainerScreen> {
  final TextEditingController lemmaController = TextEditingController();

  String? selectedCase;
  String? selectedNumber;
  String? selectedGender;

  @override
  void dispose() {
    lemmaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grammatiktrainer"),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Settings
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                const SizedBox(height: 40),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),

                    child: Column(
                      children: const [
                        Text(
                          "λόγοις",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCase,
                        decoration: const InputDecoration(labelText: "Kasus"),
                        items: const [
                          DropdownMenuItem(value: "Nom", child: Text("Nom.")),
                          DropdownMenuItem(value: "Gen", child: Text("Gen.")),
                          DropdownMenuItem(value: "Dat", child: Text("Dat.")),
                          DropdownMenuItem(value: "Akk", child: Text("Akk.")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCase = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedNumber,
                        decoration: const InputDecoration(labelText: "Numerus"),
                        items: const [
                          DropdownMenuItem(
                            value: "Sg",
                            child: Text("Singular"),
                          ),
                          DropdownMenuItem(value: "Pl", child: Text("Plural")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedNumber = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(labelText: "Genus"),
                        items: const [
                          DropdownMenuItem(value: "m", child: Text("Mask.")),
                          DropdownMenuItem(value: "f", child: Text("Fem.")),
                          DropdownMenuItem(value: "n", child: Text("Neutr.")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: lemmaController,
                  decoration: InputDecoration(
                    labelText: "Grundform (Lemma)",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        // TODO Griechische Tastatur
                      },
                      icon: const Icon(Icons.keyboard),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Prüfen", style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 32),

                Card(
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Feedback erscheint hier.",
                      style: TextStyle(fontSize: 18),
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
}
