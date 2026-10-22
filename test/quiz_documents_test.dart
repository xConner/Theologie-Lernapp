import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/church_history/church_history_store.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/old_testament/old_testament_store.dart';
import 'package:theologie_lernapp/services/quiz_documents.dart';

/// Gemeinsamer Speicher der Lernbereiche unter `quiz_settings`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("Gast: Einträge werden zusammengeführt, null entfernt", () async {
    final docs = QuizDocuments.forUser(null);

    expect(docs, isA<LocalQuizDocuments>());
    expect(await docs.load("old_testament"), isEmpty);

    await docs.mergeEntries("old_testament", "cards", {"a": 1, "b": 2});
    await docs.mergeEntries("old_testament", "cards", {"b": null, "c": 3});

    expect(await docs.load("old_testament"), {
      "cards": {"a": 1, "c": 3},
    });

    await docs.replaceField("old_testament_settings", "settings", {"x": 1});

    expect((await docs.load("old_testament_settings"))["settings"], {"x": 1});

    await docs.remove("old_testament");

    expect(await docs.load("old_testament"), isEmpty);
  });

  test("Kartendokument: ungültige Einträge werden übergangen", () {
    final cards = QuizCardDocument.cardsOf({
      "cards": {
        "ok": {"stability": 2.0, "difficulty": 6.0, "lastReviewed": 1000},
        "kaputt": "x",
      },
    });

    expect(cards.keys, ["ok"]);
    expect(cards["ok"]!.stability, 2.0);
    expect(
      cards["ok"]!.lastReviewed,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });

  test("Bereiche teilen den Speicher, ohne sich zu berühren", () async {
    final card = LearningCard(id: "q|kind", lastReviewed: DateTime(2026));

    await LocalOldTestamentStore().saveCards([card]);

    expect(await LocalChurchHistoryStore().loadCards(), isEmpty);
    expect((await LocalOldTestamentStore().loadCards()).keys, ["q|kind"]);

    // Gleiches lokales Format wie vor der Vereinheitlichung.
    final raw = await LocalLearningStore.instance.loadQuizDocument(
      LocalLearningStore.oldTestament,
    );

    expect(
      raw["cards"]["q|kind"]["lastReviewed"],
      DateTime(2026).millisecondsSinceEpoch,
    );

    await LocalOldTestamentStore().resetCards(["q|kind"]);

    expect(await LocalOldTestamentStore().loadCards(), isEmpty);
  });
}
