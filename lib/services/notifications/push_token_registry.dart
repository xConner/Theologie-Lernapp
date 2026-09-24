import 'package:cloud_firestore/cloud_firestore.dart';

/// Verwaltung der FCM-Tokens eines Kontos unter
/// `users/{uid}/push_tokens/{token}` – vorbereitet für Firebase Cloud
/// Messaging (siehe docs/notifications.md, "Push aktivieren").
///
/// Ein Konto kann mehrere Geräte/Browser haben (ein Dokument je Token).
/// Der Server entfernt Tokens, die FCM als ungültig meldet; der Client
/// meldet neue Tokens (onTokenRefresh) und entfernt das eigene beim
/// Abmelden bzw. beim Ausschalten von Push.
class PushTokenRegistry {
  PushTokenRegistry({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tokens(String uid) {
    return _db.collection("users").doc(uid).collection("push_tokens");
  }

  /// Registriert bzw. aktualisiert [token] (idempotent).
  Future<void> register(String uid, String token, {required String platform}) {
    return _tokens(uid).doc(token).set({
      "token": token,
      "platform": platform,
      "lastSeenAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregister(String uid, String token) {
    return _tokens(uid).doc(token).delete();
  }
}
