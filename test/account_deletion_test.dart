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

  // Subcollections mit eigener Regel (z. B. timetable mit Feldprüfung);
  // inbox löscht die Kontolöschung gesondert.
  final usersBlock = rules.substring(rules.indexOf('match /users/{uid}'));
  final dedicatedCollections = RegExp(r"match /([a-z_]+)/\{[A-Za-z]+\}")
      .allMatches(usersBlock)
      .map((m) => m.group(1)!)
      .toSet()
    ..removeAll(['users', 'inbox']);

  test('Kontolöschung kennt genau die Subcollections der Firestore-Regeln', () {
    expect(
      AccountDeletionService.userCollections.toSet(),
      {...allowedCollections, ...dedicatedCollections},
    );
    expect(dedicatedCollections, contains('timetable'));
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
