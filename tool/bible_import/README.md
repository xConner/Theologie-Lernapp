# Import der Bibeltexte

Erzeugt die Texte des Bibel-Readers unter `assets/bible/` aus den
USFM-Archiven von eBible.org. Die Werkzeuge gehören nicht zur App; alles
Heruntergeladene liegt im nicht versionierten `build/content_import/bible`.
Herkunft und Lizenzen: `docs/bible-sources.md`.

```
python fetch_sources.py        # Archive und Katalog laden (--force: neu laden)
python build_bible.py          # alle Ausgaben erzeugen und prüfen
python build_bible.py grcsbl   # nur einzelne Ausgaben neu erzeugen
```

| Datei | Aufgabe |
|---|---|
| `sources.json` | Die Ausgaben: ID, Name, Sprache, Edition, Lizenz, Einschränkungen, Zählung, Abweichungen von der Quelldatei |
| `fetch_sources.py` | Lädt je Ausgabe `<id>_usfm.zip` und den Katalog `translations.csv` |
| `usfm.py` | Liest ein USFM-Buch (Kapitel, Verse, Absätze, Überschriften, Anmerkungen) |
| `build_bible.py` | Schreibt Buchdateien und `translations.json`, legt den Lizenzhinweis der Quelle unter `docs/bible-sources/` ab |
| `build_search_folding.py` | Erzeugt `lib/services/bible/search_folding_table.dart` (Vergleichsform für die Suche) |

## Ergebnis

* `assets/bible/translations.json` – Verzeichnis der Ausgaben mit Herkunft,
  Lizenz, Büchern (Name der Ausgabe, höchste Versnummer je Kapitel).
* `assets/bible/<id>/<BUCH>.json` – ein Buch je Datei, Kennung nach USFM
  (`GEN`, `MRK`, …). Aufbau der Einträge: Kopfkommentar in `usfm.py`.

Der Reader liest ausschließlich diese Dateien; welche Ausgaben er anbietet,
ergibt sich aus `translations.json`.

## Prüfungen beim Erzeugen

`build_bible.py` bricht ab, wenn

* die Zahl der gelesenen Verse nicht der Angabe im Katalog von eBible.org
  entspricht,
* Kapitel nicht lückenlos gezählt sind oder ein Buch unbekannt ist,
* im Verstext Reste von Formatmarken stehen,
* die Quelle eine Marke enthält, die `usfm.py` nicht kennt (dann dort
  eintragen, wie sie zu behandeln ist).

Leere Kapitel der Quelle (Septuaginta, Spr 30) werden gemeldet und bleiben
leer.

## Neue Ausgabe

1. Detailseite bei eBible.org lesen; Lizenz, Copyright und Einschränkungen
   in einen neuen Eintrag von `sources.json` übernehmen. `versification`
   nach der Zählung der Ausgabe setzen (`german`, `english`, `lxx`,
   `vulgate`; Anhaltspunkt: Zahl der Verse von Psalm 51, Kapitel von Joel).
2. `python fetch_sources.py && python build_bible.py`.
3. Das von `build_bible.py` genannte Verzeichnis in `pubspec.yaml` ergänzen.
4. `docs/bible-sources.md` fortschreiben, `flutter test` ausführen.

Texte aus einer anderen Quelle als eBible.org brauchen keinen eigenen
Reader: Entweder erzeugt ein weiteres Skript dieselben Dateien, oder die App
erhält eine weitere `BibleTextSource` (siehe `docs/architecture.md`).
