# Bibellesepläne

Ein Leseplan ist eine JSON-Datei mit Stellenangaben – ohne Bibeltext und
unabhängig von einer Bibelausgabe. Integrierte Pläne
(`assets/reading_plans/`) und eigene, importierte Pläne verwenden dasselbe
Format; gelesen und geprüft wird es von `ReadingPlanCodec`
(`lib/services/bible/reading_plan_codec.dart`).

## Format (Version 1)

```json
{
  "format": "theologie.app/reading-plan",
  "formatVersion": 1,
  "id": "mein-plan",
  "name": "Markus in einer Woche",
  "description": "Das Markusevangelium mit einem Psalm am Tag.",
  "language": "de",
  "category": "gospels",
  "difficulty": "easy",
  "source": { "name": "Eigener Plan", "url": "https://example.org" },
  "license": "CC0 1.0",
  "days": [
    ["MRK 1-2", "PSA 1"],
    { "title": "Gleichnisse", "readings": ["MRK 3-4", "PSA 2"] },
    ["MRK 5:1-20", "JOL"]
  ]
}
```

| Feld | Pflicht | Bedeutung |
|---|---|---|
| `id` | ja | Stabile Kennung: 2–63 Zeichen aus `a–z`, `0–9`, `.`, `-`, `_`. An ihr hängt der gespeicherte Fortschritt; ein Plan mit vorhandener Kennung wird nicht erneut importiert. |
| `name` | ja | Anzeigename, höchstens 100 Zeichen. |
| `days` | ja | Die Tage in ihrer Reihenfolge (höchstens 1500). Ein Tag ist eine Liste von Lesungen oder ein Objekt mit `readings` und optionalem `title`. Je Tag 1–30 Lesungen. |
| `description` | nein | Kurze Beschreibung, höchstens 1000 Zeichen. |
| `language` | nein | Sprache von Name und Beschreibung (`de`, `en`, …); Standard `de`. |
| `category` | nein | `whole-bible`, `old-testament`, `new-testament`, `gospels`, `psalms`, `topical`, `custom` oder ein eigener Text. |
| `difficulty` | nein | `easy`, `moderate`, `demanding`, `intensive`, `extreme`. |
| `source` | nein | Herkunft des Plans: Text oder Objekt mit `name`, `url`, `note`. |
| `license` | nein | Lizenz bzw. Nutzungsbedingungen des Plans. |
| `format`, `formatVersion` | nein | Falls angegeben, müssen sie den Werten oben entsprechen. |

Die Dauer ergibt sich aus der Zahl der Tage. Den täglichen Umfang
(Kapitel, ungefähre Lesezeit) berechnet die App aus den Stellen; sehr
intensive Pläne kennzeichnet sie unabhängig von `difficulty`.

### Stellenangaben

Bücher tragen die USFM-Kennung, die auch der Reader verwendet (`GEN`,
`PSA`, `MRK`, `1CO`, … – siehe `BibleBooks`).

| Schreibweise | Bedeutung |
|---|---|
| `JOL` | das ganze Buch |
| `GEN 1` | ein Kapitel |
| `GEN 1-3` | Kapitel 1 bis 3 |
| `JHN 3:16` | ein Vers |
| `JHN 3:16-21` | Verse innerhalb eines Kapitels |
| `GEN 1:1-2:3` | Verse über Kapitelgrenzen |

Beim Import wird jede Stelle geprüft: Das Buch muss bekannt sein, Kapitel
und Vers müssen in mindestens einer Bibelausgabe der App vorkommen. Fehler
nennt die App mit Tag und Stelle.

Die Ausgaben zählen nicht überall gleich. Joel hat je nach Ausgabe 3 oder 4
Kapitel, Maleachi 4 oder 3; die Psalmen sind in Septuaginta und Vulgata
anders nummeriert. Ein Plan, der in jeder Ausgabe funktionieren soll, nennt
Joel und Maleachi deshalb als ganzes Buch und vermeidet Versangaben im
Alten Testament.

## Verhältnis zu anderen Formaten

