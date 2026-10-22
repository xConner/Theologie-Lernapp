# Architektur der Trainer

Kurzer Überblick, wo welche Verantwortung liegt. Grundsatz: gemeinsame
Infrastruktur + trainer-spezifische Fachlogik – kein „Universaltrainer“.

## Gemeinsame Infrastruktur

| Aufgabe | Ort |
|---|---|
| Lernstand je Karte (`stability`, `difficulty`, `lastReviewed`, Lernhilfe) | `models/greek/vocabulary/learning_card.dart` |
| Laden/Speichern der Lernstände, Konto (Firestore) oder Gast (lokal) | `services/learning_service.dart`, `services/local_learning_store.dart` |
| Dokumente unter `quiz_settings` (Bücher lernen, Kirchengeschichte, Altes Testament, Latein-Lernplan), Konto oder Gast, Kartenfeld `cards` | `services/quiz_documents.dart` (`QuizDocuments`, `QuizCardDocument`) |
| Auswahl der nächsten Frage (Vokabeln, Perikopen) | `algorithms/learning_selector.dart`, `algorithms/spaced_repetition.dart` |
| Auswahl nach grammatischer Bestimmung | `algorithms/grammar_learning.dart` |
| Sound, Tagesstatistik, Streak nach einer Antwort | `reportTrainerAnswer` in `widgets/trainer_widgets.dart` |
| Lernhilfe, Sound-Schalter, Ergebnis-Rahmen | `widgets/trainer_widgets.dart` |
| Auswahl-Bausteine der Einstellungsdialoge | `widgets/settings_selection.dart`, `widgets/settings_access.dart` |

Lernfortschritte zurücksetzen – alle, je Lernbereich oder die
Perikopenkenntnisse eines Bibelbuchs – geschieht zentral in
`ProgressDataService` (`resetProgress`, `resetArea`, `resetPericopeBook`).
Die Lernbereiche und ihre Collections stehen in `ProgressArea`
(`services/progress_reset.dart`); Einstellungen, Eselsbrücken und Inhalte
bleiben erhalten, und es läuft immer nur ein Zurücksetzen zur Zeit.
Streaks, Tagesstatistik, Lesepläne und Klausur-Markierungen gehören nicht
dazu.

Streaks berechnet nur `StreakCalculator` (`services/streak/streak_state.dart`)
auf lokalen Kalendertagen; `StreakService` lädt, zählt und speichert sie für
alle Lernbereiche. Ein leerer Firestore-Cache (offline, im Web nach jedem
Neuladen) gilt als Ladefehler, nicht als „keine Streak“: Bis der Stand
gelesen ist, wird nichts gespeichert, und offline gezählte Antworten werden
danach nachgetragen. Beim Neuladen gewinnt je Track der weiter
fortgeschrittene Stand (`StreakCalculator.merge`), und vor dem Zählen wird
ein Stand von einem früheren Tag oder älter als 15 Minuten neu geladen,
damit ein offener Tab keine auf einem anderen Gerät fortgeführte Streak
zurücksetzt.

`uid == null` bedeutet überall Gastmodus: dieselben Datenstrukturen, lokal
über `LocalLearningStore` statt in Firestore. Die Collection-Namen stehen
einmal in `LocalLearningStore.cardCollections`.

## Je Trainer

Jeder Trainer besitzt einen Screen (Sitzungszustand, Dialoge), einen
Einstellungs-Service (ein Lesezugriff je Öffnen) und seine Antwortprüfung.

| Trainer | Einstellungen | Antwortprüfung |
|---|---|---|
| Griechisch-Vokabeln | `services/greek/vocabulary/vocabulary_settings_service.dart` | `vocabulary_answer_checker.dart` |
| Latein-Vokabeln (Trainer und Lernplan) | `services/latin/vocabulary/latin_vocabulary_settings_service.dart`, Plan: `latin_vocabulary_plan_store.dart` | `latin_vocabulary_answer_checker.dart` (siehe [latin.md](latin.md)) |
| Griechisch-Grammatik | `services/greek/grammar/grammar_settings_service.dart` | `grammar_answer_check.dart` |
| Latein-Grammatik | `services/latin/grammar/latin_grammar_store.dart` | `latin_grammar_answer_check.dart` (siehe [latin.md](latin.md)) |
| Kirchengeschichte | `services/church_history/church_history_store.dart` | `church_history_quiz.dart` (siehe [church-history.md](church-history.md)) |
| Altes Testament | `services/old_testament/old_testament_store.dart` | `old_testament_quiz.dart` (siehe [old-testament.md](old-testament.md)) |
| Perikopenquiz | `services/settings_service.dart` | im `quiz_screen.dart` (Vergleich der Stellen) |
| Bücher systematisch lernen | `services/book_learning_storage.dart` | `quiz/books/reference_answer.dart` (siehe [pericope-books.md](pericope-books.md)) |

