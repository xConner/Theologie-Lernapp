# Bücher systematisch lernen

Ergänzung zum Perikopenquiz: die Perikopen ganzer Bibelbücher schrittweise
lernen, ihre Reihenfolge üben, fällige Wiederholungen bearbeiten und den
Fortschritt je Buch und Kapitel sehen. Einstieg auf der Startseite unter
„Bücher systematisch lernen“, direkt unter dem Perikopenquiz.

Das bisherige Perikopenquiz (Endlos-Lernmodus) bleibt unverändert: eigener
Screen, eigene Karten (`learning_cards`), eigene Buchauswahl, eigene
Bewertung. Die neuen Funktionen lesen seine Daten nur.

## Datenbasis

* Perikopen: ausschließlich die geladene Perikopenliste
  (`assets/perikopen.json`, ggf. mit `pericope_overrides`), nur Einträge mit
  `required: true` – wie im Endlos-Quiz. Es werden keine Perikopen oder
  Stellen erzeugt.
* Eine Perikope beim Buchlernen ist **ein Eintrag** der Liste. Das
  Endlos-Quiz fasst alle Einträge einer ID zu einer Frage zusammen
  (synoptische Parallelen; „Berufung der Jünger“ steht in Mk 1 dreimal).
  Die IDs bleiben unverändert; der Eintrag wird über
  `Buch|ID|Anfangskapitel,Anfangsvers` der globalen Daten angesprochen
  (`BookPericope.key`).
* Reihenfolge im Buch: nach Anfangskapitel und -vers der Liste.

## Lernstatus

Stufe und Fälligkeit sind getrennt, damit sich nichts widerspricht: Eine
Perikope kann „Sicher gelernt“ **und** „Wiederholung fällig“ sein.

| Status | Regel |
|---|---|
| Neu | weder eingeführt noch je abgefragt |
| In Bearbeitung | eingeführt oder abgefragt, aber noch nicht sicher |
| Sicher gelernt | **2 richtige Abrufe in Folge, jeder mindestens 12 Stunden nach der vorigen Abfrage**; ein Fehler setzt die Zählung auf 0 |
| Wiederholung fällig | `letzte Abfrage + Wiederholungsabstand ≤ jetzt` |

* Den Wiederholungsabstand berechnet dieselbe `SpacedRepetition` wie im
  Endlos-Quiz (gleiche Parameter).
* Eine richtige Antwort direkt nach dem Zeigen der Lösung (Abfrage kurz nach
  der Einführung) zählt nie als zeitlich getrennter Abruf, ebenso
  Vergleichsaufgaben mit Auswahlmöglichkeiten.
* „Schwierig“: mindestens 2 Fehler und Schwierigkeit ≥ 6 (Startwert 5, +1 je
  Fehler, bis −0,5 je Treffer). „Kürzlich falsch“: Fehler in den letzten
  7 Tagen.
* Reihenfolge-Aufgaben zählen getrennt (`orderCorrect`/`orderWrong`) und
  ändern weder Status noch Wiederholungsabstand.
* Die Regeln stehen an einer Stelle: `BookLearningRules` in
  `lib/quiz/books/book_learning_status.dart`; in der App erklärt sie
  „Wie entsteht der Status?“.

### Übernahme aus dem Endlos-Quiz

Bestehende Nutzer beginnen nicht von vorn. Solange es für eine Perikope noch
keine eigene Karte gibt, gilt die Karte des Endlos-Quiz zu ihrer ID – aber
nur für Bücher, die dort ausgewählt sind (eine Frage umfasst nur deren
Stellen). Hat das Endlos-Quiz einen Abstand von mindestens 3 Tagen
ermittelt, gilt die Perikope als sicher (die `SpacedRepetition` vergrößert
den Abstand nur bei richtigen Antworten mit zeitlichem Abstand). Beim ersten
Verbuchen wird daraus eine eigene Karte; die Karte des Endlos-Quiz wird nie
geschrieben.

## Abfrage und Bewertung

Abfrageformen (`ReferencePrompt`): vollständige Stelle, Buch vorgegeben,
Buch und Kapitel vorgegeben (nur bei versgenauen Perikopen innerhalb eines
Kapitels). Dazu Reihenfolge (nächste Perikope, Perikope dazwischen, mehrere
ordnen) und Vergleich (zum Titel die richtige unter nahe beieinander
liegenden Stellen wählen). Getippt wird frei; „Im Kopf“ mit
Selbsteinschätzung ist wie im Endlos-Quiz möglich (nicht in der Prüfung).

`ReferenceAnswerChecker`:

* **Kapitelgenau** (Standard der Liste): Nur der Kapitelbereich zählt.
  Zusätzlich getippte Verse sind kein Fehler – die Liste kennt dort keine
  verbindlichen Verse.
