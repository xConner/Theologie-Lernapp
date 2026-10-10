import 'dart:convert';

import 'package:http/http.dart' as http;

import 'grammar_form_analysis.dart';
import 'verb_paradigm.dart';

class WiktionaryInflectionService {
  static const String _backendBaseUrl = 'https://www.theologie.app';

  // ---------------------------------------------------------------------------
  // AUSNAHMEN FÜR AORIST-FORMEN
  // ---------------------------------------------------------------------------

  /// Bei einigen Verben wird der Aorist über ein anderes Lemma gebildet
  /// (Suppletion). Für diese Fälle muss die API direkt mit dem Aorist-Lemma
  /// abgefragt werden.
  static const Map<String, String> _aoristApiLemmaOverrides = {'λέγω': 'εἶπον'};

  // ---------------------------------------------------------------------------
  // CACHE
  // ---------------------------------------------------------------------------

  /// Bereits erfolgreich geladene Formen, Schlüssel ist die vollständige
  /// Backend-URL (Lemma + alle Parameter).
  ///
  /// Eine Form ist für dieselbe Anfrage immer identisch. Gecacht werden nur
  /// gefundene Formen – „nicht gefunden“ und Fehler werden bei der nächsten
  /// Anfrage erneut versucht. Der Cache ist statisch, damit er auch beim
  /// erneuten Öffnen des Trainers innerhalb derselben Sitzung erhalten bleibt.
  static final Map<String, String> _formCache = {};

  /// Alle grammatisch möglichen Bestimmungen der gelieferten Form, je
  /// Anfrage. Wird zusammen mit der Form geladen, damit die Antwortprüfung
  /// formal identische Formen ohne weitere Anfrage erkennt.
  static final Map<String, List<NounFormAnalysis>> _nounAnalysesCache = {};

  /// Bereits geladene Paradigmen je Grundform. Ein Paradigma ist für
  /// dieselbe Grundform immer identisch; „nicht gefunden“ und Fehler werden
  /// nicht gecacht.
  static final Map<String, VerbParadigm> _paradigmCache = {};

  // ---------------------------------------------------------------------------
  // VERBEN
  // ---------------------------------------------------------------------------

  /// Holt das Paradigma eines Verbs über unser Vercel-Backend: Indikativ
  /// und Imperativ aller Tempora des Trainers sowie die Nominative der
  /// Partizipien, aus denen [VerbParadigm] die Deklination bildet.
  ///
  /// Das Backend übernimmt:
  /// - Wiktionary-Aufruf
  /// - Auswahl der richtigen Flexionstabelle je Tempus
  ///
  /// `null`, wenn es zu dem Verb keine Flexionstabelle gibt.
  Future<VerbParadigm?> getVerbParadigm(String lemma) async {
    final cached = _paradigmCache[lemma];

    if (cached != null) {
      return cached;
    }

    // Bestimmte Verben bilden den Aorist über ein anderes Lemma.
    // Beispiel: λέγω → εἶπον
    final aoristLemma = _aoristApiLemmaOverrides[lemma];

    final uri = Uri.parse('$_backendBaseUrl/api/greek-verb').replace(
      queryParameters: {
        'lemma': lemma,
        'paradigm': '1',
        'aoristLemma': ?aoristLemma,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Backend konnte die Verbformen nicht laden '
        '(HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is! Map<String, dynamic>) {
      throw Exception('Ungültige Antwort vom Verb-Backend.');
    }

    final paradigm = VerbParadigm.fromJson(data['paradigm']);

    if (paradigm.forms.isEmpty) {
      return null;
    }

    _paradigmCache[lemma] = paradigm;

    return paradigm;
  }

  /// Das zuvor mit [getVerbParadigm] geladene Paradigma; `null`, solange es
  /// nicht geladen wurde.
  VerbParadigm? cachedVerbParadigm(String lemma) {
    return _paradigmCache[lemma];
  }

  // ---------------------------------------------------------------------------
  // NOMEN
  // ---------------------------------------------------------------------------

  /// Holt eine flektierte Nominalform über unser Vercel-Backend.
  ///
  /// Das Backend übernimmt:
  /// - Wiktionary-Aufruf
  /// - Auswahl der Nominalflexionstabelle
  /// - Auswahl von Kasus und Numerus
  Future<String?> getNounForm({
    required String lemma,
    required String grammaticalCase,
    required String number,
  }) async {
    final uri = _nounUri(
      lemma: lemma,
      grammaticalCase: grammaticalCase,
      number: number,
    );

    final cacheKey = uri.toString();
    final cached = _formCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    final response = await http.get(uri);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Backend konnte die Nominalform nicht laden '
        '(HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Ungültige Antwort vom Nomen-Backend.');
    }

    final form = data['form'];

    if (form is! String || form.isEmpty) {
      return null;
    }

    _formCache[cacheKey] = form;
    _nounAnalysesCache[cacheKey] = parseNounFormAnalyses(data['analyses']);

    return form;
  }

  /// Bestimmungen, die für die zuvor mit [getNounForm] geladene Form möglich
  /// sind. Leer, wenn die Form nicht geladen wurde oder das Backend keine
  /// Angaben liefert.
  List<NounFormAnalysis> nounFormAnalyses({
    required String lemma,
    required String grammaticalCase,
    required String number,
  }) {
    final uri = _nounUri(
      lemma: lemma,
      grammaticalCase: grammaticalCase,
      number: number,
    );

    return _nounAnalysesCache[uri.toString()] ?? const [];
  }

  Uri _nounUri({
    required String lemma,
    required String grammaticalCase,
    required String number,
  }) {
    return Uri.parse('$_backendBaseUrl/api/greek-noun').replace(
      queryParameters: {
        'lemma': lemma,
        'case': grammaticalCase,
        'number': number,
      },
    );
  }
}
