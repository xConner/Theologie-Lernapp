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

## Nach Bibelleseplan lernen (Lernpfad)

Zweiter, gleichwertiger Lernweg neben „Einzelne Bücher“: Umschalter oben in
„Bücher systematisch lernen“ (nur, wenn der Leseplan zur Übung Bibelkunde AT
verfügbar ist, also mit Freigabe der Vorlesungsunterlagen). Logik in
`lib/quiz/books/reading_plan_path.dart` (`ReadingPlanPath`), Oberfläche in
`lib/screens/pericope_quiz/books/reading_path_view.dart`.

* **Datenquelle:** allein der Leseplan (`course-bibelkunde-at-wise-2026`)
  so, wie ihn `CourseSchedule` plant – mit eigenen Änderungen an Terminen
  und Stellen und dem Umfang „ganze Bücher“, falls der Leseplan begonnen
  wurde; sonst die Empfehlung. Eine Woche = eine Sitzung mit Lektüre, ihr
  Zeitraum und Abschluss (Vorabend bzw. Sitzungstag) sind die des
  Leseplans.
* **Zuordnung:** Eine Perikope der Liste gehört zur ersten Woche, deren
  Lesestücke sie berührt (Kapitel bzw. Versbereich). Reihenfolge: Bücher wie
  die Sitzung sie nennt (z. B. Ex vor Lev), im Buch nach der Liste.
  Perikopen ohne Stelle im Plan gehören zu keiner Woche. Nichts davon steht
  im Code.
* **Tagesmenge:** noch nicht eingeführte Perikopen bis einschließlich der
  laufenden Woche (Rückstand vergangener Wochen zuerst), gleichmäßig auf die
  Tage bis zum Abschluss der laufenden Woche verteilt; heute schon
  eingeführte zählen mit (die Menge verschiebt sich beim Lernen nicht). Je
  Einheit höchstens 8 neue; reicht die Menge weiter, bietet das Ende
  „Weiterlernen“ an. Ist sie geschafft, gibt es „Vorauslernen“ (5 neue der
  nächsten Woche mit offenen Perikopen).
* **Wiederholungen:** dieselbe `AdaptiveStudyQueue` wie Buch- und
  Abschnittseinheiten, Umfang = einzuführende Perikopen plus alle schon
  begonnenen Perikopen des Plans (auch aus späteren Wochen oder vor dem
  Beginn). Auswahl nach Lernbedarf × Fälligkeit, schwierige gelegentlich als
  Vergleich. Mit `paceNew` werden die neuen gleichmäßig zwischen die
  Wiederholungen verteilt und sicher eingeführt, damit Fälliges sie nicht
  verdrängt. Wissensfragen: die der Kapitel der Wochen bis jetzt.
* **Beginn:** „Ab dieser Woche beginnen“ (Wochen mit früherem
  Sitzungstermin sind freiwillig, kein Rückstand) oder „Ab der ersten Woche“.
  Gespeichert wird nur der Tag, im Dokument `pericope_plans`, Feld
  `readingPaths: {Plan-ID: {startedOn}}` – kein neues Dokument.
* **Gemeinsamer Lernstand:** Der Lernpfad hat keine eigenen Karten. Er liest
  und schreibt `pericope_books` mit denselben Schlüsseln
  (`BookPericope.key`) und Regeln wie „Einzelne Bücher“; Einführung,
  Treffer/Fehler, Abstände, letzte Abfrage und Startwerte aus dem
  Endlos-Quiz gelten in beiden Wegen. Übersprungene Wochen bleiben
  Rückstand; schon gelernte Perikopen späterer Wochen werden nicht neu
  eingeführt.
* **Übersicht:** laufende Woche mit Büchern und verbleibenden Tagen, heute
  neu, Rückstand, fällige Wiederholungen, schon vorausgelernte,
  Gesamtfortschritt mit Zieldatum (Abschluss der letzten Woche) und alle
  Wochen mit Status (Abgeschlossen, Diese Woche, Rückstand, Später, Vor
  Beginn); eine Woche antippen zeigt ihre Perikopen und „Diese Woche
  lernen“.

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
  Folientabellen. Seit Sitzung 3 (30.10.2026) gibt es außerdem **Exodus** nach Folie 2
  (Ägypten 1, Mose 2–4, vor dem Pharao 5–6, Plagen und Passa 7–12, Auszug
  und Wüste 13–18, Theophanie 19, Dekalog 20,1–21, Bundesbuch
  20,22–23,33, Bundesschluss 24, Stiftshütte 25–31, Goldenes Kalb 32–34,
  Ausführung 35–40; die Teilung innerhalb von 1–18 ist feiner als die
  Folie) und **Levitikus** nach Folie 8 (Opfer 1–7, Priesterweihe 8–10,
  Reinheit 11–15, Jom Kippur 16, Heiligkeitsgesetz 17–26, Gelübde 27).
  Abschnitte speichern keinen Lernstand; neue Gliederungen ändern daher
  nichts am Fortschritt.
