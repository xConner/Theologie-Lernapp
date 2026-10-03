import 'module_info.dart';

/// Allgemeine Angaben zur App.
class AppInfo {
  AppInfo._();

  static const String name = "Theologie Lernapp";

  /// Muss der `version` in pubspec.yaml entsprechen (durch
  /// test/info_report_test.dart abgesichert).
  static const String version = "1.0.0+1";

  static const String repositoryUrl =
      "https://github.com/xConner/Theologie-Lernapp";

  /// Öffentliche Website; Impressum und Datenschutz liegen dort als
  /// statische Seiten (Quelle: web/impressum.html, web/datenschutz.html).
  static const String websiteUrl = "https://www.theologie.app/";
}

/// Zentrale, deklarative Beschreibung aller inhaltlichen Bereiche.
///
/// WICHTIG: Hier stehen nur Angaben, die im Projekt belegt sind (Code,
/// Datendateien, Skripte). Unbekannte Herkunft bleibt unbekannt
/// (`origin: null`) und wird nicht durch eine plausibel klingende Quelle
/// ersetzt.
class AppModules {
  AppModules._();

  /// Für Meldungen ohne Bezug zu einem bestimmten Bereich.
  static const ModuleInfo general = ModuleInfo(
    id: "general",
    title: "Allgemein",
    description: "",
  );

  static const ModuleInfo pericopeQuiz = ModuleInfo(
    id: "pericope_quiz",
    title: "Perikopenquiz",
    description:
        "Zu einem Perikopentitel wird die passende Bibelstelle abgefragt. "
        "Die Eingabe wird mit der in der App hinterlegten Stelle verglichen; "
        "die Wiederholung richtet sich nach deinem Lernstand.",
    sources: [
      SourceInfo(
        title: "Perikopen (Titel und Bibelstellen)",
        processing:
            "Die Perikopen sind als Liste mit Titel, Buch sowie Anfangs- und "
            "Endstelle in der App hinterlegt.",
      ),
    ],
    notes: [
      "Abgrenzung und Überschriften von Perikopen unterscheiden sich je nach "
          "Bibelausgabe. Welche Ausgabe der Liste zugrunde liegt, ist im "
          "Projekt nicht dokumentiert.",
    ],
  );

  static const ModuleInfo greekVocabulary = ModuleInfo(
    id: "greek_vocabulary",
    title: "Griechisch – Vokabeln",
    description:
        "Vokabeltrainer und Vokabelübersicht für Altgriechisch. Abgefragt "
        "werden Übersetzung und – je nach Einstellung – Artikel, Genitiv "
        "und Aorist.",
    sources: [
      SourceInfo(
        title: "Vokabelliste",
        processing:
            "Die Vokabeln sind in Lernschritte gegliedert in der App "
            "hinterlegt. Im Projekt liegen Skripte, die doppelte Einträge "
            "entfernen und alle Verben auf -μαι als Deponens kennzeichnen.",
      ),
    ],
    notes: [
      "Bei mehreren möglichen Übersetzungen gelten nur die hinterlegten "
          "Bedeutungen als richtig.",
    ],
  );

  static const ModuleInfo greekGrammarTrainer = ModuleInfo(
    id: "greek_grammar_trainer",
    title: "Griechisch – Grammatiktrainer",
    description:
        "Zu einer flektierten Form von Nomen, Verben und Pronomen aus der "
        "Vokabelliste werden die grammatischen Bestimmungen und die Grundform "
        "abgefragt.",
    sources: [
      SourceInfo(
        title: "Flektierte Formen",
        origin: "Wiktionary (englischsprachige Ausgabe), Flexionstabellen",
        processing:
            "Das Backend der App (theologie.app) ruft beim Üben die "
            "Flexionstabelle des jeweiligen Wortes ab und liest die gefragte "
            "Form automatisch aus. Die Formen sind nicht in der App "
            "gespeichert.",
        aiNote:
            "Die Formen werden nicht von einer KI erzeugt, sondern aus "
            "Wiktionary ausgelesen.",
        license: "Texte von Wiktionary: CC BY-SA 4.0",
        url: "https://en.wiktionary.org",
      ),
      SourceInfo(
        title: "Pronomen",
        origin:
            "Paradigmen, Gebrauchshinweise und Beispielsätze nach den "
            "Unterlagen des Sprachkurses Griechisch 1",
        processing:
            "Die Formen der Pronomen sind fest in der App hinterlegt und "
            "werden nicht aus Wiktionary geladen. Formal gleiche Formen "
            "werden anhand dieser Tabellen erkannt.",
        aiNote:
            "Die Tabellen wurden mit KI-Unterstützung aus den Unterlagen "
            "übertragen; die deutschen Übersetzungen der Beispielsätze "
            "stammen teilweise von einer KI.",
      ),
      SourceInfo(
        title: "Wörter und Übersetzungen",
        origin: "Vokabelliste der App (siehe „Griechisch – Vokabeln“)",
      ),
    ],
    notes: [
      "Wiktionary wird von Freiwilligen gepflegt und kann Fehler oder "
          "abweichende Dialektformen enthalten. Auch die automatische "
          "Auswahl der Form aus der Tabelle kann im Einzelfall danebenliegen.",
      "Einzelne Wörter und Formen sind vom Training ausgenommen.",
      "Für Nomen und Verben benötigt der Trainer eine Internetverbindung.",
    ],
  );

