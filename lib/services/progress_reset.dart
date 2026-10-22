import '../models/greek/perikope.dart';
import '../models/greek/vocabulary/learning_card.dart';
import '../quiz/books/book_catalog.dart';
import '../quiz/books/book_learning_status.dart';
import 'local_learning_store.dart';

/// Lernbereiche mit eigenem, unabhängig zurücksetzbarem Lernstand.
///
/// Die Zuordnung folgt den tatsächlichen Speichern unter `users/{uid}` bzw.
/// im [LocalLearningStore]; jeder Bereich besitzt eigene Karten. Das
/// Perikopenquiz und „Bücher systematisch lernen“ bilden zusammen die
/// Perikopenkenntnisse, weil der Buchmodus die Karten des Quiz als Startwert
/// liest – getrennt zurückgesetzt würde der Fortschritt dort weiterleben.
enum ProgressArea {
  latinVocabulary(
    label: "Latein-Vokabeln",
    resetTitle: "Latein-Vokabelfortschritt zurücksetzen",
    collection: LocalLearningStore.latinVocabulary,
    documents: [LocalLearningStore.latinVocabularyPlanProgress],
  ),
  latinGrammar(
    label: "Lateinische Grammatik",
    resetTitle: "Grammatikfortschritt (Latein) zurücksetzen",
    collection: null,
    documents: [LocalLearningStore.latinGrammar],
  ),
  greekVocabulary(
    label: "Altgriechisch-Vokabeln",
    resetTitle: "Altgriechischen Vokabelfortschritt zurücksetzen",
    collection: LocalLearningStore.greekVocabulary,
    documents: [LocalLearningStore.greekVocabularyPlanProgress],
  ),
  greekGrammar(
    label: "Altgriechische Grammatik",
    resetTitle: "Grammatikfortschritt (Altgriechisch) zurücksetzen",
    collection: LocalLearningStore.greekGrammar,
  ),
  pericopes(
    label: "Perikopenkenntnisse",
    resetTitle: "Perikopenkenntnisse zurücksetzen",
    collection: LocalLearningStore.perikopen,
    documents: [LocalLearningStore.pericopeBooks],
  ),
  memorization(
    label: "Texte auswendig lernen",
    resetTitle: "Fortschritt beim Auswendiglernen zurücksetzen",
    collection: LocalLearningStore.memorization,
  ),
  churchHistory(
    label: "Kirchengeschichte",
    resetTitle: "Fortschritt in Kirchengeschichte zurücksetzen",
    collection: null,
    documents: [LocalLearningStore.churchHistory],
  ),
  oldTestament(
    label: "Altes Testament",
    resetTitle: "Fortschritt im Alten Testament zurücksetzen",
    collection: null,
    documents: [LocalLearningStore.oldTestament],
  ),
  logic(
    label: "Einführung in die Logik",
    resetTitle: "Fortschritt in „Einführung in die Logik“ zurücksetzen",
    collection: null,
    documents: [LocalLearningStore.logicCourse],
  );

  final String label;
  final String resetTitle;

  /// Die Karten-Collection des Bereichs (null: keine Karten).
  final String? collection;

  /// Dokumente unter `quiz_settings`, die beim Zurücksetzen gelöscht werden.
  final List<String> documents;

  const ProgressArea({
    required this.label,
    required this.resetTitle,
    required this.collection,
    this.documents = const [],
  });

  /// Was beim Zurücksetzen gelöscht wird – für die Bestätigung.
  String get scopeDescription {
    switch (this) {
      case ProgressArea.latinVocabulary:
        return "Die Lernstände aller lateinischen Vokabeln, im Vokabeltrainer "
            "und im Lernplan. Die Einstellungen des Lernplans bleiben "
            "erhalten.";
      case ProgressArea.latinGrammar:
        return "Die Lernstände und Antworten des Grammatiktrainers (Latein). "
            "Die Einstellungen bleiben erhalten.";
      case ProgressArea.greekVocabulary:
        return "Die Lernstände aller altgriechischen Vokabeln.";
      case ProgressArea.greekGrammar:
        return "Die Lernstände des Grammatiktrainers (Altgriechisch).";
      case ProgressArea.pericopes:
        return "Die Lernstände im Perikopenquiz und in „Bücher systematisch "
            "lernen“ für alle Bibelbücher. Verspräzisierungen und Lernpläne "
            "bleiben erhalten.";
      case ProgressArea.memorization:
        return "Die Lernstände aller Abschnitte unter „Texte auswendig "
            "lernen“.";
      case ProgressArea.churchHistory:
        return "Die Lernstände aller Fragen, Merklisten und "
            "Reihenfolge-Aufgaben zur Kirchengeschichte. Die Einstellungen "
            "bleiben erhalten.";
      case ProgressArea.oldTestament:
        return "Die Lernstände aller Fragen, Fachbegriffe, Bibelstellen und "
            "Merklisten zum Alten Testament, einschließlich der Grundlagen "
            "der Bibelkunde (gemeinsamer Lernstand). Die Einstellungen "
            "bleiben erhalten.";
      case ProgressArea.logic:
        return "Welche Lektionen geöffnet oder als bearbeitet markiert sind "
            "und die gespeicherten Antworten zu den Übungen.";
    }
  }
}

