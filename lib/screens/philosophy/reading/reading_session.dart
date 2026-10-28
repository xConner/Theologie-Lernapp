import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/philosophy/reading_text.dart';
import '../../../models/philosophy/reading_work.dart';
import '../../../services/philosophy/greek_word_analyzer.dart';
import '../../../services/philosophy/private_edition_store.dart';
import '../../../services/philosophy/reading_repository.dart';
import '../../../services/philosophy/reading_user_data.dart';
import '../../../services/quiz_documents.dart';

/// Zustand eines geöffneten Werks: gewählte Ausgabe, geladener Text,
/// persönliche Daten und (bei Bedarf) die Wortanalyse. Alle Ansichten des
/// Werks teilen sich eine Sitzung, damit Leseposition, Modus und Notizen
/// überall gleich sind.
class ReadingSession extends ChangeNotifier {
  final String? uid;
  final String workId;
  final ReadingRepository repository;
  final ReadingUserData userData;
  final PrivateEditionStore privateStore;

  ReadingSession({
    required this.uid,
    required this.workId,
    ReadingRepository? repository,
    QuizDocuments? documents,
    PrivateEditionStore? privateStore,
  }) : repository = repository ?? ReadingRepository(),
       userData = ReadingUserData(
         documents ?? QuizDocuments.forUser(uid),
         workId,
       ),
       privateStore = privateStore ?? PrivateEditionStore(uid: uid);

  ReadingWork? work;
  ReadingText? text;
  ReadingUserState user = const ReadingUserState();

  /// Private Ausgaben, die importiert sind.
  final Set<String> importedEditions = {};
  Object? error;
  bool loading = true;

  GreekWordAnalyzer? _analyzer;
  Future<GreekWordAnalyzer>? _analyzerLoading;

  ReadingEdition? get edition => text?.edition;

  ReadingMode get mode {
    final m = user.mode;
    if (m == null) {
      return text?.hasGerman == true ? ReadingMode.interlinear : ReadingMode.greek;
    }
    // Ohne Übersetzung bleibt nur der griechische Text.
    if (text?.hasGerman != true) return ReadingMode.greek;
    return m;
  }

  /// Ausgaben, die sich jetzt lesen lassen (mitgeliefert oder importiert).
  List<ReadingEdition> get availableEditions => [
    for (final e in work?.editions ?? const <ReadingEdition>[])
      if (e.kind == EditionKind.bundled || importedEditions.contains(e.id)) e,
  ];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      work = await repository.work(workId);
      user = await userData.load();
      importedEditions.clear();
      for (final e in work!.editions) {
        if (e.kind != EditionKind.private) continue;
        try {
          if (await privateStore.has(e.id)) importedEditions.add(e.id);
        } catch (e) {
          debugPrint("Private Ausgabe nicht prüfbar: $e");
        }
      }
      text = await _open(_preferredEdition());
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Gespeicherte Ausgabe, sonst die erste mit Übersetzung, sonst die erste.
  ReadingEdition _preferredEdition() {
    final editions = availableEditions;
    for (final e in editions) {
      if (e.id == user.edition) return e;
    }
    for (final e in editions) {
      if (e.hasGerman) return e;
    }
    return editions.first;
  }

  Future<ReadingText> _open(ReadingEdition edition) async {
    if (edition.kind == EditionKind.bundled) {
      return repository.bundled(work!, edition);
    }
    final opened = await repository.private(work!, edition, privateStore);
    if (opened == null) {
      importedEditions.remove(edition.id);
      return repository.bundled(work!, availableEditions.first);
    }
    return opened;
  }

