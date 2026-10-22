import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../algorithms/review_state.dart';
import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../models/old_testament/old_testament.dart';
import '../../services/old_testament/old_testament_quiz.dart';
import '../../services/old_testament/old_testament_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_summary_tile.dart';
import 'old_testament_widgets.dart';

/// Lernstand je Einheit und Aufgabenart, schwierige Inhalte und
/// Zurücksetzen. Zeigt nur, wann Inhalte wie beantwortet wurden – keine
/// Punkte, Level oder Behauptungen über „Beherrschung“.
class OldTestamentProgressScreen extends StatefulWidget {
  final OldTestamentData data;

  /// Nur für Tests bzw. aus dem Lernmodus heraus; sonst nach Anmeldung.
  final OldTestamentStore? store;

  /// Nach einem Zurücksetzen (der Lernmodus lädt seinen Stand neu).
  final Future<void> Function()? onChanged;

  const OldTestamentProgressScreen({
    super.key,
    required this.data,
    this.store,
    this.onChanged,
  });

  @override
  State<OldTestamentProgressScreen> createState() =>
      _OldTestamentProgressScreenState();
}

class _OldTestamentProgressScreenState
    extends State<OldTestamentProgressScreen> {
  late final OldTestamentStore store;
  final algorithm = SpacedRepetition();

  Map<String, LearningCard>? cards;
  bool failed = false;

  OldTestamentData get data => widget.data;

  @override
  void initState() {
    super.initState();
    store =
        widget.store ??
        OldTestamentStore.forUser(FirebaseAuth.instance.currentUser?.uid);
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

  List<String> _ids(OtScope scope, [Set<OtQuizKind>? kinds]) {
    final quiz = OldTestamentQuiz(data: data, cards: cards);
    return quiz
        .candidates(scope, kinds ?? OtQuizKind.values.toSet())
        .map((c) => c.cardId)
        .toSet()
        .toList();
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
    final parts = cardId.split("|");
    final itemId = parts.first;

    final term = data.term(itemId);
    if (term != null) {
      return parts.last == "name"
          ? "${term.name} (Begriff zur Erklärung)"
          : term.name;
    }

    for (final u in data.units) {
      for (final q in u.questions) {
        if (q.id == itemId) return q.prompt;
      }
      for (final l in u.lists) {
        if (l.id == itemId) return "Merkliste: ${l.title}";
      }
      for (final p in u.passages) {
        if (p.id == itemId) return "Bibelstelle: ${p.label}";
      }
    }

    return itemId;
  }

  @override
  Widget build(BuildContext context) {
    final cards = this.cards;

    if (cards == null) {
      return ContentPage(
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

    final allIds = _ids(OtScope.all);
    final difficult = [
      for (final id in allIds)
        if (isDifficultCard(cards[id])) id,
    ]..sort((a, b) => cards[b]!.difficulty.compareTo(cards[a]!.difficulty));

    return ContentPage(
      title: "Fortschritt",
      children: [
        Text(
          "„Zuletzt sicher“ heißt nur: zuletzt richtig beantwortet und noch "
          "nicht wieder fällig. Fällige und oft falsch beantwortete Inhalte "
          "kommen im Lernmodus häufiger.",
          style: TextStyle(color: context.colors.textSecondary),
        ),

        const ContentSectionTitle("Gesamt"),
        ProgressSummaryTile(
          key: const ValueKey("progress-all"),
          title: "Alle Einheiten",
          summary: ProgressSummary.of(allIds, cards, algorithm),
          onReset: cards.isEmpty
              ? null
              : () => _reset("Altes Testament", cards.keys.toList()),
        ),

        const ContentSectionTitle("Nach Einheit"),
        for (final u in data.units.where((u) => u.hasLearningContent))
          Builder(
            builder: (_) {
              final ids = _ids(OtScope.unit(u.id));
              final summary = ProgressSummary.of(ids, cards, algorithm);
              return ProgressSummaryTile(
                key: ValueKey("progress-${u.id}"),
                title: "${u.label}: ${u.title}",
                summary: summary,
                onReset: summary.fresh == summary.total
                    ? null
                    : () => _reset(u.label, ids),
              );
            },
          ),

        const ContentSectionTitle("Nach Aufgabenart"),
        for (final kind in OtQuizKind.values)
          Builder(
            builder: (_) {
              final summary = ProgressSummary.of(
                _ids(OtScope.all, {kind}),
                cards,
                algorithm,
              );
              return summary.isEmpty
                  ? const SizedBox.shrink()
                  : ProgressSummaryTile(title: kind.label, summary: summary);
            },
          ),

        const ContentSectionTitle("Schwierige Inhalte"),
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
                (OtQuizKind.tryParse(id.split("|").last) ?? OtQuizKind.term)
                    .label,
              ),
            ),
      ],
    );
  }
}
