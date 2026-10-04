import '../../models/memorization/memorization_card.dart';
import '../../models/memorization/memorization_text.dart';
import 'memorization_catalog.dart';
import 'memorization_repository.dart';
import 'memorization_scheduler.dart';

/// Tagesziel des Auswendiglernens für die Streak: Stand der heutigen
/// Wiederholungen über alle aktiven Texte in „Meine Texte“.
///
/// Liest nur den bestehenden Plan ([MemorizationScheduler.planFor]) und die
/// Lernstände; die Lernlogik selbst bleibt unberührt.
class MemorizationDailyGoal {
  /// Heute frei wiedergegebene Abschnitte (bzw. ganze Texte), die im Plan
  /// nicht mehr anstehen.
  final int done;

  /// Was der Plan jetzt noch vorsieht (Abschnitte, dazu je Text das
  /// Aufsagen des ganzen Textes).
  final int open;

  const MemorizationDailyGoal({required this.done, required this.open});

  int get total => done + open;

  /// Erledigt, wenn nichts mehr ansteht und heute tatsächlich geübt wurde.
  /// Ohne eigene Übung (auch an Tagen ohne fällige Wiederholung) gilt der
  /// Tag wie bei den anderen Lernbereichen nicht als erledigt.
  bool get isComplete => open == 0 && done > 0;

  factory MemorizationDailyGoal.of(
    MemorizationScheduler scheduler,
    Iterable<MemorizationText> texts,
    Map<String, MemorizationCard> cards,
  ) {
    final now = scheduler.clock();

    bool reviewedToday(String id) {
      final last = cards[id]?.lastReviewed;

      return last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
    }

    var done = 0;
    var open = 0;

    for (final text in texts) {
      final plan = scheduler.planFor(text, cards);

      final openIds = {
        for (final unit in plan.units)
          if (unit.kind != UnitKind.full)
            for (final segment in unit.segments) segment.id,
      };

      open += openIds.length + (plan.fullDue ? 1 : 0);

      for (final segment in text.segments) {
        if (!openIds.contains(segment.id) && reviewedToday(segment.id)) {
          done++;
        }
      }

      if (!plan.fullDue && reviewedToday(text.fullCardId)) {
        done++;
      }
    }

    return MemorizationDailyGoal(done: done, open: open);
  }

  /// Stand für die aktiven Texte aus „Meine Texte“ von [repository].
  factory MemorizationDailyGoal.forRepository(
    MemorizationScheduler scheduler,
    MemorizationCatalog catalog,
    MemorizationRepository repository,
  ) {
    return MemorizationDailyGoal.of(scheduler, [
      for (final id in repository.textIds)
        if (repository.isActive(id) && catalog.text(id) != null)
          catalog.text(id)!,
    ], repository.cards);
  }
}