  Future<void> switchEdition(ReadingEdition edition) async {
    if (edition.id == this.edition?.id) return;
    loading = true;
    notifyListeners();
    try {
      text = await _open(edition);
      _analyzer = null;
      _analyzerLoading = null;
      await userData.setEdition(text!.edition.id);
      user = _copy(edition: text!.edition.id);
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Importiert eine private Ausgabe aus dem Inhalt einer Lesedatei.
  Future<PrivateEditionLocation> importEdition(
    ReadingEdition edition,
    String raw,
  ) async {
    final data = PrivateEditionStore.validate(
      raw,
      workId: workId,
      editionId: edition.id,
    );
    final location = await privateStore.save(edition.id, data);
    importedEditions.add(edition.id);
    await switchEdition(edition);
    return location;
  }

  Future<void> removeEdition(ReadingEdition edition) async {
    await privateStore.remove(edition.id);
    importedEditions.remove(edition.id);
    if (this.edition?.id == edition.id) {
      text = await _open(availableEditions.first);
      _analyzer = null;
      _analyzerLoading = null;
    }
    notifyListeners();
  }

  Future<GreekWordAnalyzer> analyzer() {
    final ready = _analyzer;
    if (ready != null) return SynchronousFuture(ready);
    return _analyzerLoading ??= GreekWordAnalyzer.load(
      repository,
      text!,
    ).then((a) => _analyzer = a);
  }

  // ---------------------------------------------------------------------------
  // Persönliche Daten
  // ---------------------------------------------------------------------------

  ReadingUserState _copy({
    ReadingMode? mode,
    String? edition,
    double? textScale,
    String? position,
    Map<String, ReadingMark>? marks,
    Map<String, WordListEntry>? words,
    Set<String>? readChapters,
  }) => ReadingUserState(
    mode: mode ?? user.mode,
    edition: edition ?? user.edition,
    textScale: textScale ?? user.textScale,
    position: position ?? user.position,
    marks: marks ?? user.marks,
    words: words ?? user.words,
    readChapters: readChapters ?? user.readChapters,
  );

  Future<void> setMode(ReadingMode mode) async {
    user = _copy(mode: mode);
    notifyListeners();
    await userData.setMode(mode);
  }

  Future<void> setTextScale(double scale) async {
    user = _copy(textScale: scale);
    notifyListeners();
    await userData.setTextScale(scale);
  }

  Timer? _positionTimer;

  /// Merkt die Leseposition; gespeichert wird gebündelt, nicht bei jedem
  /// Scrollschritt.
  void setPosition(String sentenceId) {
    if (user.position == sentenceId) return;
    user = _copy(position: sentenceId);
    _positionTimer?.cancel();
    _positionTimer = Timer(const Duration(seconds: 2), flushPosition);
  }

  Future<void> flushPosition() async {
    _positionTimer?.cancel();
    _positionTimer = null;
    final position = user.position;
    if (position != null) await userData.setPosition(position);
  }

  Future<void> saveMark(
    String anchor, {
    required bool bookmark,
    required String note,
  }) async {
    final mark = await userData.saveMark(anchor, bookmark: bookmark, note: note);
    final marks = Map.of(user.marks);
    if (mark == null) {
      marks.remove(anchor);
    } else {
      marks[anchor] = mark;
    }
    user = _copy(marks: marks);
    notifyListeners();
  }

  Future<void> addWord({
    required String form,
    required String? lemma,
    required String sentenceId,
  }) async {
    final entry = await userData.addWord(
      form: form,
      lemma: lemma,
      sentenceId: sentenceId,
    );
    user = _copy(words: {...user.words, entry.key: entry});
    notifyListeners();
  }

  Future<void> removeWord(String key) async {
    await userData.removeWord(key);
    user = _copy(words: Map.of(user.words)..remove(key));
    notifyListeners();
  }

  Future<void> setChapterRead(ReadingChapter chapter, bool read) async {
    final chapters = Set.of(user.readChapters);
    read ? chapters.add(chapter.id) : chapters.remove(chapter.id);
    user = _copy(readChapters: chapters);
    notifyListeners();
    await userData.setChapterRead(chapter.id, read);
  }

  @override
  void dispose() {
    if (_positionTimer != null) unawaited(flushPosition());
    super.dispose();
  }
}
