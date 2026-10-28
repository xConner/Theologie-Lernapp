import '../../algorithms/spaced_repetition.dart';
import '../../models/greek/vocabulary/learning_card.dart';
import '../../models/philosophy/reading_text.dart';
import '../local_learning_store.dart';
import '../quiz_documents.dart';
import 'reading_repository.dart';
import 'reading_user_data.dart';

enum ReviewKind {
  /// Fachbegriff aus dem Glossar der Ausgabe (t.t.).
  term("Begriffe"),

  /// Wort aus der eigenen Wortliste.
  word("Wortliste"),

  /// Satz mit Lesezeichen: übersetzen bzw. erklären, dann vergleichen.
  sentence("Markierte Sätze"),

  /// Textkritische Fußnote: Was liest die Ausgabe hier anders als Ross?
  textCritical("Textkritik");

  final String label;

  const ReviewKind(this.label);
}

/// Eine Wiederholungskarte. Gespeichert wird nur der Lernstand unter
/// [id]; Vorder- und Rückseite entstehen jedes Mal aus dem Text und den
/// eigenen Daten.
class ReviewItem {
  final String id;
  final ReviewKind kind;

  /// Satz, an dem die Karte hängt (für Anzeige und Rücksprung).
  final GreekSentence? sentence;
  final GlossaryEntry? glossary;
  final EditionNote? note;
  final WordListEntry? word;

  const ReviewItem({
    required this.id,
    required this.kind,
    this.sentence,
    this.glossary,
    this.note,
    this.word,
  });
}

/// Wiederholung im Lesebereich: Karten aus tatsächlich gelesenen bzw.
/// markierten Stellen und aus dem Glossar, bewertet durch
/// Selbsteinschätzung und geplant mit [SpacedRepetition]. Lernstände liegen
/// in `quiz_settings/philosophy_review` (getrennt von Leseposition und
/// Notizen).
class ReadingReviewStore {
  final QuizCardDocument cards;
  final SpacedRepetition repetition;

  ReadingReviewStore(QuizDocuments documents, {SpacedRepetition? repetition})
    : cards = QuizCardDocument(documents, LocalLearningStore.philosophyReview),
      repetition = repetition ?? SpacedRepetition();

  factory ReadingReviewStore.forUser(String? uid) =>
      ReadingReviewStore(QuizDocuments.forUser(uid));

  /// Alle Karten, die der Text und die eigenen Daten hergeben.
  static List<ReviewItem> items(
    ReadingText text,
    ReadingUserState user, {
    Set<ReviewKind> kinds = const {...ReviewKind.values},
  }) {
    final work = text.work.id;
    final result = <ReviewItem>[];
    if (kinds.contains(ReviewKind.term)) {
      for (final g in text.front.glossary) {
        if (!g.technical || g.renderings.isEmpty) continue;
        result.add(ReviewItem(
          id: "$work|term:${g.id}",
          kind: ReviewKind.term,
          glossary: g,
        ));
      }
    }
    if (kinds.contains(ReviewKind.word)) {
      for (final w in user.words.values) {
        result.add(ReviewItem(
          id: "$work|word:${w.key}",
          kind: ReviewKind.word,
          word: w,
          sentence: text.resolveSentence(w.sentenceId),
        ));
      }
    }
    if (kinds.contains(ReviewKind.sentence)) {
      for (final m in user.bookmarks) {
        final s = text.resolveSentence(m.sentenceId);
        if (s == null) continue;
        result.add(ReviewItem(
          id: "$work|sent:${s.id}",
          kind: ReviewKind.sentence,
          sentence: s,
        ));
      }
    }
    if (kinds.contains(ReviewKind.textCritical)) {
      for (final n in text.allNotes) {
        if (n.kind != EditionNoteKind.textCritical || n.range == null) continue;
        final s = text.sentenceAt(n.range!.from);
        if (s == null) continue;
        result.add(ReviewItem(
          id: "$work|tc:${n.id}",
          kind: ReviewKind.textCritical,
          note: n,
          sentence: s,
        ));
      }
    }
    // Dieselbe Karte nur einmal (z. B. zwei Lesezeichen im selben Satz).
    final seen = <String>{};
    return [
      for (final item in result)
        if (seen.add(item.id)) item,
    ];
  }

  Future<Map<String, LearningCard>> load() => cards.load();

  /// Nächste Karte: höchster Auswahlwert, neue Karten in Textreihenfolge.
  ReviewItem? next(
    List<ReviewItem> items,
    Map<String, LearningCard> state, {
    Set<String> exclude = const {},
  }) {
    ReviewItem? best;
    var bestScore = -1.0;
    for (final item in items) {
      if (exclude.contains(item.id)) continue;
      final card = state[item.id] ?? LearningCard(id: item.id);
      final score = repetition.selectionScore(card);
      if (score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    return best;
  }

  Future<LearningCard> answer(
    ReviewItem item,
    Map<String, LearningCard> state,
    bool known,
  ) async {
    final card = state[item.id] ?? LearningCard(id: item.id);
    repetition.answer(card, known);
    state[item.id] = card;
    await cards.save([card]);
    return card;
  }

  /// Wie viele Karten schon einmal wiederholt wurden.
  static int reviewedCount(
    List<ReviewItem> items,
    Map<String, LearningCard> state,
  ) => items.where((i) => state[i.id]?.lastReviewed != null).length;
}
