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

  /// Einladung zum Discord-Server: Anlaufstelle für Fragen, Ideen und
  /// Mitarbeit.
  static const String discordUrl = "https://discord.gg/vkk2f7RTMe";

  /// Öffentliche Website; Impressum und Datenschutz liegen dort als
  /// statische Seiten (Quelle: web/impressum.html, web/datenschutz.html).
  static const String websiteUrl = "https://www.theologie.app/";

  /// Name der Website, z. B. im Footer und im Copyright-Hinweis.
  static const String websiteName = "theologie.app";
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
        "Die drei altkirchlichen Symbole und das vollständige "
        "Konkordienbuch der evangelisch-lutherischen Kirche, deutsch, "
        "lateinisch und englisch.",
    sources: [
      SourceInfo(
        title: "Bekenntnistexte und Übersetzungen",
        origin:
            "Concordia Triglotta (St. Louis: Concordia Publishing House, "
            "1921); die altkirchlichen Symbole zusätzlich in den "
            "ökumenischen und liturgischen Fassungen. Die genaue Fassung "
            "steht unter jedem Text bei „Quelle“.",
        processing:
            "Ein Teil der Texte ist von Hand am Faksimile des Drucks "
            "geprüft. Die übrigen stammen aus elektronischen Textfassungen "
            "und wurden maschinell Wort für Wort mit Texterkennungen des "
            "Drucks abgeglichen; welcher Abschnitt wie geprüft ist, nennt "
            "die Quellenangabe. Absatzzähler und Herausgeberzusätze in "
            "eckigen Klammern sind weggelassen.",
        aiNote:
            "Zerlegung, Abgleich und Zusammenstellung der Texte erfolgten "
            "mit KI-Unterstützung (Skripte unter tool/content_import).",
      ),
    ],
    notes: [
      "Die maschinell abgeglichenen Texte können einzelne Lesefehler "
          "enthalten. Für wissenschaftliches Arbeiten bitte eine "
          "zitierfähige Ausgabe heranziehen; Fehler lassen sich über die "
          "Meldefunktion mitteilen.",
      "Nicht aufgenommen sind die Unterschriftenlisten, das Verzeichnis der "
          "Zeugnisse (Catalogus Testimoniorum) und die Register.",
    ],
  );

  static const ModuleInfo prayers = ModuleInfo(
    id: "prayers",
    title: "Gebete",
    description:
        "Biblische, liturgische und überlieferte Gebete sowie die festen "
        "Stücke von Gottesdienst, Abendmahl, Taufe und Beichte, nach "
        "Rubriken geordnet.",
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
      "Die liturgischen Stücke und Kollektengebete folgen einer einzigen "
          "Agende (Kirchenbuch für Evangelisch-Lutherische Gemeinden, "
          "Philadelphia 1877) in deren Orthographie und sind am Faksimile "
          "nachgelesen; andere Agenden haben abweichende Wortlaute.",
      "Bei den älteren Einträgen sind die Quellenangaben Teil des "
          "Datensatzes; ob sie alle gegen die genannten Ausgaben geprüft "
          "wurden, ist nicht durchgehend dokumentiert.",
    ],
  );

  static const ModuleInfo memorization = ModuleInfo(
    id: "memorization",
    title: "Texte auswendig lernen",
    description:
        "Gebete, liturgische Texte und Bekenntnisse abschnittsweise "
        "auswendig lernen: vom "
        "Mitlesen über Lücken und Anfangsbuchstaben bis zum freien Aufsagen "
        "oder Schreiben. Gelernte Abschnitte werden verbunden und in "
        "wachsenden Abständen wiederholt.",
    sources: [
      SourceInfo(
        title: "Lerntexte",
        origin:
            "Texte der Bereiche „Gebete“ und „Bekenntnisse“ dieser App "
            "(Quellen siehe dort)",
        processing:
            "Die Texte werden in der App automatisch anhand von Zeilen, "
            "Absätzen und Satzzeichen in Abschnitte geteilt. Lücken und "
            "Anfangsbuchstaben werden daraus auf dem Gerät erzeugt.",
      ),
      SourceInfo(
        title: "Auswertung",
        processing:
            "Getippte oder gesprochene Wiedergaben werden auf dem Gerät Wort "
            "für Wort mit dem Text verglichen. Groß-/Kleinschreibung, "
            "Satzzeichen und Akzente bleiben unberücksichtigt.",
        aiNote: "Für die Auswertung wird keine KI verwendet.",
      ),
      SourceInfo(
        title: "Spracherkennung",
        processing:
            "Für das Aufsagen nutzt die App die Spracherkennung des Geräts "
            "bzw. Browsers. Die App speichert keine Aufnahme und erhält nur "
            "den erkannten Text. Je nach Gerät oder Browser kann die "
            "Erkennung bei dessen Anbieter stattfinden.",
      ),
      SourceInfo(
        title: "Spracherkennung für Latein",
        origin:
            "Sprachmodell Whisper „small“ (OpenAI, MIT-Lizenz), ausgeführt "
            "mit sherpa-onnx bzw. im Browser mit Transformers.js und ONNX "
            "Runtime (Apache-2.0 / MIT)",
        processing:
            "Für Latein bietet kein Gerät eine Spracherkennung. Die App "
            "nutzt dafür ein eigenes Sprachmodell, das vollständig auf dem "
            "Gerät bzw. im Browser rechnet: Die Aufnahme wird weder "
            "gespeichert noch übertragen. Das Modell wird beim ersten "
            "Gebrauch nach Rückfrage einmalig von huggingface.co geladen "
            "(ca. 250–375 MB). Weil das Modell Latein nach Gehör schreibt, "
            "wird das Erkannte vor dem Wortvergleich nach festen Regeln "
            "lautlich mit dem Lerntext abgeglichen.",
        aiNote:
            "Die Umwandlung von Sprache in Text erfolgt mit einem "
            "KI-Sprachmodell auf dem Gerät. Der Vergleich mit dem Lerntext "
            "erfolgt ohne KI.",
      ),
    ],
    notes: [
      "Die Spracherkennung steht nicht in jedem Browser und nicht für "
          "Altgriechisch zur Verfügung. Dort kann getippt oder im Kopf "
          "aufgesagt werden.",
      "Die lateinische Erkennung braucht ein leistungsfähiges Gerät; die "
          "Auswertung dauert nach dem Aufsagen einige Sekunden.",
      "Die Spracherkennung kann Wörter falsch verstehen. Eine gemeldete "
          "Abweichung ist dann kein Fehler beim Aufsagen.",
      "Die Einteilung in Abschnitte erfolgt automatisch und ist nicht "
          "redaktionell geprüft.",
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
        "Suche nach Nummer, Titel, Verfasser, Schlagwort und Bibelstelle. "
        "Im Lied lässt sich zwischen „Nur Text“ und „Text und Noten“ "
        "umschalten, soweit Noten vorhanden sind.",
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
      SourceInfo(
        title: "Noten",
        origin:
            "Melodien nach den Tonsätzen von Peter Gerloff auf Wikimedia "
            "Commons (Kategorie „Melodies from Evangelisches Gesangbuch“), "
            "überwiegend unter CC0, bei einigen Liedern nach den "
            "Notensätzen der Wikipedia-Liedartikel (CC BY-SA 4.0). Vorlage "
            "und Lizenz stehen unter jedem Notenbild.",
      ),
    ],
    notes: [
      "Noten gibt es bisher nur für einen Teil der Lieder. Die erste "
          "Strophe steht nur dann unter den Noten, wenn die Zuordnung der "
          "Silben mit einer Vorlage übereinstimmt oder zwingend ist (jede "
          "Silbe genau ein Ton); sonst erscheint die Melodie allein. Die "
          "Noten wurden automatisch aus den Vorlagen erzeugt; Tonart und "
          "Notenwerte können von der Fassung im Gesangbuch abweichen.",
      "Bei einem Teil der Lieder wird der Text aus urheberrechtlichen "
          "Gründen nicht angezeigt.",
      "Erklärungen, Schlagworte und Bibelstellen sind nicht bei allen "
          "Liedern vorhanden.",
    ],
  );

  static const ModuleInfo bible = ModuleInfo(
    id: "bible",
    title: "Bibel",
    description:
        "Bibel-Reader mit mehreren Ausgaben in Deutsch, Englisch, Griechisch "
        "und Latein. Die Texte sind in der App enthalten und ohne "
        "Internetverbindung lesbar; gesucht wird nach Stellen und im Text "
        "der gewählten Ausgabe. Dazu kommen Lesepläne und eine "
        "Bibellese-Streak: Ein Tag zählt, sobald du eine Lesung selbst als "
        "gelesen markiert hast.",
    sources: [
      SourceInfo(
        title: "Bibeltexte",
        origin:
            "Frei verwendbare Ausgaben von eBible.org. Edition, Copyright "
            "und Lizenz stehen bei jeder Ausgabe in der Übersetzungsauswahl "
            "(Symbol ⓘ).",
        processing:
            "Die Texte wurden aus den USFM-Dateien der Quelle übernommen. "
            "Der Wortlaut ist unverändert; entfernt wurden nur die "
            "Formatmarken, bei der Vulgata außerdem die beigegebene Glossa "
            "ordinaria.",
        url: "https://ebible.org/",
      ),
      SourceInfo(
        title: "Perikopenüberschriften",
        origin:
            "Perikopen-Datensatz von theologie.app – dieselbe Liste, aus "
            "der das Perikopenquiz seine Fragen bildet.",
        processing:
            "Die Überschriften stehen im Reader am ersten Vers der "
            "jeweiligen Perikope. Sie wurden unabhängig von der "
            "ausgewählten Bibelübersetzung erstellt und sind nicht "
            "Bestandteil des jeweiligen Bibeltextes.",
      ),
    ],
    notes: [
      "Die integrierten Lesepläne sind eigene Einteilungen von "
          "theologie.app nach Kapitel- und Verszahlen; sie enthalten nur "
          "Stellenangaben. Eigene Pläne lassen sich erstellen oder als "
          "JSON-Datei importieren.",
      "Die Ausgaben zählen Kapitel und Verse teilweise unterschiedlich, vor "
          "allem im Alten Testament und in den Psalmen. Perikopen und "
          "ihre Überschriften folgen der Zählung deutscher Bibelausgaben. "
          "In englisch gezählten Ausgaben (auch Luther 1912 und Schlachter "
          "1951) rechnet die App verschobene Kapitelgrenzen um, z. B. "
          "1. Mose 32,1 = 31,55.",
      "Wo sich eine Stelle nicht sicher übertragen lässt (Psalmen, "
          "Septuaginta, Vulgata), kann die Hervorhebung um einzelne Verse "
          "abweichen; Perikopenüberschriften werden dort nicht angezeigt.",
      "Die Lutherbibel 1912 nennt in ihrem Text die abweichende deutsche "
          "Zählung in eckigen Klammern, z. B. „[32:1]“. Das gehört zum "
          "Wortlaut der Quelle und wird nicht verändert.",
      "Nicht jede Ausgabe enthält alle Bücher: Das SBL Greek New Testament "
          "umfasst nur das Neue Testament, Apokryphen stehen nur in "
          "Septuaginta und Vulgata.",
    ],
  );

  /// Bereiche, die in „Über die App“ aufgelistet werden.
  static const List<ModuleInfo> all = [
    pericopeQuiz,
    bible,
    calendar,
    hymns,
    confessions,
    prayers,
    memorization,
    greekVocabulary,
    greekGrammarTrainer,
    greekGrammarOverview,
    latinVocabulary,
  ];
}
