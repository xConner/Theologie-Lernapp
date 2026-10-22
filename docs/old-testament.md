# Altes Testament

Lernbereich zur Vorlesung „Einführung in das Alte Testament“
(Prof. Dr. Christoph Berner, CAU Kiel). Erreichbar über die Startseite
(„Altes Testament“) und den Deep Link `/old-testament`.

Der Bereich wächst mit den Vorlesungsfolien: Jede hochgeladene Foliendatei
wird eine **Vorlesungseinheit**. Er enthält nur, was die Folien hergeben,
und keine allgemeine Wissensdatenbank zum Alten Testament.

## Inhalte

Alle Inhalte liegen als JSON in `assets/old_testament/`, getrennt vom
Lernstand:

| Datei | Inhalt |
|---|---|
| `course.json` | Veranstaltung und Liste der Einheiten-Dateien |
| `terms.json` | Fachbegriffe aller Einheiten (je Begriff ein Eintrag) |
| `units/einheit-NN.json` | eine Einheit: Folien (Abschrift, Hervorhebungen, Abbildungsbeschreibung, Bild), Kernpunkte, Gliederung, Begriffsnennungen, Bibelstellen, Zusammenhänge, Literatur, Merklisten, Fragen |
| `slides/eNN-folie-MM.*` | verkleinerte Bilder der Originalfolien (Einheit NN, Folie MM) |

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
