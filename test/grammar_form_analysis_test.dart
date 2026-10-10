import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:theologie_lernapp/services/greek/grammar/grammar_form_analysis.dart';
import 'package:theologie_lernapp/services/greek/grammar/wiktionary_inflection_service.dart';

http.Response _json(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  // Bestimmungen so, wie das Backend sie für die jeweilige Form liefert.

  // τέκνον: Nominativ und Akkusativ Singular sind formal identisch.
  final teknon = parseNounFormAnalyses([
    {'case': 'Nominativ', 'number': 'Sg'},
    {'case': 'Akkusativ', 'number': 'Sg'},
  ]);

  // ἡμέρας: Genitiv Singular und Akkusativ Plural sind formal identisch.
  final hemeras = parseNounFormAnalyses([
    {'case': 'Genitiv', 'number': 'Sg'},
    {'case': 'Akkusativ', 'number': 'Pl'},
  ]);

  // λόγου: eindeutig.
  final logou = parseNounFormAnalyses([
    {'case': 'Genitiv', 'number': 'Sg'},
  ]);

  group("Nomen", () {
    test("Neutrum: Nominativ und Akkusativ Singular gelten beide", () {
      expect(
        nounAnswerMatchesForm(teknon, userCase: "Akkusativ", userNumber: "Sg."),
        isTrue,
      );
      expect(
        nounAnswerMatchesForm(teknon, userCase: "Nominativ", userNumber: "Sg."),
        isTrue,
      );
    });

    test("Neutrum: andere Kasus und Numeri bleiben falsch", () {
      expect(
        nounAnswerMatchesForm(teknon, userCase: "Genitiv", userNumber: "Sg."),
        isFalse,
      );
      expect(
        nounAnswerMatchesForm(teknon, userCase: "Nominativ", userNumber: "Pl."),
        isFalse,
      );
    });

    test("Kasus und Numerus müssen gemeinsam zu einer Bestimmung passen", () {
      expect(
        nounAnswerMatchesForm(
          hemeras,
          userCase: "Akkusativ",
          userNumber: "Pl.",
        ),
        isTrue,
      );
      expect(
        nounAnswerMatchesForm(hemeras, userCase: "Genitiv", userNumber: "Sg."),
        isTrue,
      );

      // Keine Mischung aus zwei verschiedenen Bestimmungen.
      expect(
        nounAnswerMatchesForm(
          hemeras,
          userCase: "Akkusativ",
          userNumber: "Sg.",
        ),
        isFalse,
      );
      expect(
        nounAnswerMatchesForm(hemeras, userCase: "Genitiv", userNumber: "Pl."),
        isFalse,
      );
    });

    test("eindeutige Form lässt nur ihre eine Bestimmung zu", () {
      expect(
        nounAnswerMatchesForm(logou, userCase: "Genitiv", userNumber: "Sg."),
        isTrue,
      );
      expect(
        nounAnswerMatchesForm(logou, userCase: "Nominativ", userNumber: "Sg."),
        isFalse,
      );
    });

    test("unvollständige Antwort passt zu keiner Bestimmung", () {
      expect(
        nounAnswerMatchesForm(teknon, userCase: "Nominativ", userNumber: null),
        isFalse,
      );
      expect(
        nounAnswerMatchesForm(teknon, userCase: null, userNumber: null),
        isFalse,
      );
    });
  });

  group("Unsichere Daten", () {
    test("ohne Angaben des Backends wird nichts zusätzlich akzeptiert", () {
      expect(parseNounFormAnalyses(null), isEmpty);
      expect(parseNounFormAnalyses("Nominativ"), isEmpty);

      expect(
        nounAnswerMatchesForm(
          const [],
          userCase: "Nominativ",
          userNumber: "Sg.",
        ),
        isFalse,
      );
    });

    test("ungültige Einträge werden übersprungen", () {
      expect(
        parseNounFormAnalyses([
          {'case': 'Nominativ'},
          {'case': 1, 'number': 'Sg'},
          "Akkusativ",
          {'case': 'Akkusativ', 'number': 'Sg'},
        ]),
        [(grammaticalCase: 'Akkusativ', number: 'Sg')],
      );
    });
  });

  group("WiktionaryInflectionService", () {
    test("Bestimmungen werden mit der Form geladen und gecacht", () async {
      var requests = 0;

      final client = MockClient((request) async {
        requests++;

        return _json({
          'form': 'δῶρον',
          'analyses': [
            {'case': 'Nominativ', 'number': 'Sg'},
            {'case': 'Akkusativ', 'number': 'Sg'},
          ],
        });
      });

      await http.runWithClient(() async {
        final service = WiktionaryInflectionService();

        // Vor dem Laden ist nichts bekannt.
        expect(
          service.nounFormAnalyses(
            lemma: 'δῶρον',
            grammaticalCase: 'Akkusativ',
            number: 'Sg',
          ),
          isEmpty,
        );

        await service.getNounForm(
          lemma: 'δῶρον',
          grammaticalCase: 'Akkusativ',
          number: 'Sg',
        );

        expect(requests, 1);

        final nounAnalyses = service.nounFormAnalyses(
          lemma: 'δῶρον',
          grammaticalCase: 'Akkusativ',
          number: 'Sg',
        );

        expect(
          nounAnswerMatchesForm(
            nounAnalyses,
            userCase: "Nominativ",
            userNumber: "Sg.",
          ),
          isTrue,
        );

        // Die Prüfung löst keine weitere Anfrage aus.
        expect(requests, 1);
      }, () => client);
    });

    test(
      "Antwort ohne Bestimmungen lässt die Form unverändert laden",
      () async {
        final client = MockClient((request) async {
          return _json({'form': 'οἴκου'});
        });

        await http.runWithClient(() async {
          final service = WiktionaryInflectionService();

          final form = await service.getNounForm(
            lemma: 'οἶκος',
            grammaticalCase: 'Genitiv',
            number: 'Sg',
          );

          expect(form, 'οἴκου');
          expect(
            service.nounFormAnalyses(
              lemma: 'οἶκος',
              grammaticalCase: 'Genitiv',
              number: 'Sg',
            ),
            isEmpty,
          );
        }, () => client);
      },
    );
  });
}
