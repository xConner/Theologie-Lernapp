import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greek/vocabulary/learning_card.dart';
import 'local_learning_store.dart';

/// Dokumente unter `users/{uid}/quiz_settings/` (Konto) bzw. lokal im
/// [LocalLearningStore] (Gast) – der gemeinsame Speicher der Lernbereiche,
/// die keine eigene Collection haben (Bücher systematisch lernen,
/// Kirchengeschichte, Altes Testament, Latein-Lernplan).
///
/// Beide Seiten speichern dasselbe Format (Zeitpunkte in Millisekunden),
/// damit die Übernahme von Gastdaten die Dokumente unverändert kopiert
/// (`ProgressDataService.transferGuestData`). Die Namen stehen in
/// [LocalLearningStore.quizDocuments].
///
/// Bereiche, die Zähler atomar erhöhen (`FieldValue.increment`: Logik,
/// Latein-Grammatik), schreiben weiterhin selbst.
abstract class QuizDocuments {
  /// Inhalt des Dokuments; leer, wenn es nicht existiert.
  Future<Map<String, dynamic>> load(String name);

  /// Ersetzt die Einträge [entries] im Map-Feld [field]; ein Wert `null`
  /// entfernt den Eintrag. Andere Einträge bleiben erhalten (Merge), damit
  /// gleichzeitige Änderungen anderer Einträge nicht verloren gehen.
  Future<void> mergeEntries(
    String name,
    String field,
    Map<String, Object?> entries,
  );

  /// Speichert [value] als Feld [field] (Einstellungen, Pläne). In Firestore
  /// ersetzt das das Dokument; lokal werden die Einträge des Felds ersetzt.
  Future<void> replaceField(
    String name,
    String field,
    Map<String, dynamic> value,
  );

  /// Entfernt das Dokument.
  Future<void> remove(String name);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory QuizDocuments.forUser(String? uid) =>
      uid == null ? LocalQuizDocuments() : FirestoreQuizDocuments(uid);
}

class LocalQuizDocuments implements QuizDocuments {
  LocalLearningStore get _store => LocalLearningStore.instance;

  @override
  Future<Map<String, dynamic>> load(String name) =>
      _store.loadQuizDocument(name);

  @override
  Future<void> mergeEntries(
    String name,
    String field,
    Map<String, Object?> entries,
  ) => _store.mergeQuizDocument(name, field, entries);

  @override
  Future<void> replaceField(
    String name,
    String field,
    Map<String, dynamic> value,
  ) => _store.mergeQuizDocument(name, field, value);

  @override
  Future<void> remove(String name) => _store.removeQuizDocument(name);
}

class FirestoreQuizDocuments implements QuizDocuments {
  final String uid;

  FirestoreQuizDocuments(this.uid);

  DocumentReference<Map<String, dynamic>> _doc(String name) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("quiz_settings")
        .doc(name);
  }

  @override
  Future<Map<String, dynamic>> load(String name) async =>
      (await _doc(name).get()).data() ?? {};

  @override
  Future<void> mergeEntries(
    String name,
    String field,
    Map<String, Object?> entries,
  ) {
    if (entries.isEmpty) return Future.value();

    return _doc(name).set({
      field: {
        for (final entry in entries.entries)
          entry.key: entry.value ?? FieldValue.delete(),
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> replaceField(
    String name,
    String field,
    Map<String, dynamic> value,
  ) => _doc(name).set({field: value});

  @override
  Future<void> remove(String name) => _doc(name).delete();
}

/// Lernkarten im Feld `cards` eines Dokuments (Wissensbereiche):
/// `{cards: {kartenId: {difficulty, stability, lastReviewed: ms}}}`.
class QuizCardDocument {
  final QuizDocuments documents;

  final String name;

  const QuizCardDocument(this.documents, this.name);

  static const String field = "cards";

  /// Ungültige Einträge werden übergangen.
  static Map<String, LearningCard> cardsOf(Map<String, dynamic>? doc) {
    final raw = doc?[field];

    return {
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key.toString(): LearningCard.fromJson(
              entry.key.toString(),
              Map<String, dynamic>.from(entry.value as Map),
            ),
    };
  }

  Future<Map<String, LearningCard>> load() async =>
      cardsOf(await documents.load(name));

  Future<void> save(Iterable<LearningCard> cards) {
    return documents.mergeEntries(name, field, {
      for (final card in cards) card.id: card.toJson(),
    });
  }

  Future<void> reset(Iterable<String> cardIds) {
    return documents.mergeEntries(name, field, {
      for (final id in cardIds) id: null,
    });
  }
}
