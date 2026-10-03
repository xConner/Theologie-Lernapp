import 'dart:convert';

import 'package:http/http.dart' as http;

import 'grammar_form_analysis.dart';

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
  static final Map<String, List<VerbFormAnalysis>> _verbAnalysesCache = {};

  // ---------------------------------------------------------------------------
  // VERBEN
  // ---------------------------------------------------------------------------

  /// Holt eine flektierte Verbform über unser Vercel-Backend.
  ///
  /// Das Backend übernimmt:
  /// - Wiktionary-Aufruf
  /// - Auswahl der richtigen Flexionstabelle
  /// - Auswahl von Tempus
  /// - Auswahl von Aktiv / Medium-Passiv
  /// - Auswahl von Person und Numerus
  Future<String?> getVerbForm({
    required String lemma,
    required String tense,
    required String voice,
    required String number,
    required int person,
  }) async {
    final uri = _verbUri(
      lemma: lemma,
      tense: tense,
      voice: voice,
      number: number,
      person: person,
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
        'Backend konnte die Verbform nicht laden '
        '(HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Ungültige Antwort vom Verb-Backend.');
    }

    final form = data['form'];

    if (form is! String || form.isEmpty) {
      return null;
    }

    _formCache[cacheKey] = form;
    _verbAnalysesCache[cacheKey] = parseVerbFormAnalyses(data['analyses']);

    return form;
  }

  /// Bestimmungen, die für die zuvor mit [getVerbForm] geladene Form möglich
  /// sind. Leer, wenn die Form nicht geladen wurde oder das Backend keine
  /// Angaben liefert.
  List<VerbFormAnalysis> verbFormAnalyses({
    required String lemma,
    required String tense,
    required String voice,
    required String number,
    required int person,
  }) {
    final uri = _verbUri(
      lemma: lemma,
      tense: tense,
      voice: voice,
      number: number,
      person: person,
    );

    return _verbAnalysesCache[uri.toString()] ?? const [];
  }

  Uri _verbUri({
    required String lemma,
    required String tense,
    required String voice,
    required String number,
    required int person,
  }) {
    // Für den Aorist können bestimmte Verben ein anderes Lemma benötigen.
    // Beispiel: λέγω → εἶπον
    final apiLemma = tense == 'Aorist'
        ? (_aoristApiLemmaOverrides[lemma] ?? lemma)
        : lemma;

    return Uri.parse('$_backendBaseUrl/api/greek-verb').replace(
      queryParameters: {
        'lemma': apiLemma,
        'tense': tense,
        'voice': voice,
        'number': number,
        'person': person.toString(),
      },
    );
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
