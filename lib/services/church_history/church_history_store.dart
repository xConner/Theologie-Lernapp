import '../../models/greek/vocabulary/learning_card.dart';
import '../local_learning_store.dart';
import '../quiz_documents.dart';
import 'church_history_quiz.dart';

/// Einstellungen des Lernbereichs: zuletzt gewählter Umfang, Aufgabenarten
/// und ob nur schwierige Inhalte geübt werden.
class ChurchHistorySettings {
  final String scope;
  final Set<QuizKind> kinds;
  final bool onlyDifficult;

  /// Neue Inhalte in Vorlesungsreihenfolge einführen
  /// (`ChurchHistoryQuiz.next`, `orderedIntroduction`).
  final bool inOrder;

  ChurchHistorySettings({
    this.scope = "all",
    Set<QuizKind>? kinds,
    this.onlyDifficult = false,
    this.inOrder = false,
  }) : kinds = kinds ?? QuizKind.values.toSet();

  ChurchHistorySettings copyWith({
    String? scope,
    Set<QuizKind>? kinds,
    bool? onlyDifficult,
    bool? inOrder,
  }) {
    return ChurchHistorySettings(
      scope: scope ?? this.scope,
      kinds: kinds ?? this.kinds,
      onlyDifficult: onlyDifficult ?? this.onlyDifficult,
      inOrder: inOrder ?? this.inOrder,
    );
  }

  /// Ungültige oder fehlende Werte fallen auf die Vorgaben zurück.
  factory ChurchHistorySettings.fromMap(Object? raw) {
    if (raw is! Map) return ChurchHistorySettings();

    final kinds = raw["kinds"] is List
        ? {
            for (final k in raw["kinds"] as List)
              if (QuizKind.tryParse(k) != null) QuizKind.tryParse(k)!,
          }
        : null;

    return ChurchHistorySettings(
      scope: raw["scope"] is String ? raw["scope"] as String : "all",
      kinds: kinds == null || kinds.isEmpty ? null : kinds,
      onlyDifficult: raw["onlyDifficult"] == true,
      inOrder: raw["inOrder"] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    "scope": scope,
    "kinds": [
      for (final k in QuizKind.values)
        if (kinds.contains(k)) k.name,
    ],
    "onlyDifficult": onlyDifficult,
    "inOrder": inOrder,
  };
}

/// Speicherort des Lernstands im Bereich Kirchengeschichte.
///
/// Kein eigenes Speichersystem: wie der lateinische Grammatiktrainer als
/// Dokumente unter `users/{uid}/quiz_settings/` (Gäste lokal über den
/// [LocalLearningStore]). Die Inhalte selbst liegen als Assets in der App;
/// gespeichert werden nur die Lernkarten (Schlüssel `<Inhalt>|<Art>`) und
/// die Einstellungen:
///
/// ```text
/// church_history:          cards:    {kartenId: {difficulty, stability, lastReviewed: ms}}
/// church_history_settings: settings: {scope, kinds, onlyDifficult, inOrder}
/// ```
///
/// Zurückgesetzt wird über `ProgressArea.churchHistory` (nur
/// `church_history`; die Einstellungen bleiben) oder je Umfang
/// ([resetCards]).
class ChurchHistoryStore {
  final QuizDocuments documents;

  ChurchHistoryStore(this.documents);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory ChurchHistoryStore.forUser(String? uid) => uid == null
      ? LocalChurchHistoryStore()
      : ChurchHistoryStore(FirestoreQuizDocuments(uid));

  static const String _doc = LocalLearningStore.churchHistory;
  static const String _settingsDoc = LocalLearningStore.churchHistorySettings;

  QuizCardDocument get _cards => QuizCardDocument(documents, _doc);

  Future<Map<String, LearningCard>> loadCards() => _cards.load();

  Future<void> saveCards(Iterable<LearningCard> cards) => _cards.save(cards);

  Future<void> resetCards(Iterable<String> cardIds) => _cards.reset(cardIds);

  Future<ChurchHistorySettings> loadSettings() async {
    final doc = await documents.load(_settingsDoc);
    return ChurchHistorySettings.fromMap(doc["settings"]);
  }

  Future<void> saveSettings(ChurchHistorySettings settings) {
    return documents.replaceField(_settingsDoc, "settings", settings.toMap());
  }
}

/// Gastmodus (lokale Speicherung).
class LocalChurchHistoryStore extends ChurchHistoryStore {
  LocalChurchHistoryStore() : super(LocalQuizDocuments());
}
