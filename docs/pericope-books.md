# Bücher systematisch lernen

Ergänzung zum Perikopenquiz: die Perikopen ganzer Bibelbücher schrittweise
lernen, ihre Reihenfolge üben, fällige Wiederholungen bearbeiten und den
Fortschritt je Buch, Abschnitt und Kapitel sehen. Einstieg auf der
Startseite unter „Bibelkunde“ (`BibelkundeScreen`), dort neben dem
Perikopenquiz. Der dritte Knopf dort, „Grundlagen der Bibelkunde“, öffnet
die Sitzungen der Übung Bibelkunde AT; sie liegen in der Datenbasis des
Alten Testaments (siehe [old-testament.md](old-testament.md)).

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

Aufgaben: Stelle zum Titel nennen, Reihenfolge (nächste Perikope, Perikope
dazwischen, mehrere ordnen) und Vergleich (zum Titel die richtige unter nahe
beieinander liegenden Stellen wählen). Getippt wird frei, mit der
Schnelleingabe des Perikopenquiz (`QuickEntryPanel`, gleiche gespeicherte
Wahl) oder „Im Kopf“ mit Selbsteinschätzung (nicht in der Prüfung).

### Buchkontext der Eingabe

Ob das Buch mit eingegeben werden muss, hängt allein vom Umfang der
Lerneinheit ab – nicht von der einzelnen Aufgabe:

* **Ein Buch** (Buchansicht, Abschnitt, Kapitel, Prüfung, Wiederholung eines
  Kapitels): Das Buch steht vor dem Eingabefeld, eingegeben wird nur das
  Kapitel („5“ für Gen 5; bei versgenauen Perikopen „1,14-20“). Wer das Buch
  trotzdem mittippt, wird nicht bestraft. Die Schnelleingabe beginnt bei den
  Kapiteln.
* **Mehrere Bücher** (z. B. alle fälligen Wiederholungen gemischt): Die
  Eingabe muss das Buch nennen („Gen 5“); die Schnelleingabe bietet die
  Bücher der Einheit an.

Eine Quelle für alles: `StudySession.contextBook` (aus den Büchern der
Aufgaben). Eingabefeld, Schnelleingabe, Vorab-Prüfung und Bewertung lesen nur
diesen Wert. Früher wählte der Planer die Form je Aufgabe zufällig – das war
die Ursache der uneinheitlichen Eingabe.

Vor der Bewertung prüft `ReferenceAnswerChecker.problem` die Eingabe;
solche Eingaben zählen **nicht** als Fehler, der Knopf „Prüfen“ bleibt aus:
leere Eingabe, unlesbares Format, unbekannter Buchname, fehlendes Buch ohne
Buchkontext, Buch ohne Kapitel und Kapitel, in denen es laut Perikopenliste
keine Perikope gibt (dieselbe `BibleStructure` wie die Schnelleingabe).

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
fortsetzen. Der Plan bestimmt nur, wie viele neue Perikopen eine
Buch-Lerneinheit einführen darf (ohne Plan 3 am Tag); die Auswahl selbst
folgt dem Wiederholungsverfahren (siehe unten). Ein pausierter Plan
schlägt nichts Neues vor; Abschnitte, Kapitel und einzelne Perikopen
bleiben jederzeit frei wählbar.

## Auswahl der Perikopen (Spaced Repetition)

Buch-, Abschnitts- und Kapitel-Lerneinheiten werden fortlaufend gebildet
(`AdaptiveStudyQueue`, `lib/quiz/books/adaptive_study_queue.dart`) – mit dem
unveränderten Auswahlverfahren des Perikopenquiz (`LearningSelector`,
`SpacedRepetition`):

* **Auswahlwert = Lernbedarf × Fälligkeit**, gewichtete Zufallswahl. Der
  Lernbedarf kommt aus `difficulty` (Fehler erhöhen, Treffer senken), die
  Fälligkeit aus der Zeit seit `lastReviewed` im Verhältnis zum
  Wiederholungsabstand `stability`. (Felder „weight“ oder „lastAsked“ gibt
  es im Code nicht; diese drei Werte sind es.)
* Zuletzt gefragte Perikopen sind kurz gesperrt; neue Karten haben ein
  gemeinsames Budget, damit sie fällige Wiederholungen nicht verdrängen.
* Gewählt wird nach jeder Antwort neu, also mit dem aktuellen Stand.
* Die Stufen „Neu“, „In Bearbeitung“, „Sicher“ und „fällig“ dienen nur der
  Anzeige; keine schließt eine Perikope von der Auswahl aus.
* Startwert: Ohne eigene Karte gewichtet die Karte des Endlos-Quiz
  (`BookLearningState.selectionCardOf`); sie wird nicht verändert.

Geprüft für ganze Bücher und nur dort ergänzt, wo es nötig war:

* **Neue Perikopen** kommen aus einem Fenster der nächsten 10 noch nicht
  eingeführten (Buchreihenfolge), darin zufällig – sonst würde aus allen
  96 neuen Markus-Perikopen wahllos eingeführt. Je Einheit höchstens die
  Tagesmenge des Plans (Buch) bzw. 6 (Abschnitt, Kapitel). Jede neue wird
  vorgestellt und zwei Aufgaben später abgefragt.
