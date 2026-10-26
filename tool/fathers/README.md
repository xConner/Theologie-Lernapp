# tool/fathers – Daten für „Kirchenväter & Schriften“

Erzeugt `assets/fathers/`. Nicht Teil der App. Hintergrund, Rechte und
Quellenmatrix: `docs/church-fathers.md`.

Benötigt Python 3.10+ mit `beautifulsoup4` und `lxml`.

## Skripte

| Skript | Aufgabe |
|---|---|
| `crossrefs.py <cross_references.txt>` | OpenBible-Verweise → `assets/fathers/xrefs/<BUCH>.json`, Bericht `reports/crossrefs.json` |
| `import_bkv.py <Rohdaten>` | BKV-Abruf → Katalog, Texte, Zuordnungen, Manifest; Bericht `reports/bkv_import.json` |
| `import_bkv.py --ohne-bkv` | nur die redaktionell gepflegten Autoren (ohne BKV-Abruf) |
| `import_bkv.py [<Rohdaten>] --epub <Ordner>` | dazu die EPUB-Exporte der BKV in `<Ordner>` (siehe unten) |
| `… --pdf <Ordner>` | dazu Texte aus PDF-Drucken nach `curation/pdf_texts.json` (`pdf_text.py`) |
| `… --open <Ordner>` | dazu Texte aus freien Sammlungen nach `curation/open_texts.json` (`open_texts.py`, siehe unten) |
| `import_bkv.py <Rohdaten> --check` | schreibt nichts; Fehler, wenn Kennungen wegfallen würden |
| `test_import_bkv.py` | prüft den Import an erfundenen Seiten in `testdata/bkv/` |
| `test_open_texts.py` | prüft die Leser der freien Sammlungen an `testdata/open/` |

`crossrefs.py` vor `import_bkv.py` ausführen (das Manifest übernimmt die
Bücherliste und Lizenzangaben aus `reports/crossrefs.json`). Beide Skripte
schreiben eine Datei nur, wenn sich ihr Inhalt ändert.

Kuratierung in `curation/`:

- `later_authors.json` – Autoren und Werke außerhalb der BKV
  (Mittelalter, Reformation, lutherische Orthodoxie), `appLink` auf
  vorhandene Bekenntnistexte.
- `bkv_authors.json` – Einordnung der BKV-Autoren (Gruppe, Tradition,
  Sprachen), Schlüssel = Name wie in der BKV.
- `rights.json` – Rechte je Fassung mit Begründung; `default` für BKV-Fassungen, die nicht nach GND gemeinfrei sind (Nutzungserlaubnis laut Conner, 24.10.2026).
- `book_aliases.json` (eine Ebene höher) – historische Buchabkürzungen →
  USFM; `?KINGS1/2` für „1/2 Kön.“, deren Zählung (Vulgata oder Luther) der
  Import je Fassung bestimmt.

## EPUB-Exporte der BKV

Auf der Fassungsseite der BKV von Hand „EPUB“ herunterladen (KI-Agenten
dürfen das laut `robots.txt` nicht) und alle Dateien in einen Ordner legen;
Dateinamen bleiben, wie die BKV sie vergibt (`<Titel>_deutsch_<Nr>.epub`).
`bkv_epub.py` liest Werk, Autor, Schlüssel (CPL/CPG) und Bibliographie aus
`ch001.xhtml` und die Gliederung aus den pandoc-Abschnitten. Kennungen:
Werk `bkv.<cpl-123>`, Fassung `bkv.v<Nr>` (Nummer der BKV-Fassung aus den
Seitenlinks). Rechte aus `curation/rights.json` (Einzelangabe, sonst
`default`).

    python3 tool/fathers/import_bkv.py --epub ~/bkv-epub

Der Import ersetzt den ganzen Katalog: bei jedem Lauf alle Quellen
mitgeben (Rohdaten, `--epub`, `--pdf`, `--open`). Ein EPUB eines Werks, das
schon aus einer freien Sammlung kommt (gleiche Clavis oder gleicher
Originaltitel), übernimmt dessen Kennung; so entsteht kein zweites Werk.

## Freie Sammlungen (`--open`)

`curation/open_texts.json` nennt je Fassung Sammlung, Dateien, Werk (neu oder
Kennung eines vorhandenen Werks), Rechte und Gliederung. Der Ordner enthält
Klone der Sammlungen unter den Namen aus `sources.*.dir`; die verwendeten
Commits stehen ebenfalls dort:

    mkdir open && cd open
    git clone https://github.com/HistoricalChristianFaith/Writings-Database hcf
    git clone https://github.com/OpenGreekAndLatin/csel-dev
    git clone https://github.com/PerseusDL/canonical-greekLit
    python3 tool/fathers/import_bkv.py --epub … --pdf … --open open

