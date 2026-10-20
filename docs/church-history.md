# Kirchengeschichte

Lernbereich zur Vorlesung „Geschichte des Christentums im Überblick I“
(Prof. Dr. A. Müller). Erreichbar über die Startseite („Kirchengeschichte“)
und den Deep Link `/church-history`.

## Inhalte

Alle Inhalte liegen als JSON in `assets/church_history/`, getrennt vom
Lernstand des Nutzers:

| Datei | Inhalt |
|---|---|
| `lectures.json` | Kurs mit Gliederung, Vorlesungen mit Folien (Abschrift, Hervorhebungen, Bild), strukturierter Zusammenfassung, Erwähnungen, Merklisten und kuratierten Fragen |
| `entries.json` | Personen, Ereignisse, Begriffe und Quellen in einem einheitlichen Modell |
| `epochs.json` | Epochen mit Richtwerten und der Kennzeichnung aus der Vorlesung |
| `themes.json` | thematische Zugänge |
| `slides/folie-NN.*` | Bilder der Originalfolien (verkleinert) |

Die Originale (PDF) liegen nicht in der App.

### IDs

Jeder Inhalt hat eine stabile ID der Form `<typ>.<name>`
(`person.decius`, `event.decian_persecution`, `term.lapsi`,
`source.pliny_letters`, `epoch.antiquity`, `theme.martyrdom`,
`lecture.02`, `q.l02.decius`, `list.persecutions`). Lernkarten verweisen
auf diese IDs; **eine ID nie umbenennen**, sonst geht der Lernstand dazu
verloren. Verknüpfungen (`related`) werden nur in eine Richtung
eingetragen, die Gegenrichtung ergänzt die App.

`ChurchHistoryLoader.validate` prüft beim Laden (und in den Tests) doppelte
IDs, das ID-Format, alle Verweise auf Einträge, Epochen, Themen und Folien,
Datierungen von Ereignissen und eindeutige Antwortmöglichkeiten.

### Vorlesung und Ergänzung

- Was die Vorlesung sagt, steht in den Folien (`slides`), den Punkten der
  Zusammenfassung (`sections[].points`) und den Erwähnungen (`mentions`).
  Die App zeigt es mit „VL n“ und Folienangabe.
- Erläuterungen der App (`summary`, `significance`, `sections[].supplement`,
  Epochen-`summary`) sind als „Ergänzung“ gekennzeichnet.
- Datierungen tragen `approx` (ungefähr) bzw. `disputed` (umstritten) und
  ggf. eine `note`. Forschungsdiskussionen und konfessionelle Perspektiven
  stehen in `notes`.

### Neue Vorlesung ergänzen

1. Folien als Bilder unter `assets/church_history/slides/` ablegen
   (fortlaufend nummeriert).
2. In `lectures.json` eine Vorlesung `lecture.NN` mit Folien,
   Zusammenfassung, Erwähnungen, Merklisten und Fragen anlegen und in der
   Gliederung (`course.outline`) die behandelten Themen verknüpfen.
3. Neue Personen, Ereignisse, Begriffe und Quellen in `entries.json`
   ergänzen; vorhandene Einträge nur verknüpfen, nicht doppeln.
4. `flutter test test/church_history` ausführen.

Code muss dafür nicht geändert werden.

## Lernen

| Modus | Aufgabenarten |
|---|---|
| Wissensquiz | Fragen zur Vorlesung, Merklisten (Selbstbewertung), Personen, Begriffe und Quellen, Epochen |
| Chronologietrainer | Reihenfolge, Datierungen, Epochen |

Lernumfang: alle Inhalte, alle bisherigen Vorlesungen, eine Vorlesung,
eine Epoche oder ein Thema; zusätzlich „Nur schwierige Inhalte“.

Die Aufgaben entstehen aus den Daten (`ChurchHistoryQuiz`). Damit jede
Aufgabe eindeutig ist, überschneiden sich Datierungen von Antwort und
Ablenkern auch mit ihrer Unschärfe nicht, verknüpfte Personen sind keine
Ablenker, und Fragen verraten die Antwort nicht im Fragetext.

Die Auswahl verwendet `LearningSelector` und `SpacedRepetition` wie die
übrigen Trainer. Jede Aufgabenart hat eigene Lernkarten
(`<Inhalt>|<Art>`); bei der Reihenfolge wird jedes Ereignis einzeln
gewertet. Der Fortschritt zeigt nur „Noch nicht geübt“, „Zum Wiederholen“
und „Zuletzt sicher“, ohne Punkte, Level oder Aussagen über Beherrschung.

## Speicherung

`ChurchHistoryStore`: angemeldet unter
`users/{uid}/quiz_settings/church_history` (Lernkarten) und
`.../church_history_settings` (Einstellungen), als Gast lokal über
`LocalLearningStore`. Zurücksetzen über `ProgressArea.churchHistory`
(Lernstand, nicht die Einstellungen) oder je Vorlesung im
Fortschrittsbildschirm. Statistik, Serie (`StreakTrack.churchHistory`) und
Sounds laufen über `reportTrainerAnswer`.

## Code

| Aufgabe | Ort |
|---|---|
| Modell | `lib/models/church_history/church_history.dart` |
| Laden und Prüfen | `lib/services/church_history/church_history_loader.dart` |
| Aufgaben und Auswahl | `lib/services/church_history/church_history_quiz.dart` |
| Suche | `lib/services/church_history/church_history_search.dart` |
| Lernstand | `lib/services/church_history/church_history_store.dart`, `church_history_progress.dart` |
| Oberfläche | `lib/screens/church_history/` |
| Tests | `test/church_history/` |