* **Keine unnötigen Wiederholungen:** Je Einheit wird jede Perikope einmal
  abgefragt, nach einer falschen Antwort genau ein weiteres Mal (später).
  Eine Einheit hat höchstens 15 geplante Abfragen und nie mehr, als es
  abfragbare Perikopen gibt.

Feste Folgen behalten ihren Zweck: Prüfung (jede Perikope einmal,
gemischt), Reihenfolge, einzelne Perikope. Wiederholungslisten
(„Überfällig“, „Fehler wiederholen“ …) fragen jede Perikope einmal, gereiht
nach Auswahlwert mit Zufall statt starrer Sortierung.

Endlos-Quiz und Buchlernen behalten getrennte Karten: Das Quiz führt eine
Karte je Perikopen-ID über alle gewählten Bücher (Parallelstellen
zusammen), das Buchlernen eine je Eintrag (z. B. dreimal „Berufung der
Jünger“ in Mk 1). Eine gemeinsame Datenbasis hieße, Karten umzurechnen
oder zu verschmelzen – das würde bestehende Lernstände verändern. Das
Buchlernen nutzt die Quiz-Karten deshalb weiter als Startwert.

## Buchansicht

Keine Liste aller Perikopen mehr. Die Buchansicht zeigt Fortschritt,
Lernplan, die **Abschnitte** der Gliederung (mit Fortschritt, „Hier weiter“
am aktuellen Abschnitt), weitere Lernmodi und je Kapitel ein kleines Feld
(Farbe nach Fortschritt, Antippen lernt das Kapitel). Einzelne Perikopen –
zum gezielten Üben, Vergleichen oder für eine Verspräzisierung – stehen
eingeklappt im Blatt ihres Abschnitts.

## Buchgliederung (abschnittsweises Lernen)

Ein Buch kann in eine geordnete Folge von Lernabschnitten gegliedert werden
(`lib/quiz/books/book_outline.dart`). Die Gliederungen stehen zentral in
`assets/book_outlines.json` und lassen sich dort ergänzen oder austauschen,
ohne Code zu ändern:

```json
{"books": {"Mk": {"provisional": true, "note": "…", "sections": [
  {"id": "mk-beispiel-1", "title": "Anfang des Evangeliums",
   "start": "1,1", "end": "1,13"}]}}}
```

* `id` (eindeutig), `title`, `start`, `end`; Grenzen als „Kapitel“ oder
  „Kapitel,Vers“ (deutsche Zählung der Perikopenliste). Als Anfang heißt
  „Kapitel“ ab Vers 1, als Ende bis Kapitelende.
* Perikopen gehören zu dem Abschnitt, in dem sie **beginnen** – so landet
  jede genau einmal in einem Abschnitt, auch wenn Kapitel- und
  Abschnittsgrenzen nicht übereinstimmen (z. B. Mk 6,6: Ablehnung in Nazaret
  vorn, Aussendung der Zwölf im nächsten Abschnitt).
* Was keinem Abschnitt angehört, kommt in einen Abschnitt „Weitere
  Perikopen“. Ungültige Abschnitte (fehlende Felder, doppelte ID, Ende vor
  Anfang) werden übergangen und protokolliert.
* `provisional: true` kennzeichnet vorläufige Daten; die App zeigt das an.
  Hinterlegt sind eine **vorläufige Beispielgliederung für Markus** zum
  Ausprobieren und die **Genesis nach der Übung Bibelkunde AT** (Sitzung 2,
  Folie 7): Urgeschichte (1–11), Erzelterngeschichte Abraham (12–25,18),
  Isaak (25,19–26), Jakob und Esau (27–36), Josephsgeschichte (37), Juda und
  Tamar (38, nach der Folie Teil der Erzelterngeschichte),
  Josephsgeschichte (39–50). Die Grenzen 25,18/25,19 folgen den Farben der
  Folientabellen.
* Bücher ohne Eintrag erhalten automatisch Abschnitte aus ganzen Kapiteln
  mit je etwa 10 Perikopen; sie sind als automatisch gebildet
  gekennzeichnet.

Abschnitt lernen: eine Lerneinheit über die Perikopen des Abschnitts
(Auswahl wie oben, bis zu 6 neue). Am Ende bietet die Einheit „Abschnitt
weiterlernen“ (solange er neue Perikopen hat) und „Weiter: nächster
Abschnitt“ an. Der aktuelle Abschnitt ist der erste mit neuen Perikopen,
sonst der erste mit fälligen oder noch nicht sicheren. Es wird nichts
zusätzlich gespeichert.

## Lernmöglichkeiten

Bewusst wenige, klar verschiedene:

