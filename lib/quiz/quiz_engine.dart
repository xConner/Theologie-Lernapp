import 'package:flutter/foundation.dart';

import '../models/greek/vocabulary/learning_card.dart';
import '../algorithms/learning_selector.dart';
import '../algorithms/spaced_repetition.dart';
import '../services/learning_service.dart';

import 'quiz_question.dart';

class QuizEngine {
  List<QuizQuestion> _items;

  final Map<String, LearningCard> _cards;

  // null = Gastmodus (lokale Speicherung).
  final String? uid;

  final LearningService learningService;

  final LearningSelector selector;

  SpacedRepetition get algorithm => selector.algorithm;

  QuizQuestion? _current;

  final bool perikopen;

  QuizEngine(
    List<QuizQuestion> items,
    this._cards, {
    required this.uid,
    required this.learningService,
    this.perikopen = false,
    LearningSelector? selector,
  }) : _items = items,
       selector = selector ?? LearningSelector();

  bool get isEmpty => _items.isEmpty;

  int get length => _items.length;

  QuizQuestion? get current => _current;

  LearningCard _getCard(String id) {
    return _cards.putIfAbsent(id, () => LearningCard(id: id));
  }

  void updateItems(List<QuizQuestion> items) {
    _items = items;

    // Die laufende Frage auf den neuen Stand bringen, damit z.B. geänderte
    // Varianten sofort gelten und nicht erst ab der nächsten Frage.
    final id = _current?.id;

    for (final item in items) {
      if (item.id == id) {
        _current = item;
        break;
      }
    }
  }

  void start() {
    _current = _selectNext();
  }

  QuizQuestion? next() {
    _current = _selectNext();
    return _current;
  }

  QuizQuestion? _selectNext() {
    return selector.select(
      candidates: _items,
      idOf: (item) => item.id,
      cards: _cards,
    );
  }

  Future<void> answer(bool correct) async {
    if (_current == null) {
      return;
    }

    final card = _getCard(_current!.id);

    algorithm.answer(card, correct);

    // Nicht auf den Server warten: Firestore bestätigt offline erst später,
    // die Auswertung soll trotzdem sofort erscheinen.
    final save = perikopen
        ? learningService.savePerikopeCard(uid, card)
        : learningService.saveCard(uid, card);

    save.catchError((Object e) {
      debugPrint("Lernstand konnte nicht gespeichert werden: $e");
    });
  }
}
