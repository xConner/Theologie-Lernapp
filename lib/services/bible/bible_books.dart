import '../../models/bible/bible_translation.dart';
import 'bible_search_folding.dart';

enum BibleTestament { old, apocrypha, newTestament }

/// Ein biblisches Buch unabhängig von einer Ausgabe.
class BibleBook {
  /// Kennung nach USFM, wie sie auch die Buchdateien tragen.
  final String id;

  final BibleTestament testament;

  /// Deutscher Name für Oberfläche und Meldungen.
  final String name;

  /// Abkürzung der Perikopenliste (Loccumer Richtlinien), z. B. „Mk“.
  final String abbreviation;

  /// Weitere Namen und Abkürzungen (deutsch, englisch, lateinisch,
  /// griechisch) für die Stelleneingabe.
  final List<String> aliases;

  const BibleBook(
    this.id,
    this.testament,
    this.name,
    this.abbreviation,
    this.aliases,
  );
}

/// Verzeichnis der Bücher: Reihenfolge, deutsche Namen und alle Namen, unter
/// denen ein Buch bei der Stelleneingabe erkannt wird.
///
/// Welche Bücher eine Ausgabe tatsächlich enthält und wie sie dort heißen,
/// steht in der Ausgabe selbst (`BibleTranslation.books`).
class BibleBooks {
  BibleBooks._();

  static const _ot = BibleTestament.old;
  static const _ap = BibleTestament.apocrypha;
  static const _nt = BibleTestament.newTestament;

