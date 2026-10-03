import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../models/greek/grammar/pronoun_paradigm.dart';
import '../../../utils/greek_normalization.dart';
import 'grammar_form_analysis.dart';

/// Die lokal gespeicherten Pronomen-Paradigmen. Anders als bei Nomen und
/// Verben kommen Formen und mögliche Bestimmungen nicht vom Backend, sondern
/// aus `assets/greek_pronoun_forms.json`.
class PronounParadigms {
  final List<PronounParadigm> all;

  const PronounParadigms(this.all);

  static const PronounParadigms empty = PronounParadigms([]);

  factory PronounParadigms.fromJson(String jsonString) {
    final List<dynamic> json = jsonDecode(jsonString);

    return PronounParadigms([
      for (final item in json) PronounParadigm.fromJson(item),
    ]);
  }

  static Future<PronounParadigms> load() async {
    return PronounParadigms.fromJson(
      await rootBundle.loadString("assets/greek_pronoun_forms.json"),
    );
  }

  PronounParadigm? byId(int id) {
    for (final paradigm in all) {
      if (paradigm.id == id) return paradigm;
    }

    return null;
  }

  PronounParadigm? byLabel(String? label) {
    for (final paradigm in all) {
      if (paradigm.label == label) return paradigm;
    }

    return null;
  }

  /// Alle grammatisch möglichen Bestimmungen der Form – über alle Pronomen
  /// hinweg (ἐμοῦ: Genitiv von ἐγώ und von ἐμός). Verglichen wird die exakte
  /// Schreibung: Akzent und Spiritus unterscheiden hier Wörter (τίνα / τινα,
  /// αὕτη / αὐτή) und dürfen deshalb nicht normalisiert werden.
  List<PronounFormAnalysis> analysesOf(String form) {
    final analyses = <PronounFormAnalysis>[];

    for (final paradigm in all) {
      for (final cell in paradigm.cells) {
        if (cell.forms.any((f) => f.text == form)) {
          analyses.add((
            pronounId: paradigm.id,
            grammaticalCase: cell.grammaticalCase,
            number: cell.number,
            gender: cell.gender,
          ));
        }
      }
    }

    return analyses;
  }

  /// Bezeichnung der Formvariante ("enklitisch"), falls die Form eine ist.
  String? variantOf(String form) {
    for (final paradigm in all) {
      for (final cell in paradigm.cells) {
        for (final f in cell.forms) {
          if (f.text == form && f.variant != null) return f.variant;
        }
      }
    }

    return null;
  }

  /// Formen, die sich von [form] nur in Akzent oder Spiritus unterscheiden,
  /// aber etwas anderes bedeuten: andere Pronominalformen ("αὐτή (αὐτός)")
  /// und die in den Daten hinterlegten Wörter außerhalb der Pronomen
  /// ("ὁ (Artikel)").
  List<String> lookalikesOf(String form) {
    final plain = _withoutAccents(form);
    final own = _analysisKeys(form);
    final result = <String>[];

    for (final paradigm in all) {
      for (final cell in paradigm.cells) {
        for (final f in cell.forms) {
          if (f.text == form || _withoutAccents(f.text) != plain) {
            continue;
          }

          // Bloße Varianten derselben Bestimmung (σοῦ / σου bei σύ) sind
          // keine Verwechslung.
          if (own.contains(_key(paradigm.id, cell))) {
            continue;
          }

          final hint = "${f.text} (${paradigm.lemma})";

          if (!result.contains(hint)) {
            result.add(hint);
          }
        }
      }
    }

    for (final paradigm in all) {
      if (paradigm.cells.any((c) => c.forms.any((f) => f.text == form))) {
        for (final hint in paradigm.lookalikes[form] ?? const <String>[]) {
          if (!result.contains(hint)) {
            result.add(hint);
          }
        }
      }
    }

    return result;
  }

  static final RegExp _iotaSubscript = RegExp('[ᾀ-ᾯᾲ-ᾴᾷῂ-ῄῇῲ-ῴῷ]');

  /// Die Form ohne Akzente und Spiritus. Das Iota subscriptum bleibt als
  /// Buchstabe erhalten: ἥ und ᾗ oder αὐτή und αὐτῇ sind keine bloßen
  /// Akzentvarianten.
  static String _withoutAccents(String form) {
    return form.split("").map((char) {
      final plain = normalizeGreekForComparison(char);

      return _iotaSubscript.hasMatch(char) ? "$plainι" : plain;
    }).join();
  }

  String _key(int pronounId, PronounCell cell) {
    return "$pronounId|${cell.grammaticalCase}|${cell.number}|${cell.gender}";
  }

  Set<String> _analysisKeys(String form) {
    return {
      for (final paradigm in all)
        for (final cell in paradigm.cells)
          if (cell.forms.any((f) => f.text == form)) _key(paradigm.id, cell),
    };
  }
}
