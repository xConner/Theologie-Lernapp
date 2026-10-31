import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theologie_lernapp/screens/philosophy/logic/proof_editor.dart';
import 'package:theologie_lernapp/services/logic/logic_progress_store.dart';
import 'package:theologie_lernapp/services/logic/proof_checker.dart';
import 'package:theologie_lernapp/services/logic/proof_rules.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = LocalLogicProgressStore();
  const theorem = "¬¬q → r, ¬r ⊢ ¬q";
  const draftKey = "l4.k2.i";

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditor(WidgetTester tester, {Size size = const Size(390, 1600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProofEditor(
                theorem: Theorem.parse(theorem),
                theoremText: theorem,
                system: ProofSystem.byId("l4"),
                solution: const [],
                store: store,
                draftKey: draftKey,
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  String text(WidgetTester tester, String k) => tester.widget<TextField>(key(k)).controller!.text;

  List<String> formulas(WidgetTester tester) => [
    for (var i = 0; find.byKey(ValueKey("proof-formula-$i")).evaluate().isNotEmpty; i++)
      text(tester, "proof-formula-$i"),
  ];

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  Future<void> chooseRule(WidgetTester tester, int line, String symbol) async {
    await tap(tester, "proof-rule-$line");
    await tester.tap(find.text(symbol).last);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, int line, String entry) async {
    await tap(tester, "proof-menu-$line");
    await tester.tap(find.text(entry).last);
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester) async {
    await tap(tester, "proof-check");
    await settle(tester);
  }

  /// Beweis mit vergessener Annahme ¬r: sie wird erst am Ende ergänzt.
  Future<void> enterProofWithLateAssumption(WidgetTester tester) async {
    await tester.enterText(key("proof-formula-0"), "¬¬q → r");
    await tap(tester, "proof-add-line");
    await tester.enterText(key("proof-formula-1"), "¬q ∨ r");
    await chooseRule(tester, 1, "+A");
    await tester.enterText(key("proof-refs-1"), "α");
    await tap(tester, "proof-add-line");
    await tester.enterText(key("proof-formula-2"), "¬q");
    await chooseRule(tester, 2, "-A");
    await tester.enterText(key("proof-refs-2"), "1, β");
    await tester.pump();
    // Vergessene Annahme hinzufügen – sie landet am Ende.
    await tap(tester, "proof-add-assumption");
    await tester.enterText(key("proof-formula-3"), "¬r");
    await tester.pump();
  }

  testWidgets("Vergessene Annahme nachträglich nach oben schieben", (tester) async {
    await pumpEditor(tester);
    await enterProofWithLateAssumption(tester);

    await check(tester);
    expect(
      find.textContaining("Der Beweis ist vollständig"),
      findsNothing,
      reason: "β steht noch hinter der Zeile, die sie verwendet",
    );

    await tap(tester, "proof-up-3");
    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    expect(text(tester, "proof-refs-3"), "1, β", reason: "Inhalt bleibt erhalten");

    await check(tester);
    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);
  });

  testWidgets("Zeile dazwischen einfügen und wieder löschen: Verweise ziehen mit", (tester) async {
    await pumpEditor(tester);
    await enterProofWithLateAssumption(tester);
    await tap(tester, "proof-up-3"); // α, 1, β, 2

    // Neue Zeile zwischen α und 1.
    await menu(tester, 1, "Zeile darüber einfügen");
    expect(formulas(tester), ["¬¬q → r", "", "¬q ∨ r", "¬r", "¬q"]);
    expect(text(tester, "proof-refs-4"), "2, β", reason: "¬q ∨ r ist jetzt Zeile 2");

    await tester.enterText(key("proof-formula-1"), "¬q ∨ r");
    await chooseRule(tester, 1, "+A");
    await tester.enterText(key("proof-refs-1"), "α");
    await tester.pump();

    // Die alte Zeile 2 löschen: der Verweis zeigt auf die gelöschte Zeile.
    await menu(tester, 2, "Zeile löschen");
    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    expect(text(tester, "proof-refs-3"), "?, β");
    await tester.enterText(key("proof-refs-3"), "1, β");
    await tester.pump();

    await check(tester);
    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);
  });

  testWidgets("An den Anfang/ans Ende und Annahmen verschieben", (tester) async {
    await pumpEditor(tester);
    await enterProofWithLateAssumption(tester); // α, 1, 2, β

    await menu(tester, 3, "An den Anfang"); // ¬r wird α, ¬¬q → r wird β
    expect(formulas(tester), ["¬r", "¬¬q → r", "¬q ∨ r", "¬q"]);
    expect(text(tester, "proof-refs-2"), "β", reason: "verweist weiter auf ¬¬q → r");
    expect(text(tester, "proof-refs-3"), "1, α", reason: "β war ¬r, das jetzt α heißt");

    await menu(tester, 0, "Ans Ende");
    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬q", "¬r"]);
    expect(text(tester, "proof-refs-1"), "α");
    expect(text(tester, "proof-refs-2"), "1, β");

    // Mehrere Schritte: ¬r zwei Mal nach oben, dann ist der Beweis gültig.
    await tap(tester, "proof-up-3");
    await tap(tester, "proof-up-2");
    await tap(tester, "proof-down-1");
    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    await check(tester);
    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);
  });

  testWidgets("Ziehen am Griff verschiebt die Zeile", (tester) async {
    await pumpEditor(tester);
    await enterProofWithLateAssumption(tester);

    final from = tester.getCenter(key("proof-handle-3"));
    final target = tester.getCenter(key("proof-handle-2"));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 100));
    final dy = target.dy - from.dy - 20;
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(Offset(0, dy / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    await check(tester);
    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);
  });

  testWidgets("Reihenfolge bleibt nach Schließen und erneutem Öffnen erhalten", (tester) async {
    await pumpEditor(tester);
    await enterProofWithLateAssumption(tester);
    await tap(tester, "proof-up-3");

    // Schließen (Editor verschwindet, ausstehendes Speichern wird geschrieben).
    await tester.pumpWidget(const SizedBox());
    await settle(tester);

    final saved = (await tester.runAsync(store.load))!.proof(draftKey)!;
    expect(saved.lines.map((l) => l.formula), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    final ids = saved.lines.map((l) => l.id).toList();
    expect(ids.toSet(), hasLength(4));

    await pumpEditor(tester);
    expect(formulas(tester), ["¬¬q → r", "¬q ∨ r", "¬r", "¬q"]);
    expect(text(tester, "proof-refs-1"), "α");
    expect(text(tester, "proof-refs-3"), "1, β");
    await check(tester);
    expect(find.textContaining("Der Beweis ist vollständig"), findsOneWidget);

    // IDs bleiben nach weiterem Verschieben stabil.
    await tap(tester, "proof-down-0");
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    final again = (await tester.runAsync(store.load))!.proof(draftKey)!;
    expect(again.lines.map((l) => l.id), [ids[1], ids[0], ids[2], ids[3]]);
  });

  testWidgets("Kleiner Bildschirm: keine Überläufe", (tester) async {
    await pumpEditor(tester, size: const Size(320, 1400));
    await enterProofWithLateAssumption(tester);
    expect(tester.takeException(), isNull);
  });
}
