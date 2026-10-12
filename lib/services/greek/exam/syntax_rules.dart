import '../../../models/greek/exam/corpus_token.dart';
import 'greek_form_key.dart';
import 'phenomenon_detection.dart';

/// Regelbasierte Erkennung von Satzkonstruktionen auf Grundlage der
/// morphologischen Bestimmungen (ohne Syntaxbaum).
///
/// Die Regeln sind bewusst einfach und nachvollziehbar; sie markieren ihre
/// Belegformen, damit ein Treffer im Text überprüft werden kann. Weil sie
/// Konstruktionen übersehen oder falsch zuordnen können, gelten die
/// zugehörigen Phänomene als „heuristisch“ und lassen sich nur fordern,
/// nicht ausschließen (siehe `grammar_phenomena.dart`).
///
/// Alle Regeln arbeiten innerhalb eines Verses; Konstruktionen über eine
/// Versgrenze hinweg werden nicht erkannt.
class SyntaxRules {
  SyntaxRules._();

  // ---------------------------------------------------------------------------
  // WORTLISTEN
  // ---------------------------------------------------------------------------

  /// Nachgestellte Partikeln, die zwischen Artikel und Bezugswort stehen.
  static const List<String> postpositives = [
    "δέ",
    "γάρ",
    "οὖν",
    "μέν",
    "τε",
    "γε",
  ];

  /// Verben, deren Objekt im Genitiv steht (ἤκουσαν αὐτοῦ λαλοῦντος ist
  /// kein Genitivus absolutus).
  static const List<String> genitiveVerbs = [
    "ἀκούω",
    "ἅπτω",
    "ἄρχω",
    "κρατέω",
    "μιμνῄσκομαι",
    "μνημονεύω",
    "ἐπιθυμέω",
    "γεύομαι",
    "ἐπιλανθάνομαι",
    "κατηγορέω",
    "μετέχω",
    "φείδομαι",
    "ἀντέχω",
    "ἐπιμελέομαι",
    "δέομαι",
    "κυριεύω",
    "κατακυριεύω",
    "ἀνέχω",
    "πυνθάνομαι",
    "τυγχάνω",
    "ἐπιτυγχάνω",
    "καταφρονέω",
    "ὀρέγω",
  ];

  /// Verben des Sagens, Meinens und Wahrnehmens (ὅτι-Satz, AcI, indirekte
  /// Frage).
  static const List<String> speechVerbs = [
    "λέγω",
    "φημί",
    "λαλέω",
    "οἶδα",
    "γινώσκω",
    "ἐπιγινώσκω",
    "ἀκούω",
    "ὁράω",
    "βλέπω",
    "θεωρέω",
    "πιστεύω",
    "ὁμολογέω",
    "μαρτυρέω",
    "ἀπαγγέλλω",
    "ἀναγγέλλω",
    "γράφω",
    "νομίζω",
    "δοκέω",
    "ἡγέομαι",
    "μανθάνω",
    "ἀναγινώσκω",
    "ἐρωτάω",
    "ἐπερωτάω",
    "πυνθάνομαι",
    "κηρύσσω",
    "διδάσκω",
    "ἐπίσταμαι",
    "συνίημι",
    "λογίζομαι",
    "ἀποκρίνομαι",
    "κράζω",
    "ἐλπίζω",
    "θαυμάζω",
    "μιμνῄσκομαι",
  ];

  /// Verben und unpersönliche Ausdrücke, nach denen ein AcI steht.
  static const List<String> aciGovernors = [
    "λέγω",
    "φημί",
    "νομίζω",
    "δοκέω",
    "ἡγέομαι",
    "οἴομαι",
    "ὑπολαμβάνω",
    "ὁμολογέω",
    "ἐλπίζω",
    "κελεύω",
    "ἐάω",
    "ἀξιόω",
    "παρακαλέω",
    "δεῖ",
    "ἔξεστι",
    "ἔξεστιν",
    "γίνομαι",
    "συμφέρω",
    "πρέπω",
    "λογίζομαι",
    "κρίνω",
    "ἐπιτρέπω",
    "προστάσσω",
    "πείθω",
  ];