### Grammatiktrainer

* `grammar_question_picker.dart` – fachliche Regeln: Blacklist, Aoristblatt,
  εἰμί, zulässige Tempora und Genera Verbi je Verb, Auswahl der Grundform
  und der Zielbestimmung. Reine Funktionen, ohne UI und Netzwerk.
* `grammar_answer_check.dart` – Bewertung inklusive formal identischer
  Formen (Ambiguitäten) und Deponentien.
* `wiktionary_inflection_service.dart` – lädt Formen über `/api/greek-*`
  und merkt sich Formen samt möglicher Bestimmungen für die Sitzung.
* `utils/greek_normalization.dart` – Normalisierung für Anzeige und
  Vergleich der Grundform.
* `grammar_trainer_screen.dart` – Sitzungszustand, Preloading der nächsten
  Frage (`_preloadedQuestion`, Tokens gegen überholte Antworten) und UI.

Der Latein-Grammatiktrainer bildet seine Formen selbst
(`services/latin/grammar/latin_morphology.dart`, ohne Netzwerk) und
speichert Lernstand und Einstellungen als Dokumente unter `quiz_settings`
(`LatinGrammarStore`), ohne eigene Collection.

Ein neuer Trainer braucht eigene Regeln und eine
eigene Antwortprüfung, kann aber `LearningService`, `GrammarLearning`,
`reportTrainerAnswer` und die Widgets unverändert verwenden. Für den
Lernstand kommt eine Collection in `LocalLearningStore.cardCollections`,
in `firestore.rules` und in `AccountDeletionService.userCollections` hinzu.

## Texte auswendig lernen

Längere Texte (Gebete, Bekenntnisse, später z. B. Bibeltexte) werden
abschnittsweise gelernt. Kein eigener Unterbau: Der Lernstand je Abschnitt
ist eine `MemorizationCard` (erweitert `LearningCard`), gespeichert über
`LearningService` in der Collection `memorization`; die Abstände führt
`SpacedRepetition`.

| Aufgabe | Ort |
|---|---|
| Lerntext, Abschnitt, Werk (statischer Inhalt) | `models/memorization/memorization_text.dart` |
| Streak-Regel (zehn wortgetreu richtige Eingaben am Tag) | `services/memorization/memorization_streak_rule.dart` |
| Lernstand je Abschnitt (Hilfestufe, Versuche) | `models/memorization/memorization_card.dart` |
| Gebete/Bekenntnisse → Lerntexte | `services/memorization/memorization_catalog.dart` |
| Erzeugung der Bekenntnis- und Liturgiedaten (nicht Teil der App) | `tool/content_import/` |
| Zerlegung in Abschnitte | `services/memorization/text_segmenter.dart` |
| Überschriften als Abschnittstitel statt Lernaufgabe (Zehn Gebote, Kleiner Katechismus, Tischgebete) | `services/memorization/segment_headings.dart` |
| Lücken, Anfangsbuchstaben | `services/memorization/hint_generator.dart` |
| Wortvergleich mit Alignment (lokal, ohne KI) | `services/memorization/text_evaluator.dart` |
| Status, Tagesplan, Bewertung | `services/memorization/memorization_scheduler.dart` |
| Ablauf einer Lernrunde (Verbinden, Wiederholen) | `services/memorization/memorization_session.dart` |
| Lernstände, „Meine Texte“ und Favoriten (Konto/Gast) | `services/memorization/memorization_repository.dart` |
| Spracherkennung (austauschbar) | `services/speech/speech_recognition_service.dart` |
| Wahl der Erkennung je Sprache (Latein → eigenes Modell) | `services/speech/routing_speech_recognition_service.dart` |
| Lateinische Erkennung auf dem Gerät (Aufnahme, Whisper) | `services/speech/latin/`, im Web zusätzlich `web/latin_stt/` |
| Lautlicher Abgleich lateinischer Transkripte (lokal, ohne KI) | `services/memorization/latin_speech_matcher.dart` |
| Screens | `screens/memorization/` |

Jede Sprachfassung ist ein eigener Lerntext (`prayer.vaterunser.de`,
`prayer.vaterunser.la`) mit eigenem Lernstand. Eine neue Textquelle braucht
nur eine Methode im Katalog, die `MemorizationWork`s liefert.

