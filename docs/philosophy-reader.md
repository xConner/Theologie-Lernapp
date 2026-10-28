# Philosophie: Lesebereich (Aristoteles, Physik)

Lektüre eines philosophischen Werks im Original mit Übersetzung, Apparat,
Anmerkungen, Einleitung und Lernhilfen. Erstes Werk: Aristoteles, *Physik*
I–IV (Seminar). Der Bereich ist so gebaut, dass weitere Werke nur einen
Eintrag im Werkverzeichnis und ihre Textdateien brauchen.

## Aufbau

| Schicht | Ort |
| --- | --- |
| Werkverzeichnis | `assets/philosophy/works.json` |
| freier griechischer Text | `assets/philosophy/aristotle_physics/ross/book-N.json` |
| Formenindex | `assets/philosophy/aristotle_physics/forms.json` |
| Modelle | `lib/models/philosophy/` (`reading_work.dart`, `reading_text.dart`) |
| Dienste | `lib/services/philosophy/` |
| Oberfläche | `lib/screens/philosophy/reading/` |
| Werkzeuge | `tool/philosophy/` |
| Tests | `test/philosophy/` |

Einstieg: `PhilosophyHomeScreen.areas` → `ReadingWorkScreen(workId:
"aristotle.physics")`. Alle Ansichten eines Werks teilen eine
`ReadingSession` (gewählte Ausgabe, geladener Text, Nutzerdaten,
Wortanalyse).

Reiter der Werkseite erscheinen nur, wenn die gewählte Ausgabe Inhalt dafür
hat: Übersicht (immer), Kommentar (Anmerkungen/Textkritik), Ausgabe
(Vorwort, Einleitung, Glossar, Siglen, Literatur), Seminar (sobald ein
Seminarplan hinterlegt ist), Meine Stellen, Lernen.

## Ausgaben und Rechte

Werk und Ausgabe sind getrennt (`ReadingWork` / `ReadingEdition`). Zwei
Arten:

* **bundled** – liegt in `assets/`, nur für freie Texte. Derzeit Ross,
  *Aristotelis Physica* (Oxford 1950), Digitalisierung von First1KGreek
  (CC BY-SA 4.0). Die Digitalisierung hat vereinzelt Lesefehler (z. B.
  „Ἐπειθὴ“ in 184a10); sie werden nicht stillschweigend korrigiert. Sie
  nennt nur jede fünfte Bekker-Zeile, die Zeilen dazwischen sind geschätzt
  (Abschnitte deshalb als „ungefähr“ markiert).
* **private** – urheberrechtlich geschützt, **nie im Repository** (das
  Repository ist öffentlich). Heinemann, *Aristoteles, Physikvorlesung*
  Teilband 1 (Meiner 2021). Wer die Ausgabe besitzt, erzeugt daraus eine
  Lesedatei und importiert sie in der App (Werkseite → Ausgaben →
  „Lesedatei importieren“). Gespeichert wird sie

  * mit Konto in `users/{uid}/private_texts/{edition}__{teil}` (je Teil
    ein Dokument: `meta`, `front`, `book-N`, jedes unter der
    Firestore-Grenze von 1 MiB) plus lokale Kopie,
  * als Gast nur auf dem Gerät (Datei bzw. `localStorage`; reicht der Platz
    nicht, nur für die laufende Sitzung).

  Nur der Nutzer selbst darf lesen und schreiben (`firestore.rules`,
  `isUserCollection`); beim Löschen des Kontos wird die Sammlung entfernt
  (`AccountDeletionService.userCollections`). Auf dem Handy gibt es keinen
  Dateiwähler: dort einmal im Web mit demselben Konto importieren oder die
  Datei aus der Zwischenablage einfügen.

Eigene Texte der App (Werkbeschreibung, Hinweise) sind als solche erkennbar;
Inhalte der Ausgabe werden immer mit Ausgabe und Seite angezeigt.

### Lesedatei erzeugen

```
python3 -I tool/philosophy/import_heinemann_physics.py EBOOK.txt heinemann.json
```

Eingabe ist die Textebene des E-Books (ISBN 978-3-7873-3801-6). Das Skript
liest griechischen Text, Übersetzung, textkritische Fußnoten, Fußnoten zur
Übersetzung, Anmerkungen des Herausgebers, Vorwort, Einleitung (mit
Fußnoten), Glossar, Siglen und Literatur. Es erfindet nichts: Was es nicht
sicher zuordnen kann, markiert es als ungefähr (`fit: "approx"`) statt zu
raten. Bekannte Eigenheiten:

* Die Übersetzung trägt eigene Zeilenmarken (`a12`); daraus entstehen
  Abschnitte, die per dynamischer Programmierung den griechischen Sätzen
  zugeordnet werden (Toleranz ±1 Zeile). Rund 18 % der Abschnitte sind
  ungefähr zugeordnet; sie zeigen im Leser „≈“ bzw. „Zuordnung ungefähr“.
* Heinemanns Sonderzeichen für das Zahlwort *en/enes* (privater
  Unicode-Bereich U+F644) wird entfernt, weil keine Schrift es darstellt.
