import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/greek/exam/exam_config.dart';
import '../../../models/greek/exam/passage_ref.dart';
import '../../../models/greek/exam/text_corpus.dart';
import '../../../models/greek/vocabulary/greek_vocabulary_entry.dart';
import '../../../services/bible/bible_books.dart';
import '../../../services/greek/exam/exam_corpus_source.dart';
import '../../../services/greek/exam/exam_generator.dart';
import '../../../services/greek/exam/exam_store.dart';
import '../../../services/greek/exam/exam_task_types.dart';
import '../../../services/greek/exam/grammar_phenomena.dart';
import '../../../services/greek/vocabulary/greek_vocabulary_loader.dart';
import '../../../services/greek/vocabulary/vocabulary_settings_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_access.dart';
import '../../../widgets/settings_selection.dart';
import 'exam_diagnosis_view.dart';
import 'exam_screen.dart';

/// Klausurersteller: Konfiguration einer Graecum-ähnlichen Übungsklausur.
///
/// Die Oberfläche stellt nur dar, was zentral definiert ist (Korpora aus
/// `corpora.json`, Phänomene aus [GrammarPhenomena], Aufgabenarten aus
/// [ExamTaskTypes]); Suche und Prüfung liegen in den Services.
class GreekExamBuilderScreen extends StatefulWidget {
  final ExamCorpusSource? source;
  final ExamStore? store;
  final Future<List<GreekVocabularyEntry>> Function()? loadVocabulary;
  final Random? random;

  const GreekExamBuilderScreen({
    super.key,
    this.source,
    this.store,
    this.loadVocabulary,
    this.random,
  });

  @override
  State<GreekExamBuilderScreen> createState() => _GreekExamBuilderScreenState();
}

class _GreekExamBuilderScreenState extends State<GreekExamBuilderScreen> {
  late final ExamCorpusSource source =
      widget.source ?? AssetExamCorpusSource();
  late final ExamStore store =
      widget.store ??
      ExamStore.forUser(FirebaseAuth.instance.currentUser?.uid);
  late final ExamGenerator generator = ExamGenerator(
    source: source,
    random: widget.random,
  );

  ExamConfig config = const ExamConfig();
  List<TextCorpus> corpora = const [];
  Map<PassageRef, DateTime> done = {};
  List<GreekVocabularyEntry>? vocabulary;

  bool loading = true;
  String? loadError;
  bool generating = false;
  bool saveFailed = false;
  ExamNotPossible? failure;

  Timer? _saveTimer;

