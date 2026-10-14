# UnivIS-Prototyp (Machbarkeitsprüfung)

Abgegrenzter Prototyp zur Prüfung der UnivIS-PRG-Schnittstelle. Nicht Teil
der App. Ergebnisse und Einordnung: `docs/univis-integration-feasibility.md`.

| Datei | Zweck |
|---|---|
| `univis_parser.mjs` | XML (`show=xml`) → normalisierte Veranstaltungen, Qualitätskennzahlen, Element-Inventar |
| `univis_probe.mjs` | genau ein Abruf je Aufruf (oder `--file` offline), Ausgabe als JSON |
| `univis_parser.test.mjs` | Tests des Parsers ohne Netzwerk |
| `fixtures/synthetic_lectures.xml` | **synthetische** Beispieldaten (erfundene Namen), keine echte UnivIS-Antwort |

Voraussetzung: Node 22 und `npm ci` im Repository (nutzt das vorhandene
`cheerio`).

```sh
node --test tool/univis/univis_parser.test.mjs

# Erster echter Abruf (von einem Rechner mit Zugriff auf univis.uni-kiel.de):
node tool/univis/univis_probe.mjs --sem 2026w --param name=Exegese --sample 2
node tool/univis/univis_probe.mjs --sem 2026w --param department=<OrgNr> --sample 0
```

Was beim ersten echten Abruf zu prüfen ist:

1. `meta.status`/`meta.contentType`: Liefert Kiel `show=xml` überhaupt aus?
2. `inventory.Lecture` und `inventory.term`: Stimmen die angenommenen
   Elementnamen (`name`, `id`, `type`, `dozs/doz`, `terms/term`, `repeat`,
   `starttime`, `endtime`, `room`, `exclude`)? Abweichungen im Parser
   nachziehen.
3. `validation.unknownRepeatValues`: Welche Wiederholungsmuster kommen vor?
   Deutung mit Abschnitt 19.4 des Benutzerhandbuchs abgleichen.
4. `meta.etag`/`meta.lastModified`/`meta.cacheControl`: Grundlage für
   Abrufintervalle und bedingte Anfragen.

Rohantworten (`--save-raw`) enthalten Namen von Lehrpersonen und gehören
nicht ins Repository. Keine Massenabfragen: einzelne, zeitlich gestreute
Anfragen, bis die CAU einer regelmäßigen Nutzung zugestimmt hat.
