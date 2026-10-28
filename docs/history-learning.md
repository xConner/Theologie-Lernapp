# Geschichte Schritt für Schritt

Lernweg für historische Inhalte in **Kirchengeschichte** und **Altes
Testament** (Vorlesung „Einführung in das Alte Testament“ und Übung
„Grundlagen der Bibelkunde“). Er ergänzt die bestehenden Modi
(Wissensquiz, Chronologietrainer, Lernmodus), ersetzt sie nicht.

Erreichbar über den Knopf „Geschichte Schritt für Schritt“ (Key
`church-history-history`) bzw. „Geschichte Israels Schritt für Schritt“
(`old-testament-history`) auf der Startseite des Bereichs.

## Warum

Die freien Quizfragen setzen oft viele Personen, Ereignisse und Daten auf
einmal voraus: Ablenker stammen aus dem ganzen Stoff, Reihenfolgefragen
kombinieren unbekannte Ereignisse, kuratierte Fragen fragen mehrere Daten
zugleich ab. Der Lernweg baut das schrittweise auf.

## Bausteine

| Baustein | Wo | Was |
|---|---|---|
| Lernschritte | `HistoryLessonSession`, `HistoryLessonScreen` | höchstens vier neue Inhalte: vorstellen → gleich abrufen → festigen → mit Gelerntem verknüpfen; Fehler kommen mit Abstand wieder (Einführungsfrage bis zweimal, sonst einmal) |
| Personen und Ereignisse | `HistoryMode.people` | Person am Hinweis erkennen, Lebenszeit, Beteiligte, Bedeutung erklären (Selbstbewertung) |
| Jahreszahlen und Zeiträume | `HistoryMode.dates` | Datierung wählen, „Was gehört in die Zeit …?“, Zeitraum/Jahrhundert zuordnen, Jahreszahl frei eingeben (nur genaue Angaben), Zeitabstände schätzen |
| Chronologie | `HistoryMode.chronology` | Stufe 1 Paare, 2 Dreiergruppen, 3 Vierergruppen und Einordnen, 4 längere Folgen; Stufe steigt mit sicheren Reihenfolge-Karten |
| Zusammenhänge | `HistoryMode.connections` | Beteiligte, Person ↔ Ereignis, Folgen, Zeitraum, „Was folgte in der Übersicht?“ |
| Gemischte Wiederholung | `HistoryMode.mixed` | Runde mit 10 Aufgaben aus allem Eingeführten, Rückblick, Fehler gleich wiederholen |
| Zeitstrahl | `HistoryTimelineScreen` | Überblick (Zeiträume, Personenbalken, Ereignisse), Detail je Zeitraum/Jahrhundert, Filter nach Art und Spur, Jahreszahlen verdecken; standardmäßig nur Eingeführtes, umschaltbar – nichts gesperrt |

### Lernstufen eines Inhalts

Aus den Karten abgeleitet (`HistoryTrainer.stageOf`), nie gespeichert:

1. **nicht eingeführt** – Einführungsfrage (`…|h.intro`) noch nie beantwortet
2. **Grundlagen** – bis Einführung und eine Grundlage (`who`, `year`,
   `when`, `life`) zuletzt sicher waren
3. **Verknüpfen** – bis eine Verknüpfung (`actor`, `deed`, `effect`,
   `period`, `chrono` oder `next`) zuletzt sicher war
4. **ohne Hilfen** – freie Eingabe, Zeitabstände, Erklären

„Zuletzt sicher“ (`HistoryCardBook.solid`): beantwortet, Schwierigkeit unter
5,5, Stabilität ≥ 1. Ein Fehler stuft zurück. Das ist keine Aussage über
Beherrschung; die Oberfläche zeigt nur „eingeführt“, „Zuletzt sicher“ und
„Zum Wiederholen“.

Ausnahme: Wer ausdrücklich den Chronologie-Modus wählt, bekommt
Reihenfolge-Paare schon nach der Einführung.

### Umfang

Standard ist „Eingeführte Inhalte“: Antworten und Ablenker kommen aus dem
schon Gelernten. „Alle Inhalte“ (Filter oben rechts) nimmt den ganzen Stoff
dazu, beginnt aber auch dort mit Grundlagen.

### Eindeutigkeit und Datierungen

`HistoricalDating` (`lib/models/history/historical_dating.dart`, früher in
`church_history.dart`) unterscheidet genaue, ungefähre (`approx`) und
umstrittene (`disputed`) Angaben; ungefähre und umstrittene bekommen
±10 Jahre Unschärfe.

* Ablenker überschneiden sich nie mit der Antwort, verknüpfte Inhalte sind
  nie Ablenker, Fragen nach Zeit verraten die Jahreszahl nicht
  (`HistoryItem.revealsDate`, `timelessName`).
* Reihenfolgen nur zwischen sicher ordnenbaren Inhalten (`areOrderable`);
  Zeiträume werden nur mit Zeiträumen verglichen.
* Freie Jahreszahl nur bei genauen Angaben; Hinweis „Die Angabe ist
  ungefähr/umstritten“ bei den anderen.
