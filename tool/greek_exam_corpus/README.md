# Import der Klausurkorpora

Erzeugt die Textkorpora des Klausurerstellers (Altgriechisch) unter
`assets/greek_corpus/`. Die Werkzeuge gehören nicht zur App; Heruntergeladenes
liegt im nicht versionierten `build/content_import/greek_exam`. Herkunft,
Lizenzen und Grenzen der Daten: `docs/greek-exam-sources.md`.

```
dart run tool/greek_exam_corpus/fetch_sources.dart   # Quellen laden (--force: neu laden)
dart run tool/greek_exam_corpus/fetch_pape.dart      # Pape-Artikel der Grundformen (einmalig, setzt fort)
dart run tool/greek_exam_corpus/build_corpus.dart    # Korpora erzeugen (einige Minuten)
dart run tool/greek_exam_corpus/build_lexicon.dart   # nur die Vokabelhilfen neu erzeugen
flutter test test/greek_exam_corpus_test.dart        # Index gegen die Regeln prüfen
```

Ohne Flutter genügt das Dart-SDK; der Import verwendet dieselben
Erkennungsregeln wie die App (`lib/services/greek/exam/`).

| Datei | Aufgabe |
|---|---|
| `sources.json` | Quellen mit fester Version (MorphGNT-Commit), Lizenz und Zitierweise |
| `fetch_sources.dart` | Lädt die 27 MorphGNT-Dateien und die beiden Wiktionary-Auszüge |
| `build_corpus.dart` | Liest die Quellen, bestimmt die Septuaginta-Formen, erkennt die Phänomene je Vers und schreibt die Assets |
| `fetch_pape.dart` | Fragt je Grundform einmal den Pape-Artikel ab (Classical Language Dictionary der BBAW), nacheinander und mit Pause; Zwischenspeicher `pape.jsonl`, häufige Grundformen zuerst. Die App fragt den Dienst nie ab. |
| `german_lexicon.dart` | Deutsche Vokabelhilfen: redaktionelle Angaben, deutsches Wiktionary, Pape; Kürzung auf höchstens drei Bedeutungen |
| `german_glosses.json` | Redaktionelle Angaben (Vorrang vor den Wörterbüchern); hier Bedeutungen korrigieren oder ergänzen |
| `build_lexicon.dart` | Schreibt nur `lexicon.json` neu; `--report` listet die Grundformen nach Häufigkeit mit Quelle und Bedeutung |

## Ergebnis

* `assets/greek_corpus/corpora.json` – Verzeichnis der Korpora (Edition,
  Art der Analyse, Quellen, Lizenzen, Bücher, Importstatistik). Die App
  bietet genau diese Korpora an.
* `assets/greek_corpus/<korpus>/index.json` – Suchindex: je Vers Wortzahl,
  Satzgrenzen, sicher und möglicherweise belegte Phänomene, Grundformen.
* `assets/greek_corpus/<korpus>/<BUCH>.json` – Verstext und Bestimmungen je
  Wort. Format: Kopfkommentar in `lib/services/greek/exam/corpus_codec.dart`.
* `assets/greek_corpus/lexicon.json` – deutsche Vokabelhilfen (mit Quelle)
  und Deklinationsklassen der vorkommenden Grundformen; keine englischen
  Angaben.

## Wann neu erzeugen?

* nach Änderungen an Phänomenen oder Regeln (`grammar_phenomena.dart`,
  `syntax_rules.dart`, `phenomenon_detection.dart`) – sonst schlägt
  `test/greek_exam_corpus_test.dart` fehl und neue Phänomene gelten in der
  App als nicht verfügbar;
* nach einem Update der Bibeltexte (`assets/bible/grcsbl`, `grcbrent`);
* um eine neuere MorphGNT-Version zu verwenden (`commit` in `sources.json`).

Die Wiktionary-Auszüge von kaikki.org sind nicht versioniert; ein neuer
Abruf kann die Septuaginta-Bestimmungen und Bedeutungen leicht verändern.

## Ein weiteres Korpus

Ein Korpus braucht Verse mit Text und je Wort Bestimmungen im Code-Format
von `GreekMorphAnalysis`. In `build_corpus.dart` eine weitere
`buildCorpus(...)`-Zeile mit eigener Quelle ergänzen (im Kontext bestimmte
Texte wie MorphGNT, sonst `FormAnalyzer` für die formale Bestimmung) und den
Eintrag in `writeCorpora` hinzufügen; danach das Verzeichnis in
`pubspec.yaml` aufnehmen. Die App und die Suche brauchen keine Änderung.
