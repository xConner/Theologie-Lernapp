import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theologie_lernapp/info/app_info.dart';
import 'package:theologie_lernapp/info/module_info.dart';
import 'package:theologie_lernapp/screens/about_screen.dart';
import 'package:theologie_lernapp/screens/settings_screen.dart';
import 'package:theologie_lernapp/services/reports/report.dart';
import 'package:theologie_lernapp/services/reports/report_service.dart';
import 'package:theologie_lernapp/widgets/info_report.dart';

class FakeSender implements ReportSender {
  final List<Report> sent = [];

  Object? failure;

  @override
  Future<void> send(Report report) async {
    if (failure != null) throw failure!;

    sent.add(report);
  }
}

Widget host({
  ModuleInfo module = AppModules.prayers,
  ReportDetails? reportDetails,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [InfoButton(module: module, reportDetails: reportDetails)],
      ),
      body: InfoReportFooter(module: module, reportDetails: reportDetails),
    ),
  );
}

void main() {
  late FakeSender sender;

  setUp(() {
    sender = FakeSender();
    ReportService.sender = sender;
    ReportService.instance.resetCooldown();
  });

  group("Daten", () {
    test("AppInfo.version entspricht pubspec.yaml", () {
      final pubspec = File("pubspec.yaml").readAsStringSync();
      final version = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);

      expect(AppInfo.version, version);
    });

    test("Bereiche haben eindeutige Kennungen und eine Beschreibung", () {
      final ids = AppModules.all.map((m) => m.id).toSet();

      expect(ids.length, AppModules.all.length);
      expect(ids, isNot(contains(AppModules.general.id)));

      for (final module in AppModules.all) {
        expect(module.description, isNotEmpty, reason: module.id);
        expect(module.sources, isNotEmpty, reason: module.id);
      }
    });

    test("Kategorien und Felder passen zu firestore.rules", () {
      final rules = File("firestore.rules").readAsStringSync();

      for (final category in ReportCategory.values) {
        expect(rules, contains("'${category.id}'"));
      }

      final report = Report(
        category: ReportCategory.content,
        description: "  Falsche Stelle  ",
        context: const ReportContext(
          module: AppModules.pericopeQuiz,
          details: {"Perikope": "Das Paradies (das_paradies)"},
        ),
      );

      final map = report.toMap();

      // Keine personenbezogenen Felder.
      expect(map.keys.toSet(), {
        "kind",
        "category",
        "description",
        "area",
        "areaTitle",
        "context",
        "appVersion",
        "platform",
      });

      for (final key in map.keys) {
        expect(rules, contains("'$key'"));
      }

      expect(map["kind"], "report");
      expect(map["description"], "Falsche Stelle");
      expect(map["area"], "pericope_quiz");
      expect(map["context"], "Perikope: Das Paradies (das_paradies)");
    });

    test("Kontext: leere Werte entfallen, lange werden gekürzt", () {
      final context = ReportContext(
        module: AppModules.general,
        details: {
          "Leer": "   ",
          "Mehrzeilig": "a\n\n b",
          for (int i = 0; i < 20; i++) "Lang $i": "x" * 1000,
        },
      );

      final text = context.text;

      expect(text, isNot(contains("Leer")));
      expect(text, contains("Mehrzeilig: a b"));
      expect(text.length, lessThanOrEqualTo(Report.maxContextLength));
    });

    test("Meldungen in kurzer Folge werden gebremst", () async {
      final report = Report(
        category: ReportCategory.bug,
        description: "Absturz",
        context: const ReportContext(module: AppModules.general),
      );

      await ReportService.instance.submit(report);

      expect(
        () => ReportService.instance.submit(report),
        throwsA(isA<ReportThrottledException>()),
      );
      expect(sender.sent.length, 1);
    });

    test("Fehlgeschlagenes Senden löst keine Sperre aus", () async {
      final report = Report(
        category: ReportCategory.bug,
        description: "Absturz",
        context: const ReportContext(module: AppModules.general),
      );

      sender.failure = Exception("offline");
      await expectLater(ReportService.instance.submit(report), throwsException);

      sender.failure = null;
      await ReportService.instance.submit(report);

      expect(sender.sent.length, 1);
    });
  });

  group("Info", () {
    testWidgets("ⓘ zeigt Beschreibung, Quellen und Hinweise des Bereichs", (
      tester,
    ) async {
      await tester.pumpWidget(host(module: AppModules.greekGrammarTrainer));

      await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text(AppModules.greekGrammarTrainer.title), findsOneWidget);
      expect(find.text("Daten und Quellen"), findsOneWidget);
      expect(
        find.textContaining("Wiktionary", findRichText: true),
        findsWidgets,
      );
      expect(find.text("en.wiktionary.org"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Undokumentierte Herkunft wird offen benannt", (tester) async {
      await tester.pumpWidget(host(module: AppModules.confessions));

      await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(SourceInfoView.undocumented, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets("Alle Bereiche: Info-Blatt auf kleinem Display ohne Overflow", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final module in AppModules.all) {
        await tester.pumpWidget(host(module: module));

        await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text(module.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: module.id);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets("Über die App listet alle Bereiche", (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

      expect(find.text("KI-Unterstützung"), findsOneWidget);

      for (final module in AppModules.all) {
        expect(find.text(module.title), findsOneWidget);
      }

      await tester.tap(find.text(AppModules.hymns.title));
      await tester.pumpAndSettle();

      expect(find.text("Daten und Quellen"), findsOneWidget);
      // Aus „Über die App“ heraus kein Link zurück auf sich selbst.
      expect(find.widgetWithText(TextButton, "Über die App"), findsNothing);
    });

    testWidgets("Einstellungen führen zu Über die App und Fehler melden", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      GeneralSettingsView.currentUser = () => null;

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      await tester.tap(find.text("Fehler melden"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsOneWidget);
      expect(find.textContaining("Bereich: Allgemein"), findsOneWidget);

      await tester.tap(find.text("Abbrechen"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Über die App"));
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsOneWidget);
    });
  });

  group("Fehler melden", () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text("Fehler melden"));
      await tester.pumpAndSettle();
    }

    testWidgets("Kontext wird beim Öffnen ermittelt, angezeigt und gesendet", (
      tester,
    ) async {
      var entry = "alt";

      await tester.pumpWidget(host(reportDetails: () => {"Gebet": entry}));

      entry = "vaterunser";

      await openForm(tester);

      expect(infoReportOverlayOpen, isTrue);
      expect(find.textContaining("Bereich: Gebete"), findsOneWidget);
      expect(find.textContaining("Gebet: vaterunser"), findsOneWidget);

      await tester.tap(find.text(ReportCategory.source.label));
      await tester.enterText(find.byType(TextField), "Quelle stimmt nicht");
      await tester.tap(find.text("Senden"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsNothing);
      expect(infoReportOverlayOpen, isFalse);
      expect(find.text("Danke! Deine Meldung wurde gesendet."), findsOneWidget);

      final report = sender.sent.single;

      expect(report.category, ReportCategory.source);
      expect(report.description, "Quelle stimmt nicht");
      expect(report.context.module, AppModules.prayers);
      expect(report.context.text, "Gebet: vaterunser");
    });

    testWidgets("Über das Info-Blatt bleibt der Kontext erhalten", (
      tester,
    ) async {
      await tester.pumpWidget(host(reportDetails: () => {"Gebet": "kyrie"}));

      await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(infoReportOverlayOpen, isTrue);

      await tester.ensureVisible(find.text("Fehler in diesem Bereich melden"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Fehler in diesem Bereich melden"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsOneWidget);
      expect(find.textContaining("Gebet: kyrie"), findsOneWidget);
    });

    testWidgets("Leere Eingabe wird nicht gesendet", (tester) async {
      await tester.pumpWidget(host());
      await openForm(tester);

      await tester.tap(find.text("Senden"));
      await tester.pumpAndSettle();

      expect(find.text("Bitte wähle aus, worum es geht."), findsOneWidget);

      await tester.ensureVisible(find.text(ReportCategory.bug.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReportCategory.bug.label));
      await tester.enterText(find.byType(TextField), "  ");
      await tester.tap(find.text("Senden"));
      await tester.pump();

      expect(
        find.text("Bitte beschreibe kurz, was falsch ist."),
        findsOneWidget,
      );
      expect(sender.sent, isEmpty);
      expect(find.byType(ReportDialog), findsOneWidget);
    });

    testWidgets("Abbrechen sendet nichts", (tester) async {
      await tester.pumpWidget(host());
      await openForm(tester);

      await tester.tap(find.text(ReportCategory.bug.label));
      await tester.enterText(find.byType(TextField), "Absturz");
      await tester.tap(find.text("Abbrechen"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsNothing);
      expect(sender.sent, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets("Fehler beim Senden: Formular bleibt offen, Text kopierbar, "
        "erneutes Senden möglich", (tester) async {
      String? clipboard;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == "Clipboard.setData") {
            clipboard = (call.arguments as Map)["text"] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      sender.failure = Exception("permission-denied");

      await tester.pumpWidget(host(reportDetails: () => {"Gebet": "kyrie"}));
      await openForm(tester);

      await tester.tap(find.text(ReportCategory.content.label));
      await tester.enterText(find.byType(TextField), "Text weicht ab");
      await tester.tap(find.text("Senden"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsOneWidget);
      expect(
        find.textContaining("konnte nicht gesendet werden"),
        findsOneWidget,
      );

      // Die Fehlermeldung wird in den sichtbaren Bereich gescrollt.
      await tester.ensureVisible(find.text("Meldung als Text kopieren"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Meldung als Text kopieren"));
      await tester.pumpAndSettle();

      expect(clipboard, contains("Bereich: Gebete"));
      expect(clipboard, contains("Gebet: kyrie"));
      expect(clipboard, contains("Text weicht ab"));
      expect(find.text("Kopiert"), findsOneWidget);

      sender.failure = null;

      await tester.tap(find.text("Senden"));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDialog), findsNothing);
      expect(sender.sent.single.description, "Text weicht ab");
    });

    testWidgets("Sehr lange Eingabe wird auf die Höchstlänge begrenzt", (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await openForm(tester);

      await tester.tap(find.text(ReportCategory.other.label));
      await tester.enterText(find.byType(TextField), "x" * 5000);
      await tester.tap(find.text("Senden"));
      await tester.pumpAndSettle();

      expect(
        sender.sent.single.description.length,
        Report.maxDescriptionLength,
      );
    });

    testWidgets("Kleines Display: Formular ohne Overflow", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          reportDetails: () => {
            "Perikope": "Die Erschaffung der Welt (die_erschaffung_der_welt)",
            "Hinterlegte Stelle": "Gen 1-2",
            "Eingabe": "Gen 1",
          },
        ),
      );
      await openForm(tester);

      expect(find.byType(ReportDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
