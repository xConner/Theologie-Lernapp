import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<void> saveBooks(String uid, Set<String> books) async {
    await db
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc("perikopen")
        .set({"selectedBooks": books.toList()});
  }

  Future<Set<String>> loadBooks(String uid) async {
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
