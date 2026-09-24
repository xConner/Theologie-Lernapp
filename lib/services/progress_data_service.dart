import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/vocabulary/learning_card.dart';
import 'local_learning_store.dart';

/// Kontoübergreifende Operationen auf den Lernständen: Übernahme der
/// Gastdaten in ein Konto und Zurücksetzen der Lernfortschritte.
///
/// Die Firestore-Pfade entsprechen exakt denen von [LearningService] und den
/// Settings-Services; es werden keine neuen Strukturen angelegt.
class ProgressDataService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final LocalLearningStore local = LocalLearningStore.instance;

  /// Firestore-Collections mit Lernstands-/SRS-Daten unter `users/{uid}`.
  /// `grammar` wird aktuell von keinem Trainer beschrieben, enthält aber
  /// ggf. ältere Grammatik-Lernstände.
  static const List<String> _progressCollections = [
    "vocabulary",
    "learning_cards",
    "latin_vocabulary",
    "grammar",
  ];

  static const int _batchLimit = 400;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return db.collection("users").doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _perikopenSettingsDoc(String uid) {
    return _userDoc(uid).collection("quiz_settings").doc("perikopen");
  }

  // ==========================
  // GAST → KONTO
  // ==========================

  /// Hat das Konto bereits Lernstände oder Lerneinstellungen? Dann werden
  /// Gastdaten nicht angeboten, damit nichts überschrieben wird.
  Future<bool> accountHasLearningData(String uid) async {
    for (final collection in _progressCollections) {
      final snapshot = await _userDoc(
        uid,
      ).collection(collection).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        return true;
      }
    }

    final userData = (await _userDoc(uid).get()).data();

    if (userData != null &&
        LocalLearningStore.settingsGroups.any(userData.containsKey)) {
      return true;
    }

    return (await _perikopenSettingsDoc(uid).get()).exists;
  }

  /// Überträgt die validierten lokalen Gastdaten in die bestehenden
  /// Firestore-Strukturen des Kontos und entfernt sie danach lokal.
  ///
  /// Bricht ab (StateError), wenn das Konto inzwischen eigene Daten hat.
  Future<void> transferGuestData(String uid) async {
    if (await accountHasLearningData(uid)) {
      throw StateError("account-has-data");
    }

    final writes = <void Function(WriteBatch)>[];

    for (final collection in LocalLearningStore.cardCollections) {
      // loadCards validiert die Werte (ungültige → normale Defaults).
      final cards = await local.loadCards(collection);

      for (final card in cards.values) {
        final ref = _userDoc(uid).collection(collection).doc(card.id);

        writes.add(
          (batch) =>
              batch.set(ref, card.toFirestore(), SetOptions(merge: true)),
        );
      }
    }

    final settings = <String, dynamic>{};

    for (final group in LocalLearningStore.settingsGroups) {
      final values = await local.loadSettingsGroup(group);

      if (values.isNotEmpty) {
        settings[group] = values;
      }
    }

    if (settings.isNotEmpty) {
      final ref = _userDoc(uid);
      writes.add((batch) => batch.set(ref, settings, SetOptions(merge: true)));
    }

    if (await local.hasSelectedBooks()) {
      final books = await local.loadSelectedBooks();
      final ref = _perikopenSettingsDoc(uid);
      writes.add((batch) => batch.set(ref, {"selectedBooks": books.toList()}));
    }

    await _commitInBatches(writes);

    await local.clearGuestData();
  }

  // ==========================
  // RESET
  // ==========================

  /// Setzt alle Lernstände (stability, difficulty, lastReviewed) auf die
  /// Initialwerte zurück. uid == null → lokaler Gast-Lernstand.
  ///
  /// Karten ohne Eselsbrücke werden gelöscht (fehlende Karte = Initialwerte),
  /// Karten mit Eselsbrücke behalten nur diese. Einstellungen, Konto- und
  /// sonstige Daten bleiben unberührt.
  Future<void> resetProgress(String? uid) async {
    if (uid == null) {
      return local.resetProgress();
    }

    final writes = <void Function(WriteBatch)>[];

    for (final collection in _progressCollections) {
      final snapshot = await _userDoc(uid).collection(collection).get();

      for (final doc in snapshot.docs) {
        final mnemonic = doc.data()["mnemonic"];

        if (collection != "grammar" &&
            mnemonic is String &&
            mnemonic.isNotEmpty) {
          final reset = LearningCard(id: doc.id, mnemonic: mnemonic);

          writes.add((batch) => batch.set(doc.reference, reset.toFirestore()));
        } else {
          writes.add((batch) => batch.delete(doc.reference));
        }
      }
    }

    await _commitInBatches(writes);
  }

  Future<void> _commitInBatches(List<void Function(WriteBatch)> writes) async {
    for (var start = 0; start < writes.length; start += _batchLimit) {
      final batch = db.batch();

      for (final write in writes.skip(start).take(_batchLimit)) {
        write(batch);
      }

      await batch.commit();
    }
  }
}
