import 'package:cloud_firestore/cloud_firestore.dart';

import '../../local_learning_store.dart';
import 'grammar_question_picker.dart';

/// Einstellungen des Grammatiktrainers. Ohne gespeicherte bzw. bei ungültigen
/// Werten gelten die Defaults des Konstruktors.
class GrammarTrainerSettings {
  static const List<int> allSteps = [1, 2, 3, 4, 5, 6, 7];

  static const List<String> allTypes = GrammarQuestionPicker.types;

  static const List<String> allPronounKinds =
      GrammarQuestionPicker.pronounKinds;

  static const List<String> allComparisonKinds =
      GrammarQuestionPicker.comparisonKinds;

  static const List<String> allMoods = GrammarQuestionPicker.moods;

  final List<int> enabledSteps;
  final List<String> enabledTypes;

  /// Grundform-Feld anzeigen und abfragen?
  final bool showLemmaFieldNoun;
  final bool showLemmaFieldVerb;

  /// Bei Pronomen eine Auswahl des Pronomens statt eines Textfelds.
  final bool showLemmaFieldPronoun;

  /// Unterauswahl der Wortart Pronomen: welche Pronomenarten gefragt werden.
  final List<String> enabledPronounKinds;

  /// Unterauswahl der Adjektivsteigerung: unregelmäßige und/oder
  /// regelmäßige Steigerungen.
  final List<String> enabledComparisonKinds;

  /// Adjektivsteigerung: Zur gesteigerten Form wird die Grundform (griechisch)
  /// und/oder ihre deutsche Übersetzung gefragt; mindestens eins von beiden.
  final bool askComparisonLemma;
  final bool askComparisonTranslation;

  /// Adjektivsteigerung: zusätzlich die Steigerungsstufe bestimmen.
  final bool askComparisonDegree;

  /// Adjektivsteigerung: flektierte Formen vorlegen und Kasus, Numerus und
  /// Genus bestimmen. Ausgeschaltet stehen nur die Tabellenformen zur Wahl.
  final bool askComparisonForm;

  /// Unterauswahl der Wortart Verb: welche Modi gefragt werden (Indikativ,
  /// Imperativ, Infinitiv, Partizip). Eine gespeicherte Auswahl gilt
  /// unverändert: Ein später hinzugekommener Modus bleibt dort
  /// ausgeschaltet, bis er ausgewählt wird.
  final List<String> enabledMoods;

  /// Nomen und Verben: Zur vorgelegten Form wird zusätzlich die deutsche
  /// Übersetzung der Grundform gefragt. Die Adjektivsteigerung hat dafür
  /// ihren eigenen Schalter ([askComparisonTranslation]).
  final bool askLemmaTranslation;

  const GrammarTrainerSettings({
    this.enabledSteps = allSteps,
    this.enabledTypes = allTypes,
    this.enabledPronounKinds = allPronounKinds,
    this.enabledComparisonKinds = allComparisonKinds,
    this.showLemmaFieldNoun = true,
    this.showLemmaFieldVerb = true,
    this.showLemmaFieldPronoun = true,
    this.askComparisonLemma = true,
    this.askComparisonTranslation = true,
    this.askComparisonDegree = true,
    this.askComparisonForm = true,
    this.enabledMoods = allMoods,
    this.askLemmaTranslation = false,
  });

  /// Liest das gespeicherte Feld `greek_grammar_settings`. Unbekannte
  /// Schritte und Wortarten werden verworfen; die Listen sind eigene,
  /// veränderbare Kopien. Eine gespeicherte Wortartenliste gilt unverändert:
  /// später hinzugekommene Wortarten (Pronomen) bleiben dort ausgeschaltet,
  /// bis sie ausgewählt werden. Später hinzugekommene Unterauswahlen (Modi)
  /// und Schalter gelten ohne gespeicherten Wert mit ihrem Default.
  factory GrammarTrainerSettings.fromMap(Object? data) {
    if (data is! Map<String, dynamic>) {
      return GrammarTrainerSettings(
        enabledSteps: List.of(allSteps),
        enabledTypes: List.of(allTypes),
        enabledPronounKinds: List.of(allPronounKinds),
        enabledComparisonKinds: List.of(allComparisonKinds),
        enabledMoods: List.of(allMoods),
      );
    }

    final kinds = data['enabledPronounKinds'];
    final comparisonKinds = data['enabledComparisonKinds'];

    final steps = data['enabledSteps'];
    final types = data['enabledTypes'];
    final lemmaNoun = data['showLemmaFieldNoun'];
    final lemmaVerb = data['showLemmaFieldVerb'];
    final lemmaPronoun = data['showLemmaFieldPronoun'];
    final comparisonLemma = data['askComparisonLemma'];
    final comparisonTranslation = data['askComparisonTranslation'];
    final comparisonDegree = data['askComparisonDegree'];
    final comparisonForm = data['askComparisonForm'];
    final moods = data['enabledMoods'];
    final lemmaTranslation = data['askLemmaTranslation'];

    final askTranslation = comparisonTranslation is bool
        ? comparisonTranslation
        : true;

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
      // Ohne gespeicherte Unterauswahl gelten alle Pronomenarten.
      enabledPronounKinds: kinds is List
          ? kinds.whereType<String>().where(allPronounKinds.contains).toList()
          : List.of(allPronounKinds),
      enabledComparisonKinds: comparisonKinds is List
          ? comparisonKinds
                .whereType<String>()
                .where(allComparisonKinds.contains)
                .toList()
          : List.of(allComparisonKinds),
      showLemmaFieldNoun: lemmaNoun is bool ? lemmaNoun : true,
      showLemmaFieldVerb: lemmaVerb is bool ? lemmaVerb : true,
      showLemmaFieldPronoun: lemmaPronoun is bool ? lemmaPronoun : true,
      askComparisonTranslation: askTranslation,
      askComparisonDegree: comparisonDegree is bool ? comparisonDegree : true,
      askComparisonForm: comparisonForm is bool ? comparisonForm : true,
      // Ohne gespeicherte Unterauswahl gelten alle Modi.
      enabledMoods: moods is List
          ? moods.whereType<String>().where(allMoods.contains).toList()
          : List.of(allMoods),
      askLemmaTranslation: lemmaTranslation is bool ? lemmaTranslation : false,
      // Ohne Übersetzung wird immer die Grundform gefragt.
      askComparisonLemma:
          !askTranslation || (comparisonLemma is bool ? comparisonLemma : true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabledSteps': enabledSteps,
      'enabledTypes': enabledTypes,
      'showLemmaFieldNoun': showLemmaFieldNoun,
      'showLemmaFieldVerb': showLemmaFieldVerb,
      'showLemmaFieldPronoun': showLemmaFieldPronoun,
      'enabledPronounKinds': enabledPronounKinds,
      'enabledComparisonKinds': enabledComparisonKinds,
      'askComparisonLemma': askComparisonLemma,
      'askComparisonTranslation': askComparisonTranslation,
      'askComparisonDegree': askComparisonDegree,
      'askComparisonForm': askComparisonForm,
      'enabledMoods': enabledMoods,
      'askLemmaTranslation': askLemmaTranslation,
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
