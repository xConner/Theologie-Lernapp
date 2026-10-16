import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = LocalLogicProgressStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test("Lektionen: geöffnet und als bearbeitet markiert", () async {
    await store.markOpened("l2");
    var p = await store.load();
    expect(p.lesson("l2").isStarted, isTrue);
    expect(p.lesson("l2").isDone, isFalse);
    expect(p.lesson("l3").isStarted, isFalse);

    final opened = p.lesson("l2").opened;
    await store.markOpened("l2");
    expect((await store.load()).lesson("l2").opened, opened, reason: "erstes Öffnen bleibt");

    await store.setDone("l2", true);
    expect((await store.load()).lesson("l2").isDone, isTrue);
    await store.setDone("l2", false);
    expect((await store.load()).lesson("l2").isDone, isFalse);
  });

  test("Antworten werden gezählt; die letzte entscheidet über „wiederholen“", () async {
    await store.recordTask("l1.k1.iii", false);
    await store.recordTask("l1.k1.iii", true);
    await store.recordTask("l1.k1.iii", false);
    await store.recordGenerated("l2:truthTable", true);

    final p = await store.load();
    final t = p.task("l1.k1.iii");
    expect(t.correct, 1);
    expect(t.wrong, 2);
    expect(t.lastCorrect, isFalse);
    expect(p.generated["l2:truthTable"]!.correct, 1);
  });

  test("Zurücksetzen nur des Logik-Bereichs lässt andere Bereiche unberührt", () async {
    final local = LocalLearningStore.instance;
    await local.saveCard(
      LocalLearningStore.latinVocabulary,
      LearningCard(id: "v1", stability: 40, difficulty: 3, lastReviewed: DateTime(2026, 9, 1)),
    );
    await store.recordTask("l1.k1.i", true);
    await store.setDone("l1", true);

    await ProgressDataService().resetArea(null, ProgressArea.logic);

    final p = await store.load();
    expect(p.tasks, isEmpty);
    expect(p.lessons, isEmpty);
    expect(await local.loadCards(LocalLearningStore.latinVocabulary), contains("v1"));
  });

  test("Zurücksetzen eines anderen Bereichs lässt den Logik-Fortschritt stehen", () async {
    await store.recordTask("l1.k1.i", true);
    await ProgressDataService().resetArea(null, ProgressArea.latinVocabulary);
    expect((await store.load()).task("l1.k1.i").correct, 1);
  });

  test("Alle Lernfortschritte zurücksetzen umfasst den Logik-Fortschritt", () async {
    await store.recordTask("l1.k1.i", true);
    await ProgressDataService().resetProgress(null);
    expect((await store.load()).tasks, isEmpty);
  });

  test("Gastdaten: Logik-Fortschritt zählt mit und wird mit gelöscht", () async {
    final local = LocalLearningStore.instance;
    expect(await local.hasGuestData(), isFalse);
    await store.markOpened("l1");
    expect(await local.hasGuestData(), isTrue);
    await local.clearGuestData();
    expect((await store.load()).lessons, isEmpty);
  });

  test("Bereich „Einführung in die Logik“ ist beschrieben", () {
    expect(ProgressArea.logic.collection, isNull);
    expect(ProgressArea.logic.documents, [LocalLearningStore.logicCourse]);
    expect(ProgressArea.logic.scopeDescription, contains("Lektionen"));
  });
}