  static const List<BibleBook> all = [
    BibleBook("GEN", _ot, "1. Mose (Genesis)", "Gen", [
      "Genesis",
      "1. Mose",
      "1 Mo",
      "1. Buch Mose",
      "Gn",
      "Ge",
      "Γένεσις",
    ]),
    BibleBook("EXO", _ot, "2. Mose (Exodus)", "Ex", [
      "Exodus",
      "2. Mose",
      "2 Mo",
      "2. Buch Mose",
      "Exod",
      "Ἔξοδος",
    ]),
    BibleBook("LEV", _ot, "3. Mose (Levitikus)", "Lev", [
      "Levitikus",
      "Leviticus",
      "3. Mose",
      "3 Mo",
      "3. Buch Mose",
      "Lv",
      "Λευιτικόν",
    ]),
    BibleBook("NUM", _ot, "4. Mose (Numeri)", "Num", [
      "Numeri",
      "Numbers",
      "4. Mose",
      "4 Mo",
      "4. Buch Mose",
      "Nm",
      "Ἀριθμοί",
    ]),
    BibleBook("DEU", _ot, "5. Mose (Deuteronomium)", "Dtn", [
      "Deuteronomium",
      "Deuteronomy",
      "5. Mose",
      "5 Mo",
      "5. Buch Mose",
      "Deut",
      "Dt",
      "Δευτερονόμιον",
    ]),
    BibleBook("JOS", _ot, "Josua", "Jos", [
      "Joshua",
      "Josue",
      "Josh",
      "Ἰησοῦς",
    ]),
    BibleBook("JDG", _ot, "Richter", "Ri", [
      "Judges",
      "Judicum",
      "Iudicum",
      "Judg",
      "Jdg",
      "Κριταί",
    ]),
    BibleBook("RUT", _ot, "Rut", "Rut", ["Ruth", "Rt", "Ῥούθ"]),
    BibleBook("1SA", _ot, "1. Samuel", "1Sam", [
      "1 Samuel",
      "1 Sa",
      "1 Samuelis",
      "I Samuelis",
      "1 Regum",
      "1 Reg",
      "1 Βασιλειῶν",
      "Βασιλειῶν Α",
      "1 Kingdoms",
    ]),
    BibleBook("2SA", _ot, "2. Samuel", "2Sam", [
      "2 Samuel",
      "2 Sa",
      "2 Samuelis",
      "II Samuelis",
      "2 Regum",
      "2 Reg",
      "2 Βασιλειῶν",
      "Βασιλειῶν Β",
      "2 Kingdoms",
    ]),
    BibleBook("1KI", _ot, "1. Könige", "1Kön", [
      "1 Könige",
      "1 Koenige",
      "1 Kings",
      "1 Kön",
      "1 Kg",
      "1 Kgs",
      "1 Ki",
      "I Regum",
      "3 Regum",
      "3 Reg",
      "3 Βασιλειῶν",
      "Βασιλειῶν Γ",
      "3 Kingdoms",
    ]),
    BibleBook("2KI", _ot, "2. Könige", "2Kön", [
      "2 Könige",
      "2 Koenige",
      "2 Kings",
      "2 Kön",
      "2 Kg",
      "2 Kgs",
      "2 Ki",
      "II Regum",
      "4 Regum",
      "4 Reg",
      "4 Βασιλειῶν",
      "Βασιλειῶν Δ",
      "4 Kingdoms",
    ]),
    BibleBook("1CH", _ot, "1. Chronik", "1Chr", [
      "1 Chronik",
      "1 Chronicles",
      "1 Chron",
      "1 Ch",
      "1 Paralipomenon",
      "I Paralipomenon",
      "1 Par",
      "Παραλειπομένων Α",
    ]),
    BibleBook("2CH", _ot, "2. Chronik", "2Chr", [
      "2 Chronik",
      "2 Chronicles",
      "2 Chron",
      "2 Ch",
      "2 Paralipomenon",
      "II Paralipomenon",
      "2 Par",
      "Παραλειπομένων Β",
    ]),
    BibleBook("EZR", _ot, "Esra", "Esr", [
      "Ezra",
      "Esdras",
      "Esdrae",
      "Ezr",
      "1 Esdrae",
      "Ἔσδρας",
    ]),
    BibleBook("NEH", _ot, "Nehemia", "Neh", [
      "Nehemiah",
      "Nehemiae",
      "Nehemias",
      "2 Esdrae",
      "Νεεμίας",
    ]),
    BibleBook("EST", _ot, "Ester", "Est", ["Esther", "Esth", "Ἐσθήρ"]),
    BibleBook("JOB", _ot, "Hiob (Ijob)", "Ijob", ["Hiob", "Job", "Hi", "Ἰώβ"]),
    BibleBook("PSA", _ot, "Psalmen", "Ps", [
      "Psalm",
      "Psalmen",
      "Psalms",
      "Psalmi",
      "Psalmorum",
      "Psa",
      "Pss",
      "Ψαλμοί",
      "Ψαλμός",
    ]),
    BibleBook("PRO", _ot, "Sprüche", "Spr", [
      "Sprüche",
      "Sprueche",
      "Sprüche Salomo",
      "Sprüche Salomos",
      "Sprichwörter",
      "Proverbs",
      "Proverbia",
      "Proverbiorum",
      "Prov",
      "Prv",
      "Pro",
      "Παροιμίαι",
    ]),
    BibleBook("ECC", _ot, "Prediger (Kohelet)", "Koh", [
      "Kohelet",
      "Prediger",
      "Pred",
      "Ecclesiastes",
      "Eccles",
      "Eccl",
      "Ecc",
      "Qoh",
      "Ἐκκλησιαστής",
    ]),
    BibleBook("SNG", _ot, "Hoheslied", "Hld", [
      "Hoheslied",
      "Hohelied",
      "Hoheslied Salomos",
      "Song of Solomon",
      "Song of Songs",
      "Song",
      "Canticum Canticorum",
      "Canticum",
      "Cant",
      "Ct",
      "ᾎσμα",
      "ᾎσμα ᾀσμάτων",
    ]),
    BibleBook("ISA", _ot, "Jesaja", "Jes", [
      "Isaiah",
      "Isaias",
      "Isaiae",
      "Isa",
      "Is",
      "Ἠσαΐας",
    ]),
    BibleBook("JER", _ot, "Jeremia", "Jer", [
      "Jeremiah",
      "Jeremias",
      "Jeremiae",
      "Hieremias",
      "Ἰερεμίας",
    ]),
    BibleBook("LAM", _ot, "Klagelieder", "Klgl", [
      "Klagelieder",
      "Klag",
      "Lamentations",
      "Lamentationes",
      "Threni",
      "Lam",
      "Θρῆνοι",
    ]),
    BibleBook("EZK", _ot, "Hesekiel (Ezechiel)", "Ez", [
      "Ezechiel",
      "Hesekiel",
      "Hes",
      "Ezekiel",
      "Ezek",
      "Ezk",
      "Hiezechiel",
      "Ἰεζεκιήλ",
    ]),
    BibleBook("DAN", _ot, "Daniel", "Dan", ["Danihel", "Dn", "Δανιήλ"]),
    BibleBook("HOS", _ot, "Hosea", "Hos", ["Osee", "Ὡσηέ"]),
    BibleBook("JOL", _ot, "Joel", "Joel", ["Johel", "Jl", "Ἰωήλ"]),
    BibleBook("AMO", _ot, "Amos", "Am", ["Amos", "Ἀμώς"]),
    BibleBook("OBA", _ot, "Obadja", "Obd", [
      "Obadiah",
      "Abdias",
      "Obad",
      "Ob",
      "Ἀβδιού",
    ]),
    BibleBook("JON", _ot, "Jona", "Jona", ["Jonah", "Jonas", "Jon", "Ἰωνᾶς"]),
    BibleBook("MIC", _ot, "Micha", "Mi", [
      "Micah",
      "Michaeas",
      "Micha",
      "Mic",
      "Μιχαίας",
    ]),
    BibleBook("NAM", _ot, "Nahum", "Nah", ["Naum", "Na", "Ναούμ"]),
    BibleBook("HAB", _ot, "Habakuk", "Hab", [
      "Habakkuk",
      "Habacuc",
      "Abacuc",
      "Ἀμβακούμ",
    ]),
    BibleBook("ZEP", _ot, "Zefanja", "Zef", [
      "Zephanja",
      "Zephaniah",
      "Sophonias",
      "Zeph",
      "Zep",
      "Σοφονίας",
    ]),
    BibleBook("HAG", _ot, "Haggai", "Hag", ["Aggaeus", "Aggeus", "Ἀγγαῖος"]),
    BibleBook("ZEC", _ot, "Sacharja", "Sach", [
      "Zechariah",
      "Zacharias",
      "Zech",
      "Zec",
      "Ζαχαρίας",
    ]),
    BibleBook("MAL", _ot, "Maleachi", "Mal", [
      "Malachi",
      "Malachias",
      "Μαλαχίας",
    ]),

    BibleBook("TOB", _ap, "Tobit", "Tob", ["Tobias", "Tobiae", "Τωβίτ"]),
    BibleBook("JDT", _ap, "Judit", "Jdt", ["Judith", "Idt", "Ἰουδίθ"]),
    BibleBook("ESG", _ap, "Ester (griechisch)", "EstGr", [
      "Esther Greek",
      "Ester griechisch",
    ]),
    BibleBook("WIS", _ap, "Weisheit", "Weish", [
      "Weisheit Salomos",
      "Wisdom",
      "Wisdom of Solomon",
      "Sapientia",
      "Sapientiae",
      "Sap",
      "Wis",
      "Σοφία Σαλωμῶνος",
    ]),
    BibleBook("SIR", _ap, "Jesus Sirach", "Sir", [
      "Sirach",
      "Jesus Sirach",
      "Ecclesiasticus",
      "Ecclus",
      "Σειράχ",
    ]),
    BibleBook("BAR", _ap, "Baruch", "Bar", ["Baruch", "Βαρούχ"]),
    BibleBook("LJE", _ap, "Brief des Jeremia", "EpJer", [
      "Brief Jeremias",
      "Letter of Jeremiah",
      "Epistle of Jeremiah",
      "Ἐπιστολὴ Ἰερεμίου",
    ]),
    BibleBook("S3Y", _ap, "Gebet des Asarja", "GebAs", [
      "Song of the Three",
      "Prayer of Azariah",
    ]),
    BibleBook("SUS", _ap, "Susanna", "Sus", ["Susanna", "Σουσάννα"]),
    BibleBook("BEL", _ap, "Bel und der Drache", "Bel", [
      "Bel and the Dragon",
      "Βὴλ καὶ Δράκων",
    ]),
    BibleBook("1MA", _ap, "1. Makkabäer", "1.Makk", [
      "1 Makkabäer",
      "1 Makk",
      "1 Maccabees",
      "1 Macc",
      "1 Mac",
      "1 Machabaeorum",
      "I Maccabeorum",
      "Μακκαβαίων Α",
    ]),
    BibleBook("2MA", _ap, "2. Makkabäer", "2.Makk", [
      "2 Makkabäer",
      "2 Makk",
      "2 Maccabees",
      "2 Macc",
      "2 Mac",
      "2 Machabaeorum",
      "II Maccabeorum",
      "Μακκαβαίων Β",
    ]),
    BibleBook("3MA", _ap, "3. Makkabäer", "3.Makk", [
      "3 Makkabäer",
      "3 Makk",
      "3 Maccabees",
      "3 Macc",
      "Μακκαβαίων Γ",
    ]),
    BibleBook("4MA", _ap, "4. Makkabäer", "4.Makk", [
      "4 Makkabäer",
      "4 Makk",
      "4 Maccabees",
      "4 Macc",
      "Μακκαβαίων Δ",
    ]),
    BibleBook("1ES", _ap, "1. Esdras (3. Esra)", "3Esr", [
      "1 Esdras",
      "3 Esra",
      "Ἔσδρας Α",
    ]),
    BibleBook("2ES", _ap, "2. Esdras (4. Esra)", "4Esr", [
      "2 Esdras",
      "4 Esra",
    ]),
    BibleBook("MAN", _ap, "Gebet Manasses", "GebMan", [
      "Gebet des Manasse",
      "Prayer of Manasseh",
      "Oratio Manassae",
      "Προσευχὴ Μανασσῆ",
    ]),
    BibleBook("PS2", _ap, "Psalm 151", "Ps151", ["Psalm 151"]),
    BibleBook("DAG", _ap, "Daniel (griechisch)", "DanGr", [
      "Daniel Greek",
      "Daniel griechisch",
    ]),

    BibleBook("MAT", _nt, "Matthäus", "Mt", [
      "Matthäus",
      "Matthaeus",
      "Matthew",
      "Matt",
      "Mat",
      "Mattheum",
      "Matthaeum",
      "Μαθθαῖον",
      "Ματθαῖον",
    ]),
    BibleBook("MRK", _nt, "Markus", "Mk", [
      "Markus",
      "Mark",
      "Marcus",
      "Marcum",
      "Mrk",
      "Mar",
      "Mc",
      "Μᾶρκον",
    ]),
    BibleBook("LUK", _nt, "Lukas", "Lk", [
      "Lukas",
      "Luke",
      "Lucas",
      "Lucam",
      "Luk",
      "Lc",
      "Λουκᾶν",
    ]),
    BibleBook("JHN", _nt, "Johannes", "Joh", [
      "Johannes",
      "John",
      "Jhn",
      "Jn",
      "Joannes",
      "Ioannem",
      "Iohannem",
      "Ἰωάννην",
    ]),
    BibleBook("ACT", _nt, "Apostelgeschichte", "Apg", [
      "Apostelgeschichte",
      "Acts",
      "Acta",
      "Actus Apostolorum",
      "Act",
      "Πράξεις",
      "Πράξεις Ἀποστόλων",
    ]),
    BibleBook("ROM", _nt, "Römer", "Röm", [
      "Römer",
      "Roemer",
      "Romans",
      "Romanos",
      "Rom",
      "Rm",
      "Ῥωμαίους",
    ]),
    BibleBook("1CO", _nt, "1. Korinther", "1Kor", [
      "1 Korinther",
      "1 Corinthians",
      "1 Cor",
      "1 Co",
      "1 Corinthios",
      "Corinthios I",
      "Κορινθίους Α",
    ]),
    BibleBook("2CO", _nt, "2. Korinther", "2Kor", [
      "2 Korinther",
      "2 Corinthians",
      "2 Cor",
      "2 Co",
      "2 Corinthios",
      "Corinthios II",
      "Κορινθίους Β",
    ]),
    BibleBook("GAL", _nt, "Galater", "Gal", [
      "Galater",
      "Galatians",
      "Galatas",
      "Γαλάτας",
    ]),
    BibleBook("EPH", _nt, "Epheser", "Eph", [
      "Epheser",
      "Ephesians",
      "Ephesios",
      "Ἐφεσίους",
    ]),
    BibleBook("PHP", _nt, "Philipper", "Phil", [
      "Philipper",
      "Philippians",
      "Philippenses",
      "Php",
      "Φιλιππησίους",
    ]),
    BibleBook("COL", _nt, "Kolosser", "Kol", [
      "Kolosser",
      "Colossians",
      "Colossenses",
      "Col",
      "Κολοσσαεῖς",
    ]),
    BibleBook("1TH", _nt, "1. Thessalonicher", "1Thess", [
      "1 Thessalonicher",
      "1 Thessalonians",
      "1 Thess",
      "1 Th",
      "1 Thessalonicenses",
      "Thessalonicenses I",
      "Θεσσαλονικεῖς Α",
    ]),
    BibleBook("2TH", _nt, "2. Thessalonicher", "2Thess", [
      "2 Thessalonicher",
      "2 Thessalonians",
      "2 Thess",
      "2 Th",
      "2 Thessalonicenses",
      "Thessalonicenses II",
      "Θεσσαλονικεῖς Β",
    ]),
    BibleBook("1TI", _nt, "1. Timotheus", "1Tim", [
      "1 Timotheus",
      "1 Timothy",
      "1 Ti",
      "1 Timotheum",
      "Timotheum I",
      "Τιμόθεον Α",
    ]),
    BibleBook("2TI", _nt, "2. Timotheus", "2Tim", [
      "2 Timotheus",
      "2 Timothy",
      "2 Ti",
      "2 Timotheum",
      "Timotheum II",
      "Τιμόθεον Β",
    ]),
    BibleBook("TIT", _nt, "Titus", "Tit", ["Titus", "Titum", "Τίτον"]),
    BibleBook("PHM", _nt, "Philemon", "Phlm", [
      "Philemon",
      "Philemonem",
      "Phm",
      "Philem",
      "Φιλήμονα",
    ]),
    BibleBook("HEB", _nt, "Hebräer", "Hebr", [
      "Hebräer",
      "Hebraeer",
      "Hebrews",
      "Hebraeos",
      "Heb",
      "Ἑβραίους",
    ]),
    BibleBook("JAS", _nt, "Jakobus", "Jak", [
      "Jakobus",
      "James",
      "Jacobi",
      "Iacobi",
      "Jas",
      "Jam",
      "Ἰακώβου",
    ]),
    BibleBook("1PE", _nt, "1. Petrus", "1Petr", [
      "1 Petrus",
      "1 Peter",
      "1 Pet",
      "1 Pe",
      "1 Pt",
      "1 Petri",
      "Petri I",
      "Πέτρου Α",
    ]),
    BibleBook("2PE", _nt, "2. Petrus", "2Petr", [
      "2 Petrus",
      "2 Peter",
      "2 Pet",
      "2 Pe",
      "2 Pt",
      "2 Petri",
      "Petri II",
      "Πέτρου Β",
    ]),
    BibleBook("1JN", _nt, "1. Johannes", "1Joh", [
      "1 Johannes",
      "1 John",
      "1 Jn",
      "1 Jo",
      "1 Joannis",
      "Iohannis I",
      "Ἰωάννου Α",
    ]),
    BibleBook("2JN", _nt, "2. Johannes", "2Joh", [
      "2 Johannes",
      "2 John",
      "2 Jn",
      "2 Jo",
      "2 Joannis",
      "Iohannis II",
      "Ἰωάννου Β",
    ]),
    BibleBook("3JN", _nt, "3. Johannes", "3Joh", [
      "3 Johannes",
      "3 John",
      "3 Jn",
      "3 Jo",
      "3 Joannis",
      "Iohannis III",
      "Ἰωάννου Γ",
    ]),
    BibleBook("JUD", _nt, "Judas", "Jud", ["Judas", "Jude", "Judae", "Ἰούδα"]),
    BibleBook("REV", _nt, "Offenbarung", "Offb", [
      "Offenbarung",
      "Offenbarung des Johannes",
      "Offenbarung an Johannes",
      "Apokalypse",
      "Apocalypsis",
      "Apocalypse",
      "Revelation",
      "Rev",
      "Apk",
      "Apc",
      "Off",
      "Ἀποκάλυψις",
    ]),
  ];

