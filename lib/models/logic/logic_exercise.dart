import 'lesson_text.dart';

/// Herkunft einer Übung.
enum ExerciseOrigin {
  /// Kursübung: inhaltlich nach einer Übung des Kurses, abgewandelt.
  course("Kursübung"),

  /// Zusätzliche Übung des Lernbereichs.
  extra("Zusatzübung"),

  /// Automatisch erzeugt und vor der Anzeige geprüft.
  generated("Erzeugte Übung");

  final String label;

  const ExerciseOrigin(this.label);
}

/// Eine Übung. Jede Art hat eine eindeutig prüfbare Lösung – bis auf
/// [OpenExercise], die ausdrücklich als offene Aufgabe gekennzeichnet ist.
sealed class LogicExercise {
  /// Stabile ID (z. B. `l2.k1.c`), bei erzeugten Übungen null.
  final String? id;

  final ExerciseOrigin origin;

  /// Gruppierung in der Übersicht, z. B. „Übung 1“.
  final String group;

  /// Ergänzende Aufgabenstellung oder Hinweis.
  final String? note;

  const LogicExercise({
    required this.id,
    required this.origin,
    required this.group,
    this.note,
  });

  /// Kurze Beschreibung der Aufgabe für Listen.
  String get summary;

  static LogicExercise fromJson(Map<String, dynamic> json, {String group = ""}) {
    final id = json["id"] as String?;
    final origin = ExerciseOrigin.values.byName(
      (json["origin"] as String?) ?? "course",
    );
    final note = json["note"] as String?;
    final g = (json["group"] as String?) ?? group;

    switch (json["type"]) {
      case "wellFormed":
        return WellFormedExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          expression: json["expression"] as String,
          predicateLogic: json["pl"] == true,
        );
      case "truthTable":
        return TruthTableExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          formula: json["formula"] as String,
          classify: json["classify"] != false,
          models: json["models"] != false,
        );
      case "evaluate":
        return EvaluateExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          formula: json["formula"] as String,
          interpretation: {
            for (final e in (json["interpretation"] as Map).entries)
              e.key as String: e.value == 1 || e.value == true,
          },
        );
      case "entailment":
        return EntailmentExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          theorem: json["theorem"] as String,
          argument: json["argument"] as String?,
        );
      case "findPremises":
        return FindPremisesExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          thesis: json["thesis"] as String,
          count: (json["count"] as int?) ?? 2,
          sample: List<String>.from(json["sample"] as List),
        );
      case "proof":
        return ProofExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          theorem: json["theorem"] as String,
          system: json["system"] as String,
          solution: [
            for (final row in json["solution"] as List)
              ProofRow(
                row[0] as String,
                row[1] as String,
                row[2] as String,
                row.length > 3 ? row[3] as String : "",
              ),
          ],
          plan: json["plan"] as String?,
        );
      case "choice":
        return ChoiceExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          question: json["question"] as String,
          options: [
            for (final o in json["options"] as List)
              ChoiceOption(
                o["text"] as String,
                correct: o["correct"] == true,
                feedback: o["feedback"] as String?,
              ),
          ],
          explanation: json["explanation"] as String?,
          tree: json["tree"] as String?,
        );
      case "open":
        return OpenExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          question: json["question"] as String,
          sample: json["sample"] as String,
        );
      case "formalize":
        return FormalizeExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          sentence: json["sentence"] as String,
          key: Map<String, String>.from(json["key"] as Map),
          expected: json["expected"] as String,
          explanation: json["explanation"] as String?,
        );
      case "freeVariables":
        return FreeVariablesExercise(
          id: id,
          origin: origin,
          group: g,
          note: note,
          expression: json["expression"] as String,
        );
      default:
        throw FormatException("Unbekannter Übungstyp ${json["type"]}");
    }
  }
}

/// Ist der Ausdruck ein Satz? (Definition 1.2 bzw. 7.4, Klammerersparnis)
class WellFormedExercise extends LogicExercise {
  final String expression;
  final bool predicateLogic;