  static const ModuleInfo greekGrammarOverview = ModuleInfo(
    id: "greek_grammar_overview",
    title: "Griechisch – Grammatikübersicht",
    description:
        "Übersichtstabellen zum bestimmten Artikel, zu Deklinationen, "
        "Pronomen und Konjugationen.",
    sources: [
      SourceInfo(
        title: "Tabellen",
        processing: "Die Tabellen sind fest in der App hinterlegt.",
      ),
    ],
  );

  static const ModuleInfo latinVocabulary = ModuleInfo(
    id: "latin_vocabulary",
    title: "Latein – Vokabeln",
    description:
        "Vokabeltrainer für Latein. Abgefragt werden Übersetzung und – je "
        "nach Einstellung – Zusatzformen und Genus.",
    sources: [
      SourceInfo(
        title: "Vokabelliste",
        processing:
            "Die Vokabeln sind in Schritte und Unter-Schritte gegliedert in "
            "der App hinterlegt. Laut Projektcode orientieren sich die "
            "Zusatzformen an einem Lehrbuch, das im Projekt nicht benannt "
            "ist.",
      ),
    ],
    notes: [
      "Bei mehreren möglichen Übersetzungen gelten nur die hinterlegten "
          "Bedeutungen als richtig.",
    ],
  );

  static const ModuleInfo confessions = ModuleInfo(
    id: "confessions",
    title: "Bekenntnisse",
    description:
        "Altkirchliche und lutherische Bekenntnistexte, je nach Text in "
        "mehreren Sprachen.",
    sources: [SourceInfo(title: "Bekenntnistexte und Übersetzungen")],
    notes: [
      "Welche Textausgaben und Übersetzungen verwendet wurden, ist im "
          "Projekt nicht dokumentiert. Für wissenschaftliches Arbeiten "
          "bitte eine zitierfähige Ausgabe heranziehen.",
    ],
  );

  static const ModuleInfo prayers = ModuleInfo(
    id: "prayers",
    title: "Gebete",
    description:
        "Biblische, liturgische und überlieferte Gebete in mehreren "
        "Sprachfassungen.",
    sources: [
      SourceInfo(
        title: "Gebetstexte",
        origin:
            "Zu jedem Gebet sind Quelle, Datierung und – soweit bekannt – "
            "Verfasser angegeben, zu jeder Sprachfassung zusätzlich die "
            "Textgrundlage. Die Angaben stehen auf der Seite des jeweiligen "
            "Gebets.",
        processing:
            "Jede Fassung ist als Originalsprache, Übersetzung, "
            "eigenständige liturgische Fassung oder Nachdichtung "
            "gekennzeichnet.",
      ),
    ],
    notes: [
      "Die Quellenangaben sind Teil des Datensatzes der App. Wie sie "
          "zusammengestellt und ob sie gegen die genannten Ausgaben geprüft "
          "wurden, ist im Projekt nicht dokumentiert.",
    ],
  );

  static const ModuleInfo calendar = ModuleInfo(
    id: "liturgical_calendar",
    title: "Liturgischer Kalender",
    description:
        "Sonn- und Feiertage mit liturgischer Farbe, Wochenspruch, Psalm, "
        "Liedern, Lesungen und Predigttext.",
    sources: [SourceInfo(title: "Kalenderdaten, Lesungen und Wochensprüche")],
    notes: [
      "Der Kalender enthält derzeit nur einen Teil des Jahres 2026.",
      "Welcher Bibelübersetzung die zitierten Wochensprüche folgen, ist im "
          "Projekt nicht dokumentiert.",
    ],
  );

  static const ModuleInfo hymns = ModuleInfo(
    id: "hymns",
    title: "Evangelisches Gesangbuch",
    description:
        "Lieder nach den Nummern des Evangelischen Gesangbuchs (EG) mit "
        "Suche nach Nummer, Titel, Verfasser, Schlagwort und Bibelstelle.",
    sources: [
      SourceInfo(
        title: "Liedtexte, Text- und Melodieangaben",
        origin:
            "Die Lieder folgen der Nummerierung des Evangelischen "
            "Gesangbuchs; Angaben zu Text und Melodie stehen beim jeweiligen "
            "Lied. Aus welcher Ausgabe oder Vorlage die Texte in den "
            "Datensatz übernommen wurden, ist im Projekt nicht dokumentiert.",
      ),
      SourceInfo(title: "Schlagworte, Bibelstellen und Erklärungen"),
    ],
    notes: [
      "Bei einem Teil der Lieder wird der Text aus urheberrechtlichen "
          "Gründen nicht angezeigt.",
      "Erklärungen, Schlagworte und Bibelstellen sind nicht bei allen "
          "Liedern vorhanden.",
    ],
  );

  /// Bereiche, die in „Über die App“ aufgelistet werden.
  static const List<ModuleInfo> all = [
    pericopeQuiz,
    calendar,
    hymns,
    confessions,
    prayers,
    greekVocabulary,
    greekGrammarTrainer,
    greekGrammarOverview,
    latinVocabulary,
  ];
}
