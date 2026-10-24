# Altes Testament

Lernbereich zur Vorlesung „Einführung in das Alte Testament“
(Prof. Dr. Christoph Berner, CAU Kiel). Erreichbar über die Startseite
(„Altes Testament“) und den Deep Link `/old-testament`.

Der Bereich wächst mit den Vorlesungsfolien: Jede hochgeladene Foliendatei
wird eine **Vorlesungseinheit**. Er enthält nur, was die Folien hergeben,
und keine allgemeine Wissensdatenbank zum Alten Testament.

Dieselbe Datenbasis trägt die **Grundlagen der Bibelkunde** (Übung
„Bibelkunde Altes Testament“, Louisa Thomsen) im Bereich Bibelkunde, siehe
[Zwei Veranstaltungen, eine Datenbasis](#zwei-veranstaltungen-eine-datenbasis).

## Inhalte

Alle Inhalte liegen als JSON in `assets/old_testament/`, getrennt vom
Lernstand:

| Datei | Inhalt |
|---|---|
| `course.json` | Veranstaltung und Liste der Einheiten-Dateien |
| `terms.json` | Fachbegriffe aller Einheiten (je Begriff ein Eintrag) |
| `units/einheit-NN.json` | eine Einheit der Vorlesung: Folien (Abschrift, Hervorhebungen, Abbildungsbeschreibung, Bild), Kernpunkte, Gliederung, Begriffsnennungen, Bibelstellen, Zusammenhänge, Literatur, Merklisten, Fragen |
| `units/bibelkunde-NN.json` | eine Sitzung der Übung Bibelkunde (gleicher Aufbau, `course: "bibelkunde"`, dazu `shared`) |
| `slides/eNN-folie-MM.*`, `slides/bkNN-folie-MM.*` | verkleinerte Bilder der Originalfolien (Einheit bzw. Sitzung NN, Folie MM) |

Die Original-PDFs liegen nicht in der App.

### Drei Ebenen

| Ebene | Wo | Anzeige |
|---|---|---|
| Folieninhalt | `slides[].text` (vollständige Abschrift, Tabellen und Schaubilder abgeschrieben), Begriffsnennungen `terms[].text`, `literature` | „Originalfolien“, blau umrandete Zitate |
| Didaktische Zusammenfassung | `keyPoints`, `sections[].points`, `connections`, `lists` – immer mit `slides` | Überblick mit Folienknopf |
| Ergänzung der App | `sections[].supplement`, `connections` mit `supplement: true`, Begriffe mit `fromSlides: false` oder `supplement`, Hinweise „Ergänzung:“ in Erklärungen | grau, „Ergänzung – nicht von den Folien“ |

Was die Folien nicht eindeutig machen, steht in `sections[].unclear`
(orange, „Nicht eindeutig“) und wird nicht abgefragt. Vertritt die
Vorlesung eine umstrittene Forschungsposition, sagt die Frage „nach der
Vorlesung“ und die Erklärung nennt andere Positionen.

### IDs

| Inhalt | Form | Beispiel |
|---|---|---|
| Einheit | `unit.NN` (passt zu `number`) | `unit.01` |
| Sitzung der Übung | `bk.NN`, Inhalte `q.bkNN.*`, `list.bkNN.*`, `passage.bkNN.*` | `bk.01`, `q.bk01.ziel` |
| Begriff | `term.<name>` | `term.tanak` |
| Frage | `q.uNN.<name>` | `q.u01.luther` |
| Merkliste | `list.uNN.<name>` | `list.u01.tanak` |
| Bibelstelle | `passage.uNN.<name>` | `passage.u01.2kor_3_14` |

Lernkarten heißen `<ID>|<Art>` (`q.u01.luther|lecture`,
`term.tanak|term`, `term.tanak|name`, `list.u01.tanak|recall`,
`list.u01.tanak|order`). **Eine ID nie umbenennen oder neu vergeben**,
sonst geht der Lernstand dazu verloren. `OldTestamentLoader.validate`
prüft beim Laden und in den Tests: doppelte IDs, ID-Format und Einheit,
Folienangaben (jede Aussage braucht eine vorhandene Folie), Begriffe,
Antwortmöglichkeiten und verwandte Einheiten.

## Neue Folien ergänzen

1. Folien als Bilder unter `slides/eNN-folie-MM.(png|jpg)` ablegen
   (Breite 1170 px wie in der Kirchengeschichte).
2. `units/einheit-NN.json` mit `id: "unit.NN"` anlegen und in
   `course.json` unter `units` anhängen.
3. Begriffe, die schon in `terms.json` stehen, nur in der Einheit nennen
   (`terms: [{term, slides, text}]`) – so erscheinen sie bei beiden
   Einheiten, ohne doppelten Eintrag und ohne zweite Lernkarte. Neue
   Begriffe in `terms.json` ergänzen; Begriffe, deren Erklärungen sich
   überschneiden, unter `confusable` eintragen.
4. Vertieft die Einheit das Thema einer früheren, `related: ["unit.MM"]`
   setzen (wird in beide Richtungen angezeigt).
5. `flutter test test/old_testament` ausführen.

Code muss dafür nicht geändert werden. Vorhandener Lernstand bleibt, weil
neue Einheiten nur neue IDs mitbringen.

## Zwei Veranstaltungen, eine Datenbasis

Die Übung „Bibelkunde Altes Testament“ überschneidet sich in ihren
Grundlagen (Bezeichnungen, Kanon, Textüberlieferung, Eckdaten der
Geschichte) stark mit Einheit 1 der Vorlesung. Damit nichts doppelt gepflegt
wird, liegt sie in denselben Daten:

* `course.json` nennt unter `courses.bibelkunde` die Übung; ihre Sitzungen
  tragen `"course": "bibelkunde"` (`OtCourseId`).
* **Begriffe** stehen einmal in `terms.json`. Eine Sitzung nennt sie nur
  (`terms: [{term, slides, text}]`, mit dem Wortlaut ihrer Folie). Lernkarte
  `term.kanon|term` gilt für beide Veranstaltungen.
* **Geteilte Inhalte**: `shared: ["q.u01.luther", "list.u01.tanak", …]` in
  einer Sitzung übernimmt Fragen, Merklisten und Bibelstellen einer
  Vorlesungseinheit, die die Folie der Übung ebenso aussagt. Sie werden nicht
  kopiert: gleiche Karte, Fundstelle bleibt die Vorlesung („Vorlesung AT ·
  Einheit 1, Folie 11“). Die Detailansicht zeigt sie unter „Gemeinsame
  Inhalte“. Eigene Fragen der Übung nur für das, was die Vorlesung nicht oder
  anders sagt (ein Test prüft, dass keine Frage einer Vorlesungsfrage
  gleicht).
* **Sicht**: `OldTestamentData.forCourse(course)` liefert Einheiten und
  Begriffe einer Veranstaltung; Nachschlagen, Begriffsherkunft und
  „Verwandte Einheiten“ reichen über beide. Alle Bildschirme des Bereichs
  arbeiten mit einer Sicht (`OldTestamentHomeScreen(course: …)`), die
  Vorlesung sieht nichts von der Übung außer dem Verweis unter „Verwandte
  Einheiten“.
* **Lernstand** gemeinsam in `old_testament`, **Einstellungen** getrennt
  (`old_testament_settings` bzw. `old_testament_bibelkunde_settings`).
  „Alle zurücksetzen“ im Fortschritt einer Veranstaltung lässt die Karten
  stehen, die nur die andere hat; gemeinsame Karten werden für beide
  zurückgesetzt (der Dialog sagt das).
* Serie und Statistik: Antworten zählen wie im Alten Testament
  (`StreakTrack.oldTestament`), weil es dieselben Karten sind.

Nicht in die Grundlagen gehören die Bücher im Einzelnen; sie folgen in
späteren Sitzungen bzw. liegen unter „Bücher systematisch lernen“.

**Leseplan zur Übung**: Termine und Bibelstellen der Sitzungen stehen
zusätzlich im Leseplan `assets/reading_plans/course-bibelkunde-at-wise-2026.json`
(Bereich Bibelkunde → „Leseplan zur Übung“, siehe `docs/reading-plans.md`).
Seine Sitzungen tragen dieselben IDs (`bk.NN`) und verlinken die Folien.
Kommt eine Sitzung mit Lesestellen hinzu, dort die Stellen eintragen und
`readingSource` auf `slides` setzen.

## Lernen

Ein Lernmodus mit Umfang „Alle Einheiten“ oder eine Einheit, wählbaren
Aufgabenarten und „Nur schwierige Inhalte“:

| Art | Aufgabe | Bewertung |
|---|---|---|
| Fragen zur Vorlesung | kuratierte Auswahlfragen mit Erklärung und Folie | automatisch |
| Fachbegriffe | Erklärung zum Begriff bzw. Begriff zur Erklärung; Ablenker aus anderen Begriffen ohne verwechselbare | automatisch |
| Bibelstellen | Stelle zu einer eindeutigen Beschreibung (`clue`); erst ab drei Stellen mit Ablenkern | automatisch |
| Merklisten | Aufzählung aus dem Gedächtnis | Selbstbewertung |
| Gliederungen ordnen | Punkte einer geordneten Liste (3–7) in die Reihenfolge der Folie bringen; Angaben wie Jahreszahlen stehen nur in der Lösung | automatisch |

Arten, für die es keine Aufgaben gibt, erscheinen nicht. Die Auswahl
verwendet `LearningSelector` und `SpacedRepetition` wie die übrigen
Trainer; „schwierig“ und die Fortschrittszustände („Noch nicht geübt“,
„Zum Wiederholen“, „Zuletzt sicher“) teilt der Bereich mit der
Kirchengeschichte (`algorithms/review_state.dart`). Keine Punkte oder
Level.

„In Reihenfolge der Vorlesung einführen“ (`inOrder`) funktioniert wie in der
Kirchengeschichte (`algorithms/ordered_introduction.dart`): Geübtes bleibt,
von den noch nie gefragten Inhalten kommen nur die ersten drei hinzu, in der
Reihenfolge der Einheiten (ein Begriff bei seiner ersten Einheit).

## Bibelstellen und Verknüpfungen

Bibelstellen öffnen den Bibel-Reader der App (`BibleReaderScreen`) über
`BibleReferenceParser`. Lässt sich eine Angabe nicht lesen (z. B. Halbvers
„2,4a“), steht die lesbare Form in `open`. Bücher, die in der gewählten
Ausgabe fehlen (1 Makk in der Lutherbibel 1912), bietet der Reader in
einer anderen Ausgabe an.

### Verweise auf die Perikopenliste

Eine Bibelstelle kann unter `pericopes` die Perikopen der Perikopenliste
(`assets/perikopen.json`) nennen, die sie umfasst oder anschneidet – als
`Buch|ID|Kapitel,Vers` wie `BookPericope.key` in „Bücher systematisch
lernen“. Teilt die Folie gröber, verweist eine Stelle auf mehrere
Perikopen. Für die Genesis übernimmt die Liste seit 24.10.2026 die
Überschriften, Grenzen und feinere Teilung der Folientabellen von
Sitzung 2, wo eindeutig dieselbe Perikope gemeint ist (Bericht im
Projektordner `bibelkunde/perikopenabgleich-bericht.md`); geteilte
Perikopen behalten ihren Lernstand über `PericopeIdMigration`. Angezeigt wird das als „Deine Perikopen: …“ unter der Stelle
und nach der Antwort im Lernmodus (`PericopeLinksNote`, Titel aus der
ausgelieferten Liste über `OtPericopeLinks`). Der Loader prüft das Format,
`test/old_testament/bibelkunde_genesis_test.dart` gegen die Liste
(Eintrag vorhanden, Stellen überschneiden sich, jede Genesis-Perikope
zugeordnet).

Verknüpfungen zu anderen Bereichen werden nicht automatisch erzeugt; sie
stehen als Ergänzung unter „Zusammenhänge“.

## Speicherung

`OldTestamentStore`: angemeldet unter
`users/{uid}/quiz_settings/old_testament` (Lernkarten) und
`.../old_testament_settings` (Umfang, abgewählte Arten, nur schwierige),
als Gast lokal über `LocalLearningStore` (wird bei der Anmeldung
übernommen). Abgewählt statt ausgewählt gespeichert, damit neue
Aufgabenarten von selbst aktiv sind. Zurücksetzen über
`ProgressArea.oldTestament` oder je Einheit im Fortschritt. Statistik,
Serie (`StreakTrack.oldTestament`) und Sounds laufen über
`reportTrainerAnswer`.

## Code

| Aufgabe | Ort |
|---|---|
| Modell | `lib/models/old_testament/old_testament.dart` |
| Laden und Prüfen | `lib/services/old_testament/old_testament_loader.dart` |
| Aufgaben und Auswahl | `lib/services/old_testament/old_testament_quiz.dart` |
| Speicherung | `lib/services/old_testament/old_testament_store.dart` |
| Ansichten | `lib/screens/old_testament/` |
| Tests | `test/old_testament/` |

Seitengerüst, Ergänzungskasten, Zitat, Fortschrittskarte und
Antwortknöpfe kommen aus der Kirchengeschichte.

## Stand

| Einheit | Folien | Inhalt |
|---|---|---|
| 1 | 1–21 | Grundlagen: Der alttestamentliche Kanon und die Geschichte Israels (Bibel/AT als Bezeichnungen, jüdischer und christlicher Kanon, Textüberlieferung, Geschichte und Literaturgeschichte) |
| Übung, Sitzung 1 | 1–28 | Einführung Bibelkunde AT: Ziele, Organisatorisches, Bibelstellen lesen, Begriffe, Kanon (jüdisch, LXX, Lutherbibel), Text und Übersetzungen, Erzählbogen, Entstehung, Eckdaten; 23 Inhalte mit Einheit 1 geteilt |
| Übung, Sitzung 2 | 1–16 | Pentateuch und Genesis (Präsentation von Ronja Koch, ohne Tonspur): Namen der fünf Bücher, Tora/nomos, Erzählrahmen und Erzählmotive, drei Rechtstexte, Grobgliederung der Genesis, alle Tabellenzeilen von Ur-, Erzeltern- und Josephsgeschichte als Bibelstellen mit Verweis auf die Perikopenliste, Gen 38 |
