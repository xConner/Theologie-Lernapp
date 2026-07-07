import '../models/perikope.dart';

class SimpleQuizEngine {
  final List<Perikope> _items;
  int _index = 0;

  SimpleQuizEngine(List<Perikope> items) : _items = items;

  bool get isEmpty => _items.isEmpty;

  int get length => _items.length;

  Perikope? get current {
    if (_items.isEmpty) return null;
    if (_index >= _items.length) _index = 0;
    return _items[_index];
  }

  void next() {
    if (_items.isEmpty) return;
    _index = (_index + 1) % _items.length;
  }
}
