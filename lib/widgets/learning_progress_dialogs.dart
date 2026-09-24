import 'package:flutter/material.dart';

/// Fragt nach der Anmeldung, ob die als Gast gesammelten Lernstände ins Konto
/// übernommen werden sollen. true = übernehmen, false = ohne Fortschritte.
Future<bool> askGuestDataTransfer(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Deine bisherigen Lernfortschritte übernehmen?"),
      content: const Text(
        "Du hast bereits als Gast gelernt. Möchtest du deine Lernstände und "
        "gespeicherten Lerneinstellungen in dein Konto übernehmen?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Ohne Fortschritte starten"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text("Übernehmen"),
        ),
      ],
    ),
  );

  return accepted ?? false;
}

/// Bestätigung vor dem Zurücksetzen aller Lernfortschritte.
Future<bool> confirmProgressReset(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Lernfortschritte zurücksetzen?"),
      content: const Text(
        "Deine bisherigen Lernstände und Wiederholungsdaten, einschließlich "
        "Schwierigkeits-/Stabilitätswerten und Lernzeitpunkten, werden "
        "zurückgesetzt. Dieser Vorgang kann nicht rückgängig gemacht werden.\n\n"
        "Deine Einstellungen und eigenen Eselsbrücken bleiben erhalten.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text("Zurücksetzen"),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
