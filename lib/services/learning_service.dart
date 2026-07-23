import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/learning_card.dart';

class LearningService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return db.collection("users").doc(uid).collection("vocabulary");
  }

  Future<LearningCard> loadCard(String uid, String id) async {
    final doc = await _collection(uid).doc(id).get();

    if (!doc.exists) {
      return LearningCard(id: id);
    }

    return LearningCard.fromFirestore(id, doc.data()!);
  }

  Future<Map<String, LearningCard>> loadCards(String uid) async {
    final snapshot = await _collection(uid).get();

    final Map<String, LearningCard> cards = {};

    for (final doc in snapshot.docs) {
      cards[doc.id] = LearningCard.fromFirestore(doc.id, doc.data());
    }

    return cards;
  }

  Future<void> saveCard(String uid, LearningCard card) async {
    await _collection(
      uid,
    ).doc(card.id).set(card.toFirestore(), SetOptions(merge: true));
  }
}
