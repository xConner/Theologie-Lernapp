import '../../algorithms/review_state.dart';
import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';

/// Speicher der Lernkarten eines Bereichs (Kirchengeschichte bzw. Altes
/// Testament): „Geschichte Schritt für Schritt“ legt keine eigenen
/// Dokumente an, sondern speichert seine Karten (`<ID>|h.<Fähigkeit>`)
/// neben denen von Wissensquiz und Lernmodus.
class HistoryCardStore {
  final Future<Map<String, LearningCard>> Function() load;
  final Future<void> Function(Iterable<LearningCard> cards) save;
  final Future<void> Function(Iterable<String> cardIds) reset;

  const HistoryCardStore({
    required this.load,
    required this.save,
    required this.reset,
  });
}

/// Lernkarten im Speicher, gemeinsam für alle Ansichten einer Sitzung von
/// „Geschichte Schritt für Schritt“.
///
/// Jede Antwort wird genau einmal verbucht ([record]) und sofort im
/// Speicher sichtbar; gespeichert wird der Reihe nach (eine Kette von
/// Schreibvorgängen), damit ein späterer Stand nie von einem früheren
/// überholt wird. Vor dem Neuladen wartet [flush] auf alle Schreibvorgänge.
class HistoryCardBook {
  final HistoryCardStore store;
  final Map<String, LearningCard> cards;
  final SpacedRepetition algorithm;

  /// Meldet einen fehlgeschlagenen Schreibvorgang (z. B. als Hinweis).
  void Function(Object error)? onSaveError;

  Future<void> _writes = Future.value();

  HistoryCardBook({
    required this.store,
    Map<String, LearningCard>? cards,
    SpacedRepetition? algorithm,
  }) : cards = cards ?? {},
       algorithm = algorithm ?? SpacedRepetition();

  /// Präfix der Fähigkeiten dieses Lernwegs in Kartennamen.
  static const String skillPrefix = "|h.";

  static bool isHistoryCard(String id) => id.contains(skillPrefix);

  LearningCard? operator [](String id) => cards[id];

  bool answered(String id) => cards[id]?.lastReviewed != null;

  /// Zuletzt richtig und nicht „schwierig“ – Grundlage für die nächste
  /// Stufe, keine Aussage über Beherrschung.
  bool solid(String id) {
    final card = cards[id];
    return card != null &&
        card.lastReviewed != null &&
        card.difficulty < difficultThreshold &&
        card.stability >= 1;
  }

  ReviewState stateOf(String id) => ReviewState.of(cards[id], algorithm);

  /// Verbucht Ergebnisse (Karte → richtig) und speichert sie.
  List<LearningCard> record(Map<String, bool> results) {
    final changed = <LearningCard>[];

    for (final entry in results.entries) {
      final card = cards.putIfAbsent(
        entry.key,
        () => LearningCard(id: entry.key),
      );
      algorithm.answer(card, entry.value);
      changed.add(card);
    }

    if (changed.isNotEmpty) {
      final snapshot = [
        for (final c in changed)
          LearningCard(
            id: c.id,
            stability: c.stability,
            difficulty: c.difficulty,
            lastReviewed: c.lastReviewed,
          ),
      ];
      _writes = _writes.then((_) => store.save(snapshot)).catchError((
        Object error,
      ) {
        onSaveError?.call(error);
      });
    }

    return changed;
  }

  /// Wartet, bis alle verbuchten Antworten gespeichert sind.
  Future<void> flush() => _writes;

  /// Lädt die Karten neu (nach Änderungen in anderen Ansichten des
  /// Bereichs), erst nachdem alle eigenen Schreibvorgänge abgeschlossen sind.
  Future<void> reload() async {
    await flush();
    final loaded = await store.load();
    cards
      ..clear()
      ..addAll(loaded);
  }

  /// Setzt Karten zurück (im Speicher sofort, gespeichert der Reihe nach).
  Future<void> reset(Iterable<String> ids) {
    final list = ids.toList();
    for (final id in list) {
      cards.remove(id);
    }
    final done = _writes.then((_) => store.reset(list));
    _writes = done.catchError((Object _) {});
    return done;
  }
}
