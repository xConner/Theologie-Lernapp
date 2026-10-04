import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/info/app_info.dart';
import 'package:theologie_lernapp/theme/app_theme.dart';
import 'package:theologie_lernapp/widgets/open_source_footer.dart';

/// Kontrastverhältnis nach WCAG 2.x (1–21).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _app(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: OpenSourceFooter(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel("plugins.flutter.io/url_launcher");
  final launched = <String>[];

  setUp(() {
    launched.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == "launch") {
            launched.add((call.arguments as Map)["url"] as String);
          }

          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test("Der Link zeigt auf das Repository bei GitHub", () {
    expect(
      AppInfo.repositoryUrl,
      "https://github.com/xConner/Theologie-Lernapp",
    );
  });

  testWidgets("Ein Tipp öffnet das Repository", (tester) async {
    await tester.pumpWidget(_app(AppTheme.light));

    expect(find.text("Open Source"), findsOneWidget);
    expect(find.byType(GithubIcon), findsOneWidget);

    await tester.tap(find.text("Auf GitHub ansehen"));
    await tester.pump();

    expect(launched, [AppInfo.repositoryUrl]);
  });

  for (final entry in {
    "Light": (AppTheme.light, AppColors.light),
    "Dark": (AppTheme.dark, AppColors.dark),
  }.entries) {
    final (theme, colors) = entry.value;

    testWidgets("${entry.key}: passt auf schmale Bildschirme, Icon in "
        "Linkfarbe mit ausreichendem Kontrast", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(theme));

      // Ein Überlauf würde als Exception gemeldet.
      expect(tester.takeException(), isNull);

      final button = tester.getRect(find.byType(OutlinedButton));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(320));
      expect(button.height, greaterThanOrEqualTo(44));

      final iconColor = IconTheme.of(
        tester.element(find.byType(GithubIcon)),
      ).color;

      expect(iconColor, colors.primary);
      expect(_contrast(colors.primary, colors.background), greaterThan(4.5));
      expect(
        _contrast(colors.textSecondary, colors.background),
        greaterThan(4.5),
      );
    });
  }
}
