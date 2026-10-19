import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/greek/vocabulary/learning_card.dart';
import '../../local_learning_store.dart';
import 'latin_grammar_trainer.dart';

/// Antworten je Thema (für die Fortschrittsansicht).
class LatinTopicProgress {
  final int correct;
  final int wrong;
  final DateTime? at;

  const LatinTopicProgress({this.correct = 0, this.wrong = 0, this.at});

  int get attempts => correct + wrong;

  /// Anteil richtiger Antworten (0 … 1); null ohne Antworten.
  double? get rate => attempts == 0 ? null : correct / attempts;

  static LatinTopicProgress fromJson(Object? raw) {
    if (raw is! Map) return const LatinTopicProgress();

    return LatinTopicProgress(
      correct: (raw["c"] as num?)?.toInt() ?? 0,
      wrong: (raw["w"] as num?)?.toInt() ?? 0,
      at: _time(raw["at"]),
    );
  }

  LatinTopicProgress record(bool ok, DateTime now) => LatinTopicProgress(
    correct: correct + (ok ? 1 : 0),
    wrong: wrong + (ok ? 0 : 1),
    at: now,
  );

  Map<String, dynamic> toJson() => {
    "c": correct,
    "w": wrong,
    if (at != null) "at": at!.millisecondsSinceEpoch,
  };
}

DateTime? _time(Object? raw) {
  if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  if (raw is Timestamp) return raw.toDate();
  return null;
}

/// Gespeicherter Lernstand des lateinischen Grammatiktrainers.
class LatinGrammarProgress {
  /// Lernkarten (Thema, Wort, grammatischer Wert) für die Gewichtung.
  final Map<String, LearningCard> cards;

  /// Thema → Antworten.
  final Map<String, LatinTopicProgress> topics;

  const LatinGrammarProgress({this.cards = const {}, this.topics = const {}});

  factory LatinGrammarProgress.fromJson(Map<String, dynamic>? doc) {
    final rawCards = doc?["cards"];
    final rawTopics = doc?["topics"];

    return LatinGrammarProgress(
      cards: {
        if (rawCards is Map)
          for (final entry in rawCards.entries)
            if (entry.value is Map)
              entry.key.toString(): LearningCard.fromJson(
                entry.key.toString(),
                Map<String, dynamic>.from(entry.value as Map),
              ),
      },
      topics: {
        if (rawTopics is Map)
          for (final entry in rawTopics.entries)
            if (LatinTrainerTopics.ids.contains(entry.key))
              entry.key.toString(): LatinTopicProgress.fromJson(entry.value),
      },
    );
  }

  LatinTopicProgress topic(String id) =>
      topics[id] ?? const LatinTopicProgress();
}

/// Speicherort von Lernstand und Einstellungen des lateinischen
/// Grammatiktrainers.
///
/// Kein neues Speichersystem: angemeldete Nutzer speichern unter
/// `users/{uid}/quiz_settings/` (dieselbe Collection wie „Einführung in die
/// Logik“), Gäste lokal über den [LocalLearningStore]. Getrennt vom
/// Altgriechisch-Grammatiktrainer (Collection `grammar`):
///
/// ```text
/// latin_grammar:          cards:  {kartenId: {difficulty, stability, lastReviewed: ms}}
///                         topics: {themaId: {c: richtig, w: falsch, at: ms}}
/// latin_grammar_settings: settings: {enabledTopics, enabledKinds, …}
/// ```
///
/// Zurückgesetzt wird über `ProgressArea.latinGrammar` (nur `latin_grammar`;
/// die Einstellungen bleiben).
abstract class LatinGrammarStore {
  Future<LatinGrammarProgress> load();

  Future<void> record(
    String topic,
    bool correct,
    Iterable<LearningCard> changedCards,
  );

  /// Setzt ein Thema zurück: Antwortzähler und die Karten [cardIds]
  /// (siehe [LatinGrammarTaskGenerator.cardsOfTopic]).
  Future<void> resetTopic(String topic, Iterable<String> cardIds);

  Future<LatinGrammarSettings> loadSettings();

  Future<void> saveSettings(LatinGrammarSettings settings);

  factory LatinGrammarStore.forUser(String? uid) =>
      uid == null ? LocalLatinGrammarStore() : FirestoreLatinGrammarStore(uid);
}

class LocalLatinGrammarStore implements LatinGrammarStore {
  LocalLearningStore get _store => LocalLearningStore.instance;

  static const String _doc = LocalLearningStore.latinGrammar;
  static const String _settingsDoc = LocalLearningStore.latinGrammarSettings;

  @override
  Future<LatinGrammarProgress> load() async =>
      LatinGrammarProgress.fromJson(await _store.loadQuizDocument(_doc));

  @override
  Future<void> record(
    String topic,
    bool correct,
    Iterable<LearningCard> changedCards,
  ) async {
    final current = await load();

    await _store.mergeQuizDocument(_doc, "topics", {
      topic: current.topic(topic).record(correct, DateTime.now()).toJson(),
    });

    await _store.mergeQuizDocument(_doc, "cards", {
      for (final card in changedCards) card.id: card.toJson(),
    });
  }

  @override
  Future<void> resetTopic(String topic, Iterable<String> cardIds) async {
    await _store.mergeQuizDocument(_doc, "topics", {topic: null});
    await _store.mergeQuizDocument(_doc, "cards", {
      for (final id in cardIds) id: null,
    });
  }

  @override
  Future<LatinGrammarSettings> loadSettings() async {
    final doc = await _store.loadQuizDocument(_settingsDoc);
    return LatinGrammarSettings.fromMap(doc["settings"]);
  }

  @override
  Future<void> saveSettings(LatinGrammarSettings settings) {
    return _store.mergeQuizDocument(_settingsDoc, "settings", settings.toMap());
  }
}

class FirestoreLatinGrammarStore implements LatinGrammarStore {
  final String uid;

  FirestoreLatinGrammarStore(this.uid);

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore
      .instance
      .collection("users")
      .doc(uid)
      .collection("quiz_settings");

  DocumentReference<Map<String, dynamic>> get _doc =>
      _collection.doc(LocalLearningStore.latinGrammar);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _collection.doc(LocalLearningStore.latinGrammarSettings);

  @override
  Future<LatinGrammarProgress> load() async =>
      LatinGrammarProgress.fromJson((await _doc.get()).data());

  @override
  Future<void> record(
    String topic,
    bool correct,
    Iterable<LearningCard> changedCards,
  ) {
    // Karten im selben Format wie lokal (Zeitstempel in Millisekunden),
    // damit die Übernahme von Gastdaten das Dokument unverändert kopiert.
    return _doc.set({
      "topics": {
        topic: {
          correct ? "c" : "w": FieldValue.increment(1),
          "at": DateTime.now().millisecondsSinceEpoch,
        },
      },
      "cards": {for (final card in changedCards) card.id: card.toJson()},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> resetTopic(String topic, Iterable<String> cardIds) {
    return _doc.set({
      "topics": {topic: FieldValue.delete()},
      "cards": {for (final id in cardIds) id: FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  @override
  Future<LatinGrammarSettings> loadSettings() async {
    final data = (await _settingsDoc.get()).data();
    return LatinGrammarSettings.fromMap(data?["settings"]);
  }

  @override
  Future<void> saveSettings(LatinGrammarSettings settings) {
    return _settingsDoc.set({"settings": settings.toMap()});
  }
}