* **Versgenau** (global oder persönlich präzisiert): Kapitel und Verse müssen
  der hinterlegten Stelle entsprechen. Nur Kapitel ohne Verse ergibt
  „Verse fehlen“.
* Schreibweisen: Quiz-Schreibweise („Mk 1,14-20“), Gedankenstriche,
  Doppelpunkt, Leerzeichen, Groß-/Kleinschreibung und alle Buchnamen, die der
  Bibel-Reader versteht („Markus 1,14–20“).

## Persönliche Verspräzisierung

An jeder Perikope (Antippen → „Versgenau festlegen“): bisherige Angabe der
Liste, Schalter „Für mich versgenau abfragen“, Anfangs- und Endvers (bei
kapitelübergreifenden Perikopen auch die Kapitel). Vorbelegt sind die in der
Liste hinterlegten Verse – nur als Vorschlag.

* Geprüft wird: Kapitel innerhalb der Kapitel der Perikope, Endvers nicht vor
  dem Anfangsvers, Verse nicht über der Verszahl des Kapitels (deutsche
  Zählung aus `assets/bible/translations.json`; für Bücher ohne deutsch
  gezählte Ausgabe nur die Form).
* Gespeichert getrennt von der Perikopenliste (siehe unten); die globale
  Perikope bleibt unverändert. „Präzisierung entfernen“ stellt die
  Genauigkeit der Liste wieder her.
* Gilt in allen neuen Modi, in Fortschritt, Wiederholungen und Prüfung.
  Das Endlos-Quiz fragt weiterhin nach der Liste ab.

## Lernplan

Je Buch: neue Perikopen pro Tag, optional ein Zieldatum (dann mindestens
`⌈verbleibende neue / verbleibende Tage⌉` pro Tag), pausieren und
fortsetzen. Eine Lerneinheit bringt zuerst die fälligen Wiederholungen
(höchstens 20, die am längsten fälligen zuerst), danach neue Perikopen in
Buchreihenfolge bis zur Tagesmenge (ohne Plan 3). Neue Perikopen werden
eingeführt und erst einige Aufgaben später abgefragt. Ein pausierter Plan
schlägt nichts Neues vor; Kapiteltraining, Auswahl und einzelne Perikopen
bleiben jederzeit frei wählbar.

## Lernmodi

| Modus | Inhalt |
|---|---|
| Buch lernen | Lerneinheit nach Plan (s. o.) |
| Kapiteltraining | Kapitel oder Bereich: fällige zuerst, dann alle übrigen; neue werden eingeführt |
| Gemischte Wiederholung | fällige, schwierige und gelernte Perikopen gemischt (20), ohne neue |
| Reihenfolge lernen | Kapitelbereich oder ganzes Buch; nur an der Reihenfolge der Liste bewertet |
| Schwierige Perikopen | schwierige und kürzlich falsche, fehleranfälligste zuerst, mit Vergleichsaufgaben |
| Prüfung | ganzes Buch, Kapitelbereich oder Auswahl; keine Lösung und kein Ton während der Bearbeitung, am Ende Ergebnis und Fehler |
| Wiederholungen | überfällig, heute fällig, kürzlich falsch, auf Wunsch bald fällig (3 Tage); gemischt (auch buchübergreifend), je Kapitel oder einzeln |

## Speicherung

Kein neues Speichersystem und keine neue Firestore-Collection: Konten
speichern unter `users/{uid}/quiz_settings/` (dieselbe, bereits
freigegebene Collection wie die Buchauswahl des Endlos-Quiz), Gäste lokal
im `LocalLearningStore` (`guest.v1.quiz_settings.<name>`).

| Dokument | Inhalt |
|---|---|
| `pericope_books` | `{cards: {key: {s, d, r, n, w, sp, lw, i, oc, ow}}}` – Lernstand je Perikope |
| `pericope_precision` | `{items: {key: {startChapter, startVerse, endChapter, endVerse}}}` |
| `pericope_plans` | `{plans: {Buch: {dailyNew, targetDate, paused, createdAt}}}` |

Geschrieben werden nur geänderte Einträge (Merge). Gast → Konto übernimmt
die drei Dokumente; „Lernfortschritt zurücksetzen“ löscht `pericope_books`,
Präzisierungen und Pläne bleiben; die Kontolöschung entfernt
`quiz_settings` vollständig.

## Grenzen

* Ein Dokument je Nutzer für alle Lernstände: bei allen 2 884 Perikopen
  etwa 350 KB, unter der Firestore-Grenze von 1 MB.
* Präzisierungen gelten nicht im Endlos-Quiz.
* Antworten im Endlos-Quiz fließen nach dem ersten Verbuchen einer Perikope
  beim Buchlernen nicht mehr in deren Status ein.
