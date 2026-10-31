import 'proof_rules.dart';

/// Eine Zeile eines angefangenen Beweises im Beweiseditor.
///
/// [id] ist die stabile Identität der Zeile. Der Bezeichner (α, β, … für
/// Annahmen, 1, 2, … für alle anderen Zeilen) ergibt sich dagegen aus der
/// Position und ändert sich beim Verschieben – siehe [ProofLineOrder].
class ProofDraftLine {
  final String id;
  final ProofRule? rule;
  final String formula;
  final String refs;
  final String deps;
  final String comment;

  const ProofDraftLine({
    required this.id,
    this.rule,
    this.formula = "",
    this.refs = "",
    this.deps = "",
    this.comment = "",
  });

  bool get isAssumption => rule == ProofRule.assumption;

  bool get isEmpty =>
      formula.trim().isEmpty &&
      refs.trim().isEmpty &&
      deps.trim().isEmpty &&
      comment.trim().isEmpty;

  /// Liest eine gespeicherte Zeile; null, wenn der Eintrag unbrauchbar ist.
  /// Fehlt die ID (oder ist sie doppelt), vergibt [freshId] eine neue.
  static ProofDraftLine? fromJson(Object? raw, String Function() freshId) {
    if (raw is! Map) return null;
    String text(String key) {
      final v = raw[key];
      return v is String ? v : "";
    }

    final id = raw["id"];
    final ruleName = raw["rule"];
    ProofRule? rule;
    if (ruleName is String) {
      for (final r in ProofRule.values) {
        if (r.name == ruleName) rule = r;
      }
    }
    return ProofDraftLine(
      id: id is String && id.isNotEmpty ? id : freshId(),
      rule: rule,
      formula: text("f"),
      refs: text("r"),
      deps: text("d"),
      comment: text("c"),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    if (rule != null) "rule": rule!.name,
    if (formula.isNotEmpty) "f": formula,
    if (refs.isNotEmpty) "r": refs,
    if (deps.isNotEmpty) "d": deps,
    if (comment.isNotEmpty) "c": comment,
  };
}

/// Ein gespeicherter, angefangener (oder fertiger) Beweis: die Zeilen in
/// ihrer aktuellen Reihenfolge.
///
/// Gespeichert im Logik-Dokument unter `proofs.{schlüssel}`:
///
/// ```text
/// proofs: {übungsId: {lines: [{id, rule, f, r, d, c}, …], at: ms}}
/// ```
///
/// Die Reihenfolge der Liste ist die Reihenfolge des Beweises.
class ProofDraft {
  final List<ProofDraftLine> lines;
  final DateTime? at;

  const ProofDraft({required this.lines, this.at});

  bool get isEmpty => lines.every((l) => l.isEmpty);

  static int _seq = 0;

  /// Neue, stabile Zeilen-ID.
  static String newLineId() =>
      "${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_seq++).toRadixString(36)}";

  static ProofDraft? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final list = raw["lines"];
    if (list is! List) return null;
    final seen = <String>{};
    final lines = <ProofDraftLine>[];
    for (final item in list) {
      var line = ProofDraftLine.fromJson(item, newLineId);
      if (line == null) continue;
      if (!seen.add(line.id)) {
        line = ProofDraftLine(
          id: newLineId(),
          rule: line.rule,
          formula: line.formula,
          refs: line.refs,
          deps: line.deps,
          comment: line.comment,
        );
        seen.add(line.id);
      }
      lines.add(line);
    }
    if (lines.isEmpty) return null;
    final at = raw["at"];
    return ProofDraft(
      lines: lines,
      at: at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    "lines": [for (final l in lines) l.toJson()],
    "at": (at ?? DateTime.now()).millisecondsSinceEpoch,
  };
}

/// Reihenfolge und Bezeichner der Beweiszeilen.
///
/// Die Bezeichner hängen von der Position ab. Verschiebt, löscht oder
/// ergänzt man Zeilen, ändern sie sich; damit die Verweise („Zeilen“) und
/// Abhängigkeiten weiter auf dieselben Zeilen zeigen, werden sie über die
/// stabilen IDs umgeschrieben ([relabel], [rewrite]).
class ProofLineOrder {
  ProofLineOrder._();

  /// Bezeichner in der Reihenfolge der Zeilen: Annahmen α, β, γ, …, alle
  /// anderen Zeilen 1, 2, 3, ….
  static List<String> labels(Iterable<bool> assumptions) {
    var greek = 0;
    var number = 0;
    return [
      for (final a in assumptions)
        a ? ProofLabels.greek[(greek++) % ProofLabels.greek.length] : "${++number}",
    ];
  }

  /// Alter Bezeichner → neuer Bezeichner derselben Zeile (über die ID).
  /// Gelöschte Zeilen werden auf null abgebildet.
  static Map<String, String?> relabel(
    List<({String id, bool assumption})> before,
    List<({String id, bool assumption})> after,
  ) {
    final oldLabels = labels(before.map((l) => l.assumption));
    final newLabels = labels(after.map((l) => l.assumption));
    final newById = {for (var i = 0; i < after.length; i++) after[i].id: newLabels[i]};
    return {for (var i = 0; i < before.length; i++) oldLabels[i]: newById[before[i].id]};
  }

  /// true, wenn [map] mindestens einen Bezeichner verändert.
  static bool changes(Map<String, String?> map) => map.entries.any((e) => e.key != e.value);

  /// Schreibt eine Verweisliste („α, 1“) nach [map] um. Verweise auf
  /// gelöschte Zeilen werden zu „?“, damit die Prüfung sie meldet;
  /// Unbekanntes bleibt stehen. Ändert sich nichts, bleibt der Text
  /// unverändert (auch die Schreibweise).
  static String rewrite(String text, Map<String, String?> map) {
    if (text.trim().isEmpty) return text;
    final tokens = ProofLabels.parseList(text);
    var changed = false;
    final out = <String>[];
    for (final t in tokens) {
      if (map.containsKey(t)) {
        final n = map[t] ?? "?";
        if (n != t) changed = true;
        out.add(n);
      } else {
        out.add(t);
      }
    }
    return changed ? out.join(", ") : text;
  }

  /// Liste mit dem Element an [from] an der Position [to] (Zielindex in der
  /// neuen Liste).
  static List<T> moved<T>(List<T> list, int from, int to) {
    final result = [...list];
    final item = result.removeAt(from);
    result.insert(to.clamp(0, result.length), item);
    return result;
  }
}
