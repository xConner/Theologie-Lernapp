import 'package:flutter/material.dart';

/// Fragt nach, ob sich der Nutzer wirklich abmelden will, damit ein
/// versehentlicher Klick nicht sofort zur Abmeldung führt.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Abmelden"),
      content: const Text("Möchtest du dich wirklich abmelden?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text("Abmelden"),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
