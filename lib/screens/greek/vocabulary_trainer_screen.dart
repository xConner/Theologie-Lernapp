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

      correct: result,
    );

    progress = await progressService.loadProgress(uid!);

    setState(() {
      answered = true;

      correct = result;
    });
  }

  void openKeyboard(TextEditingController controller) {
    setState(() {
      activeController = controller;

      showKeyboard = true;
    });
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

      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text(
                    q.entry.lemma,

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
                            child: greekField("Artikel", articleController),
                          ),

                        if (q.hasArticleField && q.hasGenitiveField)
                          const SizedBox(width: 10),

                        if (q.hasGenitiveField)
                          Expanded(
                            child: greekField("Genitiv", genitiveController),
                          ),
                      ],
                    ),

                  if (q.hasAoristField) greekField("Aorist", aoristController),

                  const SizedBox(height: 15),

                  TextField(
                    controller: translationController,

                    decoration: const InputDecoration(
                      labelText: "Übersetzung",

                      border: OutlineInputBorder(),
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
                    Text(
                      correct ? "Richtig" : "Falsch",

                      style: TextStyle(
                        fontSize: 22,

                        color: correct ? Colors.green : Colors.red,
                      ),
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
    );
  }

  Widget greekField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,

      readOnly: true,

      onTap: () {
        openKeyboard(controller);
      },

      decoration: InputDecoration(
        labelText: label,

        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard),

          onPressed: () {
            openKeyboard(controller);
          },
        ),

        border: const OutlineInputBorder(),
      ),
    );
  }
}