* Bekommt eine Perikope der Liste nachträglich eine eigene ID, trägt
  `PericopeIdMigration` (`lib/quiz/pericope_id_migration.dart`) alte und
  neue ID bzw. alten und neuen Schlüssel ein. Beim Laden gilt dann eine
  Kopie der alten Karte (Endlos-Quiz, Buch-Karte, Präzisierung), solange
  die neue noch keine eigene hat; gelöscht wird nichts. Das betrifft
  Gen 6,9-22 (`noahs_erwaehlung_und_bau_der_arche`, früher wie Gen 6,1-8
  `die_bosheit_der_menschen`) und die Genesis-Perikopen, die nach der Übung
  Bibelkunde AT geteilt wurden oder einen anderen Anfang bekamen
  (`movedKeys`, 24.10.2026). Bei diesen gilt die Buch-Karte weiter, eine
  persönliche Präzisierung aber nicht, weil sie die frühere Stelle
  beschrieb.
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
| Wissensfragen | Personen, Ereignisse, Begriffe, Aufbau, Musterantworten (siehe unten); auch in jeder Lerneinheit eingestreut |

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

## Wissensfragen und Musterantworten

Neben den Perikopen gibt es inhaltliche Fragen zu einem Buch
(`lib/quiz/books/knowledge.dart`, Oberfläche in
`lib/screens/pericope_quiz/books/knowledge_widgets.dart`). Drei Ebenen:
**Lesen** (Leseplan, Bibelstelle lesen), **Verstehen** (Musterantworten
und Erklärungen zum Nachlesen), **Wiederholen** (Fragen mit Spaced
Repetition).

### Daten

* Öffentlich: `assets/bible_knowledge/index.json` nennt die Dateien
  (`gen.json`, `ex.json`, `lev.json`), Fragen-IDs `bq.<buch>.<name>`.
* Geschützt (Vorlesungsunterlagen, nur für freigeschaltete Konten, siehe
  `docs/lecture-materials.md`): `assets/old_testament/model_answers/`,
  je Sitzung eine Datei, z. B. `bk02-genesis.json`. Aufgaben `ma.bk02.NN`
  mit **wörtlicher Musterantwort** (`answer`), Anmerkung (`note`),
  Bereich, Stellen und den daraus gebildeten Lernfragen
  (`ma.bk02.NN.<name>`). Die Musterantwort ist die maßgebliche Referenz;
  Lernfragen zerlegen sie nur in kleinere Schritte.
* Je Frage: `format` (`choice` eine richtige, `multi` mehrere richtige,
  `reveal` aufdecken mit Selbsteinschätzung, `match` zuordnen, `order`
  Reihenfolge), `topic`, `prompt`, Lösung (`answer`/`correct`/
  `distractors`/`pairs`/`items`), `explanation`, `range` (`"12-25"`,
  `"12,1-25,18"`, `"19,1-29"`; ohne Bereich: Frage zum ganzen Buch),
  `refs` (öffnen den Bibelreader), optional `pericopes`, `memoryVerse`.
  Ungültige Fragen werden beim Laden abgelehnt, doppelte IDs ebenso.
* IDs sind stabil: Lernstände hängen an ihnen. Fragen nie umbenennen,
  nur ergänzen.

### Zuordnung

Eine Frage gehört zu einem Abschnitt der Gliederung bzw. einem
Kapitelbereich, wenn ihr Bereich ganz darin liegt; Fragen ohne Bereich
gehören nur zum ganzen Buch. Lerneinheit (Buch) mischt bis zu 5
Wissensfragen (höchstens 3 neue) gleichmäßig zwischen die Perikopen;
Abschnitt und Kapitel nehmen die Fragen ihres Bereichs. „Wissensfragen
lernen“ (Buchkarte) und „Musterantworten“ (je Aufgabe) üben nur Fragen,
bis zu 12 je Einheit, davon 6 neue. Keine Frage zweimal in einer Einheit.

### Bewertung

Wie Perikopen (`BookCard`, `BookLearningRules.recordRecall`): sicher nach
2 richtigen Abrufen mit je 12 Stunden Abstand, fällig nach dem
Wiederholungsabstand; Auswahl nach Lernbedarf × Fälligkeit. Auswahl,
Zuordnen und Reihenfolge werden automatisch bewertet, Aufdecken durch
„Gewusst“/„Nicht gewusst“. Fällige Wissensfragen erscheinen in den
Wiederholungen (eigener Knopf in der Übersicht).

### Schalter

„Wissensfragen einbeziehen“ (Buchkarte und Einstellungen → „Bücher
lernen“), Standard **an**, gespeichert in `bible_knowledge_settings`.
Aus: keine Wissensfragen in Einheiten und Wiederholungen; Perikopen,
Leseplan und das Nachlesen der Musterantworten bleiben. Lernstände
bleiben gespeichert und gelten nach dem Wiedereinschalten weiter.

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
| `pericope_plans` | `{plans: {Buch: {dailyNew, targetDate, paused, createdAt}}, readingPaths: {Plan-ID: {startedOn}}}` |
| `bible_knowledge` | `{cards: {Fragen-ID: {…wie pericope_books}}}` – Lernstand je Wissensfrage |
| `bible_knowledge_settings` | `{settings: {enabled}}` – Schalter Wissensfragen |