  static final Map<String, BibleBook> _byId = {for (final b in all) b.id: b};

  static final Map<String, int> _order = {
    for (int i = 0; i < all.length; i++) all[i].id: i,
  };

  static final Map<String, BibleBook> _byAbbreviation = {
    for (final b in all) b.abbreviation: b,
  };

  // Schlüssel der Stelleneingabe → Bücher. Ein Schlüssel kann mehrdeutig
  // sein (z. B. „1 Regum“: 1. Samuel in der Vulgata, sonst 1. Könige).
  static final Map<String, List<BibleBook>> _byKey = _buildKeys();

  static Map<String, List<BibleBook>> _buildKeys() {
    final result = <String, List<BibleBook>>{};

    for (final book in all) {
      final names = {book.name, book.abbreviation, book.id, ...book.aliases};

      for (final name in names) {
        final list = result.putIfAbsent(nameKey(name), () => []);

        if (!list.contains(book)) list.add(book);
      }
    }

    return result;
  }

  static BibleBook? byId(String id) => _byId[id];

  /// Position in der kanonischen Reihenfolge; unbekannte Bücher am Ende.
  static int order(String id) => _order[id] ?? all.length;

  /// Das Buch zu einer Abkürzung der Perikopenliste, z. B. „1Kön“.
  static BibleBook? byAbbreviation(String abbreviation) {
    return _byAbbreviation[abbreviation.trim()];
  }

