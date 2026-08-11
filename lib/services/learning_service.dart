import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/vocabulary/learning_card.dart';

class LearningService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ==========================
  // VOKABELN
  // ==========================

  CollectionReference<Map<String, dynamic>> _vocabularyCollection(String uid) {
    return db.collection("users").doc(uid).collection("vocabulary");
  }

  Future<LearningCard> loadCard(String uid, String id) async {
    final doc = await _vocabularyCollection(uid).doc(id).get();

    if (!doc.exists) {
      return LearningCard(id: id);
    }

    return LearningCard.fromFirestore(id, doc.data()!);
  }

  Future<Map<String, LearningCard>> loadCards(String uid) async {
    final snapshot = await _vocabularyCollection(uid).get();

    final Map<String, LearningCard> cards = {};

    for (final doc in snapshot.docs) {
      cards[doc.id] = LearningCard.fromFirestore(doc.id, doc.data());
    }

    return cards;
  }

  Future<void> saveCard(String uid, LearningCard card) async {
    await _vocabularyCollection(
      uid,
    ).doc(card.id).set(card.toFirestore(), SetOptions(merge: true));
  }

  // ==========================
  // PERIKOPEN
  // ==========================

  CollectionReference<Map<String, dynamic>> _perikopenCollection(String uid) {
    return db.collection("users").doc(uid).collection("learning_cards");
  }

  Future<LearningCard> loadPerikopeCard(String uid, String id) async {
    final doc = await _perikopenCollection(uid).doc(id).get();

    if (!doc.exists) {
      return LearningCard(id: id);
    }

    return LearningCard.fromFirestore(id, doc.data()!);
  }

  Future<Map<String, LearningCard>> loadPerikopeCards(String uid) async {
    final snapshot = await _perikopenCollection(uid).get();

    final Map<String, LearningCard> cards = {};

    for (final doc in snapshot.docs) {
      cards[doc.id] = LearningCard.fromFirestore(doc.id, doc.data());
    }

    return cards;
  }

  Future<void> savePerikopeCard(String uid, LearningCard card) async {
    await _perikopenCollection(
      uid,
    ).doc(card.id).set(card.toFirestore(), SetOptions(merge: true));
  }
}
