import 'package:flutter_test/flutter_test.dart';

import 'package:theologie_lernapp/services/latin/grammar/latin_grammar_words.dart';
import 'package:theologie_lernapp/services/latin/grammar/latin_morphology.dart';

LatinNoun _noun(String id) =>
    LatinGrammarWords.nouns.firstWhere((noun) => noun.id == id);

LatinVerb _verb(String id) =>
    LatinGrammarWords.verbs.firstWhere((verb) => verb.id == id);

LatinAdjective _adjective(String id) =>
    LatinGrammarWords.adjectives.firstWhere((adj) => adj.id == id);

LatinPronoun _pronoun(String id) =>
    LatinGrammarWords.pronouns.firstWhere((p) => p.id == id);

/// Hauptformen in der Reihenfolge Nom., Gen., Dat., Akk., Abl., Vok.
List<String> _column(Paradigm<NominalAnalysis> p, String number, [String? g]) {
  return [
    for (final c in LatinCases.all)
      p.mainForm(NominalAnalysis(c, number, g)) ?? "–",
  ];
}

List<String> _persons(
  LatinVerb verb,
  String mood,
  String tense, [
  String voice = LatinVoices.active,
]) {
  final p = verb.paradigm();
  return [
    for (final person in LatinPersons.all)
      p.mainForm(VerbAnalysis(mood, tense, voice, person)) ?? "–",
  ];
}

const _ind = LatinMoods.indicative;
const _konj = LatinMoods.subjunctive;
const _pass = LatinVoices.passive;