* Ablenker bevorzugt aus Eingeführtem und aus derselben Spur
  (Geschichte bzw. Textgeschichte).

## Daten

### Kirchengeschichte: `assets/church_history/learning_path.json`

Nur die Anordnung; alle Inhalte kommen aus den vorhandenen Epochen,
Personen und Ereignissen (IDs unverändert), Aussagen aus den Erwähnungen
der Vorlesungen und Sitzungen (`sourceLabel`), Bedeutung aus dem Eintrag
(als „Ergänzung“).

```json
{"lessons": [{"id": "lesson.epochs_1", "part": "Überblick (VL 1)",
  "unit": "lecture.01", "title": "…", "items": ["epoch.antiquity", "…"]}],
 "sequences": [{"id": "seq.persecutions", "title": "…",
  "unit": "lecture.02", "slides": [13], "items": ["event.claudius_49", "…"]}]}
```

### Altes Testament: `assets/old_testament/history.json`

Eigene Inhalte, jede Aussage mit Einheit bzw. Sitzung und Folie. Eine
Datei für beide Veranstaltungen; die Sicht einer Veranstaltung
(`data.courseId`) enthält nur Inhalte mit Aussagen auf ihren Folien.
Abweichende Angaben stehen je Veranstaltung in `datingBy`, `nameBy`,
`consequenceBy` (z. B. Königtümer 10. Jh. in der Vorlesung, 9. Jh. in der
Übung, beide als umstritten markiert).

Felder eines Inhalts: `id`, `kind` (`period`, `person`, `group`, `event`),
`track`, `name`/`nameBy`, `dating`/`datingBy` (`from`, `to`, `label`,
`approx`, `disputed`, `note`; negative Jahre = v. Chr.), `statements`
(`unit`, `slides`, `text`), optional `period`, `role`, `clue`, `related`,
`consequence`/`consequenceBy`.

### Prüfung

`HistoryCourseLoader` wirft eine `FormatException` mit allen Problemen:
doppelte oder ungültige IDs, Kollisionen mit Fachbegriffen,
unbekannte Einheiten/Folien/Verweise, Lernschritte mit mehr als vier
Inhalten, Inhalte in keinem oder mehreren Lernschritten, Übersichten, deren
Reihenfolge den Datierungen widerspricht, Personen ohne Hinweis.

**Neue Inhalte:** nichts erfinden – nur, was Folien bzw. Material sagen;
unsichere Datierungen mit `approx`/`disputed` und `note`. Neue Inhalte in
einen (neuen) Lernschritt aufnehmen. IDs nie umbenennen.

## Speicherung

Keine neuen Dokumente: Karten `<ID>|h.<Fähigkeit>` (Folge in einer
Übersicht: `<seq>/<ID>|h.next`) liegen neben den Karten von Wissensquiz bzw.
Lernmodus in `users/{uid}/quiz_settings/church_history` bzw.
`old_testament` (Gäste lokal). Dadurch gelten Regeln, Zurücksetzen des
Bereichs (Einstellungen → Fortschritt), Kontolöschung und Export
unverändert. Die Karten des Lernwegs mischen sich nicht mit denen der
anderen Modi (eigenes Suffix).

* Zurücksetzen nur des Lernwegs: Menü auf der Startseite des Lernwegs
  (löscht nur `|h.`-Karten der Sicht; Wissensquiz, Einstellungen,
  Favoriten bleiben).
* Das Zurücksetzen „Alle Inhalte“ einer AT-Veranstaltung im
  Fortschrittsbildschirm löscht auch die Lernweg-Karten der anderen
  Veranstaltung, soweit Inhalte gemeinsam sind.
* `HistoryCardBook`: ein Kartenbestand je geöffnetem Lernweg; jede Antwort
  wird genau einmal verbucht und der Reihe nach gespeichert (kein späterer
  Stand wird von einem früheren überholt); Schreibfehler melden sich als
  Hinweis und blockieren spätere Schreibvorgänge nicht.
* Antworten zählen für Statistik und Streak des Bereichs (Quelle
  `history_steps`).

## Code

| Datei | Inhalt |
|---|---|
| `lib/models/history/history_course.dart` | `HistoryItem`, `HistoryLesson`, `HistorySequence`, `HistoryCourse`, Vergleichsfunktionen |
| `lib/models/history/historical_dating.dart` | Datierung mit Genauigkeit |
| `lib/services/history/history_course_loader.dart` | Sicht je Bereich/Veranstaltung, Prüfung |
| `lib/services/history/history_cards.dart` | `HistoryCardStore`, `HistoryCardBook` |
| `lib/services/history/history_trainer.dart` | Fähigkeiten, Stufen, Modi, Aufgaben, Auswahl (`LearningSelector`, `SpacedRepetition`) |
| `lib/services/history/history_lesson.dart` | Ablauf eines Lernschritts, Fortschritt |
| `lib/screens/history/` | Startseite, Lernschritt, Übungsmodi, Zeitstrahl, gemeinsame Widgets |
| `test/history/` | Daten, Logik, Speicherung, Oberfläche |
