/// Inhaltliche Wissensfragen zu biblischen Büchern („Bücher systematisch
/// lernen“): Personen, Ereignisse, Orte, Begriffe, Aufbau und Zusammenhänge
/// – ergänzend zu den Perikopenstellen. Siehe docs/pericope-books.md,
/// Abschnitt „Wissensfragen“.
///
/// Jede Frage gehört zu genau einem Buch und, wo möglich, zu einem
/// Kapitel- bzw. Versbereich ([KnowledgeRange]); darüber erscheint sie in
/// den Lerneinheiten des Buchs, eines Abschnitts oder eines Kapitels.
/// Fragen ohne Bereich gehören zum ganzen Buch.
///
/// Zwei Quellen mit demselben Format:
/// * `assets/bible_knowledge/` – Fragen der App zum Bibeltext (für alle).
/// * `assets/old_testament/model_answers/` – Aufgaben und Musterantworten
///   der Übung Bibelkunde AT samt der daraus gebildeten Lernfragen; wie alle
///   Vorlesungsunterlagen nur für freigeschaltete Konten
///   (`LectureMaterials`).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'book_outline.dart';

/// Antwortform einer Wissensfrage. Sie folgt dem Inhalt: Was sich eindeutig
/// auswählen lässt, wird ausgewählt; wer eine Musterantwort braucht, deckt
/// sie auf und schätzt sich selbst ein.
enum KnowledgeFormat {
  /// Eine richtige Antwort unter mehreren.
  choice("Auswahl"),

  /// Mehrere richtige Antworten; richtig nur, wenn genau diese gewählt sind.
  multi("Mehrfachauswahl"),

  /// Erst selbst nachdenken, dann die (Muster-)Antwort aufdecken und
  /// einschätzen, ob man sie wusste.
  reveal("Aufdecken"),

  /// Paare zuordnen (Person – Rolle, Stelle – Inhalt, Begriff – Bedeutung).
  match("Zuordnen"),

  /// In die richtige Reihenfolge bringen (Ereignisse, Gliederung).
  order("Reihenfolge");

  final String label;

  const KnowledgeFormat(this.label);

  static KnowledgeFormat? tryParse(Object? value) {
    for (final f in values) {
      if (f.name == value) return f;
    }
    return null;
  }
}

/// Worum es inhaltlich geht – für die Anzeige und spätere Filter.
enum KnowledgeTopic {
  person("Person"),
  event("Ereignis"),
  place("Ort"),
  term("Begriff"),
  structure("Aufbau"),
  theme("Theologie und Motive"),
  law("Gesetz und Kult"),
  connection("Zusammenhang");

  final String label;

  const KnowledgeTopic(this.label);

  static KnowledgeTopic tryParse(Object? value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return KnowledgeTopic.event;
  }
}

/// Herkunft einer Frage bzw. Antwort.
enum KnowledgeSource {
  /// Aufgabe und Musterantwort der Dozentin – maßgebliche Referenz.
  modelAnswer("Musterantwort"),

  /// Nach den Folien einer Sitzung.
  slides("Nach den Folien"),

  /// Frage der App zum Bibeltext.
  app("Frage der App");

  final String label;

  const KnowledgeSource(this.label);

  static KnowledgeSource tryParse(Object? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return KnowledgeSource.app;
  }
}

/// Kapitel- oder Versbereich eines Buchs, z. B. „12,1-25,18“, „37-50“
/// oder „22“. Ohne Vers gilt „ab Vers 1“ bzw. „bis Kapitelende“.
class KnowledgeRange {
  final int startChapter;
  final int? startVerse;
  final int endChapter;
  final int? endVerse;

  const KnowledgeRange(
    this.startChapter, {
    this.startVerse,
    int? endChapter,
    this.endVerse,
  }) : endChapter = endChapter ?? startChapter;

  static final RegExp _pattern = RegExp(
    r'^\s*(\d+)(?:\s*,\s*(\d+))?\s*(?:[-–]\s*(\d+)(?:\s*,\s*(\d+))?)?\s*$',
  );