  /// Verben, die einen Infinitiv als Ergänzung bei sich haben.
  static const List<String> infinitiveGovernors = [
    "δύναμαι",
    "θέλω",
    "βούλομαι",
    "μέλλω",
    "ἄρχω",
    "δεῖ",
    "ἔξεστι",
    "ἔξεστιν",
    "ὀφείλω",
    "ζητέω",
    "τολμάω",
    "ἐπιθυμέω",
    "σπουδάζω",
    "προστίθημι",
    "παύω",
  ];

  /// Konjunktionen und Wörter, die einen Nebensatz einleiten.
  static const List<String> subordinators = [
    "ἵνα",
    "ὅπως",
    "ἐάν",
    "ὅταν",
    "ἄν",
    "ἕως",
    "πρίν",
    "μήποτε",
    "ὅστις",
    "ὅς",
    "εἰ",
    "ὅτι",
    "ἐπάν",
    "ἄχρι",
    "μέχρι",
    "ὡς",
    "καθώς",
    "ὥστε",
  ];

  static const List<String> interrogatives = [
    "τίς",
    "πῶς",
    "ποῦ",
    "πόθεν",
    "πότε",
    "ποῖος",
    "πόσος",
    "πηλίκος",
  ];

  // ---------------------------------------------------------------------------
  // HILFSFUNKTIONEN
  // ---------------------------------------------------------------------------

  static AnalysisTest _lemma(List<String> lemmas) {
    final keys = {for (final l in lemmas) greekFormKey(l)};
    return (a) => keys.contains(greekFormKey(a.lemma));
  }

  static final AnalysisTest _isArticle = MorphPattern.article.matches;
  static final AnalysisTest _isPreposition = MorphPattern.preposition.matches;
  static final AnalysisTest _isPostpositive = _lemma(postpositives);

  static bool _isFinite(LemmaAnalysis a) => a.analysis.isFinite;

  static bool _isNominal(LemmaAnalysis a) => MorphPattern.nominal.matches(a);

  /// Die Form vor [i], nachgestellte Partikeln übersprungen.
  static int _previous(DetectionView v, int i) {
    var j = i - 1;
    while (j >= 0 && v.holds(j, _isPostpositive)) {
      j--;
    }
    return j;
  }

  /// Ob die Form [k] nach einer Präposition steht (auch über einen Artikel
  /// hinweg: ἐκ τοῦ ὄχλου).
  static bool _governedByPreposition(DetectionView v, int k) {
    final j = k - 1;

    if (j < 0) return false;
    if (!v.holdsNot(j, _isPreposition)) return true;

    if (v.holds(j, _isArticle)) {
      return !v.holdsNot(j - 1, _isPreposition);
    }

    return false;
  }

  /// Ob die Form [i] am Ende einer Genitivgruppe nach einer Präposition
  /// steht (διὰ Ἠσαΐου τοῦ προφήτου λέγοντος). Vorsichtig: schon eine
  /// mögliche Präposition genügt.
  static bool _inPrepositionalGenitive(DetectionView v, int i) {
    final possible = DetectionView(
      v.tokens,
      DetectionMode.possible,
      context: v.context,
    );

    bool genitiveWord(LemmaAnalysis a) =>
        a.analysis.grammaticalCase == "G" || _isPostpositive(a);

    var j = i - 1;

    while (j >= 0 && possible.holds(j, genitiveWord) && !v.endsClause(j)) {
      j--;
    }

    return j >= 0 && j < i - 1 && possible.holds(j, _isPreposition);
  }

  /// Paarweise Bedingung: [i] erfüllt [first], [k] erfüllt [second] (im
  /// aktuellen Modus), und es gibt eine Bestimmung beider, die zueinander
  /// passt ([relation], z. B. Kongruenz).
  static bool _pair(
    DetectionView v,
    int i,
    AnalysisTest first,
    int k,
    AnalysisTest second,
    bool Function(LemmaAnalysis a, LemmaAnalysis b) relation,
  ) {
    if (!v.holds(i, first) || !v.holds(k, second)) return false;

    for (final a in v.tokens[i].readings.where(first)) {
      for (final b in v.tokens[k].readings.where(second)) {
        if (relation(a, b)) return true;
      }
    }

    return false;
  }

  static bool _agree(LemmaAnalysis a, LemmaAnalysis b) =>
      a.analysis.agreesWith(b.analysis);

  /// Ob im Satz von [i] vor [i] eine Form steht, die [test] erfüllt.
  static int? _before(DetectionView v, int i, AnalysisTest test) {
    final (start, _) = v.sentenceOf(i);

    for (var j = i - 1; j >= start; j--) {
      if (v.holds(j, test)) return j;
    }

    return null;
  }

