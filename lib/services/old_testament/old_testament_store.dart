import '../../models/greek/vocabulary/learning_card.dart';
import '../local_learning_store.dart';
import '../quiz_documents.dart';
import 'old_testament_quiz.dart';

/// Einstellungen des Lernmodus: zuletzt gewählter Umfang, Aufgabenarten und
/// ob nur schwierige Inhalte geübt werden.
///
/// Gespeichert werden die abgewählten Arten, damit Aufgabenarten, die mit
/// späteren Einheiten hinzukommen, von selbst aktiv sind.
class OldTestamentSettings {
  final String scope;
  final Set<OtQuizKind> disabledKinds;
  final bool onlyDifficult;

  /// Neue Inhalte in der Reihenfolge der Einheiten einführen
  /// (`OldTestamentQuiz.next`, `orderedIntroduction`).
  final bool inOrder;

  const OldTestamentSettings({
    this.scope = "all",
    this.disabledKinds = const {},
    this.onlyDifficult = false,
    this.inOrder = false,
  });

  Set<OtQuizKind> get kinds =>
      OtQuizKind.values.toSet().difference(disabledKinds);

  OldTestamentSettings copyWith({
    String? scope,
    Set<OtQuizKind>? kinds,
    bool? onlyDifficult,
    bool? inOrder,
  }) {
    return OldTestamentSettings(
      scope: scope ?? this.scope,
      disabledKinds: kinds == null
          ? disabledKinds
          : OtQuizKind.values.toSet().difference(kinds),
      onlyDifficult: onlyDifficult ?? this.onlyDifficult,
      inOrder: inOrder ?? this.inOrder,
    );
  }

  /// Ungültige oder fehlende Werte fallen auf die Vorgaben zurück; eine
  /// Auswahl ohne jede Art gilt als „alle“.
  factory OldTestamentSettings.fromMap(Object? raw) {
    if (raw is! Map) return const OldTestamentSettings();

    final disabled = raw["disabledKinds"] is List
        ? {
            for (final k in raw["disabledKinds"] as List)
              ?OtQuizKind.tryParse(k),
          }
        : <OtQuizKind>{};

    return OldTestamentSettings(
      scope: raw["scope"] is String ? raw["scope"] as String : "all",
      disabledKinds: disabled.length == OtQuizKind.values.length
          ? const {}
          : disabled,
      onlyDifficult: raw["onlyDifficult"] == true,
      inOrder: raw["inOrder"] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    "scope": scope,
    "disabledKinds": [
      for (final k in OtQuizKind.values)
        if (disabledKinds.contains(k)) k.name,
    ],
    "onlyDifficult": onlyDifficult,
    "inOrder": inOrder,
  };
}

/// Speicherort des Lernstands im Bereich Altes Testament – wie in der
/// Kirchengeschichte als Dokumente unter `users/{uid}/quiz_settings/`
/// (Gäste lokal über den [LocalLearningStore]):
///
/// ```text
/// old_testament:          cards:    {kartenId: {difficulty, stability, lastReviewed: ms}}
/// old_testament_settings: settings: {scope, disabledKinds, onlyDifficult, inOrder}
/// ```
///
/// Kartenschlüssel sind `<Inhalts-ID>|<Art>`. Neue Einheiten bringen neue
/// IDs mit; vorhandene Karten bleiben unberührt.
class OldTestamentStore {
  final QuizDocuments documents;

  OldTestamentStore(this.documents);

  /// uid == null bedeutet Gastmodus (lokale Speicherung).
  factory OldTestamentStore.forUser(String? uid) => uid == null
      ? LocalOldTestamentStore()
      : OldTestamentStore(FirestoreQuizDocuments(uid));

  static const String _doc = LocalLearningStore.oldTestament;
  static const String _settingsDoc = LocalLearningStore.oldTestamentSettings;

  QuizCardDocument get _cards => QuizCardDocument(documents, _doc);

  Future<Map<String, LearningCard>> loadCards() => _cards.load();

  Future<void> saveCards(Iterable<LearningCard> cards) => _cards.save(cards);

  Future<void> resetCards(Iterable<String> cardIds) => _cards.reset(cardIds);

  Future<OldTestamentSettings> loadSettings() async {
    final doc = await documents.load(_settingsDoc);
    return OldTestamentSettings.fromMap(doc["settings"]);
  }

  Future<void> saveSettings(OldTestamentSettings settings) {
    return documents.replaceField(_settingsDoc, "settings", settings.toMap());
  }
}

/// Gastmodus (lokale Speicherung).
class LocalOldTestamentStore extends OldTestamentStore {
  LocalOldTestamentStore() : super(LocalQuizDocuments());
}