Favoriten gelten je Werk (`prayer.vaterunser`, alle Sprachfassungen) und
liegen als Liste von IDs im Feld `favorites` von `memorization_settings` –
neben „Meine Texte“, getrennt vom Lernstand. Es gibt nur diesen einen
Bestand: Die Menüs Gebete und Bekenntnisse setzen und filtern dieselben IDs
(`services/memorization/favorite_ids.dart`); eine Bekenntnisschrift mit
mehreren Artikeln ist dort als Ganzes Favorit (`confession.<id>`). Geladene
`MemorizationRepository`-Instanzen desselben Nutzers übernehmen jede
gespeicherte Einstellungsänderung, damit alle Ansichten sofort denselben
Stand zeigen. Die Favoritenansicht verweist auf die Werke des Katalogs,
ohne Kopien.

Die Spracherkennung liefert ausschließlich ein Transkript; bewertet wird
lokal durch `MemorizationTextEvaluator`. Ob die Erkennung selbst auf dem
Gerät oder bei einem Dienst des Betriebssystems/Browsers läuft, hängt von
der Plattform ab – die App speichert keine Audioaufnahmen.

Latein erkennt kein Plattformdienst. Dafür nimmt die App selbst auf
(Paket `record`) und wandelt die Aufnahme mit Whisper „small“ auf dem Gerät
in Text um: nativ über `sherpa_onnx`, im Web über Transformers.js in einem
Web Worker. Das Modell wird beim ersten Gebrauch nach Rückfrage von
huggingface.co geladen (nativ ca. 375 MB, Web ca. 250 MB); die Aufnahme
bleibt im Arbeitsspeicher und verlässt das Gerät nicht. Weil Whisper Latein
nach Gehör schreibt, gleicht `LatinSpeechMatcher` das Transkript vor dem
Wortvergleich lautlich mit dem Lerntext ab. Im Web braucht die Aufnahme
`microphone=(self)` in der `Permissions-Policy` (`vercel.json`).

## Klausurersteller (Altgriechisch)

Erstellt Graecum-ähnliche Übungsklausuren aus griechischen Bibeltexten. Die
Teile sind getrennt, damit weitere Korpora, Phänomene und Aufgabenarten
ohne Umbau hinzukommen:

| Aufgabe | Ort |
|---|---|
| Textkorpora (NT, LXX; Edition, Quellen, Lizenzen) | `assets/greek_corpus/corpora.json`, Modell `models/greek/exam/text_corpus.dart` |
| Erzeugung der Korpora aus MorphGNT, Bibeltexten und Wiktionary (nicht Teil der App) | `tool/greek_exam_corpus/` |
| Dateiformat, Suchindex je Vers | `services/greek/exam/corpus_codec.dart` |
| Zugriff auf die Korpora (Assets, Zwischenspeicher) | `services/greek/exam/exam_corpus_source.dart` |
| Wortform mit allen Bestimmungen, Herkunft der Bestimmung | `models/greek/exam/corpus_token.dart`, `greek_morph_analysis.dart` |
| Vergleichsschlüssel griechischer Formen | `services/greek/exam/greek_form_key.dart` |
| Phänomene: IDs, Kategorien, Status, Voraussetzungen | `services/greek/exam/grammar_phenomena.dart` |
| Erkennung (sicher/möglich), Muster, Grundformlisten | `services/greek/exam/phenomenon_detection.dart` |
| Satzkonstruktionen (Genitivus absolutus, AcI, PC, Bedingungssätze …) | `services/greek/exam/syntax_rules.dart` |
| Vokabelkenntnis nach Lernschritten, Vokabelhilfen (deutsch, je Grundform) | `services/greek/exam/vocabulary_help.dart` |
| Vorausgesetzte Wörter: Artikel, Pronomen, gängige biblische Eigennamen | `services/greek/exam/assumed_vocabulary.dart` |
| Kürzung der Wörterbuchangaben auf Vokabelhilfen | `services/greek/exam/gloss_shortener.dart` |
| Konfiguration | `models/greek/exam/exam_config.dart` |
| Textsuche, Zufallsauswahl, Begründung ohne Treffer | `services/greek/exam/passage_finder.dart` |
| Aufgabenarten (Verben bestimmen; Aufgabe 3/4: Konstruktion markieren bzw. benennen, Kasus nach Präposition, Formen finden, Nominalformen) | `services/greek/exam/exam_task_types.dart` |
| Klausur erstellen, Aufgaben austauschen | `services/greek/exam/exam_generator.dart` |
| Antwortprüfung mit Mehrdeutigkeiten | `services/greek/exam/exam_answer_check.dart` |
| Konfiguration und bearbeitete Texte (Konto: `users/{uid}/greek_exam`, Gast: lokal) | `services/greek/exam/exam_store.dart` |
| Screens | `screens/greek/exam/` |
| Herkunft, Lizenzen, Grenzen der Daten | `docs/greek-exam-sources.md` |

Grundsätze:

* **Keine geratene Morphologie.** Das NT ist im Kontext bestimmt
  (MorphGNT). Die Septuaginta wird über einen Formenindex bestimmt; jede
  Form behält alle bekannten Bestimmungen, unbekannte bleiben unbestimmt.
  Jede Regel läuft „sicher“ (alle Bestimmungen erfüllen sie) und „möglich“
  (eine erfüllt sie): Erforderlich verlangt einen sicheren Beleg,
  ausgeschlossen verlangt, dass nicht einmal ein möglicher vorliegt und
  jedes Wort bestimmt ist.
* **Status je Phänomen.** Zuverlässig (aus der Bestimmung bzw. Grundform),
  regelbasiert (Satzkonstruktionen; nur forderbar) oder nicht verfügbar
  (nicht wählbar). Die Oberfläche zeigt den Status und enthält keine
  eigene Grammatiklogik.
* **Filter sind Lernstufen.** Ein Phänomen ist nur dann ein Filter, wenn
  es einen eigenständig gelernten Stoffbereich abbildet (Tempus, Modus,
  Verbklasse, Konstruktion). Person, Numerus, Kasus und Genus werden mit
  jeder Form mitgelernt und sind keine Filter; frühere Filter dieser Art
  stehen in `GrammarPhenomena.retiredFilters` und entfallen beim Lesen
  alter Einstellungen.
* **Vokabelhilfen nur deutsch, kurz und nur wo nötig.** Bekannt sind die
  gewählten Lernschritte der Vokabelliste, dazu Artikel, Pronomen und
  gängige biblische Eigennamen (`assumed_vocabulary.dart`, über die
  Grundform, nie über die Schreibweise). Jede übrige Grundform erhält eine
  Hilfe mit höchstens drei deutschen Bedeutungen; ohne deutsche Quelle
  bleibt sie als ungelöst gekennzeichnet. Das Lexikon enthält keine
  englischen Angaben.
* **Suche ohne Texte.** Der Index hält je Vers die Phänomene als Bitmenge;
  Abschnitte sind satzgerechte Versfolgen eines Kapitels. Gewählt wird
  gleichverteilt über die Anfangsverse aller passenden Abschnitte; in der
  Sitzung gezeigte Abschnitte erst wieder, wenn es keine anderen gibt.
* **Index und Regeln gehören zusammen.** `test/greek_exam_corpus_test.dart`
  vergleicht den Index ausgewählter Bücher mit den aktuellen Regeln. Nach
  Änderungen an Phänomenen oder Regeln den Import neu ausführen
  (`tool/greek_exam_corpus/README.md`).
* **Bearbeitet nur auf Wunsch.** Eine Passage-ID (`nt:JHN.1.1-5`) markiert
  genau den gestellten Versbereich; Austausch oder Generierung ändern den
  Status nie.

Ein neues Phänomen ist ein Eintrag in `GrammarPhenomena.all` (bei einer
neuen Konstruktion zusätzlich eine Funktion in `SyntaxRules`), eine neue
Aufgabenart eine Klasse in `ExamTaskTypes.extra`, ein neues Korpus ein
Eintrag im Import (`tool/greek_exam_corpus/README.md`).

## Bibel-Reader

Liest die mit der App ausgelieferten Bibeltexte ohne Internetverbindung.
Datenbeschaffung (Import) und Darstellung sind getrennt; der Reader kennt
die Texte nur über `BibleTextSource`.

| Aufgabe | Ort |
|---|---|
| Ausgabe mit Herkunft, Lizenz, Büchern und Zählung | `models/bible/bible_translation.dart` |
| Text eines Buchs (Verse, Überschriften, Anmerkungen) | `models/bible/bible_text.dart` |
| Stelle bzw. hervorzuhebende Stelle | `models/bible/bible_reference.dart` |
| Schnittstelle zu den Texten; ausgelieferte Texte aus `assets/bible/` | `services/bible/bible_text_source.dart` |
| Verzeichnis der Ausgaben, Zwischenspeicher, Suchindex | `services/bible/bible_repository.dart` |
| Bücher: Reihenfolge, Namen und Abkürzungen aller Sprachen | `services/bible/bible_books.dart` |
| Stellen lesen und schreiben, Stelle einer Perikope | `services/bible/bible_reference_parser.dart` |
| Stellenangaben des liturgischen Kalenders → Stellen für den Reader | `services/bible/liturgical_reference_parser.dart` |
| Textsuche und Vergleichsform (Akzente, Spiritus, ß) | `services/bible/bible_search.dart`, `bible_search_folding.dart` |
| Perikopenüberschriften aus `assets/perikopen.json` je Kapitel | `services/bible/pericope_headings.dart` |
| Gewählte Ausgabe, Lesestand, Darstellung (lokal) | `services/bible/bible_reader_settings.dart` |
| Kapiteldarstellung, Position eines Verses | `widgets/bible/bible_chapter_view.dart` |
| Screens: Reader, Stellenwahl, Suche, Übersetzungsauswahl | `screens/bible/` |
| Erzeugung der Texte (nicht Teil der App) | `tool/bible_import/` |
| Herkunft und Lizenzen | `docs/bible-sources.md` |