  /// Liest „12“, „12-25“, „12,1-25,18“ oder „6,5-8,22“. Eine Endangabe
  /// ohne Komma nach einem Anfangsvers ist ein Vers im selben Kapitel
  /// („19,1-29“). `null` bei ungültiger Angabe.
  static KnowledgeRange? parse(Object? raw) {
    if (raw is! String) return null;

    final m = _pattern.firstMatch(raw);

    if (m == null) return null;

    final c1 = int.parse(m.group(1)!);
    final v1 = m.group(2) == null ? null : int.parse(m.group(2)!);
    final a = m.group(3) == null ? null : int.parse(m.group(3)!);
    final b = m.group(4) == null ? null : int.parse(m.group(4)!);

    int c2 = c1;
    int? v2;

    if (a != null && b != null) {
      c2 = a;
      v2 = b;
    } else if (a != null) {
      if (v1 != null) {
        v2 = a;
      } else {
        c2 = a;
      }
    } else {
      v2 = v1;
    }

    final range = KnowledgeRange(
      c1,
      startVerse: v1,
      endChapter: c2,
      endVerse: v2,
    );

    return c1 < 1 || range._endKey < range._startKey ? null : range;
  }

  int get _startKey => startChapter * 10000 + (startVerse ?? 0);
  int get _endKey => endChapter * 10000 + (endVerse ?? 9999);

  /// Liegt ganz in den Kapiteln [from]–[to]?
  bool withinChapters(int from, int to) =>
      startChapter >= from && endChapter <= to;

  /// Liegt ganz im Abschnitt [section]?
  bool withinSection(OutlineSection section) {
    final start = section.start.chapter * 10000 + (section.start.verse ?? 0);
    final end = section.end.chapter * 10000 + (section.end.verse ?? 9999);

    return _startKey >= start && _endKey <= end;
  }

  /// Berührt das Kapitel [chapter]?
  bool touchesChapter(int chapter) =>
      startChapter <= chapter && endChapter >= chapter;

  /// „12,1–25,18“, „37–50“ bzw. „22“.
  String get text {
    final start = startVerse == null
        ? "$startChapter"
        : "$startChapter,$startVerse";

    if (startChapter == endChapter && startVerse == null && endVerse == null) {
      return start;
    }

    if (startChapter == endChapter && startVerse != null && endVerse != null) {
      return startVerse == endVerse ? start : "$start–$endVerse";
    }

    final end = endVerse == null ? "$endChapter" : "$endChapter,$endVerse";

    return "$start–$end";
  }
}

/// Ein Paar einer Zuordnungsaufgabe.
class KnowledgePair {
  final String left;
  final String right;

  const KnowledgePair(this.left, this.right);
}

/// Eine Wissensfrage mit stabiler ID (`bq.<buch>.<name>` für Fragen der
/// App, `ma.<sitzung>.<nr>.<name>` für Lernfragen aus Musterantworten).
/// An der ID hängt der Lernstand.
class KnowledgeQuestion {
  final String id;

  /// Buchabkürzung der Perikopenliste („Gen“, „Ex“, „Lev“).
  final String book;

  final KnowledgeFormat format;

  final KnowledgeTopic topic;

  final KnowledgeSource source;

  final String prompt;

  /// Die erwartete Antwort: bei [KnowledgeFormat.reveal] die
  /// (Muster-)Antwort, sonst eine zusammenfassende Lösung (optional).
  final String? answer;

  /// Richtige Auswahlmöglichkeiten (eine bei [KnowledgeFormat.choice]).
  final List<String> correct;

  /// Falsche Auswahlmöglichkeiten.
  final List<String> distractors;

  final List<KnowledgePair> pairs;

  /// Richtige Reihenfolge bei [KnowledgeFormat.order].
  final List<String> items;

  /// Erklärung bzw. Ergänzung, getrennt von der Antwort.
  final String? explanation;

  /// Kapitel- bzw. Versbereich; `null` = ganzes Buch.
  final KnowledgeRange? range;

  /// Versgenaue Belegstellen („Gen 32,23-33“), im Reader aufschlagbar.
  final List<String> refs;

  /// Perikopen der Liste (`BookPericope.key`), auf die sich die Frage
  /// bezieht.
  final List<String> pericopeKeys;

  /// Merkvers aus „Texte auswendig lernen“, falls einer dazugehört.
  final String? memoryVerse;

  /// Sitzung der Übung (`bk.02`), aus der der Inhalt stammt.
  final String? sessionId;

  /// Aufgabe mit Musterantwort ([ModelAnswerTask.id]), aus der die Frage
  /// gebildet wurde.
  final String? taskId;

  const KnowledgeQuestion({
    required this.id,
    required this.book,
    required this.format,
    this.topic = KnowledgeTopic.event,
    this.source = KnowledgeSource.app,
    required this.prompt,
    this.answer,
    this.correct = const [],
    this.distractors = const [],
    this.pairs = const [],
    this.items = const [],
    this.explanation,
    this.range,
    this.refs = const [],
    this.pericopeKeys = const [],
    this.memoryVerse,
    this.sessionId,
    this.taskId,
  });

