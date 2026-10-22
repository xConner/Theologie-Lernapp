import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../algorithms/spaced_repetition.dart';
import '../../models/church_history/church_history.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../services/church_history/church_history_progress.dart';
import '../../services/church_history/church_history_quiz.dart';
import '../../services/church_history/church_history_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_summary_tile.dart';
import 'church_history_widgets.dart';

/// Lernstand je Veranstaltung, Vorlesung bzw. Sitzung und Aufgabenart, schwierige Inhalte und
/// Zurücksetzen. Zeigt nur, wann Inhalte wie beantwortet wurden – keine
/// Punkte, Level oder Behauptungen über „Beherrschung“.
class ChurchHistoryProgressScreen extends StatefulWidget {
  final ChurchHistoryData data;

  /// Nur für Tests bzw. aus dem Quiz heraus; sonst nach Anmeldung.
  final ChurchHistoryStore? store;

  /// Nach einem Zurücksetzen (das Quiz lädt seinen Lernstand neu).
  final Future<void> Function()? onChanged;

  const ChurchHistoryProgressScreen({
    super.key,
    required this.data,
    this.store,
    this.onChanged,
  });

  @override
  State<ChurchHistoryProgressScreen> createState() =>
      _ChurchHistoryProgressScreenState();
}

class _ChurchHistoryProgressScreenState
    extends State<ChurchHistoryProgressScreen> {
  late final ChurchHistoryStore store;
  final algorithm = SpacedRepetition();

  Map<String, LearningCard>? cards;
  bool failed = false;

  ChurchHistoryData get data => widget.data;

  @override
  void initState() {
    super.initState();
    store =
        widget.store ??
        ChurchHistoryStore.forUser(FirebaseAuth.instance.currentUser?.uid);
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await store.loadCards();
      if (mounted) setState(() => cards = loaded);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  List<String> _ids(LearningScope scope, [Set<QuizKind>? kinds]) {
    final quiz = ChurchHistoryQuiz(data: data, cards: cards);
    final candidates = quiz.candidates(scope, kinds ?? QuizKind.values.toSet());

    // Eine Reihenfolge-Karte gehört zum Ereignis, nicht zur Aufgabe.
    return candidates.map((c) => c.cardId).toSet().toList();
  }

  Future<void> _reset(String label, List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fortschritt zurücksetzen?"),
        content: Text(
          "Der Lernstand für „$label“ wird gelöscht. Inhalte und "
          "Einstellungen bleiben erhalten.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Zurücksetzen"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await store.resetCards(ids);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Zurücksetzen fehlgeschlagen.")),
        );
      }
      return;
    }

    await widget.onChanged?.call();
    await _load();
  }

  /// Lesbare Bezeichnung einer Lernkarte (`<Inhalt>|<Art>`).
  String describe(String cardId) {
    final itemId = cardId.split("|").first;

    final entry = data.entry(itemId);
    if (entry != null) return entry.name;

    final epoch = data.epoch(itemId);
    if (epoch != null) return "Epoche: ${epoch.title}";

    for (final l in data.units) {
      for (final q in l.questions) {
        if (q.id == itemId) return q.prompt;
      }
      for (final list in l.lists) {
        if (list.id == itemId) return "Merkliste: ${list.title}";
      }
    }

    return itemId;
  }

  @override
  Widget build(BuildContext context) {
    final cards = this.cards;

    if (cards == null) {
      return ChurchHistoryPage(
        title: "Fortschritt",
        children: [
          failed
              ? const EmptyHint("Der Lernstand konnte nicht geladen werden.")
              : const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
        ],
      );
    }

    final allIds = _ids(LearningScope.all);
    final difficult = [
      for (final id in allIds)
        if ((cards[id]?.difficulty ?? 0) >=
            ChurchHistoryQuiz.difficultThreshold)
          id,
    ]..sort((a, b) => cards[b]!.difficulty.compareTo(cards[a]!.difficulty));

    return ChurchHistoryPage(
      title: "Fortschritt",
      children: [
        Text(
          "„Zuletzt sicher“ heißt nur: zuletzt richtig beantwortet und noch "
          "nicht wieder fällig. Fällige und oft falsch beantwortete Inhalte "
          "kommen im Quiz häufiger.",
          style: TextStyle(color: context.colors.textSecondary),
        ),

        const SectionTitle("Gesamt"),
        ProgressSummaryTile(
          title: "Alle Inhalte",
          summary: ProgressSummary.of(allIds, cards, algorithm),
          onReset: cards.isEmpty
              ? null
              : () => _reset("Kirchengeschichte", cards.keys.toList()),
        ),

        if (data.seminar != null) ...[
          const SectionTitle("Nach Veranstaltung"),
          for (final scope in [
            LearningScope.allLectures,
            LearningScope.seminar,
          ])
            Builder(
              builder: (_) {
                final ids = _ids(scope);
                final summary = ProgressSummary.of(ids, cards, algorithm);
                return ProgressSummaryTile(
                  key: ValueKey("progress-${scope.key}"),
                  title: scope.label(data),
                  summary: summary,
                  onReset: summary.fresh == summary.total
                      ? null
                      : () => _reset(scope.label(data), ids),
                );
              },
            ),
        ],

        SectionTitle(
          data.seminar == null
              ? "Nach Vorlesung"
              : "Nach Vorlesung und Sitzung",
        ),
        for (final l in data.units.where((l) => l.hasLearningContent))
          Builder(
            builder: (_) {
              final ids = _ids(LearningScope.lecture(l.id));
              final summary = ProgressSummary.of(ids, cards, algorithm);
              return ProgressSummaryTile(
                key: ValueKey("progress-${l.id}"),
                title: l.kind == CourseKind.lecture
                    ? "${l.label}: ${l.title}"
                    : "${l.kind.label}, ${l.label}: ${l.title}",
                summary: summary,
                onReset: summary.fresh == summary.total
                    ? null
                    : () => _reset(l.label, ids),
              );
            },
          ),

        const SectionTitle("Nach Aufgabenart"),
        for (final kind in QuizKind.values)
          Builder(
            builder: (_) {
              final summary = ProgressSummary.of(
                _ids(LearningScope.all, {kind}),
                cards,
                algorithm,
              );
              return summary.isEmpty
                  ? const SizedBox.shrink()
                  : ProgressSummaryTile(title: kind.label, summary: summary);
            },
          ),

        const SectionTitle("Schwierige Inhalte"),
        if (difficult.isEmpty)
          const EmptyHint("Zurzeit keine.")
        else
          for (final id in difficult.take(15))
            ListTile(
              dense: true,
              leading: Icon(
                Icons.priority_high_rounded,
                color: context.colors.error,
              ),
              title: Text(describe(id)),
              subtitle: Text(
                QuizKind.tryParse(id.split("|").last)?.label ??
                    _kindLabel(id.split("|").last),
              ),
            ),
      ],
    );
  }

  static String _kindLabel(String suffix) => switch (suffix) {
    "actor" => "Personen",
    "name" => "Begriffe",
    "when" => "Datierungen",
    "dates" || "character" || "epoch" => "Epochen",
    _ => suffix,
  };
}
