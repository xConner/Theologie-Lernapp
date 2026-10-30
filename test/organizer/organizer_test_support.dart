import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:theologie_lernapp/services/organizer/organizer_controller.dart';
import 'package:theologie_lernapp/services/organizer/organizer_store.dart';

/// Simuliert Firestore: ein Server-Stand, mehrere Geräte (Controller)
/// beobachten ihn. Schreiben führt Felder zusammen wie
/// `set(..., merge: true)`. [offline]: Schreibvorgänge warten, bis wieder
/// eine Verbindung besteht ([goOnline]).
class MemoryOrganizerBackend implements OrganizerBackend {
  final Map<String, Map<String, dynamic>> docs = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool failWrites = false;
  bool offline = false;
  final List<Completer<void>> _waiting = [];
  int writes = 0;

  Map<String, Map<String, dynamic>> _copy() => {
    for (final e in docs.entries)
      e.key: Map<String, dynamic>.from(jsonDecode(jsonEncode(e.value)) as Map),
  };

  @override
  Stream<Map<String, Map<String, dynamic>>> watch() {
    late final StreamController<Map<String, Map<String, dynamic>>> c;
    StreamSubscription<void>? sub;
    c = StreamController(
      onListen: () {
        sub = _changes.stream.listen((_) => c.add(_copy()));
        scheduleMicrotask(() => c.add(_copy()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> read() async => _copy();

  Future<void> _online() async {
    if (!offline) return;
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  void goOnline() {
    offline = false;
    for (final c in _waiting) {
      c.complete();
    }
    _waiting.clear();
  }

  @override
  Future<void> patch(String id, Map<String, dynamic> fields) async {
    await _online();
    if (failWrites) throw StateError("offline");
    writes++;
    docs[id] = {
      ...?docs[id],
      ...jsonDecode(jsonEncode(fields)) as Map<String, dynamic>,
    };
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    await _online();
    if (failWrites) throw StateError("offline");
    docs.remove(id);
    _changes.add(null);
  }
}

/// Lernbereiche mit festem Tagesziel-Stand.
class FakeLearningSignals extends ChangeNotifier implements LearningSignals {
  final Set<String> reached = {};

  void reach(String trackId) {
    reached.add(trackId);
    notifyListeners();
  }

  @override
  bool goalReachedToday(String trackId) => reached.contains(trackId);
}

/// Steuerbare Uhr.
class TestClock {
  DateTime now;

  TestClock(this.now);

  DateTime call() => now;
}

/// Wartet, bis alle Mikroaufgaben (Schreiben, Stream) durch sind.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<OrganizerController> startController(
  MemoryOrganizerBackend backend, {
  TestClock? clock,
  LearningSignals? learning,
}) async {
  final c = OrganizerController(
    backend: backend,
    clock: (clock ?? TestClock(DateTime(2026, 10, 30, 12))).call,
    learning: learning,
  );
  c.start();
  await settle();
  return c;
}
