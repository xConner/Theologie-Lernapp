import 'package:flutter/material.dart';

import '../../../models/latin/vocabulary/latin_vocabulary_entry.dart';
import '../../../theme/app_theme.dart';

/// Vorstellung einer neuen Vokabel mit allen Angaben – ohne Abfrage und
/// ohne Bewertung. Dieselbe Ansicht in der Lerneinheit des Lernplans und im
/// freien Vokabeltrainer.
class LatinVocabularyIntroduction extends StatelessWidget {
  final LatinVocabularyEntry entry;
  final String? mnemonic;
  final VoidCallback onNext;

  const LatinVocabularyIntroduction({
    super.key,
    required this.entry,
    required this.mnemonic,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          entry.lemma,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        if (entry.form != null) ...[
          const SizedBox(height: 4),
          Text(
            entry.form!,
            style: TextStyle(fontSize: 18, color: colors.textSecondary),
          ),
        ],
        if (entry.gender != null) Text("Genus: ${entry.gender}"),
        const SizedBox(height: 16),
        SelectableText(
          entry.translations.join(", "),
          key: const ValueKey("latin-plan-intro-translation"),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (entry.note != null) ...[
          const SizedBox(height: 12),
          Text(
            entry.note!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        if (mnemonic != null && mnemonic!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Eselsbrücke: $mnemonic",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          "Gleich wird die Vokabel abgefragt.",
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey("latin-plan-intro-next"),
            onPressed: onNext,
            child: const Text("Weiter"),
          ),
        ),
      ],
    );
  }
}
