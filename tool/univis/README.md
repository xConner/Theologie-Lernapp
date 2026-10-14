# UnivIS-Prototyp (Machbarkeitsprüfung)

Werkzeuge zur Prüfung der UnivIS-PRG-Schnittstelle. Nicht Teil der App.
Ergebnisse und Einordnung: `docs/univis-integration-feasibility.md`.

Die eigentliche Katalogverarbeitung (Datenmodell, UnivIS-Adapter,
Terminauflösung, Dubletten, Überschneidungen) liegt in `api/_lib/catalog/`;
`univis_parser.mjs` hier ist der ursprüngliche Prototyp für das
Element-Inventar.

| Datei | Zweck |
|---|---|
| `univis_parser.mjs` | XML (`show=xml`) → normalisierte Veranstaltungen, Qualitätskennzahlen, Element-Inventar |
| `univis_probe.mjs` | genau ein Abruf je Aufruf (oder `--file` offline), Ausgabe als JSON; `--redact` schwärzt Lehrpersonen und Freitexte |
| `univis_find_department.mjs` | Organisationsnummer (`orgnr`) einer Einrichtung aus UnivIS ermitteln, ohne Personendaten |
| `univis_check_schedule.mjs` | Terminangaben gegen die Klartextansicht prüfen (Ausgabe nur aus einer festen Wortliste) |
| `catalog_stats.mjs` | `api/_lib/catalog` auf einer echten Antwort ausführen, nur Kennzahlen |
| `univis_http.mjs` | gemeinsamer Abruf (Zeitlimit, User-Agent, Zeichensatz) |
| `../../.github/workflows/univis-probe.yml` | Live-Test auf GitHub-Runnern (die Claude-Cloud-Umgebung erreicht UnivIS nicht) |
| `univis_parser.test.mjs` | Tests des Parsers ohne Netzwerk |
| `fixtures/synthetic_lectures.xml` | **synthetische** Beispieldaten (erfundene Namen), keine echte UnivIS-Antwort |

Voraussetzung: Node 22 und `npm ci` im Repository (nutzt das vorhandene
`cheerio`).

```sh
node --test tool/univis/univis_parser.test.mjs

# Live (von einem Rechner mit Zugriff auf univis.uni-kiel.de):
node tool/univis/univis_find_department.mjs --name Theologische
node tool/univis/univis_probe.mjs --sem 2026w --param department=010000000 --sample 2
node tool/univis/univis_check_schedule.mjs --sem 2026w --number 010076
node tool/univis/catalog_stats.mjs --sem 2026w --org 010000000
```

Stand 14.10.2026 (live, WS 2026/27, Theologische Fakultät `010000000`):
150 Veranstaltungen (89 nach Dublettenprüfung), 1149 aufgelöste Termine,
alle Verweise auflösbar, Wochentag `w1 4` = Donnerstag. Einzelheiten:
Bericht, Abschnitte 3, 4 und 11.

Hinweise:

* Organisationsnummern statt Namen verwenden (`department=<orgnr>`);
  Namensfilter liefern HTML, Umlaute in Parametern finden nichts.
* `number=` ist die sechsstellige Veranstaltungsnummer.
* `time_description` ist in Kiel ein Freitext (Anmeldehinweise, teils mit
  E-Mail-Adressen) – nie ungeschwärzt in öffentliche Protokolle schreiben.
  Der Workflow gibt nur Kennzahlen, Elementnamen, Organisationsnummern und
  Wörter einer festen Liste aus.

Rohantworten (`--save-raw`) enthalten Namen von Lehrpersonen und gehören
nicht ins Repository. Keine Massenabfragen: einzelne, zeitlich gestreute
Anfragen, bis die CAU einer regelmäßigen Nutzung zugestimmt hat.
