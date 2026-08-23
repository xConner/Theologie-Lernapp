import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../services/greek/grammar/wiktionary_inflection_service.dart';
import '../../widgets/greek_keyboard.dart';

import 'package:web/web.dart' as web;
import 'dart:js_interop';

class GreekGrammarTrainerScreen extends StatefulWidget {
  const GreekGrammarTrainerScreen({super.key});

  @override
  State<GreekGrammarTrainerScreen> createState() =>
      _GreekGrammarTrainerScreenState();
}

class _GreekGrammarTrainerScreenState extends State<GreekGrammarTrainerScreen> {
  final GreekVocabularyLoader loader = GreekVocabularyLoader();

  final WiktionaryInflectionService wiktionaryService =
      WiktionaryInflectionService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController answerController = TextEditingController();

  final Random _random = Random();

  late final web.EventListener _keyListener;

  List<GreekVocabularyEntry> entries = [];

  GreekVocabularyEntry? question;

  bool loading = true;
  bool loadingForm = false;
  bool answered = false;
  bool correct = false;

  String? formError;
  String? correctForm;

  // Preloading für nächste Frage
  GreekVocabularyEntry? _preloadedQuestion;
  String? _preloadedForm;
  String? _preloadedCase;
  String? _preloadedNumber;
  String? _preloadedGender;
  String? _preloadedPerson;
  String? _preloadedNumberVerb;
  String? _preloadedTense;
  String? _preloadedVoice;

  // Auswertung
  bool? caseCorrect;
  bool? numberCorrect;
  bool? genderCorrect;
  bool? personCorrect;
  bool? tenseCorrect;
  bool? voiceCorrect;
  bool? lemmaCorrect;

  // ---------------------------------------------------------------------------
  // EINSTELLUNGEN
  // ---------------------------------------------------------------------------

  List<int> enabledSteps = [1, 2, 3, 4, 5, 6, 7];

  List<String> enabledTypes = ["noun", "verb"];

  static const List<String> allTypes = ["noun", "verb"];

  // ---------------------------------------------------------------------------
  // NOMEN
  // ---------------------------------------------------------------------------

  String? selectedCase;
  String? selectedNumber;
  String? selectedGender;

  String? userCase;
  String? userNumber;
  String? userGender;

  static const List<String> cases = [
    "Nominativ",
    "Genitiv",
    "Dativ",
    "Akkusativ",
  ];

  static const List<String> numbers = ["Sg.", "Pl."];

  static const List<String> genders = ["m", "f", "n"];

  // ---------------------------------------------------------------------------
  // VERBEN
  // ---------------------------------------------------------------------------

  String? selectedPerson;
  String? selectedNumberVerb;
  String? selectedTense;
  String? selectedVoice;

  String? userPersonNumber;
  String? userTense;
  String? userVoice;

  static const List<String> personNumbers = [
    "1. Sg.",
    "2. Sg.",
    "3. Sg.",
    "1. Pl.",
    "2. Pl.",
    "3. Pl.",
  ];

  static const List<String> tenses = ["Präsens", "Imperfekt", "Aorist"];

  static const List<String> voices = ["Aktiv", "Medium/Passiv", "Deponent"];

  // ---------------------------------------------------------------------------
  // BLACKLIST
  // ---------------------------------------------------------------------------

  static const Set<String> grammarBlacklist = {
    "οἶδα",
    "εὐαγγελίζομαι",
    "ἐγείρομαι",
    "ἄρχομαι",
    "πείθομαι",
    "θησαυρίζω",
    "ἐκκόπτω",
    "φοβέομαι",
    "πειράομαι",
    "ἐκπορεύομαι",
    "οἶμαι",
    "καθαρίζομαι",
    "ἐκπλήσσομαι",
    "πορεύομαι",
    "μεταπέμπομαι",
    "σής",
    "βλαβή",
  };

  static const Set<String> activeOnlyVerbs = {
    "εἰμί",
    "ἀσθενέω",
    "μένω",
    "ἐπερωτάω",
    "ἐπιτιμάω",
    // weitere Verben hier ergänzen
  };

