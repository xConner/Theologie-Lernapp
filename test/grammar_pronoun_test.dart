import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/algorithms/grammar_learning.dart';
import 'package:theologie_lernapp/models/greek/grammar/pronoun_paradigm.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/greek_vocabulary_entry.dart';
import 'package:theologie_lernapp/models/greek/vocabulary/learning_card.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_answer_check.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_form_analysis.dart';
import 'package:theologie_lernapp/services/greek/grammar/grammar_question_picker.dart';
import 'package:theologie_lernapp/services/greek/grammar/pronoun_paradigms.dart';
import 'package:theologie_lernapp/widgets/pronoun_paradigm_view.dart';

const _cases = ["Nominativ", "Genitiv", "Dativ", "Akkusativ"];
const _numbers = ["Sg", "Pl"];
const _genders = ["m", "f", "n"];

void main() {
  final pronouns = PronounParadigms.fromJson(
    File("assets/greek_pronoun_forms.json").readAsStringSync(),
  );

  final vocabulary = [
    for (final item in jsonDecode(
      File("assets/greek_vocabulary.json").readAsStringSync(),
    ))
      GreekVocabularyEntry.fromJson(item),
  ];

  PronounParadigm paradigm(String lemma) {
    return pronouns.all.singleWhere((p) => p.lemma == lemma);
  }

  int idOf(String lemma) => paradigm(lemma).id;

  /// Formen einer Spalte in der Reihenfolge der Folien: Nom., Gen., Dat.,
  /// Akk. Singular, dann Plural. Varianten mit "/" verbunden.
  List<String> column(String lemma, String? gender) {
    return [
      for (final number in _numbers)
        for (final grammaticalCase in _cases)
          paradigm(lemma)
              .cell(grammaticalCase, number, gender)!
              .forms
              .map((f) => f.text)
              .join("/"),
    ];
  }

  /// Die möglichen Bestimmungen in lesbarer Form: "οὗτος Genitiv Sg m".
  Set<String> analyses(String form) {
    return {
      for (final a in pronouns.analysesOf(form))
        "${pronouns.byId(a.pronounId)!.lemma} ${a.grammaticalCase} "
            "${a.number} ${a.gender ?? '–'}",
    };
  }

  // ---------------------------------------------------------------------------
  // DATEN
  // ---------------------------------------------------------------------------

  group("Daten", () {
    test("alle Pronomen der Folien sind vorhanden", () {
      expect(pronouns.all.map((p) => p.lemma).toList(), [
        "ἐγώ",
        "σύ",
        "αὐτός",
        "ἐμός",
        "σός",
        "ἡμέτερος",
        "ὑμέτερος",
        "ὅδε",
        "οὗτος",
        "ἐκεῖνος",
        "ὅς",
        "τίς",
        "τις",
      ]);
    });

    test("Pronomenarten", () {
      String kind(String lemma) => paradigm(lemma).kind;

      expect(kind("ἐγώ"), "personal");
      expect(kind("σύ"), "personal");
      expect(kind("αὐτός"), "personal");
      expect(kind("ἐμός"), "possessive");
      expect(kind("ὑμέτερος"), "possessive");
      expect(kind("ὅδε"), "demonstrative");
      expect(kind("οὗτος"), "demonstrative");
      expect(kind("ἐκεῖνος"), "demonstrative");
      expect(kind("ὅς"), "relative");
      expect(kind("τίς"), "interrogative");
      expect(kind("τις"), "indefinite");

      for (final p in pronouns.all) {
        expect(p.kindLabel, isNot("Pronomen"), reason: p.lemma);
      }
    });

    test(
      "jedes Paradigma gehört zu einem Vokabeleintrag der Wortart Pronomen",
      () {
        for (final p in pronouns.all) {
          final entry = vocabulary.singleWhere((e) => e.id == p.id);

          expect(entry.type, "pronoun", reason: p.lemma);
          expect(entry.lemma, p.lemma);
          expect(entry.translations, isNotEmpty);
        }

        // Umgekehrt hat jedes Pronomen der Vokabelliste ein Paradigma.
        for (final entry in vocabulary.where((e) => e.type == "pronoun")) {
          expect(pronouns.byId(entry.id), isNotNull, reason: entry.lemma);
        }

        expect(vocabulary.map((e) => e.id).toSet().length, vocabulary.length);
      },
    );

    test("keine fehlenden Zellen, keine leeren Formen", () {
      for (final p in pronouns.all) {
        final genders = p.genders;
        final withoutGender = p.lemma == "ἐγώ" || p.lemma == "σύ";

        expect(genders, withoutGender ? isEmpty : _genders, reason: p.lemma);
        expect(p.cells.length, withoutGender ? 8 : 24, reason: p.lemma);

        for (final grammaticalCase in _cases) {
          for (final number in _numbers) {
            for (final gender in withoutGender ? [null] : _genders) {
              final cell = p.cell(grammaticalCase, number, gender);

              expect(
                cell,
                isNotNull,
                reason: "${p.lemma} $grammaticalCase $number $gender",
              );
              expect(cell!.forms, isNotEmpty);

              for (final form in cell.forms) {
                expect(form.text.trim(), form.text);
                expect(form.text, isNotEmpty);
              }
            }
          }
        }
      }
    });

    test("Anzahl der Zellen und Formen", () {
      final cells = pronouns.all.expand((p) => p.cells).toList();

      // 2 × 8 (ἐγώ, σύ) + 11 × 24.
      expect(cells.length, 280);

      // Dazu 6 Enklitika und 6 × τίσιν / τισίν.
      expect(cells.expand((c) => c.forms).length, 292);
    });

    test("Personalpronomen der 1. und 2. Person samt Enklitika", () {
      expect(column("ἐγώ", null), [
        "ἐγώ",
        "ἐμοῦ/μου",
        "ἐμοί/μοι",
        "ἐμέ/με",
        "ἡμεῖς",
        "ἡμῶν",
        "ἡμῖν",
        "ἡμᾶς",
      ]);

      expect(column("σύ", null), [
        "σύ",
        "σοῦ/σου",
        "σοί/σοι",
        "σέ/σε",
        "ὑμεῖς",
        "ὑμῶν",
        "ὑμῖν",
        "ὑμᾶς",
      ]);

      expect(pronouns.variantOf("ἐμοῦ"), "betont");
      expect(pronouns.variantOf("μου"), "enklitisch");
      expect(pronouns.variantOf("σε"), "enklitisch");
      expect(pronouns.variantOf("ἡμεῖς"), isNull);
    });

    test("αὐτός: Nominativ Plural αὐτοί / αὐταί (Folie: αὐτοῖ / αὐταῖ)", () {
      expect(column("αὐτός", "m"), [
        "αὐτός",
        "αὐτοῦ",
        "αὐτῷ",
        "αὐτόν",
        "αὐτοί",
        "αὐτῶν",
        "αὐτοῖς",
        "αὐτούς",
      ]);

      expect(column("αὐτός", "f"), [
        "αὐτή",
        "αὐτῆς",
        "αὐτῇ",
        "αὐτήν",
        "αὐταί",
        "αὐτῶν",
        "αὐταῖς",
        "αὐτάς",
      ]);

      expect(column("αὐτός", "n"), [
        "αὐτό",
        "αὐτοῦ",
        "αὐτῷ",
        "αὐτό",
        "αὐτά",
        "αὐτῶν",
        "αὐτοῖς",
        "αὐτά",
      ]);

      expect(pronouns.analysesOf("αὐτοῖ"), isEmpty);
      expect(pronouns.analysesOf("αὐταῖ"), isEmpty);
    });

    test("Demonstrativpronomen wie auf den Folien", () {
      expect(column("ὅδε", "m"), [
        "ὅδε",
        "τοῦδε",
        "τῷδε",
        "τόνδε",
        "οἵδε",
        "τῶνδε",
        "τοῖσδε",
        "τούσδε",
      ]);
      expect(column("ὅδε", "f"), [
        "ἥδε",
        "τῆσδε",
        "τῇδε",
        "τήνδε",
        "αἵδε",
        "τῶνδε",
        "ταῖσδε",
        "τάσδε",
      ]);
      expect(column("ὅδε", "n"), [
        "τόδε",
        "τοῦδε",
        "τῷδε",
        "τόδε",
        "τάδε",
        "τῶνδε",
        "τοῖσδε",
        "τάδε",
      ]);

      expect(column("οὗτος", "m"), [
        "οὗτος",
        "τούτου",
        "τούτῳ",
        "τοῦτον",
        "οὗτοι",
        "τούτων",
        "τούτοις",
        "τούτους",
      ]);
      expect(column("οὗτος", "f"), [
        "αὕτη",
        "ταύτης",
        "ταύτῃ",
        "ταύτην",
        "αὗται",
        "τούτων",
        "ταύταις",
        "ταύτας",
      ]);
      expect(column("οὗτος", "n"), [
        "τοῦτο",
        "τούτου",
        "τούτῳ",
        "τοῦτο",
        "ταῦτα",
        "τούτων",
        "τούτοις",
        "ταῦτα",
      ]);

      expect(column("ἐκεῖνος", "m").first, "ἐκεῖνος");
      expect(column("ἐκεῖνος", "f").first, "ἐκείνη");
      // Neutrum auf -ο, nicht -ον.
      expect(column("ἐκεῖνος", "n").first, "ἐκεῖνο");
    });

    test("Relativpronomen wie auf der Folie", () {
      expect(column("ὅς", "m"), [
        "ὅς",
        "οὗ",
        "ᾧ",
        "ὅν",
        "οἵ",
        "ὧν",
        "οἷς",
        "οὕς",
      ]);
      expect(column("ὅς", "f"), [
        "ἥ",
        "ἧς",
        "ᾗ",
        "ἥν",
        "αἵ",
        "ὧν",
        "αἷς",
        "ἅς",
      ]);
      expect(column("ὅς", "n"), ["ὅ", "οὗ", "ᾧ", "ὅ", "ἅ", "ὧν", "οἷς", "ἅ"]);
    });

    test("Interrogativ- und Indefinitpronomen samt τίσι(ν)", () {
      const interrogative = [
        "τίς",
        "τίνος",
        "τίνι",
        "τίνα",
        "τίνες",
        "τίνων",
        "τίσι/τίσιν",
        "τίνας",
      ];

      expect(column("τίς", "m"), interrogative);
      expect(column("τίς", "f"), interrogative);
      expect(column("τίς", "n"), [
        "τί",
        "τίνος",
        "τίνι",
        "τί",
        "τίνα",
        "τίνων",
        "τίσι/τίσιν",
        "τίνα",
      ]);

      const indefinite = [
        "τις",
        "τινός",
        "τινί",
        "τινα",
        "τινες",
        "τινῶν",
        "τισί/τισίν",
        "τινας",
      ];

      expect(column("τις", "m"), indefinite);
      expect(column("τις", "f"), indefinite);
      expect(column("τις", "n"), [
        "τι",
        "τινός",
        "τινί",
        "τι",
        "τινα",
        "τινῶν",
        "τισί/τισίν",
        "τινα",
      ]);

      expect(pronouns.variantOf("τίσιν"), "mit beweglichem ν");
      expect(pronouns.variantOf("τίσι"), isNull);
    });

    test("Possessivpronomen: vollständige a-/o-Deklination", () {
      expect(column("ἐμός", "m"), [
        "ἐμός",
        "ἐμοῦ",
        "ἐμῷ",
        "ἐμόν",
        "ἐμοί",
        "ἐμῶν",
        "ἐμοῖς",
        "ἐμούς",
      ]);
      expect(column("σός", "f"), [
        "σή",
        "σῆς",
        "σῇ",
        "σήν",
        "σαί",
        "σῶν",
        "σαῖς",
        "σάς",
      ]);
      expect(column("ἡμέτερος", "f"), [
        "ἡμετέρα",
        "ἡμετέρας",
        "ἡμετέρᾳ",
        "ἡμετέραν",
        "ἡμέτεραι",
        "ἡμετέρων",
        "ἡμετέραις",
        "ἡμετέρας",
      ]);
      expect(column("ὑμέτερος", "n"), [
        "ὑμέτερον",
        "ὑμετέρου",
        "ὑμετέρῳ",
        "ὑμέτερον",
        "ὑμέτερα",
        "ὑμετέρων",
        "ὑμετέροις",
        "ὑμέτερα",
      ]);
    });

    test("Gesetzmäßigkeiten der dreigeschlechtigen Paradigmen", () {
      for (final p in pronouns.all.where((p) => p.genders.isNotEmpty)) {
        String form(String grammaticalCase, String number, String gender) {
          return p.cell(grammaticalCase, number, gender)!.forms.first.text;
        }

        for (final number in _numbers) {
          expect(
            form("Nominativ", number, "n"),
            form("Akkusativ", number, "n"),
            reason: "${p.lemma}: Neutrum Nom. = Akk. $number",
          );

          for (final grammaticalCase in ["Genitiv", "Dativ"]) {
            expect(
              form(grammaticalCase, number, "m"),
              form(grammaticalCase, number, "n"),
              reason: "${p.lemma}: $grammaticalCase $number m = n",
            );
          }
        }

        expect(form("Genitiv", "Pl", "m"), form("Genitiv", "Pl", "f"));
      }
    });

    test("Gebrauchshinweise und Beispielsätze der Folien", () {
      for (final p in pronouns.all) {
        expect(p.usage, isNotEmpty, reason: p.lemma);
      }

      expect(paradigm("αὐτός").usage.join(" "), contains("derselbe Freund"));
      expect(paradigm("αὐτός").usage.join(" "), contains("der Freund selbst"));
      expect(paradigm("αὐτός").usage.join(" "), contains("sein Freund"));
      expect(paradigm("ὅδε").usage.join(" "), contains("Folgende"));
      expect(paradigm("οὗτος").usage.join(" "), contains("Vorhergehendes"));
      expect(paradigm("ὅς").usage.join(" "), contains("Bezugswort"));
      expect(paradigm("ἐμός").usage.join(" "), contains("ὁ φίλος μου"));

      final examples = {
        for (final p in pronouns.all)
          for (final example in p.examples) example.greek,
      };

      // 2 + 7 Sätze (Personalpronomen), 5 + 3 + 3 (Demonstrativ-/
      // Relativpronomen).
      expect(
        examples,
        containsAll([
          "Ἐγώ εἰμι ἡ ὁδὸς καὶ ἡ ἀλήθεια καὶ ἡ ζωή.",
          "οὐδεὶς ἔρχεται πρὸς τὸν πατέρα εἰ μὴ δι’ ἐμοῦ.",
          "ἐγὼ καὶ σὺ φίλοι ἐσμέν.",
          "πιστεύω σοι.",
          "πιστεύω τοῖς λόγοις ὑμῶν.",
          "Παῦλος αὐτὸς ἔρχεται εἰς Κόρινθον.",
          "ὁ γὰρ Χριστὸς πέμπει αὐτόν.",
          "πιστεύομεν τοῖς λόγοις αὐτοῦ.",
          "τὴν αὐτὴν γνώμην ἔχω ὡς σύ.",
          "ὅδε ὁ ἄνθρωπος πιστός ἐστιν.",
          "τῷδε τῷ ἀνθρώπῳ πιστεύω.",
          "αὕτη ἡ νῆσος καλή ἐστιν.",
          "τοῦτο τὸ βιβλίον μοι ἀρέσκει.",
          "τοῦτο τὸ βιβλίον γιγνώσκω, ἐκεῖνο δ’ οὔ.",
          "Χριστός, ὃς τοὺς ἀνθρώπους διδάσκει",
          "οἱ λόγοι, οὓς ὁ Χριστὸς λέγει",
          "ἡ ἐκκλησία, περὶ ἧς εὐχαριστῶ",
          "ὁ ποιητής, ὃς τὴν Ὀδύσσειαν ἔγραψεν, Ὅμηρος ὀνομάζεται.",
          "ἡ γυνή, ἣ τῷ Ἀλεξάνδρῳ εἵπετο εἰς Τροίαν, Ἑλένη ὠνομάζετο.",
          "ἡ νῆσος, ἣν ἐκεῖ βλέπεις, Σάμος ὀνομάζεται.",
        ]),
      );

      for (final p in pronouns.all) {
        for (final example in p.examples) {
          expect(example.german, isNotEmpty);
        }
      }
    });

    test("Auswahlbeschriftungen sind eindeutig und trennen τίς und τις", () {
      final labels = pronouns.all.map((p) => p.label).toList();

      expect(labels.toSet().length, labels.length);
      expect(paradigm("τίς").label, isNot(paradigm("τις").label));
      expect(pronouns.byLabel(paradigm("τις").label)!.id, idOf("τις"));
      expect(pronouns.byLabel(null), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // MÖGLICHE BESTIMMUNGEN
  // ---------------------------------------------------------------------------

  group("Mögliche Bestimmungen einer Form", () {
    test("eindeutige Formen", () {
      expect(analyses("αὕτη"), {"οὗτος Nominativ Sg f"});
      expect(analyses("ἡμεῖς"), {"ἐγώ Nominativ Pl –"});
      expect(analyses("μου"), {"ἐγώ Genitiv Sg –"});
      expect(analyses("τούτους"), {"οὗτος Akkusativ Pl m"});
    });

    test("Genitiv und Dativ Singular: Maskulinum = Neutrum", () {
      expect(analyses("τούτου"), {"οὗτος Genitiv Sg m", "οὗτος Genitiv Sg n"});
      expect(analyses("ᾧ"), {"ὅς Dativ Sg m", "ὅς Dativ Sg n"});
    });

    test("Neutrum: Nominativ = Akkusativ", () {
      expect(analyses("τοῦτο"), {
        "οὗτος Nominativ Sg n",
        "οὗτος Akkusativ Sg n",
      });
      expect(analyses("ταῦτα"), {
        "οὗτος Nominativ Pl n",
        "οὗτος Akkusativ Pl n",
      });
    });

    test("Genitiv Plural über alle Genera, Dativ Plural m = n", () {
      expect(analyses("ἐκείνων"), {
        "ἐκεῖνος Genitiv Pl m",
        "ἐκεῖνος Genitiv Pl f",
        "ἐκεῖνος Genitiv Pl n",
      });
      expect(analyses("αὐτοῖς"), {"αὐτός Dativ Pl m", "αὐτός Dativ Pl n"});
    });

    test("τίνα: über Numerus und Genus mehrdeutig", () {
      expect(analyses("τίνα"), {
        "τίς Akkusativ Sg m",
        "τίς Akkusativ Sg f",
        "τίς Nominativ Pl n",
        "τίς Akkusativ Pl n",
      });
    });

    test("τίς und τις bleiben getrennt", () {
      expect(analyses("τίς"), {"τίς Nominativ Sg m", "τίς Nominativ Sg f"});
      expect(analyses("τις"), {"τις Nominativ Sg m", "τις Nominativ Sg f"});
      expect(analyses("τινα").every((a) => a.startsWith("τις ")), isTrue);
      expect(analyses("τίνα").every((a) => a.startsWith("τίς ")), isTrue);
    });

    test("Formvarianten haben dieselben Bestimmungen", () {
      expect(analyses("τίσιν"), analyses("τίσι"));
      expect(analyses("τίσι"), {
        "τίς Dativ Pl m",
        "τίς Dativ Pl f",
        "τίς Dativ Pl n",
      });
      expect(analyses("με"), analyses("ἐμέ"));
    });

    test("Homographen über Pronomen hinweg", () {
      expect(analyses("ἐμοῦ"), {
        "ἐγώ Genitiv Sg –",
        "ἐμός Genitiv Sg m",
        "ἐμός Genitiv Sg n",
      });
      expect(analyses("σοί"), {"σύ Dativ Sg –", "σός Nominativ Pl m"});
      // Die enklitische Form gehört nur zum Personalpronomen.
      expect(analyses("σοι"), {"σύ Dativ Sg –"});
    });

    test("Akzent und Spiritus unterscheiden Formen", () {
      expect(analyses("αὐτή"), {"αὐτός Nominativ Sg f"});
      expect(analyses("αὗται"), {"οὗτος Nominativ Pl f"});
      expect(analyses("αὐταί"), {"αὐτός Nominativ Pl f"});
      expect(analyses("ἥ"), {"ὅς Nominativ Sg f"});
      expect(analyses("ᾗ"), {"ὅς Dativ Sg f"});

      // Artikel und andere Wörter sind keine Pronominalformen.
      for (final other in ["ὁ", "ἡ", "ἤ", "οἱ", "ἦν", "ἦς", "αυτη"]) {
        expect(pronouns.analysesOf(other), isEmpty, reason: other);
      }
    });

    test("Verwechslungsgefahren", () {
      expect(pronouns.lookalikesOf("αὕτη"), ["αὐτή (αὐτός)"]);
      expect(pronouns.lookalikesOf("αὐταί"), ["αὗται (οὗτος)"]);
      expect(pronouns.lookalikesOf("τίνα"), ["τινα (τις)"]);
      expect(pronouns.lookalikesOf("ὅ"), ["ὁ (Artikel)"]);
      // Das Iota subscriptum ist ein Buchstabe: ᾗ ist keine Akzentvariante.
      expect(pronouns.lookalikesOf("ἥ"), ["ἡ (Artikel)", "ἤ (oder)"]);
      expect(pronouns.lookalikesOf("αὐτή"), ["αὕτη (οὗτος)"]);
      expect(pronouns.lookalikesOf("ἥν"), ["ἦν (er war)"]);
      expect(pronouns.lookalikesOf("ἡμετέρα"), ["ἡμέτερα (ἡμέτερος)"]);

      // Die betonte Form desselben Pronomens ist keine Verwechslung, der
      // gleichlautende Genitiv des Possessivpronomens schon.
      expect(pronouns.lookalikesOf("σου"), ["σοῦ (σός)"]);
      expect(pronouns.lookalikesOf("τούτους"), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ANTWORTPRÜFUNG
  // ---------------------------------------------------------------------------

  group("Antwortprüfung", () {
    PronounAnswerResult check(
      String form, {
      required String targetLemma,
      required String targetCase,
      required String targetNumber,
      required String? targetGender,
      String? pronoun,
      String? grammaticalCase,
      String? number,
      String? gender,
      bool pronounAsked = true,
    }) {
      final PronounFormAnalysis target = (
        pronounId: idOf(targetLemma),
        grammaticalCase: targetCase,
        number: targetNumber,
        gender: targetGender,
      );

      // Die Zielbestimmung muss eine Bestimmung der Form sein.
      expect(pronouns.analysesOf(form), contains(target));

      return checkPronounAnswer(
        target: target,
        analyses: pronouns.analysesOf(form),
        pronounAsked: pronounAsked,
        userPronoun: pronoun == null ? null : idOf(pronoun),
        userCase: grammaticalCase,
        userNumber: number,
        userGender: gender,
      );
    }

    bool allCorrect(PronounAnswerResult result) {
      return result.pronounCorrect &&
          result.caseCorrect &&
          result.numberCorrect &&
          result.genderCorrect;
    }

    test("eindeutige Form: Zielbestimmung ist richtig", () {
      final result = check(
        "αὕτη",
        targetLemma: "οὗτος",
        targetCase: "Nominativ",
        targetNumber: "Sg",
        targetGender: "f",
        pronoun: "οὗτος",
        grammaticalCase: "Nominativ",
        number: "Sg.",
        gender: "f",
      );

      expect(allCorrect(result), isTrue);
    });

    test("eindeutige Form: Fehler werden einzeln gewertet", () {
      final result = check(
        "αὕτη",
        targetLemma: "οὗτος",
        targetCase: "Nominativ",
        targetNumber: "Sg",
        targetGender: "f",
        pronoun: "αὐτός",
        grammaticalCase: "Nominativ",
        number: "Pl.",
        gender: "f",
      );

      expect(result.pronounCorrect, isFalse);
      expect(result.caseCorrect, isTrue);
      expect(result.numberCorrect, isFalse);
      expect(result.genderCorrect, isTrue);
    });

    test("mehrdeutige Form: jede mögliche Bestimmung ist richtig", () {
      for (final gender in ["m", "n"]) {
        final result = check(
          "τούτου",
          targetLemma: "οὗτος",
          targetCase: "Genitiv",
          targetNumber: "Sg",
          targetGender: "m",
          pronoun: "οὗτος",
          grammaticalCase: "Genitiv",
          number: "Sg.",
          gender: gender,
        );

        expect(allCorrect(result), isTrue, reason: gender);
        expect(result.reference.gender, gender);
      }

      for (final grammaticalCase in ["Nominativ", "Akkusativ"]) {
        final result = check(
          "ταῦτα",
          targetLemma: "οὗτος",
          targetCase: "Akkusativ",
          targetNumber: "Pl",
          targetGender: "n",
          pronoun: "οὗτος",
          grammaticalCase: grammaticalCase,
          number: "Pl.",
          gender: "n",
        );

        expect(allCorrect(result), isTrue, reason: grammaticalCase);
      }
    });

    test("mehrdeutige Form: nicht mögliche Bestimmung bleibt falsch", () {
      final result = check(
        "τούτου",
        targetLemma: "οὗτος",
        targetCase: "Genitiv",
        targetNumber: "Sg",
        targetGender: "m",
        pronoun: "οὗτος",
        grammaticalCase: "Genitiv",
        number: "Sg.",
        gender: "f",
      );

      expect(result.genderCorrect, isFalse);
      expect(result.caseCorrect, isTrue);
      expect(result.numberCorrect, isTrue);
      expect(result.pronounCorrect, isTrue);
    });

    test("τίνα: alle vier Bestimmungen, aber keine Mischung", () {
      const possible = [
        ("Akkusativ", "Sg.", "m"),
        ("Akkusativ", "Sg.", "f"),
        ("Nominativ", "Pl.", "n"),
        ("Akkusativ", "Pl.", "n"),
      ];

      for (final (grammaticalCase, number, gender) in possible) {
        final result = check(
          "τίνα",
          targetLemma: "τίς",
          targetCase: "Akkusativ",
          targetNumber: "Sg",
          targetGender: "m",
          pronoun: "τίς",
          grammaticalCase: grammaticalCase,
          number: number,
          gender: gender,
        );

        expect(allCorrect(result), isTrue, reason: "$grammaticalCase $number");
      }

      // Akkusativ Plural Maskulinum mischt zwei mögliche Bestimmungen.
      final mixed = check(
        "τίνα",
        targetLemma: "τίς",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronoun: "τίς",
        grammaticalCase: "Akkusativ",
        number: "Pl.",
        gender: "m",
      );

      expect(allCorrect(mixed), isFalse);
      // Gleichstand: gewertet wird gegen die Zielbestimmung.
      expect(mixed.numberCorrect, isFalse);
      expect(mixed.genderCorrect, isTrue);

      // Nominativ Singular ist für τίνα nicht möglich.
      final wrong = check(
        "τίνα",
        targetLemma: "τίς",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronoun: "τίς",
        grammaticalCase: "Nominativ",
        number: "Sg.",
        gender: "m",
      );

      expect(wrong.caseCorrect, isFalse);
    });

    test("Einzelwertung folgt der nächstliegenden Bestimmung", () {
      // Ziel ist Akk. Sg. m; die Antwort meint erkennbar den Plural Neutrum
      // und irrt nur im Kasus.
      final result = check(
        "τίνα",
        targetLemma: "τίς",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronoun: "τίς",
        grammaticalCase: "Dativ",
        number: "Pl.",
        gender: "n",
      );

      expect(result.caseCorrect, isFalse);
      expect(result.numberCorrect, isTrue);
      expect(result.genderCorrect, isTrue);
      expect(result.reference.number, "Pl");
    });

    test("τίς und τις werden nicht gleichgesetzt", () {
      final result = check(
        "τίνα",
        targetLemma: "τίς",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronoun: "τις",
        grammaticalCase: "Akkusativ",
        number: "Sg.",
        gender: "m",
      );

      expect(result.pronounCorrect, isFalse);
      expect(result.caseCorrect, isTrue);

      final indefinite = check(
        "τινα",
        targetLemma: "τις",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: "f",
        pronoun: "τις",
        grammaticalCase: "Nominativ",
        number: "Pl.",
        gender: "n",
      );

      expect(allCorrect(indefinite), isTrue);
    });

    test("Enklitika: gleiche Bestimmung wie die betonte Form, kein Genus", () {
      for (final form in ["ἐμέ", "με"]) {
        final result = check(
          form,
          targetLemma: "ἐγώ",
          targetCase: "Akkusativ",
          targetNumber: "Sg",
          targetGender: null,
          pronoun: "ἐγώ",
          grammaticalCase: "Akkusativ",
          number: "Sg.",
          gender: GrammarQuestionPicker.noGender,
        );

        expect(allCorrect(result), isTrue, reason: form);
      }

      final withGender = check(
        "με",
        targetLemma: "ἐγώ",
        targetCase: "Akkusativ",
        targetNumber: "Sg",
        targetGender: null,
        pronoun: "ἐγώ",
        grammaticalCase: "Akkusativ",
        number: "Sg.",
        gender: "m",
      );

      expect(withGender.genderCorrect, isFalse);
      expect(allCorrect(withGender), isFalse);
    });

    test("Formvarianten τίσι / τίσιν", () {
      for (final form in ["τίσι", "τίσιν"]) {
        for (final gender in _genders) {
          final result = check(
            form,
            targetLemma: "τίς",
            targetCase: "Dativ",
            targetNumber: "Pl",
            targetGender: "n",
            pronoun: "τίς",
            grammaticalCase: "Dativ",
            number: "Pl.",
            gender: gender,
          );

          expect(allCorrect(result), isTrue, reason: "$form $gender");
        }
      }
    });

    test("Homograph ἐμοῦ: Personal- und Possessivpronomen", () {
      final personal = check(
        "ἐμοῦ",
        targetLemma: "ἐμός",
        targetCase: "Genitiv",
        targetNumber: "Sg",
        targetGender: "n",
        pronoun: "ἐγώ",
        grammaticalCase: "Genitiv",
        number: "Sg.",
        gender: GrammarQuestionPicker.noGender,
      );

      expect(allCorrect(personal), isTrue);
      expect(personal.reference.pronounId, idOf("ἐγώ"));

      final possessive = check(
        "ἐμοῦ",
        targetLemma: "ἐγώ",
        targetCase: "Genitiv",
        targetNumber: "Sg",
        targetGender: null,
        pronoun: "ἐμός",
        grammaticalCase: "Genitiv",
        number: "Sg.",
        gender: "m",
      );

      expect(allCorrect(possessive), isTrue);

      // ἐγώ hat kein Genus, ἐμός keinen genuslosen Genitiv.
      final mixed = check(
        "ἐμοῦ",
        targetLemma: "ἐγώ",
        targetCase: "Genitiv",
        targetNumber: "Sg",
        targetGender: null,
        pronoun: "ἐγώ",
        grammaticalCase: "Genitiv",
        number: "Sg.",
        gender: "m",
      );

      expect(allCorrect(mixed), isFalse);
    });

    test("fehlende Auswahl ist falsch", () {
      final result = check(
        "ἡμεῖς",
        targetLemma: "ἐγώ",
        targetCase: "Nominativ",
        targetNumber: "Pl",
        targetGender: null,
      );

      expect(result.pronounCorrect, isFalse);
      expect(result.caseCorrect, isFalse);
      expect(result.numberCorrect, isFalse);
      expect(result.genderCorrect, isFalse);
    });

    test("ohne Abfrage des Pronomens zählt nur die Bestimmung", () {
      final result = check(
        "αὐτῷ",
        targetLemma: "αὐτός",
        targetCase: "Dativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronounAsked: false,
        grammaticalCase: "Dativ",
        number: "Sg.",
        gender: "n",
      );

      expect(allCorrect(result), isTrue);

      final wrong = check(
        "αὐτῷ",
        targetLemma: "αὐτός",
        targetCase: "Dativ",
        targetNumber: "Sg",
        targetGender: "m",
        pronounAsked: false,
        grammaticalCase: "Genitiv",
        number: "Sg.",
        gender: "m",
      );

      expect(wrong.caseCorrect, isFalse);
    });

    test("jede Form jedes Paradigmas ist mit ihrer Bestimmung lösbar", () {
      for (final p in pronouns.all) {
        for (final cell in p.cells) {
          for (final form in cell.forms) {
            final result = checkPronounAnswer(
              target: (
                pronounId: p.id,
                grammaticalCase: cell.grammaticalCase,
                number: cell.number,
                gender: cell.gender,
              ),
              analyses: pronouns.analysesOf(form.text),
              pronounAsked: true,
              userPronoun: p.id,
              userCase: cell.grammaticalCase,
              userNumber: "${cell.number}.",
              userGender: cell.gender ?? GrammarQuestionPicker.noGender,
            );

            expect(allCorrect(result), isTrue, reason: form.text);
          }
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // FRAGEGENERIERUNG
  // ---------------------------------------------------------------------------

  group("Fragegenerierung", () {
    GreekVocabularyEntry entry(
      int id,
      String lemma, {
      String type = "noun",
      int step = 1,
    }) {
      return GreekVocabularyEntry(
        id: id,
        step: step,
        type: type,
        lemma: lemma,
        translations: const ["x"],
      );
    }

    final pronounEntries = vocabulary
        .where((e) => e.type == "pronoun")
        .toList();
    final pronounIds = {for (final p in pronouns.all) p.id};

    test("Wortarten und Genus-Auswahl", () {
      expect(GrammarQuestionPicker.types, ["noun", "verb", "pronoun"]);
      expect(GrammarQuestionPicker.pronounGenders, ["m", "f", "n", "–"]);
      // Die Auswahl der Nomen bleibt unverändert.
      expect(GrammarQuestionPicker.genders, ["m", "f", "n"]);
    });

    test("Zielbestimmung: jede Zelle und jede Variante kommt vor", () {
      final grammar = GrammarLearning(random: Random(1));
      final random = Random(2);
      final ego = paradigm("ἐγώ");

      final forms = <String>{};

      for (var i = 0; i < 600; i++) {
        final target = GrammarQuestionPicker.pickPronounTarget(
          grammar,
          ego,
          random,
        )!;

        expect(target.gender, GrammarQuestionPicker.noGender);
        expect(GrammarQuestionPicker.cases, contains(target.grammaticalCase));
        expect(GrammarQuestionPicker.numbers, contains(target.number));

        final cell = ego.cell(
          target.grammaticalCase,
          GrammarQuestionPicker.nounRequestNumber(target.number),
          null,
        )!;

        expect(cell.forms.map((f) => f.text), contains(target.form));

        forms.add(target.form);
      }

      expect(forms.length, 11);
      expect(forms, containsAll(["ἐμοῦ", "μου", "ἡμᾶς"]));
    });

    test("Zielbestimmung: Genus aus dem Paradigma", () {
      final grammar = GrammarLearning(random: Random(1));
      final random = Random(2);
      final houtos = paradigm("οὗτος");

      final seen = <String>{};

      for (var i = 0; i < 1500; i++) {
        final target = GrammarQuestionPicker.pickPronounTarget(
          grammar,
          houtos,
          random,
        )!;

        expect(_genders, contains(target.gender));

        expect(
          pronouns.analysesOf(target.form),
          contains((
            pronounId: houtos.id,
            grammaticalCase: target.grammaticalCase,
            number: GrammarQuestionPicker.nounRequestNumber(target.number),
            gender: target.gender,
          )),
        );

        seen.add("${target.grammaticalCase} ${target.number} ${target.gender}");
      }

      expect(seen.length, 24);
    });

    test(
      "unvollständiges Paradigma ergibt keine Frage statt eines Fehlers",
      () {
        const broken = PronounParadigm(
          id: 1,
          lemma: "x",
          label: "x",
          kind: "personal",
          usage: [],
          examples: [],
          lookalikes: {},
          cells: [],
        );

        expect(
          GrammarQuestionPicker.pickPronounTarget(
            GrammarLearning(random: Random(1)),
            broken,
            Random(1),
          ),
          isNull,
        );
      },
    );

    test("Pronomen lassen sich über die Wortart ein- und ausschalten", () {
      bool available(List<String> types, {List<int> steps = const [1]}) {
        return GrammarQuestionPicker.isAvailable(
          pronounEntries.first,
          enabledSteps: steps,
          enabledTypes: types,
          pronounIds: pronounIds,
        );
      }

      expect(available(["noun", "verb", "pronoun"]), isTrue);
      expect(available(["pronoun"]), isTrue);
      expect(available(["noun", "verb"]), isFalse);

      // Pronomen hängen nicht an den Schritten.
      expect(available(["pronoun"], steps: []), isTrue);
      expect(available(["pronoun"], steps: [7]), isTrue);
    });

    test("ohne Paradigma wird ein Pronomen nicht gefragt", () {
      expect(
        GrammarQuestionPicker.isAvailable(
          pronounEntries.first,
          enabledSteps: const [1, 2, 3, 4, 5, 6, 7],
          enabledTypes: GrammarQuestionPicker.types,
          pronounIds: const {},
        ),
        isFalse,
      );
    });

    test("Nomen und Verben: Schritte, Wortart und Blacklist wie bisher", () {
      bool available(
        GreekVocabularyEntry e, {
        List<int> steps = const [1],
        List<String> types = const ["noun", "verb"],
      }) {
        return GrammarQuestionPicker.isAvailable(
          e,
          enabledSteps: steps,
          enabledTypes: types,
          pronounIds: pronounIds,
        );
      }

      expect(available(entry(1, "λόγος")), isTrue);
      expect(available(entry(1, "λόγος", step: 2)), isFalse);
      expect(available(entry(1, "λόγος"), types: ["verb", "pronoun"]), isFalse);
      expect(available(entry(1, "οἶδα", type: "verb")), isFalse);
      expect(available(entry(1, "καλός", type: "adjective")), isFalse);
    });

    test("alle 13 Pronomen der Vokabelliste sind im Trainer verfügbar", () {
      final available = vocabulary.where((e) {
        return GrammarQuestionPicker.isAvailable(
          e,
          enabledSteps: const [],
          enabledTypes: const ["pronoun"],
          pronounIds: pronounIds,
        );
      }).toList();

      expect(available.length, 13);
    });
  });

  // ---------------------------------------------------------------------------
  // LERNSYSTEM
  // ---------------------------------------------------------------------------

  group("Lernsystem", () {
    GreekVocabularyEntry entry(int id, String lemma, String type) {
      return GreekVocabularyEntry(
        id: id,
        step: 1,
        type: type,
        lemma: lemma,
        translations: const ["x"],
      );
    }

    final nouns = [for (var i = 0; i < 20; i++) entry(i, "wort$i", "noun")];
    final eimi = entry(100, "εἰμί", "verb");
    final sheet = [entry(101, "βλέπω", "verb"), entry(102, "γράφω", "verb")];
    final pronounEntries = [
      for (var i = 0; i < 13; i++) entry(200 + i, "pron$i", "pronoun"),
    ];

    Map<String, int> typeCounts(
      List<GreekVocabularyEntry> available, {
      GrammarLearning? grammar,
    }) {
      final learning = grammar ?? GrammarLearning(random: Random(3));
      final result = <String, int>{};

      for (var i = 0; i < 8000; i++) {
        final picked = GrammarQuestionPicker.pickEntry(learning, available);
        final key = picked.type == "pronoun" ? "pronoun" : picked.lemma;

        result[key] = (result[key] ?? 0) + 1;
      }

      return result;
    }

    test("Pronomen bilden eine eigene, gleich gewichtete Gruppe", () {
      final all = [...nouns, eimi, ...sheet, ...pronounEntries];
      final result = typeCounts(all);

      // Vier Gruppen zu je 1/4; dazu der Anteil an der Gesamtliste (36).
      expect(result["pronoun"]! / 8000, closeTo(1 / 4 + 13 / 144, 0.03));
      expect(result["εἰμί"]! / 8000, closeTo(1 / 4 + 1 / 144, 0.03));

      final sheetCount = result["βλέπω"]! + result["γράφω"]!;

      expect(sheetCount / 8000, closeTo(1 / 4 + 2 / 144, 0.03));
    });

    test("nur Nomen und Pronomen: je zur Hälfte Gruppe und Gesamtliste", () {
      final result = typeCounts([...nouns, ...pronounEntries]);

      expect(result["pronoun"]! / 8000, closeTo(1 / 2 + 13 / 66, 0.03));
    });

    test("ohne Pronomen bleibt die Auswahl wie bisher", () {
      final result = typeCounts([...nouns, eimi, ...sheet]);

      expect(result.containsKey("pronoun"), isFalse);
      expect(result["εἰμί"]! / 8000, closeTo(1 / 3 + 1 / 69, 0.03));
    });

    test("nur Pronomen: alle kommen vor", () {
      final grammar = GrammarLearning(random: Random(3));
      final picked = <String>{};

      for (var i = 0; i < 2000; i++) {
        picked.add(
          GrammarQuestionPicker.pickEntry(grammar, pronounEntries).lemma,
        );
      }

      expect(picked.length, 13);
    });

    test("ein schwaches Pronomen kommt häufiger", () {
      final weak = pronounEntries.first;

      final grammar = GrammarLearning(
        random: Random(3),
        cards: {
          GrammarLearning.lemmaId(weak.id): LearningCard(
            id: GrammarLearning.lemmaId(weak.id),
            difficulty: 10,
            lastReviewed: DateTime.now(),
          ),
        },
      );

      var weakCount = 0;
      var otherCount = 0;

      for (var i = 0; i < 6000; i++) {
        final picked = GrammarQuestionPicker.pickEntry(grammar, pronounEntries);

        if (picked == weak) weakCount++;
        if (picked == pronounEntries[1]) otherCount++;
      }

      expect(weakCount, greaterThan(otherCount * 1.5));
    });

    test(
      "Fehler im Kasus erhöhen den Lernbedarf dieses Kasus bei Pronomen",
      () {
        final grammar = GrammarLearning(random: Random(5));
        final dative = GrammarLearning.dimensionId("pronoun", "case", "Dativ");

        for (var i = 0; i < 5; i++) {
          grammar.record({dative: false});
        }

        expect(grammar.need(dative), 2.0);

        // Eigene Karten: die Nomen sind davon nicht betroffen.
        expect(
          grammar.need(GrammarLearning.dimensionId("noun", "case", "Dativ")),
          1,
        );

        final random = Random(6);
        final counts = <String, int>{};

        for (var i = 0; i < 4000; i++) {
          final target = GrammarQuestionPicker.pickPronounTarget(
            grammar,
            paradigm("οὗτος"),
            random,
          )!;

          counts[target.grammaticalCase] =
              (counts[target.grammaticalCase] ?? 0) + 1;
        }

        // Lernbedarf 2 gegen dreimal 1: zwei Fünftel statt eines Viertels.
        expect(counts["Dativ"]! / 4000, closeTo(2 / 5, 0.04));
      },
    );

    test("Karten-IDs von Auswahl und Verbuchung stimmen überein", () {
      // Ausgewählt wird mit "Sg.", verbucht mit "Sg" aus der Bestimmung.
      expect(
        GrammarLearning.dimensionId("pronoun", "number", "Sg."),
        GrammarLearning.dimensionId("pronoun", "number", "Sg"),
      );
      expect(
        GrammarLearning.dimensionId("pronoun", "gender", "f"),
        "dim.pronoun.gender.f",
      );
    });
  });

  // ---------------------------------------------------------------------------
  // DARSTELLUNG
  // ---------------------------------------------------------------------------

  group("Formentabelle", () {
    Future<void> pump(WidgetTester tester, String lemma) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PronounParadigmView(paradigm: paradigm(lemma)),
            ),
          ),
        ),
      );
    }

    testWidgets("dreigeschlechtiges Pronomen mit Gebrauch und Beispielen", (
      tester,
    ) async {
      await pump(tester, "οὗτος");

      expect(find.text("Demonstrativpronomen"), findsOneWidget);
      expect(find.text("αὕτη"), findsOneWidget);
      expect(find.text("ταῦτα"), findsNWidgets(2));
      expect(find.text("τούτων"), findsNWidgets(3));
      expect(find.text("Gebrauch"), findsOneWidget);
      expect(find.text("Beispiele"), findsOneWidget);
      expect(find.text("αὕτη ἡ νῆσος καλή ἐστιν."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Personalpronomen zeigt betonte und enklitische Form", (
      tester,
    ) async {
      await pump(tester, "ἐγώ");

      expect(find.text("Personalpronomen"), findsOneWidget);
      expect(find.text("ἐμοῦ / μου"), findsOneWidget);
      expect(find.text("ἡμεῖς"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
