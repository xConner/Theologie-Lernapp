import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/vocabulary/learning_card.dart';
import '../models/memorization/memorization_card.dart';
import 'local_learning_store.dart';

/// Lernstände der Trainer, je Trainer eine Collection unter `users/{uid}`
/// (Namen siehe [LocalLearningStore.cardCollections]).
///
/// uid == null bedeutet Gastmodus: dann wird lokal statt in Firestore
/// gelesen/geschrieben.
class LearningService {
  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  FirebaseFirestore get db => FirebaseFirestore.instance;

  final LocalLearningStore local = LocalLearningStore.instance;

  // Griechisch – Vokabeln

  Future<Map<String, LearningCard>> loadCards(String? uid) {
    return _loadCards(uid, LocalLearningStore.greekVocabulary);
  }

  Future<void> saveCard(String? uid, LearningCard card) {
    return _saveCard(uid, LocalLearningStore.greekVocabulary, card);
  }

  // Perikopen

  Future<Map<String, LearningCard>> loadPerikopeCards(String? uid) {
    return _loadCards(uid, LocalLearningStore.perikopen);
  }

  Future<void> savePerikopeCard(String? uid, LearningCard card) {
    return _saveCard(uid, LocalLearningStore.perikopen, card);
  }

  // Latein – Vokabeln

  Future<Map<String, LearningCard>> loadLatinCards(String? uid) {
    return _loadCards(uid, LocalLearningStore.latinVocabulary);
  }

  Future<void> saveLatinCard(String? uid, LearningCard card) {
    return _saveCard(uid, LocalLearningStore.latinVocabulary, card);
  }

  // Griechisch – Grammatik

  Future<Map<String, LearningCard>> loadGrammarCards(String? uid) {
    // Ältere Grammatik-Lernstände haben ein anderes Format.
    return _loadCards(
      uid,
      LocalLearningStore.greekGrammar,
      accept: (data) => data["lastReviewed"] is Timestamp,
    );
  }

  /// Speichert die Karten einer Frage gemeinsam (ein Schreibvorgang).
  Future<void> saveGrammarCards(String? uid, List<LearningCard> cards) async {
    if (cards.isEmpty) {
      return;
    }

    return _saveCards(uid, LocalLearningStore.greekGrammar, cards);
  }

  // Texte auswendig lernen (Abschnitte von Gebeten, Bekenntnissen …)

  Future<Map<String, MemorizationCard>> loadMemorizationCards(
    String? uid,
  ) async {
    if (uid == null) {
      final cards = await local.loadCards(LocalLearningStore.memorization);

      return {
        for (final card in cards.values)
          if (card is MemorizationCard) card.id: card,
      };
    }

    final snapshot = await _collection(
      uid,
      LocalLearningStore.memorization,
    ).get();

    return {
      for (final doc in snapshot.docs)
        doc.id: MemorizationCard.fromFirestore(doc.id, doc.data()),
    };
  }

  /// Speichert die Karten einer Übung gemeinsam (ein Schreibvorgang).
  Future<void> saveMemorizationCards(
    String? uid,
    List<MemorizationCard> cards,
  ) async {
    if (cards.isEmpty) {
      return;
    }

    return _saveCards(uid, LocalLearningStore.memorization, cards);
  }

  Future<void> _saveCards(
    String? uid,
    String name,
    List<LearningCard> cards,
  ) async {
    if (uid == null) {
      return local.saveCards(name, cards);
    }

    final collection = _collection(uid, name);

    final batch = db.batch();

    for (final card in cards) {
      batch.set(
        collection.doc(card.id),
        card.toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String collection,
  ) {
    return db.collection("users").doc(uid).collection(collection);
  }

  /// [accept] filtert nur Firestore-Dokumente; lokale Karten sind immer im
  /// aktuellen Format.
  Future<Map<String, LearningCard>> _loadCards(
    String? uid,
    String collection, {
    bool Function(Map<String, dynamic> data)? accept,
  }) async {
    if (uid == null) {
      return local.loadCards(collection);
    }

    final snapshot = await _collection(uid, collection).get();

    return {
      for (final doc in snapshot.docs)
        if (accept == null || accept(doc.data()))
          doc.id: LearningCard.fromFirestore(doc.id, doc.data()),
    };
  }

  Future<void> _saveCard(String? uid, String collection, LearningCard card) {
    if (uid == null) {
      return local.saveCard(collection, card);
    }

    return _collection(
      uid,
      collection,
    ).doc(card.id).set(card.toFirestore(), SetOptions(merge: true));
  }
}
