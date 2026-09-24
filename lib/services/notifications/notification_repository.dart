import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_notification.dart';
import 'notification_read_state.dart';

/// Datenzugriff der Glocke.
///
/// Firestore-Struktur:
///   notifications/{id}                     globale Nachrichten (nur lesbar;
///                                          Veröffentlichung über Console /
///                                          Admin SDK)
///   users/{uid}/inbox/{id}                 persönliche Nachrichten, z. B.
///                                          Account & Sicherheit (nur lesbar)
///   users/{uid}/notification_state/inbox   Lesestatus (vom Nutzer schreibbar)
///
/// Gäste sehen globale Nachrichten; ihr Lesestatus liegt lokal.
abstract class NotificationRepository {
  /// Neueste globale Nachrichten (max. [NotificationRepository.pageSize]).
  Stream<List<AppNotification>> watchGlobal();

  /// Persönliche Nachrichten; leer für Gäste.
  Stream<List<AppNotification>> watchPersonal();

  Stream<NotificationReadState> watchReadState();

  Future<void> saveReadState(NotificationReadState state);

  static const int pageSize = 50;

  factory NotificationRepository.forUser(String? uid) {
    if (uid == null) {
      return GuestNotificationRepository();
    }

    return FirestoreNotificationRepository(uid);
  }
}

List<AppNotification> _parse(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  NotificationScope scope,
) {
  return [
    for (final doc in snapshot.docs)
      ?AppNotification.tryParse(doc.id, doc.data(), scope: scope),
  ];
}

Stream<List<AppNotification>> _watchGlobal(FirebaseFirestore db) {
  return db
      .collection("notifications")
      .orderBy("createdAt", descending: true)
      .limit(NotificationRepository.pageSize)
      .snapshots()
      .map((snapshot) => _parse(snapshot, NotificationScope.global));
}

class FirestoreNotificationRepository implements NotificationRepository {
  final String uid;
  final FirebaseFirestore db;

  FirestoreNotificationRepository(this.uid, {FirebaseFirestore? db})
    : db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    return db.collection("users").doc(uid);
  }

  DocumentReference<Map<String, dynamic>> get _readStateDoc {
    return _userDoc.collection("notification_state").doc("inbox");
  }

  @override
  Stream<List<AppNotification>> watchGlobal() => _watchGlobal(db);

  @override
  Stream<List<AppNotification>> watchPersonal() {
    return _userDoc
        .collection("inbox")
        .orderBy("createdAt", descending: true)
        .limit(NotificationRepository.pageSize)
        .snapshots()
        .map((snapshot) => _parse(snapshot, NotificationScope.personal));
  }

  @override
  Stream<NotificationReadState> watchReadState() {
    return _readStateDoc.snapshots().map(
      (doc) => NotificationReadState.fromMap(doc.data()),
    );
  }

  @override
  Future<void> saveReadState(NotificationReadState state) {
    return _readStateDoc.set({
      ...state.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }
}

/// Gastmodus: globale Nachrichten aus Firestore (öffentlich lesbar),
/// Lesestatus nur lokal in diesem Browser.
class GuestNotificationRepository implements NotificationRepository {
  static const String storageKey = "notifications.v1.guestReadState";

  @override
  Stream<List<AppNotification>> watchGlobal() {
    return _watchGlobal(FirebaseFirestore.instance);
  }

  @override
  Stream<List<AppNotification>> watchPersonal() => Stream.value(const []);

  @override
  Stream<NotificationReadState> watchReadState() async* {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);

      yield raw == null
          ? NotificationReadState.empty
          : NotificationReadState.fromMap(jsonDecode(raw));
    } catch (_) {
      // Defekte lokale Daten → alles gilt als ungelesen.
      yield NotificationReadState.empty;
    }
  }

  @override
  Future<void> saveReadState(NotificationReadState state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(storageKey, jsonEncode(state.toMap()));
  }
}
