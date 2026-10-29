# tool/apocrypha

Erzeugt `assets/apocrypha/` für den Bereich „Apokryphen & außerkanonische
Schriften“ (`docs/apocrypha.md`).

    python3 -I tool/apocrypha/build_apocrypha.py --src <Ordner mit den Klonen> [--check]

`--check` prüft nur und schreibt nichts.

## Eingaben

- `curation/works_a.json` (Deuterokanonen, Psalmen Salomos),
  `works_b.json` (Evangelien, Apostolische Väter, Kirchenordnungen),
  `works_c.json` (Apokalypsen, Pseudepigraphen, Apostelakten, Nag Hammadi):
  ein Eintrag je Werk, redaktionell gepflegt.
- `curation/sources.py`: Quellen (`SOURCES`, Repository und Commit),
  Ordnernamen der Klone (`DIRS`) und alle Fassungen (`versions()`), je mit
  Rechten, Lizenz, Nachweis, Umfang und Leser.
- `readers.py`: Leser für die Quellformate (scrollmapper-JSON,
  eBible-vref, Open Apostolic Fathers, CTS-TEI von First1KGreek, Coptic
  SCRIPTORIUM, Beta maṣāḥǝft, HTML der HistoricalChristianFaith-Sammlung,
  Bibel-Assets der App).

Die Klone (blobless, nur benötigte Dateien ausgecheckt) unter `--src`:

| Schlüssel | Repository |
|---|---|
| scrollmapper | scrollmapper/bible_databases (Menge, KJV) |
| ebible | BibleNLP/ebible (Brenton englisch) |
| openaf | jtauber/apostolic-fathers (Lake) |
| first1k | OpenGreekAndLatin/First1KGreek |
| hcf | HistoricalChristianFaith/Writings-Database (ANF) |
| coptic | CopticScriptorium/corpora |
| betamasaheft | BetaMasaheft/Works |

Commits stehen in `SOURCES` und im Katalog.

## Ausgabe

    assets/apocrypha/catalog.json             Kategorien, Quellen, Werke mit Fassungen (ohne Text)
    assets/apocrypha/texts/<fassung>.toc.json Einheiten: id, label, path, title, c (Datei), n (Absätze)
                                              bzw. src [Ausgabe, Buch, Kapitel, erster, letzter Vers]
    assets/apocrypha/texts/<fassung>.<c>.json {"units": [{"id", "b": [[Nummer, Text]], "notes": [...]}]}
    tool/apocrypha/reports/import.json        Zählungen

Einheiten-IDs sind in allen Fassungen eines Werks gleich (Kapitelnummer,
`vis1`/`mand1`/`sim1` bei Hermas, `eph`… bei Ignatius, `asarja`/`susanna`/`bel`
bei den Danielzusätzen), damit der Leser sie vergleichen kann.

## Prüfungen

Das Skript bricht ab bei unbekannten Kategorien und Werten, doppelten
Kennungen, Text ohne geklärte Rechte, Verweisen ohne Link, leeren Einheiten,
Anmerkungszeichen ohne Anmerkung und maschinellen Übertragungen.
`test/apocrypha/apocrypha_data_test.dart` prüft die erzeugten Dateien.
