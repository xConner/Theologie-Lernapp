import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Löscht ein Konto vollständig: zuerst alle Firestore-Daten unter
/// `users/{uid}`, danach den Firebase-Auth-Account.
///
/// Die Reihenfolge ist zwingend: Nach dem Löschen des Auth-Accounts erlauben
/// die Firestore-Regeln keinen Zugriff mehr auf `users/{uid}`. Damit
/// [deleteAuthAccount] nicht an „requires-recent-login“ scheitert, muss sich
/// der Nutzer vorher erneut angemeldet haben (siehe AccountSecurityScreen).
///
/// Meldungen unter `reports/` enthalten keinen Kontobezug und sind daher
/// nicht betroffen.
class AccountDeletionService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  AccountDeletionService({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  /// Alle Subcollections unter `users/{uid}`. Muss zu `isUserCollection` in
  /// firestore.rules passen; `inbox` wird gesondert behandelt.
  static const List<String> userCollections = [
    "quiz_settings",
    "vocabulary",
    "learning_cards",
    "latin_vocabulary",
    "grammar",
    "pericope_overrides",
    "streaks",
    "statistics",
    "notification_state",
    "push_tokens",
  ];

  static const int _batchLimit = 400;

  Future<void> deleteUserData(String uid) async {
    final userDoc = db.collection("users").doc(uid);

    for (final collection in userCollections) {
      await _deleteCollection(userDoc.collection(collection));
    }

    // Persönliche Nachrichten schreibt nur der Server. Solange die
    // aktualisierten Regeln (Löschen durch den Nutzer) noch nicht in der
    // Console eingetragen sind, darf das die Kontolöschung nicht blockieren.
    try {
      await _deleteCollection(userDoc.collection("inbox"));
    } on FirebaseException catch (e) {
      if (e.code != "permission-denied") rethrow;
      debugPrint("Persönliche Nachrichten konnten nicht gelöscht werden.");
    }

    await userDoc.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(_batchLimit).get();

      if (snapshot.docs.isEmpty) return;

      final batch = db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < _batchLimit) return;
    }
  }

  Future<void> deleteAuthAccount() async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    await user.delete();
  }
}