Welche Ausgaben es gibt, steht allein in `assets/bible/translations.json`;
die Übersetzungsauswahl entsteht daraus. Je Ausgabe liegt ein Verzeichnis mit
einer Datei je Buch vor: Beim Lesen wird nur das aufgeschlagene Buch geladen,
der App-Start bleibt unberührt. Eine Datenbank wäre für die Suche nicht
schneller und im Web aufwendiger; die Suche baut stattdessen je Ausgabe
einmal einen Index im Arbeitsspeicher auf (`BibleRepository.searchIndex`) und
durchläuft danach nur noch diesen.

Eine weitere Textquelle (nachladbare Ausgaben, ein Dienst) implementiert
`BibleTextSource` und wird dem `BibleRepository` übergeben.

Bücher tragen überall die USFM-Kennung (`GEN`, `MRK`). Das Perikopenquiz
übergibt seine Stellen mit `BibleReferenceParser.passageOf`; alle Varianten
einer Frage gehen gemeinsam an `BibleReaderScreen(passages: …)` – das sind
nur die Stellen aus den im Quiz gewählten Büchern (`QuizQuestion.forBooks`),
auch wenn dieselbe Perikopen-ID weitere Parallelstellen umfasst.

Die Perikopenliste zählt deutsch. `ListVersification`
(`services/bible/versification_map.dart`) überträgt ihre Stellen in englisch
gezählte Ausgaben (verschobene Kapitelgrenzen im Alten Testament, z. B.
1. Mose 32,1 = 31,55) und prüft jede Übertragung an den Verszahlen der
Ausgabe. Was sich nicht sicher übertragen lässt (Psalmen, Septuaginta,
Vulgata), bleibt unverändert; der Reader weist dann auf die abweichende
Zählung hin (`BibleVersification`).

Die Perikopenüberschriften im Text stammen allein aus der Perikopenliste,
nie aus einer Ausgabe; der Reader kennzeichnet sie entsprechend. Sie stehen
am Anfangsvers jeder Perikope, übertragen in die Zählung der gewählten
Ausgabe. Wo das nicht sicher möglich ist, zeigt
`PericopeHeadings.forChapter` keine Überschriften.

`test/perikopen_data_test.dart` prüft die ganze Perikopenliste gegen die
Verszahlen der Ausgaben (`test/perikopen_validator.dart`): ungültige Stellen,
widersprüchliche Doppeleinträge, Kapitelfragen, die nicht ihr Kapitel
umfassen, und Perikopen außerhalb der Reihenfolge. Bewusste Lücken,
Halbvers-Grenzen und übergeordnete Abschnitte sind zulässig; bekannte
Ausnahmen stehen dort mit Begründung.

Ausgabe, Lesestand und Schriftgröße gehören zum Gerät und liegen wie das
Erscheinungsbild in den `SharedPreferences`.

## Bibellesen: Streak und Lesepläne

Ob jemand gelesen hat, kann die App nicht feststellen. Eine Lesung zählt
deshalb nur nach ausdrücklicher Bestätigung („Als gelesen markieren“ bzw.
Abhaken einer Planlesung) – nie durch das Aufschlagen eines Kapitels.

| Aufgabe | Ort |
|---|---|
| Leseplan, Lesung, täglicher Umfang | `models/bible/reading_plan.dart` |
| Eintrag im Leseverlauf, Fortschritt eines Plans | `models/bible/bible_reading.dart` |
| Planformat lesen, prüfen, schreiben | `services/bible/reading_plan_codec.dart` |
| Texteingabe eigener Pläne | `services/bible/reading_plan_text.dart` |
| Leseverlauf, Pläne, Fortschritt; Meldung an die Streak | `services/bible/bible_reading_service.dart` |
| Speicher (Konto: `users/{uid}/bible_reading`, Gast: lokal) | `services/bible/bible_reading_repository.dart` |
| Bestätigungsdialog, Lesungen eines Plantags | `widgets/bible/bible_reading_widgets.dart` |
| Screens: Bibel-Startseite, Pläne, Plan, Import, Editor | `screens/bible/` |
| Integrierte Pläne und ihre Erzeugung | `assets/reading_plans/`, `tool/reading_plans/` |
| Format | `docs/reading-plans.md` |

Zwei getrennte Dinge:

* Die **Bibellese-Streak** ist der Track `bible` des `StreakService`
  (Tagesziel 1). Jede bestätigte Lesung – frei oder aus einem Plan – wird
  ihm gemeldet; ein lokaler Kalendertag zählt höchstens einmal.
* Der **Planfortschritt** (`plan_<Plan>`) hält fest, welche Lesungen eines
  Plans erledigt sind. Er ändert sich nur durch Abhaken; eine freie Lesung
  erledigt keinen Plantag. Ein Plan folgt nicht dem Kalender: „Aktueller
  Tag“ ist der erste Plantag mit einer offenen Lesung.

Der Reader bekommt die Lesungen eines Plantags als `passages`; mit
`planDay` lässt sich die aufgeschlagene Lesung dort erledigen.

## Themes und Erscheinungsbild

| Aufgabe | Ort |
| --- | --- |
| Farbpaletten (`AppColors.light`, `AppColors.dark`) und `ThemeData` (`AppTheme`) | `theme/app_theme.dart` |
| Gewähltes Erscheinungsbild (Hell, Dunkel, System), lokal gespeichert | `services/theme_settings.dart` |
| Auswahl durch den Nutzer | „Erscheinungsbild“ in `GeneralSettingsView` (`screens/settings_screen.dart`) |
| Anwenden auf die App | `MyApp` in `main.dart` |

Widgets verwenden keine festen Farben und fragen auch nicht ab, ob ein
dunkles Theme aktiv ist. Sie lesen die semantische Farbe des aktiven Themes
über `context.colors` (z. B. `context.colors.success` für „richtig“) oder
über `Theme.of(context)`.

Ein weiteres Theme (z. B. Sepia oder hoher Kontrast) braucht eine weitere
`AppColors`-Palette, ein daraus mit `AppTheme.fromColors` gebautes
`ThemeData` und einen gespeicherten Wert in `ThemeSettings`, nach dem `MyApp`
das Theme auswählt. `test/theme_test.dart` prüft die Kontraste jeder Palette.

## Studiumsorganisation (Stundenplan, Veranstaltungssuche, Studienunterlagen)

Ein Hauptpunkt auf dem Startbildschirm (`StudyOrganizationButton`) öffnet
`StudyOrganizationScreen` mit drei Reitern:

1. **Stundenplan** – Wochenübersicht als Raster (Mo–Fr als Spalten, Zeit von
   oben nach unten, Wochenende nur mit Terminen), Filter „Alle / Regelmäßige
   / Block- und Einzeltermine“ (je Termin, auf dem Gerät gemerkt),
   Überschneidungsstellen der Woche und des Semesters. Die Art eines
   Termins (`SessionKind` in `plan_schedule.dart`: wöchentlich, alle n
   Wochen, wiederkehrend ohne festen Rhythmus, Wochen unbekannt, Block,
   Einzeltermin) gilt einheitlich für Raster, Filter, Überschneidungen und
   PDF. Sie folgt der Regel der Quelle; Einzel- und Blocktermine werden
   anhand der Daten als Serie erkannt (mindestens drei Termine am selben
   Wochentag zur selben Uhrzeit in verschiedenen Wochen; einen Abstand nennt
   die App erst ab vier gleich weit entfernten Terminen, ohne
   unterrichtsfreie Wochen). „Alle n Wochen“ ohne Startwoche steht in jeder
   Vorlesungswoche als unsicherer Termin und zählt nicht als
   Überschneidung. Über „Drucken / als
   PDF exportieren“ (`TimetableExportScreen`) entsteht lokal ein PDF: A4
   quer oder hoch, Wochenraster im UnivIS-Stil (bei langen Tagen auf
   mehrere Seiten verteilt, Spaltenköpfe wiederholt), danach
   Veranstaltungsliste, Block- und Sondertermine mit Datum und
   Überschneidungen. Grundlage ist derselbe Plan wie in der Ansicht
   (`TimetableController.plan`, Filter als Voreinstellung); regelmäßige
   Termine werden aus den konkreten Terminen zu Wochenmustern
   zusammengefasst, nicht neu berechnet. Schrift: Lato (eingebettet, SIL OFL
   1.1, `assets/fonts/Lato-OFL.txt`).
2. **Veranstaltungen suchen** – vollständiges Verzeichnis der Theologischen
   Fakultät (lokal gefiltert, offline nutzbar) oder UnivIS-Titel-/
   Nummernsuche über alle bzw. eine Fakultät; Hinzufügen mit Vorschau und
   Korrektur.
3. **Studienunterlagen** – Verweise auf offizielle Dokumente der Fakultät
   und der CAU (nur Links, keine Kopien).

Datenquelle ist UnivIS der CAU über `/api/catalog` (Freigabe und Betrieb:
`docs/univis-integration-feasibility.md`, Abschnitte 13 und 14).

