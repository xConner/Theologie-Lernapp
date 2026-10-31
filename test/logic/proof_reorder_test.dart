import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/services/local_learning_store.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/logic/proof_draft.dart';
import 'package:theologie_lernapp/services/logic/proof_rules.dart';
import 'package:theologie_lernapp/services/progress_data_service.dart';
import 'package:theologie_lernapp/services/progress_reset.dart';

/// Zeilen eines Beweises als (id, Annahme?) – wie im Editor.
List<({String id, bool assumption})> order(String spec) => [
  for (final p in spec.split(" ")) (id: p.substring(1), assumption: p[0] == "A"),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("ProofLineOrder", () {
    test("Bezeichner: Annahmen griechisch, sonst fortlaufende Zahlen", () {
      expect(ProofLineOrder.labels([true, false, true, false, false]), ["α", "1", "β", "2", "3"]);
    });

    test("Neue Zeile zwischen zwei Zeilen: nachfolgende Verweise ziehen mit", () {
      // A, B, C, D – X wird zwischen B und C eingefügt.
      final before = order("Aa Lb Lc Ld");
      final after = order("Aa Lb Lx Lc Ld");
      final map = ProofLineOrder.relabel(before, after);
      expect(map, {"α": "α", "1": "1", "2": "3", "3": "4"});
      expect(ProofLineOrder.rewrite("α, 2", map), "α, 3");
      expect(ProofLineOrder.rewrite("1, 3", map), "1, 4");
      expect(
        ProofLineOrder.rewrite("α,1", map),
        "α,1",
        reason: "unverändert bleibt die Schreibweise",
      );
    });

    test("An den Anfang und ans Ende verschieben", () {
      final start = order("Aa Lb Lc Ld");
      final top = ProofLineOrder.moved(start, 3, 0);
      expect(top.map((l) => l.id), ["d", "a", "b", "c"]);
      var map = ProofLineOrder.relabel(start, top);
      expect(map["3"], "1", reason: "D ist jetzt Zeile 1");
      expect(map["1"], "2");
      expect(ProofLineOrder.rewrite("1, 2", map), "2, 3");

      final end = ProofLineOrder.moved(start, 0, 3);
      expect(end.map((l) => l.id), ["b", "c", "d", "a"]);
      map = ProofLineOrder.relabel(start, end);
      expect(map["α"], "α", reason: "einzige Annahme bleibt α");
    });

    test("Mehrere Verschiebungen nacheinander", () {
      var lines = order("Aa Ab Lc Ld Le");
      var refs = "β, 1, 3"; // verweist auf b, c, e
      for (final (from, to) in [(4, 0), (1, 3), (2, 4)]) {
        final next = ProofLineOrder.moved(lines, from, to);
        refs = ProofLineOrder.rewrite(refs, ProofLineOrder.relabel(lines, next));
        lines = next;
      }
      // Ergebnis: e, b, a, d, c → Bezeichner 1, α, β, 2, 3
      expect(lines.map((l) => l.id), ["e", "b", "a", "d", "c"]);
      final labels = ProofLineOrder.labels(lines.map((l) => l.assumption));
      final byId = {for (var i = 0; i < lines.length; i++) lines[i].id: labels[i]};
      expect(refs, "${byId["b"]}, ${byId["c"]}, ${byId["e"]}");
      expect(refs, "α, 3, 1");
    });

    test("Annahmen und normale Zeilen getrennt nummeriert", () {
      // Annahme b vor a geschoben: α und β tauschen, Zahlen bleiben.
      final before = order("Aa Lx Ab Ly");
      final after = ProofLineOrder.moved(before, 2, 0);
      final map = ProofLineOrder.relabel(before, after);
      expect(map, {"α": "β", "1": "1", "β": "α", "2": "2"});
      expect(ProofLineOrder.rewrite("α, β", map), "β, α");
      expect(ProofLineOrder.rewrite("b, 1", map), "α, 1", reason: "lateinische Umschrift");
    });

    test("Verweise auf gelöschte Zeilen werden zu „?“, Unbekanntes bleibt", () {
      final before = order("Aa Lb Lc");
      final after = order("Aa Lc");
      final map = ProofLineOrder.relabel(before, after);
      expect(ProofLineOrder.rewrite("α, 1, 2", map), "α, ?, 1");
      expect(ProofLineOrder.rewrite("7", map), "7");
      expect(ProofLineOrder.rewrite("", map), "");
    });
  });

  group("ProofDraft", () {
    test("JSON: Inhalte, Regel und IDs bleiben erhalten", () {
      const draft = ProofDraft(
        lines: [
          ProofDraftLine(id: "a", rule: ProofRule.assumption, formula: "p", comment: "V"),
          ProofDraftLine(id: "b", rule: ProofRule.orIntro, formula: "p ∨ q", refs: "α", deps: "α"),
          ProofDraftLine(id: "c", formula: "q"),
        ],
      );
      final back = ProofDraft.fromJson(draft.toJson())!;
      expect(back.lines.map((l) => l.id), ["a", "b", "c"]);
      expect(back.lines[0].isAssumption, isTrue);
      expect(back.lines[0].comment, "V");
      expect(back.lines[1].rule, ProofRule.orIntro);
      expect(back.lines[1].refs, "α");
      expect(back.lines[1].deps, "α");
      expect(back.lines[2].rule, isNull);
    });

    test("Unvollständige Daten: fehlende/doppelte IDs, unbekannte Regel", () {
      final d = ProofDraft.fromJson({
        "lines": [
          {"f": "p", "rule": "assumption"},
          {"id": "x", "f": "q", "rule": "gibtsNicht"},
          {"id": "x", "f": "r"},
          "Unsinn",
        ],
      })!;
      expect(d.lines, hasLength(3));
      expect(d.lines.map((l) => l.id).toSet(), hasLength(3));
      expect(d.lines[1].rule, isNull);
      expect(ProofDraft.fromJson({"lines": []}), isNull);
      expect(ProofDraft.fromJson("x"), isNull);
    });
  });

  group("Speichern", () {
    final store = LocalLogicProgressStore();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("Alte Dokumente ohne gespeicherte Beweise bleiben lesbar", () {
      final p = LogicProgress.fromJson({
        "lessons": {
          "l1": {"opened": 1},
        },
        "tasks": {
          "l4.k2.i": {"c": 1, "w": 0, "last": true},
        },
      });
      expect(p.proofs, isEmpty);
      expect(p.task("l4.k2.i").lastCorrect, isTrue);
      expect(p.proof("l4.k2.i"), isNull);
    });

    test("Reihenfolge wird gespeichert; Fortschritt bleibt erhalten", () async {
      await store.recordTask("l4.k2.i", true);
      await store.setDone("l4", true);

      const draft = ProofDraft(
        lines: [
          ProofDraftLine(id: "a", rule: ProofRule.assumption, formula: "p"),
          ProofDraftLine(id: "c", formula: "q"),
          ProofDraftLine(id: "b", formula: "r"),
        ],
      );
      await store.saveProof("l4.k2.i", draft);

      var p = await store.load();
      expect(p.proof("l4.k2.i")!.lines.map((l) => l.id), ["a", "c", "b"]);
      expect(p.task("l4.k2.i").lastCorrect, isTrue);
      expect(p.lesson("l4").isDone, isTrue);

      // Umsortiert erneut speichern ersetzt die alte Reihenfolge.
      await store.saveProof(
        "l4.k2.i",
        ProofDraft(lines: [draft.lines[0], draft.lines[2], draft.lines[1]]),
      );
      p = await store.load();
      expect(p.proof("l4.k2.i")!.lines.map((l) => l.formula), ["p", "r", "q"]);

      await store.saveProof("l4.k2.i", null);
      expect((await store.load()).proof("l4.k2.i"), isNull);
      expect((await store.load()).task("l4.k2.i").correct, 1);
    });

    test("Zurücksetzen des Logik-Bereichs entfernt auch gespeicherte Beweise", () async {
      await store.saveProof(
        "l4.k2.i",
        const ProofDraft(
          lines: [ProofDraftLine(id: "a", formula: "p")],
        ),
      );
      expect(await LocalLearningStore.instance.hasGuestData(), isTrue);
      await ProgressDataService().resetArea(null, ProgressArea.logic);
      expect((await store.load()).proofs, isEmpty);
    });
  });
}
