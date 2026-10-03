import 'package:cloud_firestore/cloud_firestore.dart';

import '../../local_learning_store.dart';
import 'grammar_question_picker.dart';

/// Einstellungen des Grammatiktrainers. Ohne gespeicherte bzw. bei ungültigen
/// Werten gelten die Defaults des Konstruktors.
class GrammarTrainerSettings {
  static const List<int> allSteps = [1, 2, 3, 4, 5, 6, 7];

  static const List<String> allTypes = GrammarQuestionPicker.types;

  final List<int> enabledSteps;
  final List<String> enabledTypes;

  /// Grundform-Feld anzeigen und abfragen?
  final bool showLemmaFieldNoun;
  final bool showLemmaFieldVerb;

  /// Bei Pronomen eine Auswahl des Pronomens statt eines Textfelds.
  final bool showLemmaFieldPronoun;

  const GrammarTrainerSettings({
    this.enabledSteps = allSteps,
    this.enabledTypes = allTypes,
    this.showLemmaFieldNoun = true,
    this.showLemmaFieldVerb = true,
    this.showLemmaFieldPronoun = true,
  });

  /// Liest das gespeicherte Feld `greek_grammar_settings`. Unbekannte
  /// Schritte und Wortarten werden verworfen; die Listen sind eigene,
  /// veränderbare Kopien. Eine gespeicherte Wortartenliste gilt unverändert:
  /// später hinzugekommene Wortarten (Pronomen) bleiben dort ausgeschaltet,
  /// bis sie ausgewählt werden.
  factory GrammarTrainerSettings.fromMap(Object? data) {
    if (data is! Map<String, dynamic>) {
      return GrammarTrainerSettings(
        enabledSteps: List.of(allSteps),
        enabledTypes: List.of(allTypes),
      );
    }

    final steps = data['enabledSteps'];
    final types = data['enabledTypes'];
    final lemmaNoun = data['showLemmaFieldNoun'];
    final lemmaVerb = data['showLemmaFieldVerb'];
    final lemmaPronoun = data['showLemmaFieldPronoun'];

    return GrammarTrainerSettings(
      enabledSteps: steps is List
          ? (steps
                .whereType<num>()
                .map((step) => step.toInt())
                .where((step) => step >= 1 && step <= 7)
                .toList()
              ..sort())
          : List.of(allSteps),
      enabledTypes: types is List
          ? types.whereType<String>().where(allTypes.contains).toList()
          : List.of(allTypes),
      showLemmaFieldNoun: lemmaNoun is bool ? lemmaNoun : true,
      showLemmaFieldVerb: lemmaVerb is bool ? lemmaVerb : true,
      showLemmaFieldPronoun: lemmaPronoun is bool ? lemmaPronoun : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabledSteps': enabledSteps,
      'enabledTypes': enabledTypes,
      'showLemmaFieldNoun': showLemmaFieldNoun,
      'showLemmaFieldVerb': showLemmaFieldVerb,
      'showLemmaFieldPronoun': showLemmaFieldPronoun,
    };
  }
}

/// uid == null bedeutet Gastmodus (lokale Speicherung).
class GrammarSettingsService {
  // Getter statt Feld: Im Gastmodus (und in Tests) wird Firestore nie berührt.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static const String _group = 'greek_grammar_settings';

  DocumentReference<Map<String, dynamic>> _document(String uid) {
    return firestore.collection('users').doc(uid);
  }

  Future<GrammarTrainerSettings> load(String? uid) async {
    if (uid == null) {
      return GrammarTrainerSettings.fromMap(
        await LocalLearningStore.instance.loadSettingsGroup(_group),
      );
    }

    final data = (await _document(uid).get()).data();

    return GrammarTrainerSettings.fromMap(data?[_group]);
  }

  Future<void> save(String? uid, GrammarTrainerSettings settings) async {
    if (uid == null) {
      return LocalLearningStore.instance.saveSettingsGroup(
        _group,
        settings.toMap(),
      );
    }

    await _document(
      uid,
    ).set({_group: settings.toMap()}, SetOptions(merge: true));
  }
}
