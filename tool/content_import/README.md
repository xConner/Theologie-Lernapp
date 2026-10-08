# Import der Bekenntnisse und liturgischen Texte

Werkzeuge, mit denen `assets/confessions.json` (vollständiges Konkordienbuch)
und die liturgischen Einträge in `assets/prayers.json` erzeugt wurden. Sie
gehören nicht zur App; alles Heruntergeladene liegt im nicht versionierten
`build/content_import`.

## Konkordienbuch

```
python fetch_sources.py        # Quellen laden (archive.org, bookofconcord.org)
python ocr_pages.py concordiatriglot00unse 285 1447 2 frak2021,Fraktur 12
python check_render.py         # Zerlegung prüfen, Klammer-Auffälligkeiten melden
python evaluate.py de          # Abgleich an den handgeprüften Abschnitten messen
python build_confessions.py    # assets/confessions.json schreiben
```

| Datei | Aufgabe |
|---|---|
| `spec.py` | Abschnittsplan: Schriften, Abschnitte, Titel, Anker in den drei Quellen |
| `textlib.py` | Quelltexte in Blöcke zerlegen, Abschnitte ausschneiden, bereinigen |
| `patches.py` | Einzelkorrekturen offenkundiger Fehler der Quellen |
| `greek.py`, `greek_table.py` | griechische Wörter (in der Vorlage fehlerhaft kodiert) |
| `collate.py`, `witnesses.py` | Wort-für-Wort-Abgleich mit Texterkennungen des Drucks |
| `build_confessions.py` | Zusammenführen mit den handgeprüften Abschnitten, Quellenangaben |

Quellen: Deutsch und Lateinisch aus der elektronischen Textfassung der
Concordia Triglotta (Northwestern Publishing House 1996), Englisch von
bookofconcord.org. Beide enthalten Abschreib- bzw. Erkennungsfehler; deshalb
wird jedes Wort mit Texterkennungen des Drucks von 1921 verglichen (Deutsch:
eigene Fraktur-Erkennung mit zwei Modellen; Lateinisch/Englisch: die
Erkennungen zweier verschiedener Scans). Ersetzt wird nur, wenn die Zeugen
gegen die Vorlage übereinstimmen; alles andere bleibt stehen und steht im
Protokoll `build/content_import/collation_<sprache>.tsv`.

Gemessen an den vorher von Hand am Faksimile geprüften Abschnitten sinken die
Abweichungen der deutschen Vorlage von 116 auf rund 25 je 7100 Wörter; ein Rest
an Lesefehlern (vor allem gleich aussehende Wörter wie „sei“/„sie“ und die
Zeichensetzung) bleibt also. Die geprüften Abschnitte selbst (`VERIFIED` in
`build_confessions.py`) werden nie überschrieben.

`ocr_pages.py` braucht `tesserocr` und die Modelle `frak2021` (UB Mannheim) und
`Fraktur` (tessdata_best) in `build/content_import/tessdata`.

## Liturgie und Gebete

`add_liturgy.py` enthält die aus dem „Kirchenbuch für Evangelisch-Lutherische
Gemeinden“ (Philadelphia 1877) abgeschriebenen Texte. Vorgehen je Text:
Seite erkennen lassen (`ocr_pages.py kirchenbuchfur00gene …`, ansehen mit
`show_ocr.py`), dann Wort für Wort am Seitenbild nachlesen.