  /// Ob im ganzen Satz von [i] sicher (bzw. möglicherweise) keine Form
  /// [test] erfüllt.
  static bool _noneInSentence(DetectionView v, int i, AnalysisTest test) {
    final (start, end) = v.sentenceOf(i);

    for (var j = start; j <= end; j++) {
      if (!v.holdsNot(j, test)) return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // PARTIZIPIALKONSTRUKTIONEN
  // ---------------------------------------------------------------------------

  static bool _isGenitiveParticiple(LemmaAnalysis a) =>
      a.analysis.isParticiple && a.analysis.grammaticalCase == "G";

  static bool _isGenitiveNominal(LemmaAnalysis a) =>
      _isNominal(a) && a.analysis.grammaticalCase == "G";

  /// Partizip mit Artikel davor (substantiviert oder attributiv). Belege:
  /// Artikel und Partizip.
  static List<int> articularParticiple(DetectionView v) {
    final hits = <int>[];

    for (var i = 0; i < v.length; i++) {
      final j = _previous(v, i);

      if (j >= 0 &&
          _pair(v, i, MorphPattern.participle.matches, j, _isArticle, _agree)) {
        hits.addAll([j, i]);
      }
    }

    return hits;
  }

  static bool _isArticular(DetectionView v, int i) {
    final j = _previous(v, i);

    return j >= 0 &&
        _pair(
          DetectionView(v.tokens, DetectionMode.possible, context: v.context),
          i,
          MorphPattern.participle.matches,
          j,
          _isArticle,
          _agree,
        );
  }

  /// Genitivus absolutus: Partizip im Genitiv ohne Artikel und ohne
  /// Präposition, dazu ein kongruentes Nomen/Pronomen im Genitiv im selben
  /// Satzteil, und kein Verb mit Genitivobjekt im Satz. Belege: Partizip und
  /// Bezugswort.
  static List<int> genitiveAbsolute(DetectionView v) {
    final hits = <int>[];
    final genitiveVerb = _lemma(genitiveVerbs);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, _isGenitiveParticiple)) continue;

      // Mit (möglichem) Artikel ist es ein attributives Partizip.
      final j = _previous(v, i);
      if (j >= 0 && !v.holdsNot(j, _isArticle)) continue;
      if (_governedByPreposition(v, i)) continue;
      if (_inPrepositionalGenitive(v, i)) continue;
      if (!_noneInSentence(v, i, genitiveVerb)) continue;

      final (start, end) = v.sentenceOf(i);

      for (var k = i - 6; k <= i + 6; k++) {
        if (k == i || k < start || k > end) continue;

        if (_pair(v, i, _isGenitiveParticiple, k, _isGenitiveNominal, _agree) &&
            !_governedByPreposition(v, k) &&
            !_inPrepositionalGenitive(v, k)) {
          hits.addAll([i, k]);
          break;
        }
      }
    }

