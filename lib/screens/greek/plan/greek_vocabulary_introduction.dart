import 'package:flutter/material.dart';

import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../theme/app_theme.dart';

/// Vorstellung einer neuen Vokabel: Lemma, Übersetzung mit Formen,
/// Eselsbrücke und „Weiter“ – ohne Abfrage und ohne Bewertung. Dieselbe
/// Ansicht in der Lerneinheit des Lernplans und im freien Vokabeltrainer.
class GreekVocabularyIntroduction extends StatelessWidget {
  final GreekVocabularyEntry entry;

  final String? mnemonic;

  final VoidCallback onNext;

  const GreekVocabularyIntroduction({
    super.key,
    required this.entry,
    required this.mnemonic,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GreekVocabularyLemma(entry: entry),
        const SizedBox(height: 16),
        GreekVocabularySolution(entry: entry),
        GreekVocabularyMnemonicText(text: mnemonic),
        const SizedBox(height: 24),
        Text(
          "Gleich wird die Vokabel abgefragt.",
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey("greek-plan-intro-next"),
            onPressed: onNext,
            child: const Text("Weiter"),
          ),
        ),
      ],
    );
  }
}

class GreekVocabularyLemma extends StatelessWidget {
  final GreekVocabularyEntry entry;

  const GreekVocabularyLemma({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      entry.lemma,
      key: const ValueKey("greek-plan-lemma"),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    );
  }
}

/// Übersetzung und Formen, wie die Lösung im Vokabeltrainer.
class GreekVocabularySolution extends StatelessWidget {
  final GreekVocabularyEntry entry;

  const GreekVocabularySolution({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SelectableText(
          entry.translations.join(", "),
          key: const ValueKey("greek-plan-translation"),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (entry.article != null ||
            entry.genitive != null ||
            entry.aorist != null)
          const SizedBox(height: 8),
        if (entry.article != null) Text("Artikel: ${entry.article}"),
        if (entry.genitive != null) Text("Genitiv: ${entry.genitive}"),
        if (entry.aorist != null) Text("Aorist: ${entry.aorist}"),
        if (entry.note != null) ...[
          const SizedBox(height: 8),
          Text(
            entry.note!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class GreekVocabularyMnemonicText extends StatelessWidget {
  final String? text;

  const GreekVocabularyMnemonicText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final mnemonic = text;
    if (mnemonic == null || mnemonic.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        "Eselsbrücke: $mnemonic",
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }
}
