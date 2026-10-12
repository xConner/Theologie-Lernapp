import '../../../utils/greek_normalization.dart';
import 'greek_form_key.dart';

/// Wörter, die der Klausurersteller ohne Vokabelhilfe voraussetzt, obwohl
/// sie nicht (oder nur teilweise) in der Vokabelliste stehen: elementare
/// Funktionswörter und gängige biblische Eigennamen.
///
/// Beide Listen werden hier zentral gepflegt; Suche, Schwierigkeitsgrenze
/// und Vokabelhilfen fragen nur diese Klassen. Verglichen wird immer die
/// Grundform (bzw. bei unbestimmten Formen ein Name der Liste), nie die
/// bloße Schreibweise eines Wortes.

/// Artikel, Pronomen und die Grundwörter der ersten Unterrichtsstunden.
///
/// Sie werden über die Formenlehre gelernt (Artikel, Pronomen: Blätter der
/// Vorlesung und Pronomentabellen des Grammatiktrainers), nicht als Vokabel.
/// Steht ein solches Wort zusätzlich in der Vokabelliste, entscheidet dort
/// der Lernschritt (`VocabularyKnowledge`); der Artikel gilt immer als
/// bekannt.
class ElementaryWords {
  ElementaryWords._();

  static const List<String> article = ["ὁ"];

  static const List<String> pronouns = [
    // Personalpronomen (MorphGNT führt ἡμεῖς unter ἐγώ, ὑμεῖς unter σύ)
    "ἐγώ", "σύ", "ἡμεῖς", "ὑμεῖς", "αὐτός",
    // Demonstrativpronomen
    "οὗτος", "ἐκεῖνος", "ὅδε",
    // Relativ-, Interrogativ- und Indefinitpronomen
    "ὅς", "ὅστις", "τίς", "τις",
    // Reflexiv- und Reziprokpronomen
    "ἐμαυτοῦ", "σεαυτοῦ", "ἑαυτοῦ", "ἀλλήλων",
    // Possessivpronomen
    "ἐμός", "σός", "ἡμέτερος", "ὑμέτερος",
  ];

  /// Konjunktionen, Negationen und Partikeln der ersten Lektionen.
  static const List<String> particles = [
    "καί", "δέ", "μέν", "γάρ", "οὖν", "τε", "ἀλλά", "ἤ",
    "οὐ", "οὐκ", "οὐχ", "μή",
    "ὅτι", "εἰ", "ἐάν", "ἄν", "ὡς",
  ];

  static final Set<String> _articleKeys = {
    for (final lemma in article) greekFormKey(lemma),
  };

  static final Set<String> _keys = {
    for (final lemma in [...article, ...pronouns, ...particles])
      greekFormKey(lemma),
  };

  static bool isArticle(String lemma) =>
      _articleKeys.contains(greekFormKey(lemma));

  static bool contains(String lemma) => _keys.contains(greekFormKey(lemma));
}

/// Gängige biblische Eigennamen (Personen, Orte, Gruppen), die ein
/// Griechisch-I-Kurs an einer theologischen Fakultät voraussetzen kann.
///
/// Erweitern: Grundform in der Schreibung des Textes ergänzen (SBLGNT bzw.
/// Septuaginta; abweichende Schreibungen als eigene Einträge). Akzente und
/// Spiritus spielen beim Vergleich keine Rolle. Seltene Namen bleiben
/// draußen; sie erhalten weiterhin eine Hilfe („Eigenname“).
class BiblicalNames {
  BiblicalNames._();

  /// Jesus, seine Familie und die Menschen der Evangelien.
  static const List<String> gospels = [
    "Ἰησοῦς", "Χριστός", "Μεσσίας", "Ἐμμανουήλ",
    "Μαρία", "Μαριάμ", "Ἰωσήφ", "Ἰωάννης", "Ἐλισάβετ", "Ζαχαρίας",
    "Λάζαρος", "Μάρθα", "Μαγδαληνή", "Νικόδημος",
    "Πιλᾶτος", "Πόντιος", "Ἡρῴδης", "Καϊάφας", "Καῖσαρ", "Βαραββᾶς",
    "Γαβριήλ", "Μιχαήλ", "Σατανᾶς",
  ];

  /// Die Zwölf und die Mitarbeiter der Apostelgeschichte und der Briefe.
  static const List<String> apostles = [
    "Πέτρος", "Σίμων", "Κηφᾶς", "Ἀνδρέας", "Ἰάκωβος", "Φίλιππος",
    "Βαρθολομαῖος", "Θωμᾶς", "Μαθθαῖος", "Ματθαῖος", "Θαδδαῖος",
    "Ἰούδας", "Ἰσκαριώτης", "Ἰσκαριώθ", "Ναθαναήλ", "Μαθθίας",
    "Παῦλος", "Σαῦλος", "Σαούλ", "Βαρναβᾶς", "Τιμόθεος", "Τίτος",
    "Λουκᾶς", "Μᾶρκος", "Στέφανος", "Σιλᾶς",
  ];

