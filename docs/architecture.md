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
