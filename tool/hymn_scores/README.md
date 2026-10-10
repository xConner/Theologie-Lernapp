# Noten-Recherche zum Evangelischen Gesangbuch

Werkzeuge, mit denen das Noten-Inventar unter `docs/hymn-scores/` erzeugt
wurde. Sie gehören nicht zur App und ändern keine produktiven Daten. Es werden
nur Metadaten geladen, keine Notendateien.

```
python fetch_sources.py        # Quellen abfragen, quellen_snapshot.json schreiben
python build_inventory.py      # Inventar (JSON, CSV) und auswertung.md erzeugen
```

| Datei | Aufgabe |
|---|---|
| `common.py` | Pfade, Stichjahr der Schutzfristen, Zerlegen der Text-/Melodieangaben |
| `fetch_sources.py` | Wikipedia-Liste und -Artikel, Commons-Kategorie, Open Hymnal, Lebensdaten aus Wikidata |
| `build_inventory.py` | Rechtsstatus je Lied, Zuordnung der Quellen, Empfehlung (ohne Netz) |
| `manual_overrides.json` | von Hand gepflegte Namensvarianten und Melodieverweise |

`fetch_sources.py persons` (oder `dewiki`, `commons`, `open_hymnal`) lädt nur
einen Teil neu. Die Personensuche wird in `build/hymn_scores/persons.json`
zwischengespeichert; zum vollständigen Neuladen die Datei löschen.

Nach einem Jahreswechsel `EVALUATION_YEAR` in `common.py` anheben und das
Inventar neu erzeugen. Ergebnis, Regeln und Grenzen:
[`docs/hymn-scores/README.md`](../../docs/hymn-scores/README.md).
