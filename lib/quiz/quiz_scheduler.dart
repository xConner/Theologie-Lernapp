import '../models/perikope.dart';

class QuizScheduler {
  final List<Perikope> perikopen;

  /// key = perikopeId
  /// value = Firebase Progress Map
  final Map<String, dynamic> progress;

  final List<String> _recent = [];

  QuizScheduler({required this.perikopen, required this.progress});

  /// 🎯 Hauptfunktion: nächste Frage auswählen
  Perikope next() {
    final available = perikopen.where((p) => !_recent.contains(p.id)).toList();

    // falls alles im recent ist → reset
    if (available.isEmpty) {
      _recent.clear();
      return next();
    }

    final weights = available.map((p) => _getWeight(p.id)).toList();
    final totalWeight = weights.fold(0, (a, b) => a + b);

    final roll = _random(totalWeight);

    int sum = 0;

    for (int i = 0; i < available.length; i++) {
      sum += weights[i];

      if (roll < sum) {
        final selected = available[i];
        _addRecent(selected.id);
        return selected;
      }
    }

    return available.first;
  }

  /// 📊 Gewicht aus Firebase-Progress holen
  int _getWeight(String id) {
    final data = progress[id];
    if (data == null) return 5;
    return data["weight"] ?? 5;
  }

  /// 🧠 Anti-repeat Buffer
  void _addRecent(String id) {
    _recent.add(id);

    if (_recent.length > 3) {
      _recent.removeAt(0);
    }
  }

  /// 🎲 Random (einfach, reicht hier völlig)
  int _random(int max) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now % (max == 0 ? 1 : max);
  }
}
