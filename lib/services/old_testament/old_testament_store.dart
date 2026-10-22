import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/greek/vocabulary/learning_card.dart';
import '../local_learning_store.dart';
import 'old_testament_quiz.dart';

/// Einstellungen des Lernmodus: zuletzt gewählter Umfang, Aufgabenarten und
/// ob nur schwierige Inhalte geübt werden.
///
/// Gespeichert werden die abgewählten Arten, damit Aufgabenarten, die mit
/// späteren Einheiten hinzukommen, von selbst aktiv sind.
class OldTestamentSettings {
  final String scope;
  final Set<OtQuizKind> disabledKinds;
  final bool onlyDifficult;

  const OldTestamentSettings({
    this.scope = "all",
    this.disabledKinds = const {},
    this.onlyDifficult = false,
  });

  Set<OtQuizKind> get kinds =>
      OtQuizKind.values.toSet().difference(disabledKinds);

  OldTestamentSettings copyWith({
    String? scope,
    Set<OtQuizKind>? kinds,
    bool? onlyDifficult,
  }) {
    return OldTestamentSettings(
      scope: scope ?? this.scope,
      disabledKinds: kinds == null
          ? disabledKinds
          : OtQuizKind.values.toSet().difference(kinds),
      onlyDifficult: onlyDifficult ?? this.onlyDifficult,
    );
  }

  /// Ungültige oder fehlende Werte fallen auf die Vorgaben zurück; eine
  /// Auswahl ohne jede Art gilt als „alle“.
  factory OldTestamentSettings.fromMap(Object? raw) {
    if (raw is! Map) return const OldTestamentSettings();

    final disabled = raw["disabledKinds"] is List
        ? {
            for (final k in raw["disabledKinds"] as List)
              ?OtQuizKind.tryParse(k),
          }
        : <OtQuizKind>{};

    return OldTestamentSettings(
      scope: raw["scope"] is String ? raw["scope"] as String : "all",
      disabledKinds: disabled.length == OtQuizKind.values.length
          ? const {}
          : disabled,
      onlyDifficult: raw["onlyDifficult"] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    "scope": scope,
    "disabledKinds": [
      for (final k in OtQuizKind.values)
        if (disabledKinds.contains(k)) k.name,
    ],
    "onlyDifficult": onlyDifficult,
  };
}

/// Speicherort des Lernstands im Bereich Altes Testament – wie in der
/// Kirchengeschichte als Dokumente unter `users/{uid}/quiz_settings/`
/// (Gäste lokal über den [LocalLearningStore]):
///
/// ```text
/// old_testament:          cards:    {kartenId: {difficulty, stability, lastReviewed: ms}}
/// old_testament_settings: settings: {scope, disabledKinds, onlyDifficult}
/// ```
///
/// Kartenschlüssel sind `<Inhalts-ID>|<Art>`. Neue Einheiten bringen neue
/// IDs mit; vorhandene Karten bleiben unberührt.
abstract class OldTestamentStore {
  Future<Map<String, LearningCard>> loadCards();

  Future<void> saveCards(Iterable<LearningCard> cards);

  Future<void> resetCards(Iterable<String> cardIds);

  Future<OldTestamentSettings> loadSettings();

  Future<void> saveSettings(OldTestamentSettings settings);

  factory OldTestamentStore.forUser(String? uid) =>
      uid == null ? LocalOldTestamentStore() : FirestoreOldTestamentStore(uid);
}

Map<String, LearningCard> _cardsFrom(Map<String, dynamic>? doc) {
  final raw = doc?["cards"];

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

class LocalOldTestamentStore implements OldTestamentStore {
  LocalLearningStore get _store => LocalLearningStore.instance;

  static const String _doc = LocalLearningStore.oldTestament;
  static const String _settingsDoc = LocalLearningStore.oldTestamentSettings;

  @override
  Future<Map<String, LearningCard>> loadCards() async =>
      _cardsFrom(await _store.loadQuizDocument(_doc));

  @override
  Future<void> saveCards(Iterable<LearningCard> cards) {
    return _store.mergeQuizDocument(_doc, "cards", {
      for (final card in cards) card.id: card.toJson(),
    });
  }

  @override
  Future<void> resetCards(Iterable<String> cardIds) {
    return _store.mergeQuizDocument(_doc, "cards", {
      for (final id in cardIds) id: null,
    });
  }

  @override
  Future<OldTestamentSettings> loadSettings() async {
    final doc = await _store.loadQuizDocument(_settingsDoc);
    return OldTestamentSettings.fromMap(doc["settings"]);
  }

  @override
  Future<void> saveSettings(OldTestamentSettings settings) {
    return _store.mergeQuizDocument(_settingsDoc, "settings", settings.toMap());
  }
}

class FirestoreOldTestamentStore implements OldTestamentStore {
  final String uid;

  FirestoreOldTestamentStore(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection("users")
      .doc(uid)
      .collection("quiz_settings");

  DocumentReference<Map<String, dynamic>> get _doc =>
      _collection.doc(LocalLearningStore.oldTestament);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _collection.doc(LocalLearningStore.oldTestamentSettings);

  @override
  Future<Map<String, LearningCard>> loadCards() async =>
      _cardsFrom((await _doc.get()).data());

  @override
  Future<void> saveCards(Iterable<LearningCard> cards) {
    // Gleiches Format wie lokal, damit die Übernahme von Gastdaten das
    // Dokument unverändert kopiert.
    return _doc.set({
      "cards": {for (final card in cards) card.id: card.toJson()},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> resetCards(Iterable<String> cardIds) {
    return _doc.set({
      "cards": {for (final id in cardIds) id: FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  @override
  Future<OldTestamentSettings> loadSettings() async {
    final data = (await _settingsDoc.get()).data();
    return OldTestamentSettings.fromMap(data?["settings"]);
  }

  @override
  Future<void> saveSettings(OldTestamentSettings settings) {
    return _settingsDoc.set({"settings": settings.toMap()});
  }
}