/// Was beim Zurücksetzen der Perikopenkenntnisse eines Bibelbuchs geschieht.
///
/// Die Karten des Perikopenquiz gehören zu einer Perikopen-ID, nicht zu
/// einem Buch: „Speisung der Fünftausend“ ist eine Karte für Mt, Mk und Lk.
/// Darum:
///
///   * [exclusiveIds]: Karten, deren ID nur in diesem Buch vorkommt –
///     werden zurückgesetzt.
///   * [sharedIds]: Karten, die auch andere Bücher betreffen – bleiben
///     erhalten, außer mit `includeShared` (dann auch für die anderen
///     Bücher zurückgesetzt).
///   * Buch-Karten von „Bücher systematisch lernen“ (Schlüssel beginnt mit
///     dem Buch): werden zurückgesetzt. Bleibt eine gemeinsame Karte des
///     Quiz erhalten, wird die Perikope markiert, damit sie nicht wieder
///     deren Stand übernimmt ([markerKeys]).
///
/// Die Zuordnung geschieht ausschließlich über die Buchabkürzung der
/// Perikopenliste (`Perikope.book`) und die Perikopen-ID.
class PericopeBookResetPlan {
  final String book;

  final bool includeShared;

  /// Zu löschende Karten des Perikopenquiz (ID → Eselsbrücke oder null).
  final Map<String, String?> resetIds;

  final Set<String> exclusiveIds;

  /// Gemeinsame IDs mit den anderen Büchern, in denen sie vorkommen.
  final Map<String, Set<String>> sharedIds;

  /// Buch-Karten, die ersatzlos entfernt werden.
  final Set<String> deleteKeys;

  /// Buch-Karten, die durch eine leere Markierung ersetzt werden.
  final Set<String> markerKeys;

  const PericopeBookResetPlan({
    required this.book,
    required this.includeShared,
    required this.resetIds,
    required this.exclusiveIds,
    required this.sharedIds,
    required this.deleteKeys,
    required this.markerKeys,
  });

  bool get isEmpty =>
      resetIds.isEmpty && deleteKeys.isEmpty && markerKeys.isEmpty;

  /// Anzahl der zurückgesetzten Perikopen in „Bücher systematisch lernen“.
  int get bookEntries => deleteKeys.length + markerKeys.length;

  /// Andere Bücher, die gemeinsame Karten mit diesem Buch haben.
  Set<String> get otherBooks => {for (final b in sharedIds.values) ...b};

  /// Präfix der Buch-Karten (siehe [BookPericope.keyOf]).
  static String keyPrefix(String book) => "$book|";

  factory PericopeBookResetPlan.build({
    required String book,
    required Iterable<Perikope> perikopen,
    required Map<String, LearningCard> quizCards,
    required Map<String, BookCard> bookCards,
    bool includeShared = false,
  }) {
    // ID → alle Bücher, in denen sie vorkommt.
    final booksOfId = <String, Set<String>>{};

    for (final p in perikopen) {
      booksOfId.putIfAbsent(p.id, () => {}).add(p.book);
    }

    final exclusive = <String>{};
    final shared = <String, Set<String>>{};

    for (final entry in booksOfId.entries) {
      if (!entry.value.contains(book)) continue;
      if (!quizCards.containsKey(entry.key)) continue;

      final others = entry.value.difference({book});

      if (others.isEmpty) {
        exclusive.add(entry.key);
      } else {
        shared[entry.key] = others;
      }
    }

    final reset = {
      for (final id in [...exclusive, if (includeShared) ...shared.keys])
        id: _mnemonicOf(quizCards[id]),
    };

    // Quiz-Karten, die nach dem Zurücksetzen bestehen bleiben und deren
    // Stand der Buchmodus sonst übernehmen würde.
    final keptQuizIds = {
      for (final id in shared.keys)
        if (!includeShared) id,
    };

    final deleteKeys = <String>{};
    final markerKeys = <String>{};

    final prefix = keyPrefix(book);

    for (final key in bookCards.keys) {
      if (key.startsWith(prefix)) deleteKeys.add(key);
    }

    for (final p in BookCatalog.fromPerikopen(perikopen).pericopesOf(book)) {
      if (keptQuizIds.contains(p.id)) {
        markerKeys.add(p.key);
        deleteKeys.remove(p.key);
      }
    }

    return PericopeBookResetPlan(
      book: book,
      includeShared: includeShared,
      resetIds: reset,
      exclusiveIds: exclusive,
      sharedIds: shared,
      deleteKeys: deleteKeys,
      markerKeys: markerKeys,
    );
  }

  static String? _mnemonicOf(LearningCard? card) {
    final mnemonic = card?.mnemonic;
    return mnemonic != null && mnemonic.isNotEmpty ? mnemonic : null;
  }

  /// Inhalt einer Markierung in `pericope_books`.
  static Map<String, dynamic> markerJson(String key) =>
      BookCard(id: key, ignoreEndlessQuiz: true).toJson();
}
