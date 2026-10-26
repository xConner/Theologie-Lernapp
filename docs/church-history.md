# Kirchengeschichte

Lernbereich zur Vorlesung „Geschichte des Christentums im Überblick I“
und zum Proseminar „Einführung in die
Kirchengeschichte: Cassian und das Menschwerden Gottes“ (Wintersemester
2026/27). Erreichbar über die Startseite („Kirchengeschichte“) und den Deep
Link `/church-history` – nur für freigeschaltete Konten: Alle Inhalte sind
geschützte Vorlesungsunterlagen, siehe [lecture-materials.md](lecture-materials.md).

## Inhalte

Alle Inhalte liegen als JSON unter `church_history/` in den geschützten
Vorlesungsunterlagen (lokal `lecture_materials/church_history/`, nicht im
Repository; in der App unter dem Pfad `assets/church_history/`), getrennt
vom Lernstand des Nutzers:

| Datei | Inhalt |
|---|---|
| `lectures.json` | Vorlesung (`course`) mit Gliederung, Vorlesungen mit Folien (Abschrift, Hervorhebungen, Bild), strukturierter Zusammenfassung, Erwähnungen, Merklisten und kuratierten Fragen |
| `seminar.json` | Proseminar (`course` mit `kind: "seminar"`, Prüfungshinweisen, Literatur und Materialliste) und seine Sitzungen (`sessions`) im selben Format wie Vorlesungen, aber ohne Folien |
| `entries.json` | Personen, Ereignisse, Begriffe und Quellen in einem einheitlichen Modell |
| `epochs.json` | Epochen mit Richtwerten und der Kennzeichnung aus der Vorlesung |
| `themes.json` | thematische Zugänge |
| `slides/folie-NN.*` | Bilder der Originalfolien (verkleinert) |

Die Originale (PDF) liegen nicht in der App.

### IDs

Jeder Inhalt hat eine stabile ID der Form `<typ>.<name>`
(`person.decius`, `event.decian_persecution`, `term.lapsi`,
`source.pliny_letters`, `epoch.antiquity`, `theme.martyrdom`,
`lecture.02`, `q.l02.decius`, `list.persecutions`; im Proseminar
`seminar.02`, `q.ps02.scytha`, `list.ps_paper_structure`,
`material.schwartz`). Lernkarten verweisen
auf diese IDs; **eine ID nie umbenennen**, sonst geht der Lernstand dazu
verloren. Verknüpfungen (`related`) werden nur in eine Richtung
eingetragen, die Gegenrichtung ergänzt die App.

`ChurchHistoryLoader.validate` prüft beim Laden (und in den Tests) doppelte
IDs, das ID-Format, alle Verweise auf Einträge, Epochen, Themen und Folien,
Datierungen von Ereignissen und eindeutige Antwortmöglichkeiten.

### Zwei Veranstaltungen, ein Bestand an Einträgen

Vorlesung und Proseminar teilen sich Einträge, Epochen und Themen. Einen
Inhalt, den beide behandeln, gibt es nur einmal; beide Veranstaltungen
erwähnen denselben Eintrag. Neue Einträge nie für eine Veranstaltung
doppeln (der Loader meldet gleiche Namen oder Aliase desselben Typs).

Die Kennzeichnung „Vorlesung“, „Proseminar“ oder „Beide“
(`ChurchHistoryData.contextOf`) ergibt sich allein aus den `mentions` und
`questions` der Vorlesungen bzw. Sitzungen, nie aus einem eigenen Feld.
„Beide“ heißt also: beide Veranstaltungen behandeln den Inhalt. Dass etwa
die Bibliographie des Proseminars Ebeling nennt, macht ihn nicht
gemeinsam; dafür gibt es keine Erwähnung. Einträge ohne Erwähnung sind
„Ergänzung“.

Themen der Vorlesungsgliederung, zu denen schon Stoff aus dem Proseminar
da ist, verweisen mit `theme` auf das Thema der App.

### Fundstellen

- Vorlesung: Folien (`slides`).
- Proseminar: `ref` auf ein Material der eigenen Veranstaltung
  (`{"material": "material.seminar_plan", "at": "S. 2"}`). Jeder Abschnitt,
  jede Erwähnung, Merkliste und Frage einer Sitzung braucht eine
  Fundstelle; der Loader prüft das.
- Was der Seminarplan sagt, steht in den Sitzungen; was die
  Forschungsliteratur sagt, steht als `notes` mit `kind: "research"` (oder
  `debate` bei Streitfragen) und `ref` am Eintrag. Offene Aufgaben des
  Seminarplans werden nicht beantwortet und nicht abgefragt, solange die
  Sitzung, für die sie gestellt sind, noch bevorsteht (ein Test prüft die
  Stellen ab der 3. Sitzung); danach dürfen sie mit Fundstelle Lernstoff
  werden. Fragen zu Forschungspositionen nennen die Autorin bzw. den Autor
  („nach Vannier“).