Das Format ist bewusst klein. Es lässt sich verlustfrei in das vorgeschlagene
[bible-reading-plan-schema](https://github.com/BibleReadingPlans/bible-reading-plan-schema)
überführen: `name` → `title`, Zahl der Tage → `timespan`, ein Tag →
`readingDays[]`, eine Lesung → `passages[]` mit `begin`/`end` aus Buch,
Kapitel und Vers. Listen von Stellen je Tag verwendet auch
[khornberg/readingplans](https://github.com/khornberg/readingplans)
(`data2`), dort mit englischen Buchnamen statt Kennungen.

## Integrierte Pläne

| Kennung | Dauer | Aufbau |
|---|---|---|
| `bible-1-year` | 365 Tage | AT fortlaufend, daneben NT im Wechsel mit den Psalmen, zum Schluss Sprüche |
| `bible-6-months` | 180 Tage | wie der Jahresplan |
| `bible-90-days` | 90 Tage | ganze Bibel fortlaufend (sehr intensiv) |
| `nt-90-days` | 90 Tage | Neues Testament fortlaufend |
| `gospels-30-days` | 30 Tage | die vier Evangelien |
| `bible-marathon-30-days` | 30 Tage | ganze Bibel fortlaufend (extrem) |
| `course-bibelkunde-at-wise-2026` | 14 Sitzungen | zur Übung Bibelkunde AT (siehe unten), im Bereich Bibelkunde unter „Leseplan zur Übung“; einmal begonnen auch auf der Startseite der Bibel und unter „Meine Pläne“ |

Die Pläne sind eigene Einteilungen: `tool/reading_plans/build_plans.py`
verteilt die Kapitel anhand der Verszahlen aus
`assets/bible/translations.json` gleichmäßig auf die Tage. Es wurde kein
fremder Leseplan übernommen. `test/bible_reading_test.dart` prüft, dass die
Ganzbibel-Pläne jedes Kapitel der 66 Bücher genau einmal enthalten und dass
sich jede Lesung in jeder Ausgabe aufschlagen lässt, die das Buch enthält.

```
python tool/reading_plans/build_plans.py
```

## Lesepläne zu Lehrveranstaltungen

Ein Plan zu einer Lehrveranstaltung richtet sich nicht nach fortlaufenden
Plantagen, sondern nach Sitzungsterminen: Bis zu jeder Sitzung sind ihre
Texte gelesen. Die Dateien liegen ebenfalls unter `assets/reading_plans/`
und stehen in `index.json` unter `coursePlans`; ihr Dateiname beginnt mit
`course-`. Angezeigt werden sie nur freigeschalteten Konten (siehe [lecture-materials.md](lecture-materials.md));
gelesen werden sie von
`CourseReadingPlan.fromJson` (`lib/models/bible/course_reading_plan.dart`),
geplant von `CourseSchedule` (`lib/services/bible/course_reading_schedule.dart`).

```json
{
  "format": "theologie.app/course-reading-plan",
  "formatVersion": 1,
  "id": "course-bibelkunde-at-wise-2026",
  "name": "Lesen zur Übung Bibelkunde AT",
  "course": "Bibelkunde Altes Testament (Übung)",
  "source": "Sitzung 1, Folie 5 und 7",
  "sessions": [
    {
      "id": "bk.02", "number": 2, "date": "2026-10-29", "topic": "Genesis",
      "unit": "bk.02", "readingSource": "slides", "readings": ["GEN"],
      "note": "Folie 7: „Gen (ganz)“"
    }
  ],
  "milestones": [
    { "start": "2026-11-13", "end": "2026-11-16", "title": "1. Zwischentest" }
  ]
}
```

| Feld | Bedeutung |
|---|---|
| `sessions[].id` | Stabile Kennung; eigene Änderungen hängen an ihr. Bei der Bibelkunde = ID der Sitzung im Bereich Altes Testament (`bk.NN`). |
| `sessions[].date` | Sitzungstermin (`yyyy-MM-dd`), spätester Abschlusstermin. |
| `sessions[].readings` | Stellen in der Schreibweise oben; leer nur bei `readingSource: "none"`. |
| `sessions[].readingSource` | `slides` (Stellen stehen in den Folien), `provisional` (nur das Thema ist bekannt, Umfang vorläufig angenommen), `none` (keine Lektüre). |
| `sessions[].unit` | Optional: Sitzung im Bereich Altes Testament, deren Folien verlinkt werden. |
| `sessions[].note` | Fundstelle bzw. Begründung, wird angezeigt. |
| `milestones` | Termine ohne Lektüre (Zwischentests, Prüfungszeitraum). |

### Planung

* Jede Lesung wird in **Lesestücke** zerlegt: ganze Kapitel, Versbereiche
  nur innerhalb eines Kapitels (`NUM 10:11-12`). Ein gelesenes Kapitel deckt
  seine Versbereiche ab.
* Der **Lesezeitraum** einer Sitzung beginnt am Tag nach dem geplanten
  Abschluss der vorigen (bzw. am Starttag des Plans) und endet am
  **Vorabend** der Sitzung – abschaltbar, dann am Sitzungstag. Am
  Sitzungstag selbst ist der Sitzungstag spätester Termin.
* Das Offene wird nach **Versen** gleichmäßig auf die verbleibenden Tage
  verteilt (ein Kapitel kommt auf den Tag, in den die Mitte seines Umfangs
  fällt). Jeden Tag wird neu verteilt; was heute abgehakt wurde, bleibt im
  heutigen Pensum stehen. Lesezeit: 9 Verse je Minute
  (`ReadingPlanExtent.versesPerMinute`).
* **Im Plan / Rückstand**: Vergleich mit einer gleichmäßigen Verteilung über
  den ganzen Zeitraum bis gestern. **Knapp** ab 45 Minuten am Tag, **sehr
  knapp** ab 75 Minuten – die Aufteilung wird trotzdem angezeigt.
* Ist eine Sitzung vorbei, steht Offenes unter „Aus vergangenen Sitzungen
  offen“ und wird nicht in den Tagesplan der nächsten Sitzung gerechnet.
* Plant eine spätere Sitzung einen schon eingeplanten Text erneut, ist er
  dort nur **gezielte Wiederholung** (optional, eigener Haken) und zählt
  nicht noch einmal.

### Umfang: nur benötigte Kapitel oder ganze Bücher

Schalter „Ganze Bücher lesen“ im Plan (`wholeBooks` im Fortschritt,
`CourseReadingProgress.withWholeBooks`), jederzeit umschaltbar:

* **Aus (Standard)**: nur die Stellen der Sitzung.
* **An**: jede Sitzung liest die Bücher, die sie behandelt, ganz – in
  Buch- und Kapitelreihenfolge. Eigene Kapitel bleiben, Versbereiche werden
  zum ganzen Kapitel; die übrigen Kapitel kommen als **ergänzend** markierte
  Lesestücke (`ScheduledPiece.extra`) dazu und werden über denselben
  Lesezeitraum gleichmäßig verteilt. Ein Kapitel, das eine spätere Sitzung
  selbst nennt, bleibt dort; was eine frühere Sitzung schon ergänzt hat,
  kommt nicht noch einmal.
* Gilt nur für Sitzungen **ab dem Tag des Einschaltens**
  (`wholeBooksSince`); vergangene Sitzungen werden nicht nachträglich
  aufgefüllt, damit kein Rückstand entsteht.
* Erledigtes bleibt in beiden Richtungen erhalten, weil je Lesestück
  gespeichert wird; beim Umschalten meldet die App, wie viele Kapitel
  ergänzt bzw. weggelassen werden.

### Auswahl und Anzeige

Ein begonnener Plan zur Übung erscheint wie die übrigen Pläne auf der
Startseite der Bibel (mit Tagespensum) und unter „Lesepläne → Meine Pläne“
(`CoursePlanCard`). „Pausieren“ (`paused`) nimmt ihn aus diesen Listen,
ohne Fortschritt zu löschen; „Fortsetzen“ holt ihn zurück. Gelesen wird im
Bibelreader mit denselben Knöpfen wie bei anderen Plänen: Der Status
„Lesen abgeschlossen“ gilt immer für das **angezeigte** Kapitel. Blättert
man mit den Pfeilen aus den Stellen des Tages hinaus, zeigt der Reader
„außerhalb des Plans“ und bietet nur das freie Markieren an.

### Fortschritt und Änderungen

Gespeichert im Dokument `course_<Plan>` der Bibellese-Daten
(`users/{uid}/bible_reading`, Gäste lokal): erledigte Lesestücke mit Datum,
Wiederholungen, die Einstellung „Vorabend“ und **eigene Änderungen** je
Sitzung (Termin, Stellen). Weil je Lesestück und nicht je Plantag
gespeichert wird, gehen bei neuen Terminen oder Stellen keine erledigten
Texte verloren; nur das Offene wird neu verteilt.

Eine eigene Änderung merkt sich die Empfehlung, auf der sie beruht. Ändert
eine neue Plandatei die Empfehlung dieser Sitzung, gilt die eigene Änderung
weiter, und die App zeigt „Empfehlung aktualisiert“ mit den Wahlmöglichkeiten
„Empfehlung übernehmen“ oder „Meine Änderung behalten“. Ohne eigene Änderung
gilt die neue Empfehlung sofort.

### Neue Folien oder Termine

Termine oder Stellen in der Plandatei ändern (`readingSource` auf `slides`
setzen, sobald die Stellen aus den Folien bzw. dem Bibelleseplan der
Veranstaltung stammen). IDs der Sitzungen nie ändern. Die Tests in
`test/course_reading_plan_test.dart` gleichen Termine und Themen mit der
Abschrift des Seminarplans (Folie 5 von `bk.01`) ab.

## Eigene Pläne

In der App unter „Bibel → Lesepläne → +“:

* **Eigenen Plan erstellen** – ein Tag je Zeile, Lesungen mit Semikolon
  getrennt (`Mk 1-2; Ps 1`). Erkannt werden dieselben Buchnamen wie bei der
  Stelleneingabe des Readers.
* **Plan aus Datei importieren** – JSON-Datei wählen (im Browser) oder den
  Inhalt einfügen.

Jeder Plan lässt sich im selben Format exportieren (Menü des Plans). Eigene
Pläne liegen beim Nutzer (Konto bzw. lokal im Gastmodus), nicht in der App.

## Rechte

Ein Leseplan enthält nur Stellenangaben und Metadaten, keinen Bibeltext;
die Lizenz der gelesenen Ausgabe bleibt davon unberührt
(`docs/bible-sources.md`). Die Auswahl und Anordnung eines veröffentlichten
Plans kann aber selbst geschützt sein. Wer einen fremden Plan importiert
oder weitergibt, braucht dafür die Erlaubnis des Urhebers und sollte
`source` und `license` ausfüllen. Ins Repository gehören nur eigene oder
ausdrücklich frei lizenzierte Pläne.
