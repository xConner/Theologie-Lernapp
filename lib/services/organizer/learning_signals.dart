import 'package:flutter/foundation.dart';

import '../streak/streak_service.dart';
import '../streak/streak_track.dart';
import 'organizer_controller.dart';

/// Tagesziele der Lernbereiche aus dem [StreakService]: Eine Aufgabe mit
/// Lernbereich (z. B. „Griechisch-Vokabeln üben“) gilt als erledigt, sobald
/// dort heute das Tagesziel erreicht ist. Gelesen wird nur; eine Aufgabe
/// zählt nie als Lernaktivität.
class StreakLearningSignals implements LearningSignals {
  final String? uid;
  final StreakService service;

  StreakLearningSignals({required this.uid, StreakService? service})
    : service = service ?? StreakService.instance;

  Future<void> load() => service.load(uid);

  /// Lernbereiche, die sich mit einer Aufgabe verknüpfen lassen.
  static List<StreakTrack> get tracks => StreakTrack.all;

  static StreakTrack? track(String id) {
    for (final t in StreakTrack.all) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  bool goalReachedToday(String trackId) {
    final t = track(trackId);
    if (t == null) return false;
    return service.snapshotFor(uid, t).completedToday;
  }

  @override
  void addListener(VoidCallback listener) => service.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      service.removeListener(listener);
}
