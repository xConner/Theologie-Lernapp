import 'package:flutter/material.dart';

class VocabularyTrainerScreen extends StatelessWidget {
  const VocabularyTrainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vokabeltrainer")),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Vokabeltrainer",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text("In Entwicklung", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