void main() {
  group("Substantive", () {
    test("a-Deklination", () {
      final p = _noun("domina").paradigm();

      expect(_column(p, LatinNumbers.singular), [
        "domina",
        "dominae",
        "dominae",
        "dominam",
        "dominā",
        "domina",
      ]);
      expect(_column(p, LatinNumbers.plural), [
        "dominae",
        "dominārum",
        "dominīs",
        "dominās",
        "dominīs",
        "dominae",
      ]);
    });

    test("o-Deklination auf -us, -er, -ius und -um", () {
      expect(_column(_noun("dominus").paradigm(), LatinNumbers.singular), [
        "dominus",
        "dominī",
        "dominō",
        "dominum",
        "dominō",
        "domine",
      ]);
      expect(_column(_noun("dominus").paradigm(), LatinNumbers.plural), [
        "dominī",
        "dominōrum",
        "dominīs",
        "dominōs",
        "dominīs",
        "dominī",
      ]);
      expect(_column(_noun("ager").paradigm(), LatinNumbers.singular), [
        "ager",
        "agrī",
        "agrō",
        "agrum",
        "agrō",
        "ager",
      ]);
      expect(
        _column(_noun("puer").paradigm(), LatinNumbers.plural).first,
        "puerī",
      );
      expect(
        _noun("filius").paradigm().mainForm(
          const NominalAnalysis(LatinCases.vocative, LatinNumbers.singular),
        ),
        "fīlī",
      );
      expect(_column(_noun("forum").paradigm(), LatinNumbers.plural), [
        "fora",
        "forōrum",
        "forīs",
        "fora",
        "forīs",
        "fora",
      ]);
      expect(
        _noun("consilium").paradigm().mainForm(
          const NominalAnalysis(LatinCases.genitive, LatinNumbers.singular),
        ),
        "cōnsiliī",
      );
    });

    test("3. Deklination (konsonantisch, Neutrum, Mischdeklination)", () {
      expect(_column(_noun("victor").paradigm(), LatinNumbers.singular), [
        "victor",
        "victōris",
        "victōrī",
        "victōrem",
        "victōre",
        "victor",
      ]);
      expect(_column(_noun("victor").paradigm(), LatinNumbers.plural), [
        "victōrēs",
        "victōrum",
        "victōribus",
        "victōrēs",
        "victōribus",
        "victōrēs",
      ]);
      expect(_column(_noun("nomen").paradigm(), LatinNumbers.singular), [
        "nōmen",
        "nōminis",
        "nōminī",
        "nōmen",
        "nōmine",
        "nōmen",
      ]);
      expect(
        _column(_noun("nomen").paradigm(), LatinNumbers.plural)[0],
        "nōmina",
      );
      expect(
        _column(_noun("urbs").paradigm(), LatinNumbers.plural)[1],
        "urbium",
      );
      expect(
        _column(_noun("rex").paradigm(), LatinNumbers.singular)[1],
        "rēgis",
      );
    });

    test("u- und e-Deklination", () {
      expect(_column(_noun("senatus").paradigm(), LatinNumbers.singular), [
        "senātus",
        "senātūs",
        "senātuī",
        "senātum",
        "senātū",
        "senātus",
      ]);
      expect(
        _column(_noun("senatus").paradigm(), LatinNumbers.plural)[1],
        "senātuum",
      );
      expect(_column(_noun("res").paradigm(), LatinNumbers.singular), [
        "rēs",
        "reī",
        "reī",
        "rem",
        "rē",
        "rēs",
      ]);
      expect(
        _column(_noun("dies").paradigm(), LatinNumbers.singular)[1],
        "diēī",
      );
      expect(_column(_noun("res").paradigm(), LatinNumbers.plural), [
        "rēs",
        "rērum",
        "rēbus",
        "rēs",
        "rēbus",
        "rēs",
      ]);
    });

    test("formgleiche Kasus werden alle erkannt", () {
      final p = _noun("servus").paradigm();

      expect(p.analysesOf("servī").toSet(), {
        const NominalAnalysis(LatinCases.genitive, LatinNumbers.singular),
        const NominalAnalysis(LatinCases.nominative, LatinNumbers.plural),
        const NominalAnalysis(LatinCases.vocative, LatinNumbers.plural),
      });

      // Längenzeichen unterscheiden: domina (Nom./Vok.) – dominā (Abl.)
      final a = _noun("domina").paradigm();
      expect(a.analysesOf("dominā"), [
        const NominalAnalysis(LatinCases.ablative, LatinNumbers.singular),
      ]);
    });

    test("Vokabelwörter verweisen auf passende Einträge", () {
      for (final noun in LatinGrammarWords.nouns) {
        // Stamm muss sich aus dem Genitiv bilden lassen.
        expect(() => noun.stem, returnsNormally, reason: noun.lemma);
      }
    });
  });

  group("Adjektive", () {
    test("a/o-Deklination mit drei Endungen", () {
      final p = _adjective("bonus").paradigm();

      expect(_column(p, LatinNumbers.singular, LatinGenders.masculine), [
        "bonus",
        "bonī",
        "bonō",
        "bonum",
        "bonō",
        "bone",
      ]);
      expect(_column(p, LatinNumbers.plural, LatinGenders.feminine), [
        "bonae",
        "bonārum",
        "bonīs",
        "bonās",
        "bonīs",
        "bonae",
      ]);
      expect(_column(p, LatinNumbers.plural, LatinGenders.neuter)[0], "bona");

      final pulcher = _adjective("pulcher").paradigm();
      expect(_column(pulcher, LatinNumbers.singular, LatinGenders.masculine), [
        "pulcher",
        "pulchrī",
        "pulchrō",
        "pulchrum",
        "pulchrō",
        "pulcher",
      ]);
      expect(
        _column(
          _adjective("miser").paradigm(),
          LatinNumbers.singular,
          LatinGenders.masculine,
        )[1],
        "miserī",
      );
    });

    test("3. Deklination: Ablativ -ī, Neutrum Plural -ia, Genitiv -ium", () {
      final p = _adjective("fortis").paradigm();

      expect(_column(p, LatinNumbers.singular, LatinGenders.masculine), [
        "fortis",
        "fortis",
        "fortī",
        "fortem",
        "fortī",
        "fortis",
      ]);
      expect(_column(p, LatinNumbers.plural, LatinGenders.neuter), [
        "fortia",
        "fortium",
        "fortibus",
        "fortia",
        "fortibus",
        "fortia",
      ]);

      final felix = _adjective("felix").paradigm();
      expect(_column(felix, LatinNumbers.singular, LatinGenders.neuter), [
        "fēlīx",
        "fēlīcis",
        "fēlīcī",
        "fēlīx",
        "fēlīcī",
        "fēlīx",
      ]);
      expect(
        _column(felix, LatinNumbers.singular, LatinGenders.feminine)[3],
        "fēlīcem",
      );
    });
  });

  group("Pronomen", () {
    test("is, ea, id mit Nebenformen", () {
      final p = _pronoun("is").paradigm();

      expect(
        p.formsOf(
          const NominalAnalysis(
            LatinCases.dative,
            LatinNumbers.plural,
            LatinGenders.feminine,
          ),
        ),
        ["eīs", "iīs"],
      );
      // eī: Dativ Sg. (alle Genera) und Nominativ Pl. m.
      expect(p.analysesOf("eī"), hasLength(4));
    });

    test("Personalpronomen ohne Genus", () {
      final p = _pronoun("ego").paradigm();

      expect(p.analysesOf("mē").toSet(), {
        const NominalAnalysis(LatinCases.accusative, LatinNumbers.singular),
        const NominalAnalysis(LatinCases.ablative, LatinNumbers.singular),
      });
      expect(
        p.formsOf(
          const NominalAnalysis(LatinCases.genitive, LatinNumbers.plural),
        ),
        ["nostrī", "nostrum"],
      );
    });

    test("Reflexivpronomen hat keinen Nominativ", () {
      final p = _pronoun("se").paradigm();

      expect(
        p.formsOf(
          const NominalAnalysis(LatinCases.nominative, LatinNumbers.singular),
        ),
        isEmpty,
      );
    });
  });

  group("Verben: Präsensstamm", () {
    test("Präsens Aktiv aller Konjugationen", () {
      expect(_persons(_verb("amare"), _ind, LatinTenses.present), [
        "amō",
        "amās",
        "amat",
        "amāmus",
        "amātis",
        "amant",
      ]);
      expect(_persons(_verb("monere"), _ind, LatinTenses.present), [
        "moneō",
        "monēs",
        "monet",
        "monēmus",
        "monētis",
        "monent",
      ]);
      expect(_persons(_verb("audire"), _ind, LatinTenses.present), [
        "audiō",
        "audīs",
        "audit",
        "audīmus",
        "audītis",
        "audiunt",
      ]);
      expect(_persons(_verb("mittere"), _ind, LatinTenses.present), [
        "mittō",
        "mittis",
        "mittit",
        "mittimus",
        "mittitis",
        "mittunt",
      ]);
      expect(_persons(_verb("capere"), _ind, LatinTenses.present), [
        "capiō",
        "capis",
        "capit",
        "capimus",
        "capitis",
        "capiunt",
      ]);
    });

    test("Imperfekt und Futur I", () {
      expect(_persons(_verb("amare"), _ind, LatinTenses.imperfect), [
        "amābam",
        "amābās",
        "amābat",
        "amābāmus",
        "amābātis",
        "amābant",
      ]);
      expect(
        _persons(_verb("audire"), _ind, LatinTenses.imperfect).first,
        "audiēbam",
      );
      expect(
        _persons(_verb("mittere"), _ind, LatinTenses.imperfect).first,
        "mittēbam",
      );
      expect(_persons(_verb("monere"), _ind, LatinTenses.future), [
        "monēbō",
        "monēbis",
        "monēbit",
        "monēbimus",
        "monēbitis",
        "monēbunt",
      ]);
      expect(_persons(_verb("mittere"), _ind, LatinTenses.future), [
        "mittam",
        "mittēs",
        "mittet",
        "mittēmus",
        "mittētis",
        "mittent",
      ]);
      expect(
        _persons(_verb("audire"), _ind, LatinTenses.future).first,
        "audiam",
      );
    });

    test("Passiv", () {
      expect(_persons(_verb("amare"), _ind, LatinTenses.present, _pass), [
        "amor",
        "amāris",
        "amātur",
        "amāmur",
        "amāminī",
        "amantur",
      ]);
      expect(_persons(_verb("mittere"), _ind, LatinTenses.present, _pass), [
        "mittor",
        "mitteris",
        "mittitur",
        "mittimur",
        "mittiminī",
        "mittuntur",
      ]);
      expect(
        _persons(_verb("audire"), _ind, LatinTenses.present, _pass).last,
        "audiuntur",
      );
      expect(
        _persons(_verb("amare"), _ind, LatinTenses.future, _pass)[1],
        "amāberis",
      );
      expect(
        _verb("amare").paradigm().formsOf(
          const VerbAnalysis(_ind, LatinTenses.present, _pass, "2. Sg."),
        ),
        ["amāris", "amāre"],
      );
    });

    test("Konjunktiv Präsens und Imperfekt", () {
      expect(_persons(_verb("amare"), _konj, LatinTenses.present), [
        "amem",
        "amēs",
        "amet",
        "amēmus",
        "amētis",
        "ament",
      ]);
      expect(
        _persons(_verb("monere"), _konj, LatinTenses.present).first,
        "moneam",
      );
      expect(
        _persons(_verb("mittere"), _konj, LatinTenses.present)[2],
        "mittat",
      );
      expect(_persons(_verb("audire"), _konj, LatinTenses.imperfect), [
        "audīrem",
        "audīrēs",
        "audīret",
        "audīrēmus",
        "audīrētis",
        "audīrent",
      ]);
      expect(
        _persons(_verb("mittere"), _konj, LatinTenses.imperfect, _pass).first,
        "mitterer",
      );
    });

    test("Imperativ und Infinitiv", () {
      final p = _verb("mittere").paradigm();

      expect(
        p.mainForm(
          const VerbAnalysis(
            LatinMoods.imperative,
            LatinTenses.present,
            LatinVoices.active,
            "2. Sg.",
          ),
        ),
        "mitte",
      );
      expect(
        p.mainForm(
          const VerbAnalysis(
            LatinMoods.infinitive,
            LatinTenses.present,
            LatinVoices.passive,
          ),
        ),
        "mittī",
      );
      expect(
        _verb("ducere").paradigm().mainForm(
          const VerbAnalysis(
            LatinMoods.imperative,
            LatinTenses.present,
            LatinVoices.active,
            "2. Sg.",
          ),
        ),
        "dūc",
      );
      expect(
        _verb("amare").paradigm().mainForm(
          const VerbAnalysis(
            LatinMoods.infinitive,
            LatinTenses.present,
            LatinVoices.passive,
          ),
        ),
        "amārī",
      );
    });

    test("intransitive Verben haben kein Passiv", () {
      final p = _verb("venire").paradigm();

      expect(
        p.cells.keys.where((a) => a.voice == LatinVoices.passive),
        isEmpty,
      );
    });
  });

  group("Verben: Perfektstamm", () {
    test("Perfekt, Plusquamperfekt, Futur II", () {
      expect(_persons(_verb("amare"), _ind, LatinTenses.perfect), [
        "amāvī",
        "amāvistī",
        "amāvit",
        "amāvimus",
        "amāvistis",
        "amāvērunt",
      ]);
      expect(
        _persons(_verb("videre"), _ind, LatinTenses.pluperfect).first,
        "vīderam",
      );
      expect(
        _persons(_verb("monere"), _ind, LatinTenses.futurePerfect).last,
        "monuerint",
      );
      expect(
        _persons(_verb("mittere"), _konj, LatinTenses.pluperfect)[2],
        "mīsisset",
      );
    });

    test("venit (Präsens) und vēnit (Perfekt) bleiben getrennt", () {
      final p = _verb("venire").paradigm();

      expect(p.analysesOf("venit"), [
        const VerbAnalysis(
          _ind,
          LatinTenses.present,
          LatinVoices.active,
          "3. Sg.",
        ),
      ]);
      expect(p.analysesOf("vēnit"), [
        const VerbAnalysis(
          _ind,
          LatinTenses.perfect,
          LatinVoices.active,
          "3. Sg.",
        ),
      ]);
    });

    test("ohne Perfektangabe kein Perfekt (Semideponentien)", () {
      final p = _verb("gaudere").paradigm();

      expect(
        p.cells.keys.where((a) => a.tense == LatinTenses.perfect),
        isEmpty,
      );
    });
  });

  group("unregelmäßige Verben", () {
    test("esse und adesse", () {
      expect(_persons(_verb("esse"), _ind, LatinTenses.present), [
        "sum",
        "es",
        "est",
        "sumus",
        "estis",
        "sunt",
      ]);
      expect(_persons(_verb("esse"), _ind, LatinTenses.perfect).first, "fuī");
      expect(_persons(_verb("adesse"), _ind, LatinTenses.present), [
        "adsum",
        "ades",
        "adest",
        "adsumus",
        "adestis",
        "adsunt",
      ]);
      expect(
        _persons(_verb("adesse"), _ind, LatinTenses.future).last,
        "aderunt",
      );
      expect(_persons(_verb("adesse"), _ind, LatinTenses.perfect)[2], "adfuit");
      expect(_persons(_verb("esse"), _konj, LatinTenses.present).first, "sim");
    });

    test("posse, velle, īre", () {
      expect(_persons(_verb("posse"), _ind, LatinTenses.present), [
        "possum",
        "potes",
        "potest",
        "possumus",
        "potestis",
        "possunt",
      ]);
      expect(_persons(_verb("velle"), _ind, LatinTenses.present), [
        "volō",
        "vīs",
        "vult",
        "volumus",
        "vultis",
        "volunt",
      ]);
      expect(_persons(_verb("ire"), _ind, LatinTenses.present), [
        "eō",
        "īs",
        "it",
        "īmus",
        "ītis",
        "eunt",
      ]);
      expect(_persons(_verb("ire"), _ind, LatinTenses.perfect)[1], "īstī");
      expect(
        _verb("ire").paradigm().formsOf(
          const VerbAnalysis(
            _ind,
            LatinTenses.perfect,
            LatinVoices.active,
            "2. Sg.",
          ),
        ),
        ["īstī", "iistī"],
      );
      expect(
        _verb(
          "velle",
        ).paradigm().cells.keys.where((a) => a.mood == LatinMoods.imperative),
        isEmpty,
      );
    });
  });

  group("Erklärungen", () {
    test("nennen Deklination, Endung und Stamm", () {
      final text = explainNounForm(
        _noun("dominus"),
        const NominalAnalysis(LatinCases.ablative, LatinNumbers.plural),
      );

      expect(text, contains("o-Deklination"));
      expect(text, contains("-īs"));
      expect(text, contains("dominī → domin-"));
    });

    test("nennen Tempuszeichen und Personalendung", () {
      final text = explainVerbForm(
        _verb("amare"),
        const VerbAnalysis(
          _ind,
          LatinTenses.imperfect,
          LatinVoices.active,
          "3. Pl.",
        ),
      );

      expect(text, contains("-bā-"));
      expect(text, contains("-nt"));
      expect(text, contains("amābant"));
    });
  });

  group("Wortlisten", () {
    test("IDs sind je Wortart eindeutig", () {
      for (final ids in [
        LatinGrammarWords.nouns.map((w) => w.id),
        LatinGrammarWords.verbs.map((w) => w.id),
        LatinGrammarWords.adjectives.map((w) => w.id),
        LatinGrammarWords.pronouns.map((w) => w.id),
      ]) {
        final list = ids.toList();
        expect(list.toSet(), hasLength(list.length));
      }
    });

    test("jedes Paradigma lässt sich vollständig bilden", () {
      for (final noun in LatinGrammarWords.nouns) {
        expect(noun.paradigm().cells, hasLength(12), reason: noun.lemma);
      }
      for (final adjective in LatinGrammarWords.adjectives) {
        expect(
          adjective.paradigm().cells,
          hasLength(36),
          reason: adjective.lemma,
        );
      }
      for (final verb in LatinGrammarWords.verbs) {
        final cells = verb.paradigm().cells;

        expect(cells, isNotEmpty, reason: verb.infinitive);
        expect(
          cells.values.every((forms) => forms.every((f) => f.isNotEmpty)),
          isTrue,
          reason: verb.infinitive,
        );
        expect(
          verb.paradigm().mainForm(
            const VerbAnalysis(
              _ind,
              LatinTenses.present,
              LatinVoices.active,
              "1. Sg.",
            ),
          ),
          verb.present,
          reason: verb.infinitive,
        );
        if (verb.perfect != null) {
          expect(
            verb.paradigm().mainForm(
              const VerbAnalysis(
                _ind,
                LatinTenses.perfect,
                LatinVoices.active,
                "1. Sg.",
              ),
            ),
            verb.perfect,
            reason: verb.infinitive,
          );
        }
      }
    });
  });
}