  /// Die Lösung in einer Zeile bzw. einem Absatz (Auswertung, Fehlerliste).
  String get solutionText {
    switch (format) {
      case KnowledgeFormat.reveal:
        return answer ?? "";
      case KnowledgeFormat.choice:
      case KnowledgeFormat.multi:
        return answer ?? correct.join(" · ");
      case KnowledgeFormat.match:
        return [for (final p in pairs) "${p.left} – ${p.right}"].join("\n");
      case KnowledgeFormat.order:
        return [
          for (int i = 0; i < items.length; i++) "${i + 1}. ${items[i]}",
        ].join("\n");
    }
  }

  /// „Gen 12–25“ bzw. „Gen“ für das ganze Buch.
  String get scopeLabel => range == null ? book : "$book ${range!.text}";

  static List<String> _strings(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is String && e.trim().isNotEmpty) e.trim(),
  ];

  /// Liest eine Frage; wirft [FormatException], wenn sie nicht stimmig ist
  /// (fehlende Felder, zu wenige Möglichkeiten, doppelte Einträge).
  factory KnowledgeQuestion.fromJson(
    Map<String, dynamic> json, {
    required String book,
    String? sessionId,
    String? taskId,
    KnowledgeSource? source,
  }) {
    final id = json["id"];
    final prompt = json["prompt"];
    final format = KnowledgeFormat.tryParse(json["format"]);

    if (id is! String || id.isEmpty) {
      throw const FormatException("Wissensfrage ohne ID");
    }

    if (prompt is! String || prompt.trim().isEmpty || format == null) {
      throw FormatException("Wissensfrage $id: Frage oder Format fehlt");
    }

    final rawRange = json["range"];
    final range = rawRange == null ? null : KnowledgeRange.parse(rawRange);

    if (rawRange != null && range == null) {
      throw FormatException("Wissensfrage $id: ungültiger Bereich $rawRange");
    }

    final pairs = <KnowledgePair>[
      if (json["pairs"] is List)
        for (final p in json["pairs"] as List)
          if (p is List && p.length == 2 && p[0] is String && p[1] is String)
            KnowledgePair(p[0] as String, p[1] as String),
    ];

    final question = KnowledgeQuestion(
      id: id,
      book: (json["book"] as String?) ?? book,
      format: format,
      topic: KnowledgeTopic.tryParse(json["topic"]),
      source: json["source"] == null
          ? (source ?? KnowledgeSource.app)
          : KnowledgeSource.tryParse(json["source"]),
      prompt: prompt.trim(),
      answer: (json["answer"] as String?)?.trim(),
      correct: _strings(json["correct"]),
      distractors: _strings(json["distractors"]),
      pairs: pairs,
      items: _strings(json["items"]),
      explanation: (json["explanation"] as String?)?.trim(),
      range: range,
      refs: _strings(json["refs"]),
      pericopeKeys: _strings(json["pericopes"]),
      memoryVerse: json["memoryVerse"] as String?,
      sessionId: (json["session"] as String?) ?? sessionId,
      taskId: (json["task"] as String?) ?? taskId,
    );

    final problem = question._problem();

    if (problem != null) throw FormatException("Wissensfrage $id: $problem");

    return question;
  }

  String? _problem() {
    bool distinct(List<String> values) => values.toSet().length == values.length;

    switch (format) {
      case KnowledgeFormat.reveal:
        if (answer == null || answer!.isEmpty) return "Antwort fehlt";
      case KnowledgeFormat.choice:
        if (correct.length != 1) return "genau eine richtige Antwort nötig";
        if (distractors.length < 2) return "mindestens zwei Ablenker nötig";
        if (!distinct([...correct, ...distractors])) return "doppelte Option";
      case KnowledgeFormat.multi:
        if (correct.length < 2) return "mindestens zwei richtige Antworten";
        if (distractors.isEmpty) return "mindestens ein Ablenker nötig";
        if (!distinct([...correct, ...distractors])) return "doppelte Option";
      case KnowledgeFormat.match:
        if (pairs.length < 3) return "mindestens drei Paare nötig";
        if (!distinct([for (final p in pairs) p.left]) ||
            !distinct([for (final p in pairs) p.right])) {
          return "doppelte Einträge in den Paaren";
        }
      case KnowledgeFormat.order:
        if (items.length < 3) return "mindestens drei Einträge nötig";
        if (!distinct(items)) return "doppelte Einträge";
    }

    return null;
  }
}