Geschrieben werden nur geänderte Einträge (Merge). Gast → Konto übernimmt
die Dokumente; „Alle Lernfortschritte zurücksetzen“ und das
Zurücksetzen der Perikopenkenntnisse löschen `pericope_books` und
`bible_knowledge` (das Zurücksetzen nur eines Bibelbuchs lässt die
Wissensfragen unberührt),
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

## Gemeinsamer Lernmodus: Wissensfragen, Perikopen und Gliederung

Seit 30.10.2026 lernt jede Lerneinheit (Buch, Abschnitt, Kapitel, Lernpfad,
Wiederholungen) gemeinsam, was eingeschaltet ist. Zwei Schalter oben in
„Bücher systematisch lernen“ und in den Einstellungen, beide Standard an:

* **Wissensfragen** – inhaltliche Fragen (`bq.*`, `ma.*`, `vl.*`).
* **Perikopen und Gliederung** – Stellen der Perikopen und die Aufgaben zur
  Grobgliederung (`go.*`).

Mindestens einer bleibt an. Gespeichert in `bible_knowledge_settings`
(`settings: {enabled, pericopes}`); Lernstände bleiben beim Ausschalten
erhalten. Ohne Perikopen besteht eine Einheit aus bis zu 12 Fragen (6 neue).
Mit beiden mischt `AdaptiveStudyQueue` bis zu 6 Fragen gleichmäßig zwischen
die Perikopen; Wissensfragen und Gliederungsaufgaben wechseln sich ab, eine
falsch beantwortete Frage kommt frühestens 3 Aufgaben später genau einmal
wieder (zählt als Abruf nach gezeigter Lösung). Wiederholungslisten verteilen
die fälligen Fragen gleichmäßig (`interleaveTasks`).

### Grobgliederung (Ebene A) und Feinperikopen (Ebene B)

`assets/book_outlines.json` kennt je Buch optional `parts`: Hauptabschnitte
nach der Vorlesung, die Abschnitte (`sections`) über ihre IDs bündeln –
auch nicht zusammenhängend (Gen 12–36 + 38). Felder: `id`, `title`, `label`
(„12–36 (+38)“), `sections`, `accept` (Kapitelbereiche für die freie
Eingabe), `keywords` (Stichwörter, an denen ein frei eingegebener Titel
erkannt wird), `summary`, `origin`. Abschnitte mit `learn: true` sind
Unterpunkte, die die Vorlesung nennt (z. B. Ex 2–4 Mose, 20,22–23,33
Bundesbuch). Jede Perikope gehört über ihren Abschnitt zu genau einem
Hauptabschnitt; die Perikopenliste bleibt unverändert.

`OutlineQuestions` (lib/quiz/books/outline_questions.dart) bildet daraus
Aufgaben mit stabilen IDs `go.<buch>.…`: Hauptabschnitte ordnen, Kapitel
zuordnen, Kapitel frei eingeben, Titel zu einem Kapitelbereich nennen,
Unterpunkte verorten, drei Zuordnungen Perikope/Stelle → Hauptabschnitt und
die ganze Gliederung frei wiedergeben. Sie nutzen Karten und Spaced
Repetition der Wissensfragen (`bible_knowledge`), gehören aber zum Schalter
„Perikopen und Gliederung“. Die Buchansicht zeigt die Karte
„Grobgliederung“ und gruppiert die Abschnitte nach Hauptabschnitten.

### Freie Eingabe (`format: input`)

`accept` nennt richtige Antworten; „A + B“ verlangt beide Teile.
`KnowledgeAnswerMatcher` erkennt gleiche Wörter ohne Groß-/Kleinschreibung,
Umlaute, Satzzeichen und Artikel sowie kleine Tippfehler, Kapitelbereiche
auch mit Buchname oder Gedankenstrich (nur Kapitel: Kapitel müssen stimmen;
mit Versen: genau). Was nicht erkannt wird, ist nicht falsch: Die App zeigt
die Lösung, und man bewertet selbst („Ja, richtig“ / „Nein, falsch“).

### Quellen und Relevanz

Jede Frage hat `basis` (`slide`, `audio`, `modelAnswer`, `supplement`),
`relevance` (`focus` = Schwerpunkt, `lecture` = Vorlesungsstoff,
`supplement` = sinnvolle Ergänzung) und `origin` (Fundstellen, z. B.
„Ex-Lev Folie 6“, später mit Zeitstempel der Aufnahme). Ohne Angabe gilt
eine öffentliche Frage als Ergänzung der App. Die Kopfzeile und der Hinweis
„Quelle“ nach der Antwort zeigen das an; Ergänzungen werden ausdrücklich
als „nicht aus der Vorlesung“ gekennzeichnet. Fragen nach den Folien liegen
geschützt in `assets/old_testament/model_answers/bk0N-*-vorlesung.json`
(IDs `vl.bkNN.*`). Randinformationen und fehlerhafte Fragen werden entfernt
(Prüfung 30.10.2026: 20 von 80 öffentlichen Fragen); IDs entfernter Fragen
nicht wiederverwenden.
