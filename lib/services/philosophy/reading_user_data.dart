import '../local_learning_store.dart';
import '../quiz_documents.dart';

/// Darstellung von Original und Übersetzung im Leser.
enum ReadingMode {
  greek("Griechisch"),
  german("Deutsch"),
  sideBySide("Nebeneinander"),
  interlinear("Untereinander");

  final String label;

  const ReadingMode(this.label);

  static ReadingMode? byName(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Persönliche Stelle: Lesezeichen und/oder Notiz zu einem Satz, Wort oder
/// Abschnitt. Gespeichert wird nur die Stelle (Bekker-Kennung), nie der
/// Text der Ausgabe.
class ReadingMark {
  /// `s:<Satz>` (Satz), `u:<Abschnitt>` (Abschnitt) oder
  /// `w:<Satz>:<Wortnummer>:<Wortform>` (Wort).
  final String anchor;
  final bool bookmark;
  final String note;
  final DateTime updated;

  const ReadingMark({
    required this.anchor,
    required this.bookmark,
    required this.note,
    required this.updated,
  });

  bool get isEmpty => !bookmark && note.trim().isEmpty;

  /// Satzkennung, an der die Stelle hängt.
  String get sentenceId {
    final parts = anchor.split(":");
    return parts.length > 1 ? parts[1] : anchor;
  }

  String get kind => anchor.split(":").first;

  /// Nur bei Wort-Anker: die Wortform.
  String? get word {
    final parts = anchor.split(":");
    return parts.length > 3 ? parts.sublist(3).join(":") : null;
  }

  Map<String, Object?> toJson() => {
    "b": bookmark,
    "n": note,
    "t": updated.millisecondsSinceEpoch,
  };

  static ReadingMark? fromJson(String anchor, Object? json) {
    if (json is! Map) return null;
    return ReadingMark(
      anchor: anchor,
      bookmark: json["b"] == true,
      note: json["n"] is String ? json["n"] as String : "",
      updated: DateTime.fromMillisecondsSinceEpoch(
        (json["t"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Eintrag der Wortliste: Wortform aus dem Text mit Fundstelle.
class WordListEntry {
  /// Grundform, falls bekannt, sonst die Form.
  final String key;
  final String form;
  final String? lemma;
  final String sentenceId;
  final DateTime added;

  const WordListEntry({
    required this.key,
    required this.form,
    required this.lemma,
    required this.sentenceId,
    required this.added,
  });

  Map<String, Object?> toJson() => {
    "f": form,
    "l": lemma,
    "s": sentenceId,
    "t": added.millisecondsSinceEpoch,
  };

  static WordListEntry? fromJson(String key, Object? json) {
    if (json is! Map || json["f"] is! String || json["s"] is! String) {
      return null;
    }
    return WordListEntry(
      key: key,
      form: json["f"] as String,
      lemma: json["l"] as String?,
      sentenceId: json["s"] as String,
      added: DateTime.fromMillisecondsSinceEpoch(
        (json["t"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class ReadingUserState {
  final ReadingMode? mode;
  final String? edition;
  final double textScale;

  /// Zuletzt gelesene Stelle (Satzkennung) – getrennt von Lernständen.
  final String? position;
  final Map<String, ReadingMark> marks;
  final Map<String, WordListEntry> words;
  final Set<String> readChapters;

  const ReadingUserState({
    this.mode,
    this.edition,
    this.textScale = 1.0,
    this.position,
    this.marks = const {},
    this.words = const {},
    this.readChapters = const {},
  });

  List<ReadingMark> get bookmarks =>
      [for (final m in marks.values) if (m.bookmark) m]
        ..sort((a, b) => b.updated.compareTo(a.updated));

  List<ReadingMark> get notes =>
      [for (final m in marks.values) if (m.note.trim().isNotEmpty) m]
        ..sort((a, b) => b.updated.compareTo(a.updated));

  /// Stellen, die zu einem Satz gehören (Satz, Wörter darin).
  List<ReadingMark> marksOfSentence(String sentenceId) => [
    for (final m in marks.values)
      if (m.sentenceId == sentenceId && m.kind != "u") m,
  ];
}

/// Persönliche Daten des Lesebereichs im Dokument
/// `quiz_settings/philosophy_reading` (Konto) bzw. lokal (Gast). Jeder
/// Eintrag beginnt mit der Werkkennung, damit weitere Werke dasselbe
/// Dokument nutzen. Alle Änderungen sind Merges einzelner Einträge, damit
/// nichts anderes überschrieben wird.
class ReadingUserData {
  final QuizDocuments documents;
  final String workId;

  ReadingUserData(this.documents, this.workId);

  factory ReadingUserData.forUser(String? uid, String workId) =>
      ReadingUserData(QuizDocuments.forUser(uid), workId);

  static const String document = LocalLearningStore.philosophyReading;

  String _key(String id) => "$workId|$id";

  Map<String, Object?> _ofWork(Object? field) {
    final prefix = "$workId|";
    return {
      if (field is Map)
        for (final e in field.entries)
          if (e.key is String && (e.key as String).startsWith(prefix))
            (e.key as String).substring(prefix.length): e.value,
    };
  }

  Future<ReadingUserState> load() async {
    final doc = await documents.load(document);
    final settings = _ofWork(doc["settings"]);
    final positions = _ofWork(doc["positions"]);
    final marks = _ofWork(doc["marks"]);
    final words = _ofWork(doc["words"]);
    final read = _ofWork(doc["read"]);
    return ReadingUserState(
      mode: ReadingMode.byName(settings["mode"] as String?),
      edition: settings["edition"] as String?,
      textScale: ((settings["scale"] as num?)?.toDouble() ?? 1.0).clamp(
        0.8,
        1.6,
      ),
      position: positions["last"] as String?,
      marks: {
        for (final e in marks.entries)
          e.key: ?ReadingMark.fromJson(e.key, e.value),
      },
      words: {
        for (final e in words.entries)
          e.key: ?WordListEntry.fromJson(e.key, e.value),
      },
      readChapters: {
        for (final e in read.entries)
          if (e.value != null) e.key,
      },
    );
  }

  Future<void> setMode(ReadingMode mode) =>
      documents.mergeEntries(document, "settings", {_key("mode"): mode.name});

  Future<void> setEdition(String editionId) => documents.mergeEntries(
    document,
    "settings",
    {_key("edition"): editionId},
  );

  Future<void> setTextScale(double scale) => documents.mergeEntries(
    document,
    "settings",
    {_key("scale"): scale},
  );

  Future<void> setPosition(String sentenceId) => documents.mergeEntries(
    document,
    "positions",
    {_key("last"): sentenceId},
  );

  /// Speichert Lesezeichen und Notiz einer Stelle; eine leere Stelle wird
  /// entfernt.
  Future<ReadingMark?> saveMark(
    String anchor, {
    required bool bookmark,
    required String note,
  }) async {
    final mark = ReadingMark(
      anchor: anchor,
      bookmark: bookmark,
      note: note.trim(),
      updated: DateTime.now(),
    );
    await documents.mergeEntries(document, "marks", {
      _key(anchor): mark.isEmpty ? null : mark.toJson(),
    });
    return mark.isEmpty ? null : mark;
  }

  Future<WordListEntry> addWord({
    required String form,
    required String? lemma,
    required String sentenceId,
  }) async {
    final entry = WordListEntry(
      key: lemma ?? form,
      form: form,
      lemma: lemma,
      sentenceId: sentenceId,
      added: DateTime.now(),
    );
    await documents.mergeEntries(document, "words", {
      _key(entry.key): entry.toJson(),
    });
    return entry;
  }

  Future<void> removeWord(String key) =>
      documents.mergeEntries(document, "words", {_key(key): null});

  Future<void> setChapterRead(String chapterId, bool read) =>
      documents.mergeEntries(document, "read", {
        _key(chapterId): read ? DateTime.now().millisecondsSinceEpoch : null,
      });
}