* Seitenzahlen der Textkritik beziehen sich auf Druckzeilen und werden in
  Bekker-Stellen umgerechnet; nicht eindeutige Fälle sind als ungefähr
  markiert.

## Kennungen

* Stelle: Bekker-Zählung `184a10` (`BekkerRef`), Bereich `184a10–16`.
* Satz: Stelle des Satzanfangs, bei mehreren Sätzen in einer Zeile mit
  Zähler (`210b30.2`). Eindeutig je Buch (Test).
* Abschnitt (`ReadingUnit`): Kennung des ersten Satzes. Ein Abschnitt
  bündelt griechische Sätze und deutsche Segmente, die zusammengehören –
  Original und Übersetzung werden nicht künstlich 1:1 gepaart.
* Kapitel: `Buch.Kapitel` (`1.7`).
* Anmerkungen: `n1.12`, Textkritik `tc1.3`, Fußnoten `t1.2`.

Nutzerdaten hängen an Satzkennungen. Fehlt eine Kennung in einer anderen
Ausgabe, löst `ReadingText.resolveSentence` sie über die Bekker-Stelle auf
(nächster Satz davor). So bleiben Notizen beim Wechsel der Ausgabe
erhalten.

## Verknüpfungen

* Satz ↔ Anmerkungen: viele-zu-viele über Bekker-Bereiche
  (`notesForSentence`: alle Anmerkungen des Buchs, deren Bereich den Satz
  berührt; Fußnoten zur Übersetzung am ersten Satz ihres Abschnitts).
* Anmerkung → Einleitung (`Einl. 2.3`), Anmerkung → Anmerkung
  (`Anm. zu 184a21`), Glossar → Einleitung/Anmerkung, Einleitung → Text
  (Zitate wie „Phys. I 1, 184a14–16“, `introCitations`).

## Wortanalyse

`GreekWordAnalyzer` nutzt den Formenindex `forms.json` (erzeugt mit
`dart run tool/philosophy/build_form_index.dart [lesedatei.json]`) aus den
Korpora des Klausurerstellers (NT/LXX) und das deutsche Lexikon
`assets/greek_corpus/lexicon.json`. Bestimmungen werden immer als „möglich“
angezeigt, nie als gesichert – sie sind nicht im Kontext der Physik geprüft.
Formen ohne Eintrag bleiben unbestimmt. Der Index enthält nur Wortformen
und Bestimmungen, keinen Text. Abdeckung: etwa 84 % der Wortvorkommen im
Text, 42 % der verschiedenen Formen (aristotelischer Fachwortschatz fehlt
in NT/LXX). Glossareinträge der Ausgabe werden über Heinemanns Umschrift
(archê, hylê, têi) zugeordnet.

## Nutzerdaten

Dokument `quiz_settings/philosophy_reading` (Konto) bzw. lokal (Gast);
jeder Eintrag beginnt mit der Werkkennung (`aristotle.physics|…`), alle
Änderungen sind Merges einzelner Einträge:

* `settings`: Modus, Ausgabe, Schriftgröße
* `positions`: letzte Stelle (Leseposition)
* `marks`: Lesezeichen und Notizen; Anker `s:<Satz>`, `u:<Abschnitt>`,
  `w:<Satz>:<Wortnummer>:<Form>`
* `words`: Wortliste
* `read`: gelesene Kapitel (Lesefortschritt)

Lernstände der Wiederholung liegen getrennt in
`quiz_settings/philosophy_review` (`ReadingReviewStore`,
`SpacedRepetition`) und lassen sich über „Fortschritt zurücksetzen“
(`ProgressArea.philosophyReading`) löschen, ohne Notizen anzutasten.
Unbekannte oder beschädigte Einträge werden beim Laden übersprungen.

Ausfuhr („Meine Stellen“ → Ausfuhr): Markdown mit Stellenangaben, eigenen
Notizen und der Wortliste – ohne Text der Ausgabe.

## Seminar und weitere Materialien

Noch nicht vorhanden. Sobald der Seminarplan vorliegt: Datei anlegen und im
Werkverzeichnis unter `seminarAsset` eintragen:

```json
{"sessions": [
  {"id": "s01", "date": "2026-10-23", "title": "…",
   "passages": ["184a10–185a20"], "materials": ["…"], "tasks": ["…"]}
]}
```

Dann erscheint der Reiter „Seminar“; Stellen sind anklickbar. Kommentare
und Sekundärliteratur kommen – je nach Rechtelage – als weitere private
Ausgabe oder als eigene Anmerkungsdatei mit Quellenangabe hinzu.

## Weiteres Werk hinzufügen

1. Eintrag in `assets/philosophy/works.json` (Bücher, Ausgaben, Zählung).
2. Freien Text im Format `theologie.app/philosophy-book` unter
   `assets/philosophy/<werk>/…` ablegen (Ordner in `pubspec.yaml`), bzw.
   für geschützte Ausgaben ein Importwerkzeug, das das Format
   `theologie.app/philosophy-edition` schreibt.
3. Optional Formenindex erzeugen.
4. Eintrag in `PhilosophyHomeScreen.areas`.

Die Bekker-Zählung ist derzeit fest; ein Werk mit anderer Zählung braucht
eine eigene Stellenklasse.
