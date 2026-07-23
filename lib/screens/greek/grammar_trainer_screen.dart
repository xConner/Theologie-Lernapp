import 'package:flutter/material.dart';

class GreekGrammarTrainerScreen extends StatelessWidget {
  const GreekGrammarTrainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Grammatiktrainer")),

      body: const Center(
        child: Text("In Bearbeitung", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
