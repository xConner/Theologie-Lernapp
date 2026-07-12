import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/greek_vocabulary_entry.dart';
import '../../models/vocabulary_question.dart';

import '../../services/greek_vocabulary_loader.dart';
import '../../services/vocabulary_answer_checker.dart';
import '../../services/vocabulary_progress_service.dart';
import '../../services/vocabulary_srs.dart';

import '../../widgets/greek_keyboard.dart';

class VocabularyTrainerScreen extends StatefulWidget {
  const VocabularyTrainerScreen({super.key});

  @override
  State<VocabularyTrainerScreen> createState() =>
      _VocabularyTrainerScreenState();
}

class _VocabularyTrainerScreenState extends State<VocabularyTrainerScreen> {
  final VocabularyProgressService progressService = VocabularyProgressService();

  List<GreekVocabularyEntry> entries = [];

  Map<String, Map<String, dynamic>> progress = {};

  VocabularyQuestion? question;

  bool loading = true;

  bool answered = false;

  bool correct = false;

  bool? translationCorrect;
  bool? articleCorrect;
  bool? genitiveCorrect;
  bool? aoristCorrect;

  final translationController = TextEditingController();
  final articleController = TextEditingController();
  final genitiveController = TextEditingController();
  final aoristController = TextEditingController();

  bool showKeyboard = false;

  TextEditingController? activeController;

  String? uid;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    entries = await GreekVocabularyLoader.load();

    progress = await progressService.loadProgress(uid!);

    nextQuestion();

    setState(() {
      loading = false;
    });
  }

  void nextQuestion() {
    final next = VocabularySrs.chooseNext(entries: entries, progress: progress);

    question = VocabularyQuestion(entry: next);

    translationController.clear();
    articleController.clear();
    genitiveController.clear();
    aoristController.clear();

    answered = false;
    correct = false;

    translationCorrect = null;
    articleCorrect = null;
    genitiveCorrect = null;
    aoristCorrect = null;

    showKeyboard = false;
    activeController = null;

    setState(() {});
  }

  Future<void> check() async {
    final q = question;

    if (q == null || uid == null) {
      return;
    }

    final result = VocabularyAnswerChecker.check(
      entry: q.entry,

      translationInput: translationController.text,

      articleInput: articleController.text,

      genitiveInput: genitiveController.text,

      aoristInput: aoristController.text,

      checkArticle: q.checkArticle,

      checkGenitive: q.checkGenitive,

      checkAorist: q.checkAorist,
    );

    await progressService.saveAnswer(
      uid: uid!,

      vocabularyId: q.entry.id.toString(),

      correct: result.correct,
    );

    progress = await progressService.loadProgress(uid!);

    setState(() {
      answered = true;

      correct = result.correct;

      translationCorrect = result.translationCorrect;

      articleCorrect = result.articleCorrect;

      genitiveCorrect = result.genitiveCorrect;

      aoristCorrect = result.aoristCorrect;

      showKeyboard = false;

      activeController = null;
    });
  }

  void openKeyboard(TextEditingController controller) {
    setState(() {
      activeController = controller;
      showKeyboard = true;
    });
  }

  void toggleKeyboard() {
    setState(() {
      if (showKeyboard) {
        showKeyboard = false;
        activeController = null;
      } else {
        showKeyboard = true;
      }
    });
  }

  void closeKeyboard() {
    setState(() {
      showKeyboard = false;
      activeController = null;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = question;

    if (q == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Vokabeltrainer")),

      body: GestureDetector(
        behavior: HitTestBehavior.translucent,

        onTap: closeKeyboard,

        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),

              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    SelectableText(
                      q.entry.lemma,

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (q.hasArticleField || q.hasGenitiveField)
                      Row(
                        children: [
                          if (q.hasArticleField)
                            Expanded(
                              child: greekField(
                                "Artikel",
                                articleController,
                                articleCorrect,
                              ),
                            ),

                          if (q.hasArticleField && q.hasGenitiveField)
                            const SizedBox(width: 10),

                          if (q.hasGenitiveField)
                            Expanded(
                              child: greekField(
                                "Genitiv",
                                genitiveController,
                                genitiveCorrect,
                              ),
                            ),
                        ],
                      ),

                    if (q.hasAoristField)
                      greekField("Aorist", aoristController, aoristCorrect),

                    const SizedBox(height: 15),

                    TextField(
                      controller: translationController,

                      enabled: !answered,

                      onTap: closeKeyboard,

                      decoration: InputDecoration(
                        labelText: "Übersetzung",

                        enabledBorder: resultBorder(translationCorrect),

                        focusedBorder: resultBorder(translationCorrect),

                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (showKeyboard && activeController != null)
                      GreekKeyboard(
                        controller: activeController!,

                        onChanged: () {
                          setState(() {});
                        },
                      ),

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

                                if (q.hasArticleField &&
                                    articleCorrect == false)
                                  Text("Artikel: ${q.entry.article ?? "-"}"),

                                if (q.hasGenitiveField &&
                                    genitiveCorrect == false)
                                  Text("Genitiv: ${q.entry.genitive ?? "-"}"),

                                if (q.hasAoristField && aoristCorrect == false)
                                  Text("Aorist: ${q.entry.aorist ?? "-"}"),

                                if (translationCorrect == false)
                                  Text(
                                    "Übersetzung: ${q.entry.translations.join(", ")}",
                                  ),
                              ],
                            ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: answered ? nextQuestion : check,

                        child: Text(answered ? "Weiter" : "Prüfen"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget greekField(
    String label,
    TextEditingController controller,
    bool? correct,
  ) {
    return TextField(
      controller: controller,

      readOnly: true,

      onTap: () {
        if (!answered) {
          openKeyboard(controller);
        }
      },

      decoration: InputDecoration(
        labelText: label,

        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard),

          onPressed: answered ? null : toggleKeyboard,
        ),

        enabledBorder: resultBorder(correct),

        focusedBorder: resultBorder(correct),

        border: const OutlineInputBorder(),
      ),
    );
  }
}
