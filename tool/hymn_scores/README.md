# Noten zum Evangelischen Gesangbuch

Werkzeuge, mit denen das Noten-Inventar unter `docs/hymn-scores/` und die
Notenbilder unter `assets/hymn_scores/` erzeugt wurden. Sie gehören nicht zur
App. Heruntergeladenes liegt im nicht versionierten `build/hymn_scores`.

```
python fetch_sources.py        # Quellen abfragen, quellen_snapshot.json schreiben
python build_inventory.py      # Inventar (JSON, CSV) und auswertung.md erzeugen
python fetch_midi.py           # MIDI-Vorlagen der vorgesehenen Lieder laden
python build_scores.py         # Notenbilder, Feld „scores“ in eg_lieder.json, integration.md
```

Die ersten beiden Schritte ändern keine produktiven Daten. `build_scores.py`
schreibt `assets/eg_lieder.json` neu, ändert dort aber nur das Feld `scores`.
Es braucht `pip install verovio` (verwendet: 6.3.0).

| Datei | Aufgabe |
|---|---|
| `common.py` | Pfade, Stichjahr der Schutzfristen, Zerlegen der Text-/Melodieangaben |
| `fetch_sources.py` | Wikipedia-Liste und -Artikel, Commons-Kategorie, Open Hymnal, Lebensdaten aus Wikidata |
| `build_inventory.py` | Rechtsstatus je Lied, Zuordnung der Quellen, Empfehlung (ohne Netz) |
| `manual_overrides.json` | von Hand gepflegte Namensvarianten und Melodieverweise |
| `fetch_midi.py` | Vorlagen von Wikimedia Commons laden, Prüfsumme gegen den Schnappschuss |
| `midi.py`, `melody.py` | MIDI lesen; Melodie der ersten Strophe herausziehen und rastern |
| `engrave.py` | Melodie über MEI mit Verovio setzen, SVG für `flutter_svg` vereinfachen |
| `build_scores.py` | Lieder und Vorlagen zuordnen, Bilder und Übersicht schreiben |

`fetch_sources.py persons` (oder `dewiki`, `commons`, `open_hymnal`) lädt nur
einen Teil neu. Die Personensuche wird in `build/hymn_scores/persons.json`
zwischengespeichert; zum vollständigen Neuladen die Datei löschen.

Nach einem Jahreswechsel `EVALUATION_YEAR` in `common.py` anheben und das
Inventar neu erzeugen. Ergebnis, Regeln und Grenzen:
[`docs/hymn-scores/README.md`](../../docs/hymn-scores/README.md).