  // Konkrete Stelle
  final TextEditingController chapterController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  // Kapitelbereich bei genau einem Buch
  final TextEditingController chapterFromController = TextEditingController();
  final TextEditingController chapterToController = TextEditingController();
  String? fixedBook; // "<Korpus>:<Buch>"

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_saveTimer != null) _save();
    chapterController.dispose();
    fromController.dispose();
    toController.dispose();
    chapterFromController.dispose();
    chapterToController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loadedCorpora = await source.loadCorpora();
      final vocab = await (widget.loadVocabulary ?? GreekVocabularyLoader.load)();

      ExamConfig loadedConfig;
      Map<PassageRef, DateTime> loadedDone;

      try {
        loadedConfig = await store.loadConfig();
        loadedDone = await store.loadDone();
      } catch (_) {
        // Gespeicherte Einstellungen nicht lesbar: Defaults verwenden.
        loadedConfig = const ExamConfig();
        loadedDone = {};
        saveFailed = true;
      }

      final ids = {for (final c in loadedCorpora) c.id};
      final selected = loadedConfig.corpusIds.where(ids.contains).toList();

      if (!mounted) return;

      setState(() {
        corpora = loadedCorpora;
        vocabulary = vocab;
        done = loadedDone;
        config = loadedConfig.copyWith(
          corpusIds: selected.isEmpty ? [loadedCorpora.first.id] : selected,
        );
        _readFixed(config.fixedPassage);
        chapterFromController.text = config.chapterFrom?.toString() ?? "";
        chapterToController.text = config.chapterTo?.toString() ?? "";
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = "Die Texte konnten nicht geladen werden ($e).";
        loading = false;
      });
    }
  }

  void _readFixed(String? id) {
    final ref = id == null ? null : PassageRef.tryParse(id);
    if (ref == null) return;

    fixedBook = "${ref.corpusId}:${ref.bookId}";
    chapterController.text = "${ref.chapter}";
    fromController.text = ref.firstVerse;
    toController.text = ref.lastVerse;
  }

  void update(ExamConfig next) {
    setState(() {
      config = next;
      failure = null;
    });

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    _saveTimer = null;

    try {
      await store.saveConfig(config);
      if (mounted && saveFailed) setState(() => saveFailed = false);
    } catch (_) {
      if (mounted) setState(() => saveFailed = true);
    }
  }

  // ---------------------------------------------------------------------------
  // GENERIEREN
  // ---------------------------------------------------------------------------

  Future<void> generate() async {
    final vocab = vocabulary;
    if (vocab == null || generating) return;

    setState(() {
      generating = true;
      failure = null;
    });

    try {
      final outcome = await generator.generate(
        config: config,
        done: done.keys.toSet(),
        vocabulary: vocab,
      );

      if (!mounted) return;

      switch (outcome) {
        case ExamCreated(:final exam):
          setState(() => generating = false);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GreekExamScreen(
                exam: exam,
                generator: generator,
                store: store,
                vocabulary: vocab,
              ),
            ),
          );

          // Markierungen können sich in der Klausur geändert haben.
          try {
            final reloaded = await store.loadDone();
            if (mounted) setState(() => done = reloaded);
          } catch (_) {}

        case final ExamNotPossible notPossible:
          setState(() {
            generating = false;
            failure = notPossible;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Klausur konnte nicht erstellt werden: $e")),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OBERFLÄCHE
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Klausurersteller"),
        actions: const [SettingsButton()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(loadError!, textAlign: TextAlign.center),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _intro(context),
                    _card(context, "Textquelle", _sourceSection(context)),
                    _card(context, "Länge und Schwierigkeit", _lengthSection(context)),
                    _card(context, "Vokabelkenntnis", _vocabularySection(context)),
                    _card(context, "Grammatik", _grammarSection(context)),
                    _card(context, "Aufgaben", _taskSection(context)),
                    if (saveFailed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Die Einstellungen konnten nicht gespeichert werden; "
                          "sie gelten für diese Sitzung.",
                          style: TextStyle(color: context.colors.error),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey("generate-exam"),
                        onPressed: generating ? null : generate,
                        icon: generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.assignment_rounded),
                        label: const Text("Klausur erstellen"),
                      ),
                    ),
                    if (failure != null)
                      Card(
                        margin: const EdgeInsets.only(top: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Kein passender Text gefunden",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              ExamDiagnosisView(outcome: failure!),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _intro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        "Erstellt eine Übungsklausur nach dem Muster des Graecums: "
        "Übersetzung mit Vokabelhilfen, Bestimmung von Verbformen und zwei "
        "Grammatikaufgaben. Der Text wird nach den gewählten Kriterien "
        "aus allen passenden Abschnitten zufällig ausgewählt.",
        style: TextStyle(color: context.colors.textSecondary),
      ),
    );
  }

  Widget _card(BuildContext context, String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEXTQUELLE
  // ---------------------------------------------------------------------------

  List<TextCorpus> get selectedCorpora => [
    for (final c in corpora)
      if (config.corpusIds.contains(c.id)) c,
  ];

  Widget _sourceSection(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final fixed = config.fixedPassage != null || fixedBook != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MultiSelectSection<TextCorpus>(
          title: "Textkorpora",
          options: corpora,
          isSelected: (c) => config.corpusIds.contains(c.id),
          labelOf: (c) => c.name,
          onChanged: (c, selected) {
            final ids = {...config.corpusIds};
            selected ? ids.add(c.id) : ids.remove(c.id);
            if (ids.isEmpty) return;
            final books = config.bookIds
                .where((b) => corpora.any((k) => ids.contains(k.id) && k.books.contains(b)))
                .toList();
            update(config.copyWith(corpusIds: ids.toList(), bookIds: books));
          },
          onToggleAll: () => update(
            config.copyWith(corpusIds: [for (final c in corpora) c.id]),
          ),
          emptyError: "Mindestens ein Korpus auswählen.",
        ),
        for (final corpus in selectedCorpora)
          if (corpus.analysis == CorpusAnalysisKind.formal)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "${corpus.shortName}: ${corpus.analysisNote} Derzeit sind "
                "${(corpus.analyzedShare * 100).toStringAsFixed(0)} % der "
                "Wörter bestimmt.",
                style: secondary,
              ),
            ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Bücher"),
          subtitle: Text(
            config.bookIds.isEmpty
                ? "Alle Bücher der gewählten Korpora"
                : config.bookIds.map(BibleBooks.nameOf).join(", "),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: fixed ? null : _chooseBooks,
          enabled: !fixed,
        ),
        if (config.bookIds.length == 1 && !fixed) _chapterRange(context),
        SwitchListTile(
          key: const ValueKey("fixed-passage-switch"),
          contentPadding: EdgeInsets.zero,
          title: const Text("Konkrete Textstelle"),
          subtitle: const Text(
            "Statt automatischer Auswahl; die Stelle wird nur verwendet, wenn "
            "sie die übrigen Kriterien erfüllt.",
          ),
          value: fixed,
          onChanged: (value) {
            setState(() {
              if (value) {
                fixedBook =
                    "${selectedCorpora.first.id}:${selectedCorpora.first.books.first}";
              } else {
                fixedBook = null;
              }
            });
            update(config.copyWith(fixedPassage: () => value ? _fixedId() : null));
          },
        ),
        if (fixed) _fixedPassage(context),
        const Divider(height: 24),
        SwitchListTile(
          key: const ValueKey("exclude-done-switch"),
          contentPadding: EdgeInsets.zero,
          title: const Text("Bearbeitete Texte ausschließen"),
          subtitle: Text(
            "${done.length} Abschnitte als bearbeitet markiert; auch "
            "überlappende Abschnitte werden übersprungen.",
          ),
          value: config.excludeDone,
          onChanged: (value) => update(config.copyWith(excludeDone: value)),
        ),
        if (done.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _manageDone,
              child: const Text("Bearbeitete Texte anzeigen"),
            ),
          ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    ValueChanged<String> onChanged, {
    Key? key,
  }) {
    return SizedBox(
      width: 110,
      child: TextField(
        key: key,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _chapterRange(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text("Kapitel"),
          _numberField(
            chapterFromController,
            "von",
            (v) => update(config.copyWith(chapterFrom: () => int.tryParse(v))),
          ),
          _numberField(
            chapterToController,
            "bis",
            (v) => update(config.copyWith(chapterTo: () => int.tryParse(v))),
          ),
        ],
      ),
    );
  }

  String? _fixedId() {
    final book = fixedBook;
    final chapter = int.tryParse(chapterController.text.trim());
    final from = fromController.text.trim();
    final to = toController.text.trim().isEmpty ? from : toController.text.trim();

    if (book == null || chapter == null || from.isEmpty) return null;

    final [corpusId, bookId] = book.split(":");

    final id = PassageRef(
      corpusId: corpusId,
      bookId: bookId,
      chapter: chapter,
      firstVerse: from,
      lastVerse: to,
    ).id;

    return PassageRef.tryParse(id) == null ? null : id;
  }

  Widget _fixedPassage(BuildContext context) {
    void changed(_) => update(config.copyWith(fixedPassage: _fixedId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: fixedBook,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: "Buch",
            border: OutlineInputBorder(),
          ),
          items: [
            for (final corpus in selectedCorpora)
              for (final book in corpus.books)
                DropdownMenuItem(
                  value: "${corpus.id}:$book",
                  child: Text("${BibleBooks.nameOf(book)} (${corpus.shortName})"),
                ),
          ],
          onChanged: (value) {
            setState(() => fixedBook = value);
            changed(null);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _numberField(
              chapterController,
              "Kapitel",
              changed,
              key: const ValueKey("fixed-chapter"),
            ),
            _numberField(
              fromController,
              "Vers von",
              changed,
              key: const ValueKey("fixed-from"),
            ),
            _numberField(
              toController,
              "Vers bis",
              changed,
              key: const ValueKey("fixed-to"),
            ),
          ],
        ),
        if (config.fixedPassage == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Kapitel und Vers angeben.",
              style: TextStyle(color: context.colors.error),
            ),
          ),
      ],
    );
  }

  Future<void> _chooseBooks() async {
    final chosen = {...config.bookIds};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Bücher"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  "Keine Auswahl = alle Bücher.",
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 8),
                for (final corpus in selectedCorpora)
                  MultiSelectSection<String>(
                    title: corpus.name,
                    options: corpus.books,
                    isSelected: chosen.contains,
                    labelOf: BibleBooks.nameOf,
                    onChanged: (book, selected) => setDialogState(() {
                      selected ? chosen.add(book) : chosen.remove(book);
                    }),
                    onToggleAll: () => setDialogState(() {
                      if (corpus.books.every(chosen.contains)) {
                        chosen.removeAll(corpus.books);
                      } else {
                        chosen.addAll(corpus.books);
                      }
                    }),
                    emptyError: "Keine Auswahl: alle Bücher.",
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Abbrechen"),
            ),
            FilledButton(
              onPressed: () {
                final ordered = <String>{
                  for (final corpus in selectedCorpora)
                    for (final book in corpus.books)
                      if (chosen.contains(book)) book,
                }.toList();

                chapterFromController.clear();
                chapterToController.clear();
                update(
                  config.copyWith(
                    bookIds: ordered,
                    chapterFrom: () => null,
                    chapterTo: () => null,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text("Übernehmen"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageDone() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final entries = done.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return AlertDialog(
            title: const Text("Bearbeitete Texte"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        passageTitle(
                          entry.key,
                          corpora.where((c) => c.id == entry.key.corpusId).firstOrNull,
                        ),
                      ),
                      subtitle: Text(
                        "markiert am ${entry.value.day}.${entry.value.month}.${entry.value.year}",
                      ),
                      trailing: IconButton(
                        tooltip: "Markierung entfernen",
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () async {
                          try {
                            await store.unmarkDone(entry.key);
                            final reloaded = await store.loadDone();
                            setState(() => done = reloaded);
                            setDialogState(() {});
                          } catch (_) {}
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Schließen"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LÄNGE, SCHWIERIGKEIT, VOKABELN
  // ---------------------------------------------------------------------------

  Widget _lengthSection(BuildContext context) {
    final maxHints = config.maxHints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Wortzahl: ${config.minWords}–${config.maxWords} Wörter"),
        RangeSlider(
          values: RangeValues(
            config.minWords.toDouble(),
            config.maxWords.toDouble(),
          ),
          min: ExamConfig.lowestWords.toDouble(),
          max: ExamConfig.highestWords.toDouble(),
          divisions: (ExamConfig.highestWords - ExamConfig.lowestWords) ~/ 5,
          labels: RangeLabels("${config.minWords}", "${config.maxWords}"),
          onChanged: (values) => update(
            config.copyWith(
              minWords: values.start.round(),
              maxWords: values.end.round(),
            ),
          ),
        ),
        Text(
          "Abschnitte beginnen und enden an Satzgrenzen; die Länge eines "
          "Abschnitts ergibt sich aus ganzen Versen.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Vokabelhilfen begrenzen"),
          subtitle: Text(
            maxHints == null
                ? "Schwierigkeit: beliebig viele unbekannte Wörter"
                : "Höchstens $maxHints Vokabelhilfen",
          ),
          value: maxHints != null,
          onChanged: (value) =>
              update(config.copyWith(maxHints: () => value ? 15 : null)),
        ),
        if (maxHints != null)
          Slider(
            value: maxHints.toDouble().clamp(0, 60),
            min: 0,
            max: 60,
            divisions: 60,
            label: "$maxHints",
            onChanged: (value) =>
                update(config.copyWith(maxHints: () => value.round())),
          ),
      ],
    );
  }

  Widget _vocabularySection(BuildContext context) {
    return MultiSelectSection<int>(
      title: "Als bekannt gelten",
      hint:
          "Lernschritte der Vokabelliste. Wörter außerhalb dieser Schritte "
          "stehen als Vokabelhilfen unter dem Text.",
      options: ExamConfig.allSteps,
      isSelected: config.knownSteps.contains,
      labelOf: VocabularySettings.stepLabel,
      onChanged: (step, selected) {
        final steps = {...config.knownSteps};
        selected ? steps.add(step) : steps.remove(step);
        update(config.copyWith(knownSteps: steps.toList()..sort()));
      },
      onToggleAll: () => update(
        config.copyWith(
          knownSteps: config.knownSteps.length == ExamConfig.allSteps.length
              ? const []
              : ExamConfig.allSteps,
        ),
      ),
      emptyError: "Kein Schritt: Jedes Wort erhält eine Vokabelhilfe.",
    );
  }

  // ---------------------------------------------------------------------------
  // GRAMMATIK
  // ---------------------------------------------------------------------------

  Widget _grammarSection(BuildContext context) {
    final secondary = TextStyle(color: context.colors.textSecondary);
    final required = config.requiredPhenomena.length;
    final excluded = config.excludedPhenomena.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Je Phänomen: erlaubt (darf vorkommen), erforderlich (muss sicher "
          "belegt sein) oder ausgeschlossen (darf nicht vorkommen). „Nur "
          "Präsens und Aorist“: die übrigen Tempora ausschließen.",
          style: secondary,
        ),
        const SizedBox(height: 4),
        Text(
          "Regelbasiert erkannte Konstruktionen lassen sich nur fordern; "
          "nicht verfügbare sind mit der vorhandenen Datenbasis nicht "
          "erkennbar.",
          style: secondary,
        ),
        const SizedBox(height: 8),
        Text("$required erforderlich · $excluded ausgeschlossen"),
        if (required + excluded > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => update(config.copyWith(requirements: const {})),
              child: const Text("Alle Grammatikfilter zurücksetzen"),
            ),
          ),
        for (final category in GrammarPhenomena.categories)
          _categoryTile(context, category),
      ],
    );
  }

  Widget _categoryTile(BuildContext context, GrammarCategory category) {
    final members = GrammarPhenomena.inCategory(category.id);
    final required = members
        .where((p) => config.requirementOf(p.id) == PhenomenonRequirement.required)
        .length;
    final excluded = members
        .where((p) => config.requirementOf(p.id) == PhenomenonRequirement.excluded)
        .length;

    return ExpansionTile(
      key: PageStorageKey("category-${category.id}"),
      tilePadding: EdgeInsets.zero,
      title: Text(category.label),
      subtitle: required + excluded == 0
          ? null
          : Text(
              [
                if (required > 0) "$required erforderlich",
                if (excluded > 0) "$excluded ausgeschlossen",
              ].join(" · "),
            ),
      children: [
        if (category.hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              category.hint!,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
        for (final phenomenon in members) _phenomenonTile(context, phenomenon),
      ],
    );
  }

  static const Map<PhenomenonRequirement, String> _requirementLabels = {
    PhenomenonRequirement.allowed: "erlaubt",
    PhenomenonRequirement.required: "erforderlich",
    PhenomenonRequirement.excluded: "ausgeschlossen",
  };

  Widget _phenomenonTile(BuildContext context, GrammarPhenomenon phenomenon) {
    final colors = context.colors;
    final current = config.requirementOf(phenomenon.id);

    final badge = switch (phenomenon.status) {
      PhenomenonStatus.reliable => null,
      PhenomenonStatus.heuristic => "regelbasiert",
      PhenomenonStatus.unavailable => "nicht verfügbar",
    };

    return Padding(
      key: ValueKey("phenomenon-${phenomenon.id}"),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  phenomenon.label,
                  style: TextStyle(
                    color: phenomenon.status == PhenomenonStatus.unavailable
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              IconButton(
                tooltip: "Wie wird das erkannt?",
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(phenomenon.label),
                    content: Text(
                      "${phenomenon.description}\n\n${switch (phenomenon.status) {
                        PhenomenonStatus.reliable => "Zuverlässig: direkt aus der Bestimmung der Wortformen. Bei mehrdeutigen Formen gilt ein Phänomen nur als belegt, wenn alle möglichen Bestimmungen es zeigen, und als ausgeschlossen, wenn keine es zulässt.",
                        PhenomenonStatus.heuristic => "Regelbasiert erkannt: Treffer werden in der Klausur angezeigt; Fälle können übersehen werden. Deshalb nur als „erforderlich“ wählbar.",
                        PhenomenonStatus.unavailable => "Mit der vorhandenen Datenbasis nicht zuverlässig erkennbar und daher nicht als Filter wählbar.",
                      }}",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (phenomenon.status != PhenomenonStatus.unavailable)
            Wrap(
              spacing: 8,
              children: [
                for (final requirement in PhenomenonRequirement.values)
                  SelectionChip(
                    key: ValueKey("${phenomenon.id}-${requirement.name}"),
                    label: _requirementLabels[requirement]!,
                    selected: current == requirement,
                    showCheckmark: false,
                    onSelected: phenomenon.supports(requirement)
                        ? (_) => update(
                            config.withRequirement(phenomenon.id, requirement),
                          )
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AUFGABEN
  // ---------------------------------------------------------------------------

  Widget _taskSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text("Aufgabe 2: Anzahl der Verbformen")),
            IconButton(
              tooltip: "Weniger",
              onPressed: config.verbCount > 1
                  ? () => update(config.copyWith(verbCount: config.verbCount - 1))
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Text("${config.verbCount}", key: const ValueKey("verb-count")),
            IconButton(
              tooltip: "Mehr",
              onPressed: config.verbCount < ExamConfig.maxVerbCount
                  ? () => update(config.copyWith(verbCount: config.verbCount + 1))
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        for (final slot in [0, 1])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
              initialValue: config.extraTaskTypes[slot],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "Aufgabe ${slot + 3}",
                border: const OutlineInputBorder(),
                helperText: ExamTaskTypes.byId(config.extraTaskTypes[slot])?.description,
                helperMaxLines: 3,
              ),
              items: [
                for (final type in ExamTaskTypes.extra)
                  DropdownMenuItem(value: type.id, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                update(
                  config.copyWith(
                    extraTaskTypes: [...config.extraTaskTypes]..[slot] = value,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Text(
          "Weitere Aufgabenformate folgen, sobald Griechisch-I-Abschlussklausuren "
          "als Vorlage vorliegen.",
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
