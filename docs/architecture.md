# Architektur der Trainer

Kurzer Überblick, wo welche Verantwortung liegt. Grundsatz: gemeinsame
Infrastruktur + trainer-spezifische Fachlogik – kein „Universaltrainer“.

## Gemeinsame Infrastruktur

| Aufgabe | Ort |
|---|---|
| Lernstand je Karte (`stability`, `difficulty`, `lastReviewed`, Lernhilfe) | `models/greek/vocabulary/learning_card.dart` |
| Laden/Speichern der Lernstände, Konto (Firestore) oder Gast (lokal) | `services/learning_service.dart`, `services/local_learning_store.dart` |
| Auswahl der nächsten Frage (Vokabeln, Perikopen) | `algorithms/learning_selector.dart`, `algorithms/spaced_repetition.dart` |
| Auswahl nach grammatischer Bestimmung | `algorithms/grammar_learning.dart` |
| Sound, Tagesstatistik, Streak nach einer Antwort | `reportTrainerAnswer` in `widgets/trainer_widgets.dart` |
| Lernhilfe, Sound-Schalter, Ergebnis-Rahmen | `widgets/trainer_widgets.dart` |
| Auswahl-Bausteine der Einstellungsdialoge | `widgets/settings_selection.dart`, `widgets/settings_access.dart` |

`uid == null` bedeutet überall Gastmodus: dieselben Datenstrukturen, lokal
über `LocalLearningStore` statt in Firestore. Die Collection-Namen stehen
einmal in `LocalLearningStore.cardCollections`.

## Je Trainer

Jeder Trainer besitzt einen Screen (Sitzungszustand, Dialoge), einen
Einstellungs-Service (ein Lesezugriff je Öffnen) und seine Antwortprüfung.

| Trainer | Einstellungen | Antwortprüfung |
|---|---|---|
| Griechisch-Vokabeln | `services/greek/vocabulary/vocabulary_settings_service.dart` | `vocabulary_answer_checker.dart` |
| Latein-Vokabeln | `services/latin/vocabulary/latin_vocabulary_settings_service.dart` | `latin_vocabulary_answer_checker.dart` |
| Griechisch-Grammatik | `services/greek/grammar/grammar_settings_service.dart` | `grammar_answer_check.dart` |
| Perikopenquiz | `services/settings_service.dart` | im `quiz_screen.dart` (Vergleich der Stellen) |

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

Ein neuer Trainer (z. B. Latein-Grammatik) braucht eigene Regeln und eine
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
| Lernstand je Abschnitt (Hilfestufe, Versuche) | `models/memorization/memorization_card.dart` |
| Gebete/Bekenntnisse → Lerntexte | `services/memorization/memorization_catalog.dart` |
| Erzeugung der Bekenntnis- und Liturgiedaten (nicht Teil der App) | `tool/content_import/` |
| Zerlegung in Abschnitte | `services/memorization/text_segmenter.dart` |
| Lücken, Anfangsbuchstaben | `services/memorization/hint_generator.dart` |
| Wortvergleich mit Alignment (lokal, ohne KI) | `services/memorization/text_evaluator.dart` |
| Status, Tagesplan, Bewertung | `services/memorization/memorization_scheduler.dart` |
| Ablauf einer Lernrunde (Verbinden, Wiederholen) | `services/memorization/memorization_session.dart` |
| Lernstände und „Meine Texte“ (Konto/Gast) | `services/memorization/memorization_repository.dart` |
| Spracherkennung (austauschbar) | `services/speech/speech_recognition_service.dart` |
| Wahl der Erkennung je Sprache (Latein → eigenes Modell) | `services/speech/routing_speech_recognition_service.dart` |
| Lateinische Erkennung auf dem Gerät (Aufnahme, Whisper) | `services/speech/latin/`, im Web zusätzlich `web/latin_stt/` |
| Lautlicher Abgleich lateinischer Transkripte (lokal, ohne KI) | `services/memorization/latin_speech_matcher.dart` |
| Screens | `screens/memorization/` |

Jede Sprachfassung ist ein eigener Lerntext (`prayer.vaterunser.de`,
`prayer.vaterunser.la`) mit eigenem Lernstand. Eine neue Textquelle braucht
nur eine Methode im Katalog, die `MemorizationWork`s liefert.

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
einer Frage gehen gemeinsam an `BibleReaderScreen(passages: …)`. Der Reader
rechnet Zählungen nicht um, sondern weist auf Abweichungen hin
(`BibleVersification`).

Die Perikopenüberschriften im Text stammen allein aus der Perikopenliste,
nie aus einer Ausgabe; der Reader kennzeichnet sie entsprechend. Sie stehen
am Anfangsvers jeder Perikope. Weil die Liste deutsch zählt, zeigt
`PericopeHeadings.forChapter` sie im Alten Testament nur in Kapiteln, die
die gewählte Ausgabe genauso zählt wie eine deutsch gezählte Ausgabe.

Ausgabe, Lesestand und Schriftgröße gehören zum Gerät und liegen wie das
Erscheinungsbild in den `SharedPreferences`.

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