  const WellFormedExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.expression,
    this.predicateLogic = false,
  });

  @override
  String get summary => "Satz oder nicht? $expression";
}

/// Wahrheitstafel aufstellen, Satz einordnen, Modelle bestimmen.
class TruthTableExercise extends LogicExercise {
  final String formula;
  final bool classify;
  final bool models;

  const TruthTableExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.formula,
    this.classify = true,
    this.models = true,
  });

  @override
  String get summary => "Wahrheitstafel: $formula";
}

/// Wahrheitswert unter einer Interpretation bestimmen.
class EvaluateExercise extends LogicExercise {
  final String formula;
  final Map<String, bool> interpretation;

  const EvaluateExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.formula,
    required this.interpretation,
  });

  @override
  String get summary => "Wahrheitswert: $formula";
}

/// Ist das Theorem gültig? Falls nicht: Gegenbeispiel angeben.
class EntailmentExercise extends LogicExercise {
  final String theorem;

  /// Beispielhafte alltagssprachliche Begründung (bei gültigen Theoremen).
  final String? argument;

  const EntailmentExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.theorem,
    this.argument,
  });

  @override
  String get summary => "Gültig? $theorem";
}

/// Voraussetzungen P1, …, Pn finden: gültig, verschieden, keine überflüssig.
class FindPremisesExercise extends LogicExercise {
  final String thesis;
  final int count;

  /// Eine mögliche Lösung.
  final List<String> sample;

  const FindPremisesExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.thesis,
    required this.count,
    required this.sample,
  });

  @override
  String get summary =>
      "${[for (var i = 1; i <= count; i++) "P$i"].join(", ")} ⊢ $thesis";
}

class ProofExercise extends LogicExercise {
  final String theorem;

  /// `ProofSystem.id`
  final String system;

  /// Geprüfte Musterlösung.
  final List<ProofRow> solution;

  /// Beweisidee (Plan), optional.
  final String? plan;

  const ProofExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.theorem,
    required this.system,
    required this.solution,
    this.plan,
  });

  @override
  String get summary => "Beweis: $theorem";
}

class ChoiceOption {
  final String text;
  final bool correct;
  final String? feedback;

  const ChoiceOption(this.text, {required this.correct, this.feedback});
}

/// Auswahlaufgabe (eine oder mehrere richtige Antworten).
class ChoiceExercise extends LogicExercise {
  final String question;
  final List<ChoiceOption> options;
  final String? explanation;

  /// Satz, dessen Syntaxbaum nach der Antwort gezeigt wird.
  final String? tree;

  const ChoiceExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.question,
    required this.options,
    this.explanation,
    this.tree,
  });

  bool get multiple => options.where((o) => o.correct).length != 1;

  @override
  String get summary => question;
}

/// Offene Aufgabe: eigene Antwort, Vergleich mit einer Musterantwort und
/// Selbsteinschätzung. Wird nicht automatisch bewertet.
class OpenExercise extends LogicExercise {
  final String question;
  final String sample;

  const OpenExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.question,
    required this.sample,
  });

  @override
  String get summary => question;
}

/// Alltagssprachlichen Satz aussagenlogisch formalisieren. Bewertet wird
/// über logische Äquivalenz mit der erwarteten Formalisierung.
class FormalizeExercise extends LogicExercise {
  final String sentence;

  /// Satzbuchstabe → Bedeutung.
  final Map<String, String> key;

  final String expected;
  final String? explanation;

  const FormalizeExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.sentence,
    required this.key,
    required this.expected,
    this.explanation,
  });

  @override
  String get summary => "Formalisieren: $sentence";
}

/// PL: Satz oder Satzfunktion? Welche Variablen sind frei?
class FreeVariablesExercise extends LogicExercise {
  final String expression;

  const FreeVariablesExercise({
    required super.id,
    required super.origin,
    required super.group,
    super.note,
    required this.expression,
  });

  @override
  String get summary => "Satz oder Satzfunktion? $expression";
}