  static const Set<String> presentOnlyVerbs = {
    "προσεύχομαι",
    // weitere Verben hier ergänzen
  };

  static const Set<String> noAorist = {
    "τάττω",
    "εἰμί",
    "ἄπειμι",
    "σύνειμι",
    "ὑποπτεύω",
    // weitere Verben hier ergänzen
  };

  static const Set<String> noImperfect = {
    "ἐμβαίνω",
    // weitere Verben hier ergänzen
  };

  // ---------------------------------------------------------------------------
  // INIT / DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    load();
    _keyListener = ((web.Event event) {
      final keyboardEvent = event as web.KeyboardEvent;

      if (keyboardEvent.key == 'Enter') {
        if (answered) {
          nextQuestion();
        } else if (!loadingForm && correctForm != null) {
          check();
        }

        keyboardEvent.preventDefault();
      }
    }).toJS;

    web.window.addEventListener('keydown', _keyListener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('keydown', _keyListener);
    answerController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FIREBASE SETTINGS
  // ---------------------------------------------------------------------------

  Future<void> loadGrammarSettings() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();

    final data = doc.data();

    if (data == null) {
      return;
    }

    final settings = data['greek_grammar_settings'];

    if (settings is! Map<String, dynamic>) {
      return;
    }

    final savedSteps = settings['enabledSteps'];
    final savedTypes = settings['enabledTypes'];

    if (savedSteps is List) {
      enabledSteps = savedSteps
          .whereType<num>()
          .map((step) => step.toInt())
          .where((step) => step >= 1 && step <= 7)
          .toList();

      enabledSteps.sort();
    }

    if (savedTypes is List) {
      enabledTypes = savedTypes
          .whereType<String>()
          .where((type) => allTypes.contains(type))
          .toList();
    }
  }

