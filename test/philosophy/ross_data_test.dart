import 'package:flutter_test/flutter_test.dart';
import 'package:theologie_lernapp/models/philosophy/reading_work.dart';
import 'package:theologie_lernapp/services/philosophy/reading_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("Werkverzeichnis: geschützte Ausgabe ist nicht mitgeliefert", () async {
    final work = await ReadingRepository().work("aristotle.physics");
    final heinemann = work.edition("heinemann-2021")!;
    expect(heinemann.kind, EditionKind.private);
    expect(heinemann.path, isNull);
    expect(heinemann.hasGerman, isTrue);
    final ross = work.edition("ross-first1k")!;
    expect(ross.kind, EditionKind.bundled);
    expect(ross.rights, contains("CC BY-SA"));
  });

  test("Ross-Text: vier Bücher, stabile Kennungen, Stellen aufsteigend", () async {
    final repo = ReadingRepository();
    final work = await repo.work("aristotle.physics");
    final text = await repo.bundled(work, work.edition("ross-first1k")!);
    expect(text.books.map((b) => b.number), [1, 2, 3, 4]);
    expect(
      text.books.map((b) => "${b.chapters.first.units.first.ref}"),
      ["184a10", "192b8", "200b12", "208a27"],
    );
    final ids = <String>{};
    var count = 0;
    for (final chapter in text.chapters) {
      var previous = chapter.units.first.ref;
      for (final s in chapter.sentences) {
        count++;
        expect(ids.add(s.id), isTrue, reason: "doppelte Kennung ${s.id}");
        expect(s.ref >= previous, isTrue, reason: "${s.id} vor $previous");
        expect(s.text.trim(), isNotEmpty);
        previous = s.ref;
      }
      for (final u in chapter.units) {
        // Keine Übersetzung im mitgelieferten Text.
        expect(u.german, isEmpty);
      }
    }
    expect(count, greaterThan(1500));
    expect(text.front.isEmpty, isTrue);
    expect(text.allNotes, isEmpty);
  });
}