/// Eine Aufgabe der Übung mit der Musterantwort der Dozentin. Die
/// Musterantwort steht vollständig und wörtlich in [answer]; die Lernfragen
/// ([questionIds]) zerlegen sie in abfragbare Teile.
class ModelAnswerTask {
  final String id;

  /// Sitzung der Übung (`bk.02`).
  final String sessionId;

  /// Nummer der Aufgabe auf der Folie.
  final int number;

  final String book;

  /// Aufgabenstellung wie auf der Folie.
  final String prompt;

  /// Musterantwort, unverändert.
  final String answer;

  /// Erläuterung der App, getrennt von der Musterantwort.
  final String? note;

  final KnowledgeRange? range;

  final List<String> refs;

  final List<String> questionIds;

  const ModelAnswerTask({
    required this.id,
    required this.sessionId,
    required this.number,
    required this.book,
    required this.prompt,
    required this.answer,
    this.note,
    this.range,
    this.refs = const [],
    this.questionIds = const [],
  });
}

/// Alle geladenen Wissensfragen und Musterantworten.
class KnowledgeBank {
  final List<KnowledgeQuestion> questions;

  final List<ModelAnswerTask> tasks;

  /// Hinweise zu Sitzungen (Titel, Herkunft), z. B. `bk.02` → „Sitzung 2:
  /// Genesis“.
  final Map<String, String> sessionTitles;

  KnowledgeBank({
    this.questions = const [],
    this.tasks = const [],
    this.sessionTitles = const {},
  });

  static final KnowledgeBank empty = KnowledgeBank();

  /// Öffentliche Fragen der App.
  static const String root = "assets/bible_knowledge";

  /// Musterantworten der Übung (geschützte Vorlesungsunterlagen; Pfad
  /// relativ zu `assets/`, wie `LectureMaterials.files` ihn liefert).
  static const String modelAnswerPrefix = "old_testament/model_answers/";

  late final Map<String, KnowledgeQuestion> _byId = {
    for (final q in questions) q.id: q,
  };

  late final Map<String, ModelAnswerTask> _tasks = {
    for (final t in tasks) t.id: t,
  };

  bool get isEmpty => questions.isEmpty;

  KnowledgeQuestion? question(String id) => _byId[id];

  ModelAnswerTask? task(String id) => _tasks[id];

  /// Bücher mit Wissensfragen.
  Set<String> get books => {for (final q in questions) q.book};

  List<KnowledgeQuestion> ofBook(String book) => [
    for (final q in questions)
      if (q.book == book) q,
  ];

  /// Fragen, deren Bereich ganz in den Kapiteln [from]–[to] liegt. Fragen
  /// zum ganzen Buch gehören nur dazu, wenn das ganze Buch gemeint ist
  /// ([wholeBook]).
  List<KnowledgeQuestion> inChapters(
    String book,
    int from,
    int to, {
    bool wholeBook = false,
  }) => [
    for (final q in questions)
      if (q.book == book &&
          (q.range == null ? wholeBook : q.range!.withinChapters(from, to)))
        q,
  ];

  /// Fragen, deren Bereich ganz im Abschnitt liegt.
  List<KnowledgeQuestion> inSection(OutlineSection section) => [
    for (final q in questions)
      if (q.book == section.book &&
          q.range != null &&
          q.range!.withinSection(section))
        q,
  ];

  List<ModelAnswerTask> tasksOf(String book) => [
    for (final t in tasks)
      if (t.book == book) t,
  ];

  List<KnowledgeQuestion> questionsOfTask(ModelAnswerTask task) => [
    for (final id in task.questionIds) ?_byId[id],
  ];

  // ==========================
  // LADEN
  // ==========================

