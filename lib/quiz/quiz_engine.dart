import 'dart:math';

import '../models/learning_card.dart';
import '../algorithms/spaced_repetition.dart';
import '../services/learning_service.dart';

import 'quiz_question.dart';

class QuizEngine {
  List<QuizQuestion> _items;

  final Map<String, LearningCard> _cards;

  final String uid;

  final LearningService learningService;

  final SpacedRepetition algorithm;

  QuizQuestion? _current;

  QuizEngine(
    List<QuizQuestion> items,
    this._cards, {
    required this.uid,
    required this.learningService,
    SpacedRepetition? algorithm,
  }) : _items = items,
       algorithm = algorithm ?? SpacedRepetition();

  bool get isEmpty => _items.isEmpty;

  int get length => _items.length;

  QuizQuestion? get current => _current;

  LearningCard _getCard(String id) {
    return _cards.putIfAbsent(id, () => LearningCard(id: id));
  }

  void updateItems(List<QuizQuestion> items) {
    _items = items;
  }

  void start() {
    _current = _selectNext();
  }

  QuizQuestion? next() {
    _current = _selectNext();
    return _current;
  }

  QuizQuestion? _selectNext() {
    if (_items.isEmpty) {
      return null;
    }

    final scores = <QuizQuestion, double>{};

    double total = 0;

    for (final item in _items) {
      final card = _getCard(item.id);

      final score = algorithm.selectionScore(card);

      scores[item] = score;

      total += score;
    }

    if (total <= 0) {
      return _items[Random().nextInt(_items.length)];
    }

    double random = Random().nextDouble() * total;

    for (final item in _items) {
      random -= scores[item]!;

      if (random <= 0) {
        return item;
      }
    }

    return _items.last;
  }

  Future<void> answer(bool correct) async {
    if (_current == null) {
      return;
    }

    final card = _getCard(_current!.id);

    algorithm.answer(card, correct);

    await learningService.saveCard(uid, card);
  }
}