  /// Deutscher Name; für unbekannte Kennungen die Kennung selbst.
  static String nameOf(String id) => _byId[id]?.name ?? id;

  static String abbreviationOf(String id) => _byId[id]?.abbreviation ?? id;

  /// Vergleichsform eines Buchnamens: ohne Akzente, Punkte und Leerzeichen,
  /// klein geschrieben; führende römische Ordnungszahlen bleiben Wörter.
  static String nameKey(String name) {
    return foldForSearch(name, keepUmlauts: false).replaceAll(" ", "");
  }

  /// Die Kennung, unter der [bookId] in [translation] zu finden ist. Daniel
  /// und Ester stehen in der Septuaginta nur in der griechischen Fassung.
  static String? resolveIn(BibleTranslation translation, String bookId) {
    if (translation.hasBook(bookId)) return bookId;

    const alternatives = {
      "DAN": "DAG",
      "DAG": "DAN",
      "EST": "ESG",
      "ESG": "EST",
    };

    final other = alternatives[bookId];

    if (other != null && translation.hasBook(other)) return other;

    return null;
  }

  /// Sucht das Buch zu einem eingegebenen Namen.
  ///
  /// Zuerst gelten die Namen der Ausgabe selbst, dann die bekannten Namen
  /// und Abkürzungen, zuletzt ein eindeutiger Wortanfang. Mehrdeutige
  /// Eingaben („Jo“) ergeben `null`.
  static String? find(String input, {BibleTranslation? translation}) {
    final key = nameKey(input);

    if (key.isEmpty) return null;

    bool available(String id) => translation == null || translation.hasBook(id);

    // Namen der Ausgabe, z. B. „ΚΑΤΑ ΜΑΡΚΟΝ“ oder „Μαρκον“.
    final own = <String, Set<String>>{};

    if (translation != null) {
      for (final book in translation.books) {
        for (final name in {book.name, book.longName}) {
          for (final variant in _ownVariants(name)) {
            own.putIfAbsent(variant, () => {}).add(book.id);
          }
        }
      }

      final exact = own[key];

      if (exact != null && exact.length == 1) return exact.first;
    }

    final known = _byKey[key];

    if (known != null) {
      // Führt die Ausgabe keines der Bücher, gilt die erste Bedeutung; der
      // Reader meldet dann, dass das Buch fehlt.
      final matching = known.where((b) => available(b.id));

      return (matching.isEmpty ? known.first : matching.first).id;
    }

    // Eindeutiger Wortanfang, z. B. „Matth“ oder „Apostelg“.
    if (key.length < 2) return null;

    final candidates = <String>{};

    for (final entry in own.entries) {
      if (entry.key.startsWith(key)) candidates.addAll(entry.value);
    }

    for (final entry in _byKey.entries) {
      if (entry.key.startsWith(key)) {
        candidates.addAll(
          entry.value.where((b) => available(b.id)).map((b) => b.id),
        );
      }
    }

    return candidates.length == 1 ? candidates.first : null;
  }

  // Griechische Buchtitel beginnen mit „ΚΑΤΑ“ bzw. „ΠΡΟΣ“; die Eingabe
  // darf sie weglassen.
  static Iterable<String> _ownVariants(String name) sync* {
    final key = nameKey(name);

    if (key.isEmpty) return;

    yield key;

    for (final prefix in const ["κατα", "προσ"]) {
      if (key.startsWith(prefix) && key.length > prefix.length) {
        yield key.substring(prefix.length);
      }
    }
  }
}
