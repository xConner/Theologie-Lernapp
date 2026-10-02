import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/services/account_deletion_service.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';

void main() {
  final rules = File('firestore.rules').readAsStringSync();

  final ruleCollections = RegExp(
    r"collection in \[([^\]]*)\]",
  ).firstMatch(rules)!.group(1)!;

  final allowedCollections = RegExp(
    r"'([a-z_]+)'",
  ).allMatches(ruleCollections).map((m) => m.group(1)!).toSet();

  test('Kontolöschung kennt genau die Subcollections der Firestore-Regeln', () {
    expect(
      AccountDeletionService.userCollections.toSet(),
      allowedCollections,
    );
  });

  test('Gastdaten-Übernahme schreibt nur erlaubte Collections', () {
    for (final collection in LocalLearningStore.cardCollections) {
      expect(allowedCollections, contains(collection));
    }
  });

  test('Einstellungsgruppen sind als Felder in users/{uid} erlaubt', () {
    for (final group in LocalLearningStore.settingsGroups) {
      expect(rules, contains("'$group'"));
    }
    expect(rules, contains("'notification_settings'"));
  });
}