```
UnivIS (univis.uni-kiel.de/prg, show=xml)
   │ Fakultätskatalog: 1 Abruf je Semester und Tag · Suche: je Suchbegriff, 12 h Cache, Drosselung
api/catalog.ts → api/_lib/catalog-endpoint.ts (+ api/_lib/catalog/search.ts)
   │ parse → Dubletten → Termine (api/_lib/catalog/) → öffentliche Form (publish.ts)
App: ApiCourseCatalogSource (CourseCatalogSource + CourseSearchSource, Offline-Kopie)
   │
TimetableController ── TimetableStore (users/{uid}/timetable bzw. lokal)
   │  Eintrag = Verweis + CourseSnapshot (Import) + EntryOverrides (eigene Korrekturen)
   │
plan_schedule.dart (Plan auflösen) → plan_conflicts.dart (Stellen) → week_layout.dart (Raster)
```

| Aufgabe | Ort |
| --- | --- |
| Katalog-Endpunkt (Eingaben, Cache, Fehler, Kopfzeilen) | `api/catalog.ts`, `api/_lib/catalog-endpoint.ts` |
| Fakultätsübergreifende Suche (Fakultäten, Latin-1-Kodierung, Rangfolge, Kürzung) | `api/_lib/catalog/search.ts`, `UnivisSource.searchUrl` |
| Zwischenspeicher (frisch/stale, parallele Abrufe, Plausibilität, Größe) | `api/_lib/catalog/cache.ts`, `api/_lib/catalog/firestore-store.ts` |
| Öffentliche Form (nur App-Felder, gehashte Personenkennungen) | `api/_lib/catalog/publish.ts` |
| UnivIS-Adapter, Terminauflösung, Dubletten, Semester | `api/_lib/catalog/` (siehe Bericht, Abschnitt 11) |
| Katalog-Datenmodell (quellneutral, mit Einrichtungshierarchie) | `models/timetable/course_catalog.dart` |
| Eigenständige Beschreibung einer Veranstaltung (Import) | `models/timetable/course_snapshot.dart` |
| Eintrag, persönliche Anpassungen, Abgleich mit dem Katalog | `models/timetable/timetable_entry.dart` |
| Katalog- und Suchquellen: API mit Offline-Kopie; synthetisch nur für Tests/Entwicklung | `services/timetable/course_catalog_source.dart`, `services/timetable/timetable_feature.dart` |
| Plan aus Import und Anpassungen, eigene Termine, Kieler Ortszeit | `services/timetable/plan_schedule.dart` |
| Überschneidungsstellen und ihre Gruppierung | `services/timetable/plan_conflicts.dart` |
| Wochenraster (Spuren gleichzeitiger Termine), Filter Block/regelmäßig | `services/timetable/week_layout.dart` |
| Wochen, unterrichtsfreie Zeit | `services/timetable/timetable_schedule.dart` |
| Suche, Filter, Filterwerte (Fakultät, Institut, Typ, Wochentag, Dozent) | `services/timetable/course_search.dart` |
| Beschriftungen (Typen, Wochentage, Terminregeln, Hinweise) | `services/timetable/course_labels.dart` |
| Speicher (Konto: `users/{uid}/timetable`, live; Gast: lokal) | `services/timetable/timetable_store.dart` |
| Übernahme des Gast-Stundenplans nach Anmeldung | `services/timetable/timetable_migration.dart`, aufgerufen in `HomeScreen` |
| Zustand für die Oberfläche (Semester, Plan, Filter, Konflikte, Abgleich) | `services/timetable/timetable_controller.dart` |
| Druck/PDF: Inhalt (Wochenmuster, Sondertermine, Raster) und Ausgabe | `services/timetable/timetable_export.dart`, `services/timetable/timetable_pdf.dart`, `screens/timetable/timetable_export_screen.dart` (Pakete `pdf`, `printing`) |
| Studienunterlagen (Metadaten zentral, Laden, Filter) | `assets/study/documents.json`, `services/study/study_documents.dart`, Linkprüfung `tool/study_documents/`, `.github/workflows/study-documents.yml` |
| Screens | `screens/study/` (Hauptbereich, Unterlagen), `screens/timetable/` (Raster, Suche, Details, Vorschau/Korrektur, Konfliktanzeige) |
| Firestore-Regeln und Emulator-Tests | `firestore.rules`, `test/firestore_rules/`, `.github/workflows/firestore-rules.yml` |

Grundsätze:

* **Import und eigene Korrekturen sind getrennt.** Ein Eintrag speichert die
  importierten Daten (`snapshot`: Titel, Termine, Räume, Lehrende,
  Semesterrahmen) und getrennt davon die persönlichen Anpassungen
  (`overrides`: Titel, Dozent, Notiz, je Termin Wochentag/Uhrzeit/Raum oder
  „ausgeblendet“, eigene wöchentliche Termine). Veranstaltungen des
  Fakultätskatalogs werden bei jedem Laden mit dem aktuellen Katalog
  abgeglichen; Veranstaltungen aus der Suche auf Wunsch („Mit UnivIS
  abgleichen“). Ein Abgleich ändert nie die Anpassungen; geänderte Termine
  der Quelle werden gemeldet („Zur Kenntnis genommen“ bzw. „Eigene
  Termin-Anpassungen verwerfen“).
* **Keine Duplikate.** Eine Veranstaltung gilt als geplant, wenn Kennung
  oder eine Quellkennung übereinstimmt (Fakultätskatalog und Suche führen
  Dubletten unterschiedlich zusammen). Erneutes Hinzufügen ersetzt den
  Eintrag und behält die Anpassungen.
* **Rückwärtskompatibel.** Einträge der ersten Version (ohne `snapshot`)
  werden weiter über den Katalog aufgelöst. Lehnt Firestore die neuen Felder
  ab (Regeln noch nicht veröffentlicht), speichert die App Veranstaltungen
  des Fakultätskatalogs in der alten Form; für Veranstaltungen aus der Suche
  meldet sie einen Speicherfehler.
* **Überschneidungen zählen Stellen, nicht Termine.** Eine Stelle ist ein
  zusammenhängender Zeitraum, in dem mindestens zwei verschiedene
  Veranstaltungen gleichzeitig stattfinden (drei gleichzeitige = eine
  Stelle). Halboffene Intervalle: direkt anschließende Termine überschneiden
  sich nicht; abgesagte Termine zählen nicht. Gerechnet wird mit konkreten
  Daten; für die Übersicht werden gleiche Wochentag-/Uhrzeit-/
  Veranstaltungs-Kombinationen zusammengefasst („an 14 Terminen“), ein
  einzelner Blocktermin bleibt ein einzelnes Datum.
* **Nie erfundene Daten.** Synthetische Daten nur mit
  `--dart-define=TIMETABLE_SYNTHETIC=true` (und stets gekennzeichnet); die
  API-Quelle lehnt Antworten mit `synthetic: true` ab. Ist der Katalog nicht
  erreichbar und keine Offline-Kopie vorhanden, zeigt die App einen Fehler;
  gespeicherte Einträge bleiben sichtbar.
* **Wiederholungslogik nur für eigene Angaben.** Termine der Quelle kommen
  aufgelöst vom Server. Die App rechnet nur, wenn du Termine anpasst oder
  ergänzt: dieselben Daten der Quelle (Ferien bleiben) bzw. Wochentage der
  Vorlesungszeit ohne unterrichtsfreie Tage, Kieler Ortszeit mit
  Sommerzeitregel.
* **Synchronisierung**: `FirestoreTimetableBackend` beobachtet die
  Collection über `snapshots()`. Gäste speichern lokal
  (`guest.v1.timetable`); nach der Anmeldung übernimmt
  `TimetableGuestMigration` die Einträge (ohne Duplikate, ohne vorhandene zu
  ändern, lokal erst nach Server-Bestätigung gelöscht, idempotent).
* **Firestore-Regeln**: `timetable` hat eine eigene Regel mit Feldprüfung
  (inklusive `snapshot`/`overrides` mit Größengrenzen) und steht bewusst
  nicht in `isUserCollection` – Regeln sind ODER-verknüpft, sonst wäre die
  Feldprüfung wirkungslos. `catalog_cache` hat keine Regel (nur Admin SDK).
  Die Regeln werden in der Firebase Console eingetragen (kein
  Firebase-CLI-Deployment im Projekt).
* **Studienunterlagen**: nur Metadaten in `assets/study/documents.json`
  (Titel, Beschreibung, Studiengang, Stand, Status `current`/`older`/
  `unclear`, Link und Fundstelle). Die App akzeptiert nur HTTPS-Links auf
  uni-kiel.de bzw. Nordkirche; der Workflow prüft alle Links wöchentlich.
  Aktualisieren: Eintrag in der JSON-Datei ändern, Workflow
  „Studienunterlagen-Links“ abwarten (siehe `docs/study-documents.md`).
* Eine neue Katalogquelle (später HISinOne) implementiert serverseitig
  `CatalogSource`; die App bleibt unverändert.

## Einführung in die Logik (Philosophie)

Inhalte unter `assets/logic/`, Logik-Engine (Parser, Semantik,
Beweisprüfer, Aufgabenerzeugung) unter `lib/services/logic/`, Screens unter
`lib/screens/philosophy/`. Details: [logic-course.md](logic-course.md).
