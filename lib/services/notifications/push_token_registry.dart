import 'package:cloud_firestore/cloud_firestore.dart';

import 'push_platform.dart';

/// Verwaltung der Push-Abonnements eines Kontos unter
/// `users/{uid}/push_tokens/{id}` (siehe docs/notifications.md).
///
/// Ein Konto kann mehrere Geräte/Browser haben (ein Dokument je
/// Abonnement). Der Server entfernt Abonnements, die der Push-Dienst als
/// abgelaufen meldet; der Client meldet sein eigenes an und entfernt es beim
/// Ausschalten von Push, beim Abmelden und wenn die Berechtigung fehlt.
class PushTokenRegistry {
  PushTokenRegistry({this._db});

  final FirebaseFirestore? _db;

  CollectionReference<Map<String, dynamic>> _tokens(String uid) {
    return (_db ?? FirebaseFirestore.instance)
        .collection("users")
        .doc(uid)
        .collection("push_tokens");
  }

  /// Registriert bzw. aktualisiert [subscription] (idempotent).
  Future<void> register(
    String uid,
    PushSubscriptionInfo subscription, {
    required String platform,
  }) {
    return _tokens(uid).doc(subscription.id).set({
      "endpoint": subscription.endpoint,
      "keys": {"p256dh": subscription.p256dh, "auth": subscription.auth},
      "platform": platform,
      "lastSeenAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregister(String uid, String id) {
    return _tokens(uid).doc(id).delete();
  }

  /// Hat das Konto (noch) mindestens ein Gerät mit Push?
  Future<bool> hasDevices(String uid) async {
    final snapshot = await _tokens(uid).limit(1).get();

    return snapshot.docs.isNotEmpty;
  }
}