  /// Geläufige Namen des Alten Testaments (Septuaginta und Zitate im NT).
  static const List<String> oldTestament = [
    "Ἀδάμ", "Εὕα", "Εὔα", "Κάϊν", "Ἅβελ", "Ἄβελ", "Νῶε",
    "Ἀβραάμ", "Ἁβραάμ", "Σάρρα", "Ἰσαάκ", "Ἰακώβ", "Ἠσαῦ", "Ῥεβέκκα",
    "Ῥαχήλ", "Λευί", "Λευίς", "Ἰούδα", "Βενιαμίν",
    "Μωϋσῆς", "Μωυσῆς", "Μωσῆς", "Ἀαρών", "Φαραώ",
    "Δαυίδ", "Δαυείδ", "Δαβίδ", "Σολομών", "Σαλωμών", "Σαμουήλ",
    "Ἠλίας", "Ἠλιού", "Ἐλισαῖος", "Ἠσαΐας", "Ἰερεμίας", "Δανιήλ",
    "Ἰωνᾶς", "Ἰώβ", "Ῥούθ", "Σαβαώθ",
  ];

  /// Länder, Orte und Volksgruppen.
  static const List<String> places = [
    "Ἰσραήλ", "Ἰσραηλίτης", "Ἰερουσαλήμ", "Ἱεροσόλυμα", "Σιών",
    "Ἰουδαία", "Ἰουδαῖος", "Γαλιλαία", "Γαλιλαῖος", "Σαμάρεια",
    "Σαμαρίτης", "Ναζαρέθ", "Ναζαρέτ", "Ναζαρά", "Ναζωραῖος",
    "Ναζαρηνός", "Βηθλέεμ", "Καφαρναούμ", "Βηθανία", "Ἰορδάνης",
    "Ἰεριχώ", "Αἴγυπτος", "Αἰγύπτιος", "Βαβυλών", "Σινᾶ", "Σόδομα",
    "Γόμορρα", "Συρία", "Δαμασκός", "Ἀντιόχεια", "Ἔφεσος", "Κόρινθος",
    "Ῥώμη", "Ῥωμαῖος", "Ἕλλην", "Ἑβραῖος", "Φαρισαῖος", "Σαδδουκαῖος",
    "Λευίτης",
  ];

  static const List<String> all = [
    ...gospels,
    ...apostles,
    ...oldTestament,
    ...places,
  ];

  static final Set<String> _lemmaKeys = {
    for (final name in all) normalizeGreekForComparison(name),
  };

  /// Endungen der deklinierten Namen je Nominativendung (Singular; für
  /// Volksgruppen auch Plural).
  static const Map<String, List<String>> _endings = {
    "ος": ["ος", "ου", "ω", "ον", "ε", "οι", "ων", "οις", "ους"],
    "ης": ["ης", "ου", "η", "ην", "α", "αι", "ων", "αις", "ας", "εως", "ει"],
    "ας": ["ας", "α", "ου", "αν"],
    "α": ["α", "ας", "αν", "ης", "η", "ων", "οις"],
    "η": ["η", "ης", "ην"],
    "ους": ["ους", "ου", "ουν"],
    "ων": ["ων", "ωνος", "ωνι", "ωνα", "ωνες", "ωνας", "ωντος", "ωντι", "ωντα"],
  };

  static final Set<String> _formKeys = () {
    final forms = <String>{};

    for (final name in _lemmaKeys) {
      forms.add(name);

      for (final MapEntry(key: ending, value: endings) in _endings.entries) {
        // Wie die Namen normalisiert (Schluss-Sigma).
        final suffix = normalizeGreekForComparison(ending);
        if (!name.endsWith(suffix)) continue;

        final stem = name.substring(0, name.length - suffix.length);
        forms.addAll(
          endings.map((e) => "$stem${normalizeGreekForComparison(e)}"),
        );
        break;
      }
    }

    return forms;
  }();

  /// Ob die Grundform ein bekannter Name ist.
  static bool containsLemma(String lemma) =>
      _lemmaKeys.contains(normalizeGreekForComparison(lemma));

  /// Ob eine Form ohne Bestimmung (Septuaginta: „vermutlich Eigenname“) zu
  /// einem bekannten Namen gehört: der Name selbst oder eine seiner
  /// deklinierten Formen.
  static bool containsForm(String form) =>
      _formKeys.contains(normalizeGreekForComparison(form));
}