    return hits;
  }

  /// Participium coniunctum: Partizip ohne Artikel, das mit einem
  /// Bezugswort im Satz kongruiert bzw. im Nominativ zum Subjekt eines
  /// finiten Verbs gehört; kein Genitivus absolutus und keine
  /// Umschreibung mit εἰμί. Belege: Partizip (und Bezugswort).
  static List<int> participiumConiunctum(DetectionView v) {
    final hits = <int>[];
    final absolute = genitiveAbsolute(v).toSet();
    final periphrastic = periphrasticConstruction(v).toSet();

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, MorphPattern.participle.matches)) continue;
      if (absolute.contains(i) || periphrastic.contains(i)) continue;
      if (_isArticular(v, i)) continue;
      if (_governedByPreposition(v, i)) continue;

      final (start, end) = v.sentenceOf(i);

      int? partner;

      for (var k = start; k <= end && partner == null; k++) {
        if (k == i || (k - i).abs() > 8) continue;

        if (_pair(
          v,
          i,
          MorphPattern.participle.matches,
          k,
          _isNominal,
          _agree,
        )) {
          partner = k;
        }
      }

      if (partner == null) {
        // Nominativ: Bezug auf das Subjekt eines finiten Verbs.
        for (var k = start; k <= end && partner == null; k++) {
          if (_pair(
            v,
            i,
            (a) =>
                a.analysis.isParticiple && a.analysis.grammaticalCase == "N",
            k,
            _isFinite,
            (a, b) => a.analysis.number == b.analysis.number,
          )) {
            partner = k;
          }
        }
      }

      if (partner != null) hits.addAll([i, partner]);
    }

    return hits;
  }

  /// Umschreibung mit εἰμί und Partizip (ἦν διδάσκων). Belege: beide.
  static List<int> periphrasticConstruction(DetectionView v) {
    final hits = <int>[];
    final isEimi = _lemma(["εἰμί"]);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, (a) => isEimi(a) && a.analysis.isFinite)) continue;

      for (var k = i + 1; k <= i + 3 && k < v.length; k++) {
        if (_pair(
          v,
          i,
          (a) => isEimi(a) && a.analysis.isFinite,
          k,
          (a) => a.analysis.isParticiple && a.analysis.grammaticalCase == "N",
          (a, b) => a.analysis.number == b.analysis.number,
        )) {
          hits.addAll([i, k]);
          break;
        }

        if (v.endsClause(k)) break;
      }
    }

    return hits;
  }

  // ---------------------------------------------------------------------------
  // INFINITIVKONSTRUKTIONEN
  // ---------------------------------------------------------------------------

  static bool _isNeuterSingularArticle(LemmaAnalysis a) =>
      _isArticle(a) &&
      a.analysis.gender == "N" &&
      a.analysis.number == "S" &&
      "GDA".contains(a.analysis.grammaticalCase);

  /// Infinitiv mit Artikel (τὸ λέγειν, τοῦ σπεῖραι, ἐν τῷ εἶναι αὐτόν).
  /// Zwischen Artikel und Infinitiv dürfen bis zu drei Formen stehen
  /// (Negation, Subjektsakkusativ), aber kein finites Verb und kein Wort,
  /// zu dem der Artikel selbst gehören kann. Ergebnis: je Treffer
  /// (Artikel, Infinitiv).
  static List<(int, int)> _articularInfinitives(DetectionView v) {
    final pairs = <(int, int)>[];

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, MorphPattern.infinitive.matches)) continue;

      for (var j = i - 1; j >= 0 && j >= i - 4; j--) {
        if (v.holds(j, _isNeuterSingularArticle)) {
          var blocked = false;

          for (var m = j + 1; m < i; m++) {
            final belongsToArticle = _pair(
              DetectionView(
                v.tokens,
                DetectionMode.possible,
                context: v.context,
              ),
              m,
              (a) => a.analysis.pos == "N-" || a.analysis.pos == "A-",
              j,
              _isNeuterSingularArticle,
              _agree,
            );

            if (belongsToArticle || !v.holdsNot(m, _isFinite)) {
              blocked = true;
            }
          }

          if (!blocked) pairs.add((j, i));
          break;
        }

        if (v.endsClause(j)) break;
      }
    }

    return pairs;
  }

  static List<int> articularInfinitive(DetectionView v) => [
    for (final (j, i) in _articularInfinitives(v)) ...[j, i],
  ];

  /// Präposition + Artikel + Infinitiv (ἐν τῷ, διὰ τό, μετὰ τό, πρὸ τοῦ,
  /// εἰς τό). Belege: Präposition, Artikel, Infinitiv.
  static List<int> prepositionalInfinitive(DetectionView v) => [
    for (final (j, i) in _articularInfinitives(v))
      if (j > 0 && v.holds(j - 1, _isPreposition)) ...[j - 1, j, i],
  ];

  /// Accusativus cum infinitivo, in zwei Formen:
  ///
  /// * mit Artikel: Subjektsakkusativ zwischen Artikel und Infinitiv (πρὸ
  ///   τοῦ ὑμᾶς αἰτῆσαι, μετὰ τὸ ἐγερθῆναί με); dahinter ist er von einem
  ///   Objekt nicht zu unterscheiden und zählt nicht;
  /// * ohne Artikel: regierendes Verb des Sagens/Meinens bzw. unpersönlicher
  ///   Ausdruck – Akkusativ – Infinitiv in dieser Reihenfolge, ohne
  ///   Nebensatzeinleitung dazwischen (ἐκέλευσεν αὐτοὺς ἀπελθεῖν, δεῖ αὐτὸν
  ///   παθεῖν). Ein Akkusativ hinter dem Infinitiv gilt als dessen Objekt.
  ///
  /// Als Subjektsakkusativ zählen Nomen und Pronomen, nicht nach einer
  /// Präposition. Belege: Akkusativ, Infinitiv (und regierendes Verb).
  static List<int> accusativeWithInfinitive(DetectionView v) {
    final hits = <int>[];
    final governor = _lemma(aciGovernors);
    final subordinator = _lemma(subordinators);

    bool isSubject(LemmaAnalysis a) =>
        const {"N-", "RP", "RD", "RI"}.contains(a.analysis.pos) &&
        a.analysis.grammaticalCase == "A";

    bool subject(int k) =>
        v.holds(k, isSubject) && !_governedByPreposition(v, k);

    final articular = <int>{};

    for (final (j, i) in _articularInfinitives(v)) {
      articular.add(i);

      // Zwischen Artikel und Infinitiv; der Artikel gehört zum Infinitiv,
      // eine Präposition davor regiert nicht den Akkusativ.
      for (var k = j + 1; k < i; k++) {
        if (v.holds(k, isSubject)) {
          hits.addAll([k, i]);
          break;
        }
      }
    }

    for (var i = 0; i < v.length; i++) {
      if (articular.contains(i)) continue;
      if (!v.holds(i, MorphPattern.infinitive.matches)) continue;

      final gov = _before(
        v,
        i,
        (a) => governor(a) && (a.analysis.isFinite || a.analysis.isParticiple),
      );

      if (gov == null) continue;

      var blocked = false;
      for (var m = gov + 1; m < i; m++) {
        if (!v.holdsNot(m, subordinator) || v.endsSentence(m)) blocked = true;
      }
      if (blocked) continue;

      for (var k = i - 1; k > gov && k >= i - 5; k--) {
        if (subject(k)) {
          hits.addAll([k, i, gov]);
          break;
        }
      }
    }

    return hits;
  }

  /// Infinitiv als Ergänzung (δύναται ποιεῖν, θέλω ἐλθεῖν, δεῖ παθεῖν).
  /// Belege: regierendes Verb und Infinitiv.
  static List<int> complementaryInfinitive(DetectionView v) {
    final hits = <int>[];
    final governor = _lemma(infinitiveGovernors);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, (a) => governor(a) && a.analysis.isFinite)) continue;

      for (var k = i + 1; k <= i + 6 && k < v.length; k++) {
        if (v.holds(k, MorphPattern.infinitive.matches)) {
          hits.addAll([i, k]);
          break;
        }

        if (v.endsSentence(k)) break;
      }
    }

    return hits;
  }

  // ---------------------------------------------------------------------------
  // NEBENSÄTZE UND REDE
  // ---------------------------------------------------------------------------

  /// ὅτι nach einem Verb des Sagens, Wissens oder Wahrnehmens (indirekte
  /// Rede bzw. ὅτι recitativum). Belege: Verb und ὅτι.
  static List<int> thatClauseAfterSpeech(DetectionView v) {
    final hits = <int>[];
    final hoti = _lemma(["ὅτι"]);
    final speech = _lemma(speechVerbs);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, (a) => hoti(a) && a.analysis.pos == "C-")) continue;

      final verb = _before(v, i, (a) => speech(a) && a.analysis.isVerb);
      if (verb != null) hits.addAll([verb, i]);
    }

    return hits;
  }

  /// Indirekte Frage: Fragewort nach einem Verb des Sagens, Wissens oder
  /// Fragens in einem Satz, der nicht mit Fragezeichen endet. Belege: Verb
  /// und Fragewort.
  static List<int> indirectQuestion(DetectionView v) {
    final hits = <int>[];
    final question = _lemma(interrogatives);
    final speech = _lemma(speechVerbs);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, question)) continue;

      final (_, end) = v.sentenceOf(i);
      final last = v.tokens[end].surface.trimRight();

      if (last.endsWith(";") || last.endsWith(";")) continue;

      final verb = _before(v, i, (a) => speech(a) && a.analysis.isVerb);
      if (verb != null) hits.addAll([verb, i]);
    }

    return hits;
  }

  /// Verallgemeinernder Relativsatz: Relativpronomen + ἄν/ἐάν + Konjunktiv
  /// (ὃς ἂν ποιήσῃ). Belege: Pronomen, Partikel, Verb.
  static List<int> generalizingRelative(DetectionView v) {
    final hits = <int>[];
    final an = _lemma(["ἄν", "ἐάν"]);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, (a) => a.analysis.pos == "RR")) continue;

      for (var k = i + 1; k <= i + 2 && k < v.length; k++) {
        if (!v.holds(k, an)) continue;

        final subjunctive = _next(v, k, (a) => a.analysis.mood == "S", 6);
        if (subjunctive != null) hits.addAll([i, k, subjunctive]);
        break;
      }
    }

    return hits;
  }

  /// Erste Form nach [i] im selben Satz (höchstens [range] Formen weiter),
  /// die [test] erfüllt.
  static int? _next(DetectionView v, int i, AnalysisTest test, int range) {
    for (var k = i + 1; k <= i + range && k < v.length; k++) {
      if (v.holds(k, test)) return k;
      if (v.endsSentence(k)) return null;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // BEDINGUNGSSÄTZE UND MODI
  // ---------------------------------------------------------------------------

  static final AnalysisTest _isAn = _lemma(["ἄν"]);

  /// ἐάν + Konjunktiv (Eventualis bzw. prospektiver Fall). Belege: ἐάν,
  /// Konjunktiv.
  static List<int> eventualCondition(DetectionView v) {
    final hits = <int>[];
    final ean = _lemma(["ἐάν", "κἄν"]);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, ean)) continue;

      final verb = _next(v, i, (a) => a.analysis.mood == "S", 8);
      if (verb != null) hits.addAll([i, verb]);
    }

    return hits;
  }

  static final AnalysisTest _isEi = _lemma(["εἰ"]);

  static bool _isPastIndicative(LemmaAnalysis a) =>
      a.analysis.isVerb &&
      a.analysis.mood == "I" &&
      "IAY".contains(a.analysis.tense);

  /// εἰ + Indikativ ohne ἄν im Satz (Realis). Belege: εἰ, Verb.
  static List<int> realCondition(DetectionView v) {
    final hits = <int>[];

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, _isEi)) continue;
      if (!_noneInSentence(v, i, _isAn)) continue;

      final verb = _next(
        v,
        i,
        (a) => a.analysis.isVerb && a.analysis.mood == "I",
        8,
      );
      if (verb != null) hits.addAll([i, verb]);
    }

    return hits;
  }

  /// Irrealis: εἰ + Indikativ eines Vergangenheitstempus, im Satz ἄν mit
  /// Indikativ eines Vergangenheitstempus. Belege: εἰ, Verben, ἄν.
  static List<int> unrealCondition(DetectionView v) {
    final hits = <int>[];

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, _isEi)) continue;

      final protasis = _next(v, i, _isPastIndicative, 8);
      if (protasis == null) continue;

      final (start, end) = v.sentenceOf(i);

      for (var k = start; k <= end; k++) {
        if (!v.holds(k, _isAn)) continue;

        for (var m = start; m <= end; m++) {
          if (m != protasis && v.holds(m, _isPastIndicative)) {
            hits.addAll([i, protasis, k, m]);
            break;
          }
        }
        break;
      }
    }

    return hits;
  }

  /// Optativ mit ἄν (Potentialis). Belege: Optativ, ἄν.
  static List<int> potentialOptative(DetectionView v) {
    final hits = <int>[];

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, (a) => a.analysis.mood == "O")) continue;

      final (start, end) = v.clauseOf(i);

      for (var k = start; k <= end; k++) {
        if (v.holds(k, _isAn)) {
          hits.addAll([i, k]);
          break;
        }
      }
    }

    return hits;
  }

  /// Optativ ohne ἄν und ohne εἰ im Satz (Wunschoptativ: μὴ γένοιτο).
  /// Belege: Optativ.
  static List<int> wishOptative(DetectionView v) {
    return [
      for (var i = 0; i < v.length; i++)
        if (v.holds(i, (a) => a.analysis.mood == "O") &&
            _noneInSentence(v, i, _isAn) &&
            _noneInSentence(v, i, _isEi))
          i,
    ];
  }

  /// Ob vor [i] im Satzteil ein Nebensatz eingeleitet wird.
  static bool _subordinateBefore(DetectionView v, int i) {
    final (start, _) = v.clauseOf(i);
    final subordinator = _lemma(subordinators);

    for (var k = start; k < i; k++) {
      if (!v.holdsNot(k, subordinator)) return true;
    }

    return false;
  }

  /// Adhortativ: 1. Pl. Konjunktiv im Hauptsatz (ἄγωμεν). Belege: Verb.
  static List<int> hortatorySubjunctive(DetectionView v) {
    return [
      for (var i = 0; i < v.length; i++)
        if (v.holds(
              i,
              (a) =>
                  a.analysis.mood == "S" &&
                  a.analysis.person == "1" &&
                  a.analysis.number == "P",
            ) &&
            !_subordinateBefore(v, i))
          i,
    ];
  }

  /// Prohibitiv: μή + 2. Person Aorist Konjunktiv (μὴ φοβηθῆτε). Belege: μή,
  /// Verb.
  static List<int> prohibitiveSubjunctive(DetectionView v) {
    final hits = <int>[];
    final me = _lemma(["μή"]);

    final ou = _lemma(["οὐ"]);

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(i, me)) continue;

      // οὐ μή + Konjunktiv ist verstärkte Verneinung, kein Verbot.
      if (!v.holdsNot(i - 1, ou)) continue;

      final verb = _next(
        v,
        i,
        (a) =>
            a.analysis.mood == "S" &&
            a.analysis.tense == "A" &&
            a.analysis.person == "2",
        3,
      );

      if (verb != null) hits.addAll([i, verb]);
    }

    return hits;
  }

  /// Deliberativ: Konjunktiv der 1. Person in einer direkten Frage (τί
  /// ποιήσωμεν;). Belege: Verb.
  static List<int> deliberativeSubjunctive(DetectionView v) {
    final hits = <int>[];

    for (var i = 0; i < v.length; i++) {
      if (!v.holds(
        i,
        (a) => a.analysis.mood == "S" && a.analysis.person == "1",
      )) {
        continue;
      }

      final (_, end) = v.sentenceOf(i);
      final last = v.tokens[end].surface.trimRight();

      if ((last.endsWith(";") || last.endsWith(";")) &&
          !_subordinateBefore(v, i)) {
        hits.add(i);
      }
    }

    return hits;
  }

  // ---------------------------------------------------------------------------
  // PRÄPOSITIONEN UND WORTSTELLUNG
  // ---------------------------------------------------------------------------

  /// Präposition mit einem Kasus ([grammaticalCase]: "G", "D", "A"),
  /// abgelesen an der ersten deklinierten Form danach. Belege: Präposition
  /// und diese Form.
  static List<int> Function(DetectionView) prepositionWithCase(
    String grammaticalCase,
  ) {
    return (v) {
      final hits = <int>[];

      bool declined(LemmaAnalysis a) => a.analysis.grammaticalCase != "-";

      for (var i = 0; i < v.length; i++) {
        if (!v.holds(i, _isPreposition) || v.endsClause(i)) continue;

        var k = i + 1;

        // Adverb oder Partikel zwischen Präposition und Nomen überspringen.
        if (k < v.length && !v.holds(k, declined)) {
          if (v.endsClause(k)) continue;
          k++;
        }

        if (k < v.length &&
            v.holds(
              k,
              (a) => declined(a) && a.analysis.grammaticalCase == grammaticalCase,
            )) {
          hits.addAll([i, k]);
        }
      }

      return hits;
    };
  }

  /// Attributive Stellung des Adjektivs: Artikel – Adjektiv – Nomen
  /// (ὁ ἀγαθὸς ἄνθρωπος) oder Nomen – Artikel – Adjektiv (ὁ ἄνθρωπος ὁ
  /// ἀγαθός), alle kongruent. Belege: die drei Formen.
  static List<int> attributivePosition(DetectionView v) {
    final hits = <int>[];

    bool adjective(LemmaAnalysis a) => a.analysis.pos == "A-";
    bool noun(LemmaAnalysis a) => a.analysis.pos == "N-";

    for (var i = 0; i + 2 < v.length; i++) {
      // Artikel – Adjektiv – Nomen
      if (_pair(v, i, _isArticle, i + 1, adjective, _agree) &&
          _pair(v, i + 1, adjective, i + 2, noun, _agree)) {
        hits.addAll([i, i + 1, i + 2]);
        continue;
      }

      // Nomen – Artikel – Adjektiv
      if (_pair(v, i, noun, i + 1, _isArticle, _agree) &&
          _pair(v, i + 1, _isArticle, i + 2, adjective, _agree)) {
        hits.addAll([i, i + 1, i + 2]);
      }
    }

    return hits;
  }
}
