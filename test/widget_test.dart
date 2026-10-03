// Die App verwendet dart:js_interop und lässt sich nur im Browser laden:
// flutter test --platform chrome test/widget_test.dart
@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/main.dart';

void main() {
  testWidgets('App startet korrekt', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
