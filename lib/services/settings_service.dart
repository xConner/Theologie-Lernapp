import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_learning_store.dart';

/// uid == null bedeutet Gastmodus (lokale Speicherung).
class SettingsService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> saveBooks(String? uid, Set<String> books) async {
    if (uid == null) {
      return LocalLearningStore.instance.saveSelectedBooks(books);
    }

    await db
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc("perikopen")
        .set({"selectedBooks": books.toList()});
  }

  Future<Set<String>> loadBooks(String? uid) async {
    if (uid == null) {
      return LocalLearningStore.instance.loadSelectedBooks();
    }

    final doc = await db
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc("perikopen")
        .get();

    if (!doc.exists) return {};

    final data = doc.data();
    final raw = data?["selectedBooks"];

    if (raw is List) {
      return raw.map((e) => e.toString()).toSet();
    }

    return {};
  }
}