- **hcf** (englische Übersetzungen, HTML): nur die in `open_texts.json`
  genannten Dateien; Übertragungen „using ChatGPT“ der Sammlung bricht
  `read_hcf` ab. Griechisch in Beta-Code wird in griechische Schrift
  umgesetzt. `passageBook` liest bei Homilienreihen den ausgelegten
  Abschnitt am Anfang jeder Homilie (Zuordnung „Auslegung des Abschnitts“).
- **csel** (lateinische Originale, EpiDoc): je Buch Gruppen von Paragraphen;
  Randangaben und textkritischer Apparat entfallen, Bibelstellen aus den
  Fußnoten der Seite bleiben als Anmerkungen (Absatz ungefähr, Sicherheit
  „mittel“). Die Texterkennung ist maschinell korrigiert; Restfehler bleiben.
- **perseus** (griechische Originale, EpiDoc): ohne Apparat.

Rechte: `publicDomain` (Ausgabe gemeinfrei) oder `openLicense`
(Digitalisat unter CC BY-SA; Namensnennung in der Fassung und im Manifest).

## Abruf der BKV-Rohdaten (Abschnittsseiten)

Nur von einem Rechner, der bkv.unifr.ch erreicht, und nur so, wie
`robots.txt` es erlaubt: keine Exporte unter `/files/`, keine Scans, höchstens
eine Seite alle 10 Sekunden. Der Rohdaten-Ordner enthält:

- die Werkübersicht `/de/works` als HTML,
- je Fassung die Fassungsseite als `<werk>__<fassung>.html`
  (z. B. `cpl-278__<slug>.html`),
- je Abschnitt `bkv-div/<werk>__<fassung>/<division_id>.html`,
- `translators.json`: `{"translators": [{"name": …, "candidates":
  [{"gndIdentifier": …, "dateOfDeath": …}]}]}` aus einer GND-Abfrage
  (lobid.org) je Übersetzername.

Abschnittsseiten werden nur für Fassungen abgerufen, deren Übersetzer
vorab als gemeinfrei bestimmt sind; der Import prüft das erneut.

## Ausgabeformat (`assets/fathers/`)

| Datei | Inhalt | geladen |
|---|---|---|
| `manifest.json` | vorhandene Dateien je Ordner, Zählungen, Quellen | beim ersten Zugriff |
| `library.json` | `authors`, `works` mit `versions` (Übersetzer, Ausgabe, Quelle, Rechte, Verfügbarkeit) | beim Öffnen der Bibliothek |
| `links/<BUCH>.json` | Zuordnungen zu Stellen eines Bibelbuchs | beim Antippen eines Verses dieses Buchs |
| `xrefs/<BUCH>.json` | verwandte Stellen: `books` (Liste) und `refs` `"k:v"` → `[Buch-Index, k, v, End-k, End-v, Stimmen]` | in der Versdetailansicht |
| `texts/<fassung>.toc.json` | Inhaltsverzeichnis: `n`, `t`, `path`, `c` (Textdatei), `ref` (Seiten), `url` | beim Öffnen des Werks |
| `texts/<fassung>.<c>.json` | Abschnitte (`n`, `p` Absätze, `notes`), je Datei etwa 150 KB | beim Lesen eines Abschnitts |
| `texts/<fassung>.links.json` | alle Zuordnungen der Fassung (mit Buch `b`) | Register „Bibelstellen“ |

Zuordnung (kompakt): `id`, `v` Fassung, `w` Werk, `a` Autor, `s` Abschnitt,
`p` [erster, letzter Absatz], `r` [k, v] oder [k, v, End-k, End-v], `k` Art,
`m` Herkunft, `c` Sicherheit, `cited` Angabe der Ausgabe, `note`.

## Kennungen

- Werk `bkv.<werk-slug>`, Fassung `bkv.<fassungs-slug>` (Slugs der BKV),
  redaktionelle Werke `<autor>.<werk>`.
- Zuordnung: SHA-1 (12 Zeichen) aus Fassung, Abschnitt, Absatz, Stelle und
  Art – bleibt bei erneutem Import gleich.
- Doppelte Kennungen brechen den Import ab; doppelte Zuordnungen werden
  verworfen und im Bericht aufgeführt. Der Bericht nennt hinzugekommene und
  weggefallene Kennungen gegenüber dem letzten Import.

Die Prüfung der ausgelieferten Daten gegen die App (Bücher, Dateien, Absätze,
Rechte, Bekenntnis-Verweise) übernimmt `test/fathers/fathers_data_test.dart`.