  /// Liest eine Datei: `{book, session?, sessionTitle?, questions: [...],
  /// tasks: [...]}`. Aufgaben enthalten ihre Lernfragen unter `questions`.
  /// Ungültige Fragen werfen [FormatException] (die Daten sollen stimmen;
  /// ein Test prüft alle Dateien).
  static KnowledgeBank parse(Map<String, dynamic> json) {
    final book = json["book"];

    if (book is! String || book.isEmpty) {
      throw const FormatException("Wissensfragen ohne Buch");
    }

    final session = json["session"] as String?;
    final questions = <KnowledgeQuestion>[];
    final tasks = <ModelAnswerTask>[];

    for (final raw in (json["questions"] as List?) ?? const []) {
      questions.add(
        KnowledgeQuestion.fromJson(
          Map<String, dynamic>.from(raw as Map),
          book: book,
          sessionId: session,
          source: session == null
              ? KnowledgeSource.app
              : KnowledgeSource.slides,
        ),
      );
    }

    for (final raw in (json["tasks"] as List?) ?? const []) {
      final t = Map<String, dynamic>.from(raw as Map);

      final id = t["id"];
      final number = t["number"];
      final prompt = t["prompt"];
      final answer = t["answer"];

      if (id is! String ||
          number is! int ||
          prompt is! String ||
          answer is! String ||
          answer.trim().isEmpty) {
        throw FormatException("Aufgabe ${t["id"]}: Angaben fehlen");
      }

      final rawRange = t["range"];
      final range = rawRange == null ? null : KnowledgeRange.parse(rawRange);
      final taskSession = (t["session"] as String?) ?? session;

      if (taskSession == null) {
        throw FormatException("Aufgabe $id: Sitzung fehlt");
      }

      final own = [
        for (final q in (t["questions"] as List?) ?? const [])
          KnowledgeQuestion.fromJson(
            Map<String, dynamic>.from(q as Map),
            book: book,
            sessionId: taskSession,
            taskId: id,
            source: KnowledgeSource.modelAnswer,
          ),
      ];

      questions.addAll(own);

      tasks.add(
        ModelAnswerTask(
          id: id,
          sessionId: taskSession,
          number: number,
          book: book,
          prompt: prompt.trim(),
          answer: answer.trim(),
          note: (t["note"] as String?)?.trim(),
          range: range,
          refs: KnowledgeQuestion._strings(t["refs"]),
          questionIds: [for (final q in own) q.id],
        ),
      );
    }

    final title = json["sessionTitle"];

    return KnowledgeBank(
      questions: questions,
      tasks: tasks,
      sessionTitles: {
        if (session != null && title is String) session: title,
      },
    );
  }

  /// Fasst mehrere Dateien zusammen; doppelte IDs werfen
  /// [FormatException].
  static KnowledgeBank merge(Iterable<KnowledgeBank> parts) {
    final questions = <KnowledgeQuestion>[];
    final tasks = <ModelAnswerTask>[];
    final titles = <String, String>{};
    final ids = <String>{};

    for (final part in parts) {
      for (final q in part.questions) {
        if (!ids.add(q.id)) {
          throw FormatException("Doppelte Wissensfrage ${q.id}");
        }
        questions.add(q);
      }
      for (final t in part.tasks) {
        if (!ids.add(t.id)) throw FormatException("Doppelte Aufgabe ${t.id}");
        tasks.add(t);
      }
      titles.addAll(part.sessionTitles);
    }

    return KnowledgeBank(
      questions: questions,
      tasks: tasks,
      sessionTitles: titles,
    );
  }

  /// Lädt die öffentlichen Fragen aus [bundle] und – nur mit Freigabe – die
  /// Musterantworten aus [lectureBundle] ([lectureFiles]: Pfade ohne
  /// `assets/`). Fehlerhafte Dateien werden protokolliert und übergangen.
  static Future<KnowledgeBank> load({
    AssetBundle? bundle,
    AssetBundle? lectureBundle,
    List<String> lectureFiles = const [],
  }) async {
    final parts = <KnowledgeBank>[];

    try {
      final index = jsonDecode(
        await (bundle ?? rootBundle).loadString("$root/index.json"),
      );

      for (final file in (index as Map)["files"] as List) {
        try {
          parts.add(
            parse(
              Map<String, dynamic>.from(
                jsonDecode(
                      await (bundle ?? rootBundle).loadString("$root/$file"),
                    )
                    as Map,
              ),
            ),
          );
        } catch (e) {
          debugPrint("Wissensfragen $file nicht lesbar: $e");
        }
      }
    } catch (e) {
      debugPrint("Wissensfragen nicht geladen: $e");
    }

    if (lectureBundle != null) {
      for (final path in lectureFiles) {
        if (!path.startsWith(modelAnswerPrefix) || !path.endsWith(".json")) {
          continue;
        }

        try {
          parts.add(
            parse(
              Map<String, dynamic>.from(
                jsonDecode(await lectureBundle.loadString(path)) as Map,
              ),
            ),
          );
        } catch (e) {
          debugPrint("Musterantworten $path nicht lesbar: $e");
        }
      }
    }

    try {
      return merge(parts);
    } catch (e) {
      debugPrint("Wissensfragen widersprüchlich: $e");
      return KnowledgeBank.empty;
    }
  }
}
