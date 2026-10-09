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

Die Pläne sind eigene Einteilungen: `tool/reading_plans/build_plans.py`
verteilt die Kapitel anhand der Verszahlen aus
`assets/bible/translations.json` gleichmäßig auf die Tage. Es wurde kein
fremder Leseplan übernommen. `test/bible_reading_test.dart` prüft, dass die
Ganzbibel-Pläne jedes Kapitel der 66 Bücher genau einmal enthalten und dass
sich jede Lesung in jeder Ausgabe aufschlagen lässt, die das Buch enthält.

```
python tool/reading_plans/build_plans.py
```

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
