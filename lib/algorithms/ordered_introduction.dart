import '../models/greek/vocabulary/learning_card.dart';

/// Neue Inhalte in Lehrreihenfolge einführen (Kirchengeschichte, Altes
/// Testament: Einstellung „In Vorlesungsreihenfolge“).
///
/// Inhalte mit Lernstand (schon einmal beantwortet) bleiben alle im Pool und
/// werden wie bisher nach Lernbedarf und Fälligkeit gewählt. Von den noch
/// nie gefragten Inhalten kommen nur die ersten [window] nach [positionOf]
/// (z. B. Nummer der Vorlesung oder Einheit) hinzu; bei gleicher Position
/// entscheidet die Reihenfolge in [pool]. Sobald einer davon beantwortet
/// ist, rückt der nächste nach.
///
/// Es wird nichts zusätzlich gespeichert: „eingeführt“ heißt, dass es eine
/// Lernkarte gibt. Ein Zurücksetzen des Bereichs beginnt daher wieder vorn.
List<T> orderedIntroduction<T>(
  List<T> pool, {
  required String Function(T) idOf,
  required Map<String, LearningCard> cards,
  required int Function(T) positionOf,
  int window = 3,
}) {
  final seen = <T>[];
  final fresh = <(int, int, T)>[];

  for (var i = 0; i < pool.length; i++) {
    final item = pool[i];
    if (cards.containsKey(idOf(item))) {
      seen.add(item);
    } else {
      fresh.add((positionOf(item), i, item));
    }
  }

  fresh.sort((a, b) {
    final byPosition = a.$1.compareTo(b.$1);
    return byPosition != 0 ? byPosition : a.$2.compareTo(b.$2);
  });

  return [...seen, for (final f in fresh.take(window)) f.$3];
}