  Future<void> saveGrammarSettings() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'greek_grammar_settings': {
        'enabledSteps': enabledSteps,
        'enabledTypes': enabledTypes,
      },
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    try {
      entries = await GreekVocabularyLoader.load();

      await loadGrammarSettings();

      await nextQuestion();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        formError = e.toString();
      });

      return;
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // FRAGE
  // ---------------------------------------------------------------------------

  bool isNoun() {
    return question?.type == "noun";
  }

  bool isVerb() {
    return question?.type == "verb";
  }

  Future<void> nextQuestion() async {
    if (enabledSteps.isEmpty || enabledTypes.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        question = null;
        correctForm = null;
        formError = null;
        answered = false;
        loadingForm = false;
      });

      return;
    }

    final available = entries.where((entry) {
      return enabledSteps.contains(entry.step) &&
          enabledTypes.contains(entry.type) &&
          !grammarBlacklist.contains(entry.lemma);
    }).toList();

    if (available.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        question = null;
        correctForm = null;
        formError = null;
        answered = false;
        loadingForm = false;
      });

      return;
    }

    // Prüfen, ob eine gültige vorgeladene Frage verfügbar ist
    // - Muss nicht null sein
    // - Muss nicht gleich der aktuellen Frage sein (falls der Nutzer zu schnell klickt)
    if (_preloadedQuestion != null &&
        _preloadedForm != null &&
        _preloadedQuestion != question) {
      // Vorgeladene Frage verwenden
      final newQuestion = _preloadedQuestion!;

      answerController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        question = newQuestion;

        answered = false;
        correct = false;
        loadingForm = false; // Bereits geladen!

        correctForm = _preloadedForm;
        formError = null;

        selectedCase = _preloadedCase;
        selectedNumber = _preloadedNumber;
        selectedGender = _preloadedGender;

        selectedPerson = _preloadedPerson;
        selectedNumberVerb = _preloadedNumberVerb;
        selectedTense = _preloadedTense;
        selectedVoice = _preloadedVoice;

        userCase = null;
        userNumber = null;
        userGender = null;

        userPersonNumber = null;
        userTense = null;
        userVoice = null;

        caseCorrect = null;
        numberCorrect = null;
        genderCorrect = null;
        personCorrect = null;
        tenseCorrect = null;
        voiceCorrect = null;
        lemmaCorrect = null;
      });

      // Nächste Frage im Hintergrund vorladen
      _preloadNextQuestion(available);
    } else {
      // Keine vorgeladene Frage verfügbar - normal laden
      final newQuestion = available[_random.nextInt(available.length)];

      answerController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        question = newQuestion;

        answered = false;
        correct = false;
        loadingForm = true;

        correctForm = null;
        formError = null;

        selectedCase = null;
        selectedNumber = null;
        selectedGender = null;

        selectedPerson = null;
        selectedNumberVerb = null;
        selectedTense = null;
        selectedVoice = null;

        userCase = null;
        userNumber = null;
        userGender = null;

        userPersonNumber = null;
        userTense = null;
        userVoice = null;

        caseCorrect = null;
        numberCorrect = null;
        genderCorrect = null;
        personCorrect = null;
        tenseCorrect = null;
        voiceCorrect = null;
        lemmaCorrect = null;
      });

      if (newQuestion.type == "noun") {
        await generateNounQuestion(newQuestion);
      } else if (newQuestion.type == "verb") {
        await generateVerbQuestion(newQuestion);
      }

      // Nach dem Laden: nächste Frage im Hintergrund vorladen
      _preloadNextQuestion(available);
    }
  }

  // Lädt die nächste Frage im Hintergrund vor
  Future<void> _preloadNextQuestion(
    List<GreekVocabularyEntry> available,
  ) async {
    if (available.isEmpty) return;

    final nextQuestion = available[_random.nextInt(available.length)];

    if (nextQuestion.type == "noun") {
      await _preloadNounQuestion(nextQuestion);
    } else if (nextQuestion.type == "verb") {
      await _preloadVerbQuestion(nextQuestion);
    }
  }

  // ---------------------------------------------------------------------------
  // ANTWORT PRÜFEN
  // ---------------------------------------------------------------------------

  void check() {
    final q = question;
    if (q == null) return;

    setState(() {
      answered = true;

      // Lemma prüfen (ohne Akzente und diakritische Zeichen)
      final userLemma = normalizeGreekForComparison(
        answerController.text.trim(),
      );
      final correctLemma = normalizeGreekForComparison(q.lemma.trim());
      lemmaCorrect = userLemma.toLowerCase() == correctLemma.toLowerCase();

      if (q.type == "noun") {
        caseCorrect = userCase == selectedCase;
        numberCorrect = userNumber == selectedNumber;
        genderCorrect = userGender == selectedGender;

        correct =
            (lemmaCorrect ?? false) &&
            (caseCorrect ?? false) &&
            (numberCorrect ?? false) &&
            (genderCorrect ?? false);
      } else if (q.type == "verb") {
        // userPersonNumber ist z.B. "1. Sg." oder "3. Pl."
        // selectedPerson ist z.B. "1.", selectedNumberVerb ist "Sg" oder "Pl"
        final correctPersonNumber = "$selectedPerson $selectedNumberVerb.";
        personCorrect = userPersonNumber == correctPersonNumber;
        tenseCorrect = userTense == selectedTense;
        voiceCorrect = userVoice == selectedVoice;

        correct =
            (lemmaCorrect ?? false) &&
            (personCorrect ?? false) &&
            (tenseCorrect ?? false) &&
            (voiceCorrect ?? false);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // NOMEN-FRAGE GENERIEREN
  // ---------------------------------------------------------------------------

  Future<void> generateNounQuestion(GreekVocabularyEntry entry) async {
    final grammaticalCase = cases[_random.nextInt(cases.length)];

    final number = numbers[_random.nextInt(numbers.length)];

    // Genus aus dem Artikel bestimmen
    String gender = "m"; // Fallback
    if (entry.article == "ὁ") {
      gender = "m";
    } else if (entry.article == "ἡ") {
      gender = "f";
    } else if (entry.article == "τό" || entry.article == "το") {
      gender = "n";
    }

    if (mounted) {
      setState(() {
        selectedCase = grammaticalCase;
        selectedNumber = number;
        selectedGender = gender;
      });
    }

    try {
      final form = await wiktionaryService.getNounForm(
        lemma: entry.lemma,
        grammaticalCase: grammaticalCase,
        number: number == "Sg." ? "Sg" : "Pl",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = form == null ? null : normalizeGreekForDisplay(form);

        if (form == null || form.isEmpty) {
          formError =
              'Keine passende Nominalform gefunden.\n\nLemma: ${entry.lemma}';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = null;
        formError =
            'Fehler beim Laden der Nominalform\n\nLemma: ${entry.lemma}\n\nFehler: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // VERB-FRAGE GENERIEREN
  // ---------------------------------------------------------------------------

  Future<void> generateVerbQuestion(GreekVocabularyEntry entry) async {
    final person = ["1.", "2.", "3."][_random.nextInt(3)];

    final number = ["Sg", "Pl"][_random.nextInt(2)];

    String tense;

    if (presentOnlyVerbs.contains(entry.lemma)) {
      tense = "Präsens";
    } else if (noAorist.contains(entry.lemma)) {
      const noAoristTenses = ["Präsens", "Imperfekt"];

      tense = noAoristTenses[_random.nextInt(noAoristTenses.length)];
    } else if (noImperfect.contains(entry.lemma)) {
      const noImperfectTenses = ["Präsens", "Aorist"];

      tense = noImperfectTenses[_random.nextInt(noImperfectTenses.length)];
    } else {
      tense = tenses[_random.nextInt(tenses.length)];
    }

    String voice;

    if (activeOnlyVerbs.contains(entry.lemma)) {
      voice = "Aktiv";
    } else if (entry.deponent) {
      voice = "Medium/Passiv";
    } else {
      voice = ["Aktiv", "Medium/Passiv"][_random.nextInt(2)];
    }

    if (mounted) {
      setState(() {
        selectedPerson = person;
        selectedNumberVerb = number;
        selectedTense = tense;
        selectedVoice = voice;
      });
    }

    final parsedPerson = _parsePerson(person);

    if (parsedPerson == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingForm = false;

        formError =
            'Fehler bei Verbform\n'
            'Lemma: ${entry.lemma}\n'
            'Form: $person $number · $tense · $voice\n'
            'Ungültige Personenangabe.';
      });

      return;
    }

    try {
      final form = await wiktionaryService.getVerbForm(
        lemma: entry.lemma,
        tense: tense,
        voice: voice,
        number: number,
        person: parsedPerson,
      );

      if (!mounted) {
        return;
      }

      if (form == null || form.isEmpty) {
        setState(() {
          loadingForm = false;
          correctForm = null;

          formError =
              'Verbform nicht gefunden\n\n'
              'Lemma: ${entry.lemma}\n'
              'Gesucht: $person $number · '
              '$tense · $voice';
        });

        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = normalizeGreekForDisplay(form);
        formError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingForm = false;
        correctForm = null;

        formError =
            'Fehler beim Laden der Verbform\n\n'
            'Lemma: ${entry.lemma}\n'
            'Gesucht: $person $number · '
            '$tense · $voice\n\n'
            'Fehler: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PRELOAD METHODEN (Im Hintergrund laden)
  // ---------------------------------------------------------------------------

  Future<void> _preloadNounQuestion(GreekVocabularyEntry entry) async {
    final grammaticalCase = cases[_random.nextInt(cases.length)];
    final number = numbers[_random.nextInt(numbers.length)];

    // Genus aus dem Artikel bestimmen
    String gender = "m";
    if (entry.article == "ὁ") {
      gender = "m";
    } else if (entry.article == "ἡ") {
      gender = "f";
    } else if (entry.article == "τό" || entry.article == "το") {
      gender = "n";
    }

    try {
      final form = await wiktionaryService.getNounForm(
        lemma: entry.lemma,
        grammaticalCase: grammaticalCase,
        number: number == "Sg." ? "Sg" : "Pl",
      );

      if (form != null && form.isNotEmpty) {
        // Speichere vorgeladene Daten (kein setState!)
        _preloadedQuestion = entry;
        _preloadedForm = normalizeGreekForDisplay(form);
        _preloadedCase = grammaticalCase;
        _preloadedNumber = number;
        _preloadedGender = gender;
        _preloadedPerson = null;
        _preloadedNumberVerb = null;
        _preloadedTense = null;
        _preloadedVoice = null;
      } else {
        // Form nicht gefunden - verwerfen
        _preloadedQuestion = null;
        _preloadedForm = null;
      }
    } catch (e) {
      // Fehler beim Vorladen - verwerfen
      _preloadedQuestion = null;
      _preloadedForm = null;
    }
  }

  Future<void> _preloadVerbQuestion(GreekVocabularyEntry entry) async {
    final person = ["1.", "2.", "3."][_random.nextInt(3)];
    final number = ["Sg", "Pl"][_random.nextInt(2)];

    String tense;
    if (presentOnlyVerbs.contains(entry.lemma)) {
      tense = "Präsens";
    } else if (noAorist.contains(entry.lemma)) {
      const noAoristTenses = ["Präsens", "Imperfekt"];
      tense = noAoristTenses[_random.nextInt(noAoristTenses.length)];
    } else if (noImperfect.contains(entry.lemma)) {
      const noImperfectTenses = ["Präsens", "Aorist"];
      tense = noImperfectTenses[_random.nextInt(noImperfectTenses.length)];
    } else {
      tense = tenses[_random.nextInt(tenses.length)];
    }

    String voice;
    if (activeOnlyVerbs.contains(entry.lemma)) {
      voice = "Aktiv";
    } else if (entry.deponent) {
      voice = "Medium/Passiv";
    } else {
      voice = ["Aktiv", "Medium/Passiv"][_random.nextInt(2)];
    }

    final parsedPerson = _parsePerson(person);
    if (parsedPerson == null) {
      _preloadedQuestion = null;
      _preloadedForm = null;
      return;
    }

    try {
      final form = await wiktionaryService.getVerbForm(
        lemma: entry.lemma,
        tense: tense,
        voice: voice,
        number: number,
        person: parsedPerson,
      );

      if (form != null && form.isNotEmpty) {
        // Speichere vorgeladene Daten (kein setState!)
        _preloadedQuestion = entry;
        _preloadedForm = normalizeGreekForDisplay(form);
        _preloadedCase = null;
        _preloadedNumber = null;
        _preloadedGender = null;
        _preloadedPerson = person;
        _preloadedNumberVerb = number;
        _preloadedTense = tense;
        _preloadedVoice = voice;
      } else {
        // Form nicht gefunden - verwerfen
        _preloadedQuestion = null;
        _preloadedForm = null;
      }
    } catch (e) {
      // Fehler beim Vorladen - verwerfen
      _preloadedQuestion = null;
      _preloadedForm = null;
    }
  }

  // ---------------------------------------------------------------------------
  // PERSON PARSEN
  // ---------------------------------------------------------------------------

  int? _parsePerson(String? value) {
    switch (value) {
      case "1.":
        return 1;
      case "2.":
        return 2;
      case "3.":
        return 3;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // RESULT BORDER
  // ---------------------------------------------------------------------------

  OutlineInputBorder resultBorder(bool? value) {
    if (value == null) {
      return const OutlineInputBorder();
    }

    return OutlineInputBorder(
      borderSide: BorderSide(
        color: value ? Colors.green : Colors.red,
        width: 2,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DROPDOWN
  // ---------------------------------------------------------------------------

  Widget _dropdown({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool? isCorrect,
    double? width,
  }) {
    final border = resultBorder(isCorrect);
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          enabledBorder: border,
          focusedBorder: border,
          disabledBorder: border,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: answered ? null : onChanged,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRIECHISCHE TASTATUR
  // ---------------------------------------------------------------------------

  void openGreekKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (context) {
        return GreekKeyboard(
          controller: answerController,
          onChanged: () {
            setState(() {});
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EINSTELLUNGEN
  // ---------------------------------------------------------------------------

  void openSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text("Einstellungen")),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      if (enabledSteps.isEmpty || enabledTypes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mindestens ein Schritt und "
                              "eine Wortart müssen ausgewählt sein.",
                            ),
                          ),
                        );

                        return;
                      }

                      await saveGrammarSettings();

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(context);

                      await nextQuestion();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ExpansionTile(
                        title: const Text("Schritte"),
                        children: [
                          CheckboxListTile(
                            title: const Text("Alle Schritte"),
                            tristate: true,
                            value: enabledSteps.length == 7
                                ? true
                                : enabledSteps.isEmpty
                                ? false
                                : null,
                            onChanged: (_) {
                              setDialogState(() {
                                if (enabledSteps.length == 7) {
                                  enabledSteps.clear();
                                } else {
                                  enabledSteps = [1, 2, 3, 4, 5, 6, 7];
                                }
                              });
                            },
                          ),
                          ...List.generate(7, (index) {
                            final step = index + 1;

                            return CheckboxListTile(
                              title: Text("Schritt $step"),
                              value: enabledSteps.contains(step),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    if (!enabledSteps.contains(step)) {
                                      enabledSteps.add(step);
                                    }
                                  } else {
                                    enabledSteps.remove(step);
                                  }

                                  enabledSteps.sort();
                                });
                              },
                            );
                          }),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text("Wortarten"),
                        children: [
                          CheckboxListTile(
                            title: const Text("Alle Wortarten"),
                            tristate: true,
                            value: enabledTypes.length == allTypes.length
                                ? true
                                : enabledTypes.isEmpty
                                ? false
                                : null,
                            onChanged: (_) {
                              setDialogState(() {
                                if (enabledTypes.length == allTypes.length) {
                                  enabledTypes.clear();
                                } else {
                                  enabledTypes = List.from(allTypes);
                                }
                              });
                            },
                          ),
                          ...allTypes.map((type) {
                            return CheckboxListTile(
                              title: Text(type == "noun" ? "Nomen" : "Verben"),
                              value: enabledTypes.contains(type),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    if (!enabledTypes.contains(type)) {
                                      enabledTypes.add(type);
                                    }
                                  } else {
                                    enabledTypes.remove(type);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    if (q == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Grammatiktrainer"),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: openSettings,
            ),
          ],
        ),
        body: Center(
          child: Text(
            formError ??
                "Mit den aktuellen Filtern sind "
                    "keine Vokabeln verfügbar.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Grammatiktrainer"),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: openSettings),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // -------------------------------------------------------------
                // DEKLINIERTE/KONJUGIERTE FORM
                // -------------------------------------------------------------
                if (loadingForm)
                  const CircularProgressIndicator()
                else if (correctForm != null)
                  SelectableText(
                    correctForm!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (formError != null)
                  SelectableText(
                    formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  )
                else
                  const Text(
                    "Form wird geladen...",
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // GRAMMATIK-EINGABEN
                // -------------------------------------------------------------
                if (isVerb())
                  _buildVerbInputs()
                else if (isNoun())
                  _buildNounInputs(),

                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // LEMMA EINGABE
                // -------------------------------------------------------------
                TextField(
                  controller: answerController,
                  enabled: !answered && !loadingForm && correctForm != null,
                  decoration: InputDecoration(
                    labelText: "Lemma (Grundform)",
                    enabledBorder: resultBorder(lemmaCorrect),
                    focusedBorder: resultBorder(lemmaCorrect),
                    disabledBorder: resultBorder(lemmaCorrect),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: "Griechische Tastatur",
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      onPressed: answered || loadingForm || correctForm == null
                          ? null
                          : openGreekKeyboard,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // FEEDBACK
                // -------------------------------------------------------------
                if (answered)
                  Column(
                    children: [
                      Text(
                        correct ? "Richtig" : "Falsch",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: correct ? Colors.green : Colors.red,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (!correct)
                        Column(
                          children: [
                            const Text(
                              "Korrekte Antworten:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),

                            if (lemmaCorrect == false)
                              Text("Lemma: ${question?.lemma ?? ''}"),

                            if (isNoun()) ...[
                              if (caseCorrect == false)
                                Text("Kasus: $selectedCase"),
                              if (numberCorrect == false)
                                Text("Numerus: $selectedNumber"),
                              if (genderCorrect == false)
                                Text("Genus: $selectedGender"),
                            ],

                            if (isVerb()) ...[
                              if (personCorrect == false)
                                Text(
                                  "Person / Numerus: $selectedPerson $selectedNumberVerb.",
                                ),
                              if (tenseCorrect == false)
                                Text("Tempus: $selectedTense"),
                              if (voiceCorrect == false)
                                Text("Genus Verbi: $selectedVoice"),
                            ],
                          ],
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),

                // -------------------------------------------------------------
                // FEHLER
                // -------------------------------------------------------------
                if (formError != null && !loadingForm)
                  Text(
                    formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // BUTTON
                // -------------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loadingForm
                        ? null
                        : () async {
                            if (answered || formError != null) {
                              await nextQuestion();
                            } else {
                              check();
                            }
                          },
                    child: Text(
                      loadingForm
                          ? "Lädt..."
                          : (answered || formError != null)
                          ? "Weiter"
                          : "Prüfen",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOMEN-EINGABEN
  // ---------------------------------------------------------------------------

  Widget _buildNounInputs() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _dropdown(
            value: userCase,
            label: "Kasus",
            items: cases,
            isCorrect: caseCorrect,
            onChanged: (value) {
              setState(() {
                userCase = value;
              });
            },
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _dropdown(
            value: userNumber,
            label: "Numerus",
            items: numbers,
            isCorrect: numberCorrect,
            onChanged: (value) {
              setState(() {
                userNumber = value;
              });
            },
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _dropdown(
            value: userGender,
            label: "Genus",
            items: genders,
            isCorrect: genderCorrect,
            onChanged: (value) {
              setState(() {
                userGender = value;
              });
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VERB-EINGABEN
  // ---------------------------------------------------------------------------

  Widget _buildVerbInputs() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dropdown(
                value: userPersonNumber,
                label: "Person / Numerus",
                items: personNumbers,
                isCorrect: personCorrect,
                onChanged: (value) {
                  setState(() {
                    userPersonNumber = value;
                  });
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _dropdown(
                value: userTense,
                label: "Tempus",
                items: tenses,
                isCorrect: tenseCorrect,
                onChanged: (value) {
                  setState(() {
                    userTense = value;
                  });
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _dropdown(
                value: userVoice,
                label: "Genus Verbi",
                items: voices,
                isCorrect: voiceCorrect,
                onChanged: (value) {
                  setState(() {
                    userVoice = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// GRIECHISCH NORMALISIEREN
// -----------------------------------------------------------------------------

String normalizeGreekForDisplay(String text) {
  // Nur spezielle Makron/Breve-Zeichen ersetzen, Akzente bleiben erhalten
  return text
      .replaceAll('ᾰ', 'α')
      .replaceAll('ᾱ', 'α')
      .replaceAll('ῐ', 'ι')
      .replaceAll('ῑ', 'ι')
      .replaceAll('ῠ', 'υ')
      .replaceAll('ῡ', 'υ');
}

String normalizeGreekForComparison(String text) {
  // Erst spezielle Zeichen normalisieren
  String normalized = normalizeGreekForDisplay(text);

  // Map für griechische Zeichen mit Akzenten/Spiritus → Basiszeichen
  const Map<String, String> greekNormalization = {
    "ά": "α",
    "ὰ": "α",
    "ᾶ": "α",
    "ἀ": "α",
    "ἁ": "α",
    "ἂ": "α",
    "ἃ": "α",
    "ἄ": "α",
    "ἅ": "α",
    "ἆ": "α",
    "ἇ": "α",
    "ᾀ": "α",
    "ᾁ": "α",
    "ᾂ": "α",
    "ᾃ": "α",
    "ᾄ": "α",
    "ᾅ": "α",
    "ᾆ": "α",
    "ᾇ": "α",
    "ᾲ": "α",
    "ᾳ": "α",
    "ᾴ": "α",
    "ᾷ": "α",

    "έ": "ε",
    "ὲ": "ε",
    "ἐ": "ε",
    "ἑ": "ε",
    "ἒ": "ε",
    "ἓ": "ε",
    "ἔ": "ε",
    "ἕ": "ε",

    "ή": "η",
    "ὴ": "η",
    "ῆ": "η",
    "ἠ": "η",
    "ἡ": "η",
    "ἢ": "η",
    "ἣ": "η",
    "ἤ": "η",
    "ἥ": "η",
    "ἦ": "η",
    "ἧ": "η",
    "ᾐ": "η",
    "ᾑ": "η",
    "ᾒ": "η",
    "ᾓ": "η",
    "ᾔ": "η",
    "ᾕ": "η",
    "ᾖ": "η",
    "ᾗ": "η",
    "ῂ": "η",
    "ῃ": "η",
    "ῄ": "η",
    "ῇ": "η",

    "ί": "ι",
    "ὶ": "ι",
    "ῖ": "ι",
    "ἰ": "ι",
    "ἱ": "ι",
    "ἲ": "ι",
    "ἳ": "ι",
    "ἴ": "ι",
    "ἵ": "ι",
    "ἶ": "ι",
    "ἷ": "ι",
    "ϊ": "ι",
    "ΐ": "ι",
    "ῒ": "ι",
    "ῗ": "ι",

    "ό": "ο",
    "ὸ": "ο",
    "ὀ": "ο",
    "ὁ": "ο",
    "ὂ": "ο",
    "ὃ": "ο",
    "ὄ": "ο",
    "ὅ": "ο",

    "ύ": "υ",
    "ὺ": "υ",
    "ῦ": "υ",
    "ὐ": "υ",
    "ὑ": "υ",
    "ὒ": "υ",
    "ὓ": "υ",
    "ὔ": "υ",
    "ὕ": "υ",
    "ὖ": "υ",
    "ὗ": "υ",
    "ϋ": "υ",
    "ΰ": "υ",
    "ῢ": "υ",
    "ῧ": "υ",

    "ώ": "ω",
    "ὼ": "ω",
    "ῶ": "ω",
    "ὠ": "ω",
    "ὡ": "ω",
    "ὢ": "ω",
    "ὣ": "ω",
    "ὤ": "ω",
    "ὥ": "ω",
    "ὦ": "ω",
    "ὧ": "ω",
    "ᾠ": "ω",
    "ᾡ": "ω",
    "ᾢ": "ω",
    "ᾣ": "ω",
    "ᾤ": "ω",
    "ᾥ": "ω",
    "ᾦ": "ω",
    "ᾧ": "ω",
    "ῲ": "ω",
    "ῳ": "ω",
    "ῴ": "ω",
    "ῷ": "ω",

    "ῤ": "ρ",
    "ῥ": "ρ",

    "ϐ": "β",
    "ϑ": "θ",
    "ϕ": "φ",
    "ϖ": "π",
  };

  // Zeichen-für-Zeichen normalisieren
  normalized = normalized
      .toLowerCase()
      .trim()
      .split("")
      .map((char) => greekNormalization[char] ?? char)
      .join();

  // Restliche kombinierende diakritische Zeichen entfernen (falls noch welche übrig sind)
  normalized = normalized.replaceAll(RegExp(r'[̀-ͯ᾽-῿]'), '');

  // Finales Sigma → normales Sigma
  return normalized.replaceAll('ς', 'σ');
}
