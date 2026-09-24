import 'package:flutter/material.dart';
import '../../widgets/settings_access.dart';

class LatinVocabularyOverviewScreen extends StatelessWidget {
  const LatinVocabularyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Latein Vokabelübersicht"),
        actions: const [SettingsButton()],
      ),
      body: const Center(child: Text("In Entwicklung")),
    );
  }
}