| Möglichkeit | Lernaufgabe |
|---|---|
| Lerneinheit (Buch) | Stellen abrufen, ganzes Buch, neue nach Lernplan |
| Abschnitt lernen | dasselbe für einen Abschnitt der Gliederung, danach der nächste |
| Kapitel oder Bereich | dasselbe für ein Kapitel (Kapitelfeld) oder einen Bereich |
| Wiederholungen | gezielt Überfälliges, heute Fälliges, kürzlich Falsches; auch buchübergreifend |
| Reihenfolge lernen | Abfolge der Perikopen (nächste, dazwischen, ordnen); zählt getrennt |
| Prüfung | Buch, Bereich oder Abschnitt ohne Hilfen, Ergebnis am Ende |
| Einzelne Perikope | über ihren Abschnitt: üben, mit Nachbarn vergleichen, versgenau festlegen |

Zusammengefasst wurden:

* **Gemischte Wiederholung** – entfiel als eigener Knopf: Jede Lerneinheit
  mischt nach Lernbedarf und Fälligkeit; bei pausiertem Plan oder ohne neue
  Perikopen ist sie genau diese Wiederholung.
* **Schwierige Perikopen** – entfiel als eigener Knopf: Fehler erhöhen den
  Lernbedarf und damit die Auswahlwahrscheinlichkeit; schwierige Perikopen
  kommen gelegentlich als Vergleichsaufgabe; „Kürzlich falsch“ steht unter
  Wiederholungen.
* **Kapiteltraining** und **Abschnitt lernen** nutzen dieselbe Lerneinheit,
  nur mit anderem Umfang.
* Freie Eingabe, Schnelleingabe und „Im Kopf“ sind Antwortformen, keine
  Modi.

## Bibelstelle lesen

Wie „Bibelstelle lesen“ im Perikopenquiz: derselbe `BibleReaderScreen`,
die Stelle über `BibleReferenceParser.passageOf` (mit persönlicher
Verspräzisierung, falls vorhanden), Perikopenüberschriften aus derselben
Liste (`lib/screens/pericope_quiz/books/bible_passage.dart`). Erreichbar
in der Buchansicht (ganzes Buch), im Abschnittsblatt, bei einzelnen
Perikopen, bei der Einführung, nach jeder Antwort (nicht in der Prüfung),
in den Wiederholungen und bei den Fehlern im Ergebnis. Der Reader liegt
über der Ansicht; zurück geht es an dieselbe Stelle, die Lerneinheit läuft
weiter. Bewertet wird weiterhin nur die Stelle.

## Einstellungen

Jede Ansicht von „Bücher systematisch lernen“ hat das Zahnrad mit dem
Einstellungsdialog der Trainer (`ModuleSettingsDialog`): Tab „Allgemein“
(globale Einstellungen samt Zurücksetzen der Lernfortschritte) und Tab
„Bücher lernen“ (Antwortform, Schnelleingabe, Sounds). Die Bibelkunde-Seite
hat das Zahnrad der allgemeinen Einstellungen.

Zurücksetzen aus einem geöffneten Lernbereich: In Trainern bleibt es
gesperrt, weil sie ihre Karten im Speicher halten und zurückschreiben
würden. Das Perikopenquiz und „Bücher systematisch lernen“ laden ihre
Lernstände nach einem Zurücksetzen neu (`onProgressReset`); dort ist es
deshalb erlaubt. Es ist dieselbe Oberfläche und derselbe Dienst wie auf
der Startseite, also dasselbe Ergebnis von jedem Einstieg aus.

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
die drei Dokumente; „Alle Lernfortschritte zurücksetzen“ und das
Zurücksetzen der Perikopenkenntnisse löschen `pericope_books`,
Präzisierungen und Pläne bleiben; die Kontolöschung entfernt
`quiz_settings` vollständig.

### Perikopenkenntnisse eines Bibelbuchs zurücksetzen

Einstellungen → „Einzelnen Lernbereich zurücksetzen“ → Perikopenkenntnisse
→ „Nur ein Bibelbuch“ (`PericopeBookResetPlan` in
`lib/services/progress_reset.dart`). Zugeordnet wird nur über die
Buchabkürzung der Perikopenliste und die Perikopen-ID:

* Karten des Perikopenquiz (`learning_cards`), deren ID nur in diesem Buch
  vorkommt, werden zurückgesetzt (Eselsbrücken bleiben).
* Karten, deren ID auch in anderen Büchern vorkommt (Parallelstellen),
  bleiben erhalten – außer der Nutzer wählt „Gemeinsame Lernstände auch
  zurücksetzen“; der Dialog nennt Anzahl und betroffene Bücher.
* Buch-Karten mit Schlüssel `Buch|…` werden gelöscht. Bleibt eine gemeinsame
  Quiz-Karte erhalten, wird die Perikope stattdessen markiert (`"nl": true`,
  `BookCard.ignoreEndlessQuiz`), damit sie nicht sofort wieder deren Stand
  übernimmt.

## Grenzen

* Ein Dokument je Nutzer für alle Lernstände: bei allen 2 884 Perikopen
  etwa 350 KB, unter der Firestore-Grenze von 1 MB.
* Präzisierungen gelten nicht im Endlos-Quiz.
* Antworten im Endlos-Quiz fließen nach dem ersten Verbuchen einer Perikope
  beim Buchlernen nicht mehr in deren Status ein.
