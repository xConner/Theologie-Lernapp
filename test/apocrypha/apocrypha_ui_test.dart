import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/screens/apocrypha/apocrypha_home_screen.dart';
import 'package:theologie_lernapp/screens/apocrypha/apocrypha_reader_screen.dart';
import 'package:theologie_lernapp/services/apocrypha/apocrypha_repository.dart';
import 'package:theologie_lernapp/services/apocrypha/apocrypha_user_data.dart';
import 'package:theologie_lernapp/services/quiz_documents.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';

import '../test_asset_bundle.dart';

Finder key(String value) => find.byKey(ValueKey(value));

Finder menuItem(String label) => find.byWidgetPredicate(
  (w) =>
      w is CheckedPopupMenuItem &&
      w.child is Text &&
      (w.child as Text).data == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApocryphaRepository repo;
  late ApocryphaUserData userData;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = ApocryphaRepository(bundle: FileAssetBundle());
    userData = ApocryphaUserData(LocalQuizDocuments());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double width = 500,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  testWidgets("Übersicht zeigt Gruppen, Filter führen zur Liste", (
    tester,
  ) async {
    await pump(
      tester,
      ApocryphaHomeScreen(repository: repo, userData: userData),
    );
    expect(key("apocrypha-overview"), findsOneWidget);
    expect(key("apocrypha-category-deuterokanonisch"), findsOneWidget);

    await tester.tap(key("apocrypha-category-deuterokanonisch"));
    await tester.pumpAndSettle();
    expect(key("apocrypha-results"), findsOneWidget);
    expect(key("apocrypha-work-tobit"), findsOneWidget);

    await tester.tap(key("apocrypha-reset"));
    await tester.pumpAndSettle();
    expect(key("apocrypha-overview"), findsOneWidget);

    await tester.enterText(key("apocrypha-search"), "Hirt");
    await tester.pumpAndSettle();
    expect(key("apocrypha-work-hermas"), findsOneWidget);
  });

  testWidgets("Werkseite mit Kanonstatus, Fassungen und Merkliste", (
    tester,
  ) async {
    await pump(
      tester,
      ApocryphaHomeScreen(repository: repo, userData: userData),
    );
    await tester.enterText(key("apocrypha-search"), "Tobit");
    await tester.pumpAndSettle();
    await tester.tap(key("apocrypha-work-tobit"));
    await tester.pumpAndSettle();

    expect(find.text("Kanonstatus"), findsOneWidget);
    expect(key("apocrypha-canon"), findsOneWidget);
    expect(find.text("Römisch-katholisch"), findsOneWidget);
    await tester.scrollUntilVisible(
      key("apocrypha-version-tobit.menge1939"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining("Hermann Menge"), findsWidgets);

    await tester.tap(key("apocrypha-favorite"));
    await tester.pumpAndSettle();
    expect((await userData.load()).isFavorite("tobit"), isTrue);
  });

  testWidgets("Leser: Navigation, Position, Fassungswechsel, Vergleich", (
    tester,
  ) async {
    await pump(
      tester,
      ApocryphaReaderScreen(
        workId: "tobit",
        repository: repo,
        userData: userData,
      ),
      width: 900,
    );
    expect(find.text("Kapitel 1"), findsWidgets);
    expect(find.textContaining("Tobit"), findsWidgets);

    await tester.scrollUntilVisible(
      key("apocrypha-next"),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(key("apocrypha-next"));
    await tester.pumpAndSettle();
    expect(key("apocrypha-unit-2"), findsOneWidget);
    var state = await userData.load();
    expect(state.positions["tobit"]!.unitId, "2");
    expect(state.positions["tobit"]!.versionId, "tobit.menge1939");

    // Vergleich mit der Septuaginta (Text aus dem Bibelbereich).
    await tester.tap(key("apocrypha-parallel-menu"));
    await tester.pumpAndSettle();
    await tester.tap(menuItem("Septuaginta (Brenton 1851)"));
    await tester.pumpAndSettle();

    expect((await userData.load()).parallels["tobit"], "tobit.lxx_brenton");

    // Fassung wechseln: Kapitel bleibt erhalten.
    await tester.tap(key("apocrypha-version-menu"));
    await tester.pumpAndSettle();
    await tester.tap(menuItem("Vulgata Clementina (1598)"));
    await tester.pumpAndSettle();
    expect(key("apocrypha-unit-2"), findsOneWidget);
    state = await userData.load();
    expect(state.versions["tobit"], "tobit.vulgata");

    // Lesezeichen per langem Tippen.
    await tester.longPress(key("apocrypha-block-1"));
    await tester.pumpAndSettle();
    state = await userData.load();
    expect(state.bookmarks.keys.single, "tobit.vulgata|2|1");
  });

  testWidgets("unvollständige Fassung ist im Leser gekennzeichnet", (
    tester,
  ) async {
    await pump(
      tester,
      ApocryphaReaderScreen(
        workId: "himmelfahrt_jesaja",
        repository: repo,
        userData: userData,
      ),
    );
    expect(key("apocrypha-coverage-note"), findsOneWidget);
  });

  test("Hauptmenü hat den Bereich auf gleicher Ebene wie die Bibel", () {
    final home = File("lib/screens/home_screen.dart").readAsStringSync();
    final bible = home.indexOf('label: const Text("Bibel")');
    final apocrypha = home.indexOf('ValueKey("open-apocrypha")');
    expect(bible, greaterThan(0));
    expect(apocrypha, greaterThan(bible));
    expect(home, contains("ApocryphaHomeScreen(uid: uid)"));
  });
}
