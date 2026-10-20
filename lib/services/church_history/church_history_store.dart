import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/greek/vocabulary/learning_card.dart';
import '../local_learning_store.dart';
import 'church_history_quiz.dart';

/// Einstellungen des Lernbereichs: zuletzt gewählter Umfang, Aufgabenarten
/// und ob nur schwierige Inhalte geübt werden.
class ChurchHistorySettings {
  final String scope;
  final Set<QuizKind> kinds;
  final bool onlyDifficult;

  ChurchHistorySettings({
    this.scope = "all",
    Set<QuizKind>? kinds,
    this.onlyDifficult = false,
  }) : kinds = kinds ?? QuizKind.values.toSet();

  ChurchHistorySettings copyWith({
    String? scope,
    Set<QuizKind>? kinds,
    bool? onlyDifficult,
  }) {
    return ChurchHistorySettings(
      scope: scope ?? this.scope,
      kinds: kinds ?? this.kinds,
      onlyDifficult: onlyDifficult ?? this.onlyDifficult,
    );
  }

  /// Ungültige oder fehlende Werte fallen auf die Vorgaben zurück.
  factory ChurchHistorySettings.fromMap(Object? raw) {
    if (raw is! Map) return ChurchHistorySettings();

    final kinds = raw["kinds"] is List
        ? {
            for (final k in raw["kinds"] as List)
              if (QuizKind.tryParse(k) != null) QuizKind.tryParse(k)!,
          }
        : null;

    return ChurchHistorySettings(
      scope: raw["scope"] is String ? raw["scope"] as String : "all",
      kinds: kinds == null || kinds.isEmpty ? null : kinds,
      onlyDifficult: raw["onlyDifficult"] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    "scope": scope,
    "kinds": [
      for (final k in QuizKind.values)
        if (kinds.contains(k)) k.name,
    ],
    "onlyDifficult": onlyDifficult,
  };
}

/// Speicherort des Lernstands im Bereich Kirchengeschichte.
///
/// Kein eigenes Speichersystem: wie der lateinische Grammatiktrainer als
/// Dokumente unter `users/{uid}/quiz_settings/` (Gäste lokal über den
/// [LocalLearningStore]). Die Inhalte selbst liegen als Assets in der App;
/// gespeichert werden nur die Lernkarten (Schlüssel `<Inhalt>|<Art>`) und
/// die Einstellungen:
///
/// ```text
/// church_history:          cards:    {kartenId: {difficulty, stability, lastReviewed: ms}}
/// church_history_settings: settings: {scope, kinds, onlyDifficult}
/// ```
///
/// Zurückgesetzt wird über `ProgressArea.churchHistory` (nur
/// `church_history`; die Einstellungen bleiben) oder je Umfang
/// ([resetCards]).
abstract class ChurchHistoryStore {
  Future<Map<String, LearningCard>> loadCards();

  Future<void> saveCards(Iterable<LearningCard> cards);

  Future<void> resetCards(Iterable<String> cardIds);

  Future<ChurchHistorySettings> loadSettings();

  Future<void> saveSettings(ChurchHistorySettings settings);

  factory ChurchHistoryStore.forUser(String? uid) => uid == null
      ? LocalChurchHistoryStore()
      : FirestoreChurchHistoryStore(uid);
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

class LocalChurchHistoryStore implements ChurchHistoryStore {
  LocalLearningStore get _store => LocalLearningStore.instance;

  static const String _doc = LocalLearningStore.churchHistory;
  static const String _settingsDoc = LocalLearningStore.churchHistorySettings;

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
  Future<ChurchHistorySettings> loadSettings() async {
    final doc = await _store.loadQuizDocument(_settingsDoc);
    return ChurchHistorySettings.fromMap(doc["settings"]);
  }

  @override
  Future<void> saveSettings(ChurchHistorySettings settings) {
    return _store.mergeQuizDocument(_settingsDoc, "settings", settings.toMap());
  }
}

class FirestoreChurchHistoryStore implements ChurchHistoryStore {
  final String uid;

  FirestoreChurchHistoryStore(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection("users")
      .doc(uid)
      .collection("quiz_settings");

  DocumentReference<Map<String, dynamic>> get _doc =>
      _collection.doc(LocalLearningStore.churchHistory);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _collection.doc(LocalLearningStore.churchHistorySettings);

  @override
  Future<Map<String, LearningCard>> loadCards() async =>
      _cardsFrom((await _doc.get()).data());

  @override
  Future<void> saveCards(Iterable<LearningCard> cards) {
    // Karten im selben Format wie lokal (Zeitstempel in Millisekunden),
    // damit die Übernahme von Gastdaten das Dokument unverändert kopiert.
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
  Future<ChurchHistorySettings> loadSettings() async {
    final data = (await _settingsDoc.get()).data();
    return ChurchHistorySettings.fromMap(data?["settings"]);
  }

  @override
  Future<void> saveSettings(ChurchHistorySettings settings) {
    return _settingsDoc.set({"settings": settings.toMap()});
  }
}