- Die Quelle selbst wird nach einer Übersetzung belegt (Material mit
  Kategorie „Quelle in Übersetzung“, Seite der Druckausgabe); zitiert wird
  im Seminar nach der kritischen Edition. Was Cassian Gegnern zuschreibt,
  bleibt als seine Darstellung gekennzeichnet.
- Offensichtliche Fehler der Vorlagen werden berichtigt und als
  `supplement` vermerkt (Jahr 2026 statt 2027 ab der 10. Sitzung,
  hochgestellte Auflagenziffern der Bibliographie).

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

1. Folien als Bilder unter `lecture_materials/church_history/slides/`
   ablegen (fortlaufend nummeriert; Bildpfad in den Daten bleibt
   `assets/church_history/slides/…`).
2. In `lectures.json` eine Vorlesung `lecture.NN` mit Folien,
   Zusammenfassung, Erwähnungen, Merklisten und Fragen anlegen und in der
   Gliederung (`course.outline`) die behandelten Themen verknüpfen.
3. Neue Personen, Ereignisse, Begriffe und Quellen in `entries.json`
   ergänzen; vorhandene Einträge nur verknüpfen, nicht doppeln.
4. `flutter test test/church_history` ausführen.
5. Unterlagen hochladen (`tool/lecture_materials`, siehe
   [lecture-materials.md](lecture-materials.md)).

Code muss dafür nicht geändert werden.

### Neue Sitzung oder neues Material zum Proseminar

1. Material in `seminar.json` unter `course.materials` aufnehmen
   (`material.<name>`, Kurzform für Fundstellen in `short`).
2. Die Sitzung `seminar.NN` mit `sections`, `mentions`, `lists` und
   `questions` füllen, jeweils mit `ref`.
3. Vorhandene Einträge erwähnen statt neue anzulegen; dadurch werden sie
   automatisch „Beide“.
4. `flutter test test/church_history` ausführen.

## Lernen

| Modus | Aufgabenarten |
|---|---|
| Wissensquiz | Fragen zu den Veranstaltungen, Merklisten (Selbstbewertung), Personen, Begriffe und Quellen, Epochen |
| Chronologietrainer | Reihenfolge, Datierungen, Epochen |

Lernumfang: alle Inhalte (beide Veranstaltungen), Vorlesungsstoff,
Proseminarstoff, eine Vorlesung oder Sitzung, eine Epoche oder ein Thema;
zusätzlich „Nur schwierige Inhalte“. Vorlesungs- bzw. Proseminarstoff
enthält auch die gemeinsamen Einträge. Epochenfragen gehören zur Vorlesung
(Folie 4). Gespeichert wird der Umfang als Schlüssel (`course:lecture`,
`course:seminar`, `lecture:seminar.02`); der frühere Schlüssel `lectures`
gilt weiter als Vorlesungsstoff.

Die Aufgaben entstehen aus den Daten (`ChurchHistoryQuiz`). Damit jede
Aufgabe eindeutig ist, überschneiden sich Datierungen von Antwort und
Ablenkern auch mit ihrer Unschärfe nicht, verknüpfte Personen sind keine
Ablenker, und Fragen verraten die Antwort nicht im Fragetext.

Die Auswahl verwendet `LearningSelector` und `SpacedRepetition` wie die
übrigen Trainer. Jede Aufgabenart hat eigene Lernkarten
(`<Inhalt>|<Art>`); bei der Reihenfolge wird jedes Ereignis einzeln
gewertet. Der Fortschritt zeigt nur „Noch nicht geübt“, „Zum Wiederholen“
und „Zuletzt sicher“, ohne Punkte, Level oder Aussagen über Beherrschung.

„In Vorlesungsreihenfolge einführen“ (Einstellung `inOrder`) hält noch nie
gefragte Inhalte zurück, bis sie an der Reihe sind: Geübtes bleibt im Pool,
von den neuen kommen nur die ersten drei hinzu, geordnet nach der ersten
Vorlesung bzw. Sitzung, die sie enthält oder nennt (`positionOf`,
`algorithms/ordered_introduction.dart`). Gespeichert wird dafür nichts
weiter; „eingeführt“ heißt, dass es eine Lernkarte gibt. Mit „Nur schwierige
Inhalte“ gilt die Einstellung nicht.

## Speicherung

`ChurchHistoryStore`: angemeldet unter
`users/{uid}/quiz_settings/church_history` (Lernkarten) und
`.../church_history_settings` (Einstellungen), als Gast lokal über
`LocalLearningStore`. Zurücksetzen über `ProgressArea.churchHistory`
(Lernstand, nicht die Einstellungen) oder je Veranstaltung, Vorlesung bzw.
Sitzung im Fortschrittsbildschirm. Statistik, Serie (`StreakTrack.churchHistory`) und
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
