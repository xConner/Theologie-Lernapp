# Bibeltexte: Herkunft, Lizenzen und Integration

Stand der Prüfung: 9. Oktober 2026. **Keine Rechtsberatung** – die Angaben
geben die Lizenzhinweise der Quelle wieder und nennen offene Fragen.

Alle Texte stammen aus dem offiziellen USFM-Download von
[eBible.org](https://ebible.org/) (ein Archiv je Ausgabe, kein Auslesen von
Webseiten). Der Lizenzhinweis jeder Quelldatei liegt unverändert unter
`docs/bible-sources/<id>-copr.htm`; die App zeigt ihn in der
Übersetzungsauswahl (ⓘ) und nennt Ausgabe, Copyright und Lizenz unter jedem
Kapitel.

Maschinenlesbare Übersicht (ID, Name, Sprache, Edition, Quelle, Lizenz,
Copyright, Einschränkungen, Funktionen): `assets/bible/translations.json`,
erzeugt aus `tool/bible_import/sources.json`.

## Integrierte Ausgaben

| ID | Ausgabe | Sprache | Umfang | Lizenz laut Quelle | Stand der Quelldatei |
|---|---|---|---|---|---|
| `deu1912` | Lutherbibel 1912 | de | AT + NT, 31 102 Verse | gemeinfrei | 2025-12-29 |
| `deu1951` | Schlachter-Bibel 1951 (Genfer Bibelgesellschaft) | de | AT + NT, 31 102 Verse | CC BY 4.0 | 2022-03-30 |
| `deuelbbk` | Elberfelder Übersetzung, Version von bibelkommentare.de | de | AT + NT, 31 165 Verse, 9 422 Fußnoten | CC BY-NC-ND 4.0 | 2023-10-23 |
| `deutkw` | Textbibel (Kautzsch/Weizsäcker, 1906) | de | AT + NT, 31 157 Verse | gemeinfrei | 2025-08-30 |
| `engwebp` | World English Bible | en | AT + NT, 31 103 Verse | gemeinfrei | 2026-10-08 |
| `eng-asv` | American Standard Version (1901) | en | AT + NT, 31 102 Verse | gemeinfrei | 2026-10-08 |
| `grcsbl` | SBL Greek New Testament (2010) | grc | NT, 7 939 Verse, Apparat | CC BY 4.0 | 2026-10-08 |
| `grcbrent` | Septuaginta nach Brenton (1851) | grc | AT + Apokryphen, 28 597 Verse | gemeinfrei | 2026-04-08 |
| `latVUC` | Vulgata Clementina (1598) | la | AT + Apokryphen + NT, 35 809 Verse | gemeinfrei | 2014-08-23 |

Quelle je Ausgabe: `https://ebible.org/details.php?id=<ID>`, Datei
`https://ebible.org/Scriptures/<ID>_usfm.zip`. Die Verszahlen stimmen mit dem
Katalog von eBible.org (`translations.csv`) überein; der Import bricht ab,
wenn sie abweichen. Die SHA-256-Prüfsumme des verwendeten Archivs steht in
`translations.json`.

### Art der Integration

Der Import (`tool/bible_import`) liest die USFM-Dateien und schreibt je
Ausgabe ein Verzeichnis `assets/bible/<ID>/` mit einer JSON-Datei je Buch.

* Der **Wortlaut wird nicht verändert**: Zeichen, Schreibweise und
  Zeichensetzung der Quelle bleiben erhalten (griechisch samt Akzenten,
  Spiritus und textkritischen Zeichen; keine Unicode-Normalisierung).
  Leerraum wird wie in USFM vorgesehen zu einem Leerzeichen zusammengefasst.
* Erhalten bleiben Buchfolge, Kapitel, Verse und Versbezeichnungen (auch
  „22a“ in der Septuaginta), Absätze, Zeilen poetischer Texte,
  Zwischenüberschriften, Psalmüberschriften und Fußnoten bzw. Apparat.
* Es entfallen die Formatmarken und damit die Schriftauszeichnung (Kursive
  für ergänzte Wörter, Kapitälchen, Worte Jesu) sowie die Strong-Nummern.
* Kapitel- und Verszählungen werden **nicht umgerechnet**; jede Ausgabe
  behält ihre eigene (siehe „Zählung“).

Abweichungen von der Quelldatei, je Ausgabe in `sources.json` unter
`deviations` und in der App unter „Quelle“ ausgewiesen:

* `deu1912`, `deu1951`, `deutkw`: Im Buchtitel der Quelldatei steht
  „1. Chonik“; die App zeigt „1. Chronik“. Der Bibeltext ist nicht berührt.
* `latVUC`: Die als Fußnoten beigegebene Glossa ordinaria (Migne 1880) wird
  nicht übernommen.
* `engwebp`: ohne Querverweise, Vorwort und Glossar.
* `grcsbl`: ohne Einleitung und Anhänge; Text und Apparat vollständig.

### Hinweise zu einzelnen Lizenzen

**Schlachter 1951 und SBLGNT (CC BY 4.0).** Weitergabe in jedem Format mit
Copyright- und Quellenangabe; Änderungen sind zu kennzeichnen. Die Angaben
stehen in der App beim Text, die Abweichungen oben.

**Elberfelder/bibelkommentare.de (CC BY-NC-ND 4.0).** eBible.org erlaubt, die
Übersetzung „in any format“ weiterzugeben, sofern Copyright und Quelle genannt
werden, das Werk nicht mit Gewinn verkauft wird und Wörter und Zeichensetzung
unverändert bleiben. Daraus folgt für die App:

* Die Ausgabe wird ohne Auslassungen übernommen (alle Bücher, alle
  Fußnoten); ein Test prüft Stichproben des Wortlauts.
* Die Umwandlung von USFM in JSON ist eine Formatänderung. CC BY-NC-ND 4.0
  rechnet technisch nötige Formatänderungen nicht als Bearbeitung
  (Abschnitt 2(a)(4)).
* **Bedingung:** Die App muss nichtkommerziell bleiben. Wird sie kostenpflichtig
  oder werbefinanziert, ist der Eintrag `deuelbbk` aus `sources.json` und
  `pubspec.yaml` zu entfernen und der Import neu auszuführen.
* **Offen:** Ob der Rechteinhaber (Verbreitung des christlichen Glaubens e.V.)
  den Wegfall der Schriftauszeichnung (Kursive, Kapitälchen) als unveränderte
  Wiedergabe ansieht, ist nicht geklärt. Eine ausdrückliche Zustimmung liegt
  nicht vor; im Zweifel dort nachfragen oder die Ausgabe entfernen.

**World English Bible.** Gemeinfrei; der Name ist eine Marke von eBible.org
und darf nur für den unveränderten Text verwendet werden.

## Geprüft und nicht integriert

| Text | Grund |
|---|---|
| King James Version | In den USA gemeinfrei, im Vereinigten Königreich aber durch königliches Patent ohne Ablaufdatum geschützt (Druckrecht bei Cambridge University Press u. a.). Die Web-App ist auch dort abrufbar; deshalb stattdessen die American Standard Version. Technisch genügt ein Eintrag `eng-kjv2006` in `sources.json`. |
| Menge-Bibel 1939 | Im Katalog von eBible.org nicht vorhanden. Hermann Menge starb 1939, die Übersetzung selbst dürfte gemeinfrei sein; eine digitale Fassung mit eindeutig dokumentierten Nutzungsbedingungen wurde in dieser Prüfung nicht ermittelt (andere Quellen, z. B. CrossWire, sind noch zu prüfen). |
| Zürcher Bibel 1931 | Im Katalog von eBible.org nicht vorhanden; eine freie Lizenz ist nicht bekannt. Nicht weiter geprüft. |
| Schlachter 2000, Lutherbibel 1984/2017, Elberfelder 2006, Einheitsübersetzung | Urheberrechtlich geschützt, keine freie Lizenz. |
| Septuaginta nach Rahlfs (1935) bzw. Rahlfs-Hanhart | Im Katalog von eBible.org nicht vorhanden. Die verbreitete digitale Fassung (CCAT) ist nach Kenntnisstand an eine Nutzererklärung gebunden, Rahlfs-Hanhart urheberrechtlich geschützt (Deutsche Bibelgesellschaft); eine zur Weitergabe freigegebene Fassung wurde nicht ermittelt. Stattdessen der gemeinfreie Brenton-Text – eine andere Textausgabe, in der App so bezeichnet. |
| Septuaginta `grclxx` (Orthodox Media Network, eBible.org) | Als gemeinfrei bezeichnet, aber die zugrunde liegende Textausgabe ist nicht angegeben. |
| Nova Vulgata | Moderne Ausgabe (1979) mit eigenem Urheberrecht; keine freie Lizenz bekannt. |
| Unrevidierte Elberfelder 1905 (`deuelo`) | Gemeinfrei und geeignet; zurückgestellt, weil die Version von bibelkommentare.de denselben Text sprachlich überarbeitet bietet. Als Ersatz vorgesehen, falls `deuelbbk` entfallen muss. |
| Apokryphen in deutscher Sprache | Die integrierten deutschen Ausgaben enthalten keine; Apokryphen stehen nur in Septuaginta und Vulgata. |

## Zählung

Die Ausgaben zählen unterschiedlich; `versification` in `sources.json` hält
fest, wie:

| Wert | Ausgaben | Merkmal |
|---|---|---|
| `german` | `deuelbbk`, `deutkw` | Psalmüberschrift als eigener Vers (Ps 51 hat 21 Verse), Joel 4, Mal 3 |
| `english` | `deu1912`, `deu1951`, `engwebp`, `eng-asv`, `grcsbl` | Überschrift in Vers 1 (Ps 51 hat 19 Verse), Joel 3, Mal 4 |
| `lxx` | `grcbrent` | Psalmenzählung der Septuaginta, abweichende Kapitelfolge, Daniel und Ester nur in griechischer Fassung |
| `vulgate` | `latVUC` | Psalmenzählung der Septuaginta |

Die Perikopenliste (`assets/perikopen.json`) folgt der deutschen Zählung. Der
Reader rechnet nicht um: Er hebt die angegebenen Verse hervor und weist im
Alten Testament darauf hin, wenn die gewählte Ausgabe anders zählt oder die
Stelle dort nicht existiert. Im Neuen Testament sind die Abweichungen
vernachlässigbar.

## Aktualisieren und erweitern

```
cd tool/bible_import
python fetch_sources.py --force   # Archive neu laden
python build_bible.py             # assets/bible neu erzeugen und prüfen
flutter test test/bible_data_test.dart
```

Eine weitere Ausgabe von eBible.org: Eintrag in `sources.json` anlegen
(Lizenz und Einschränkungen von der Detailseite übernehmen), beide Skripte
ausführen, das Verzeichnis in `pubspec.yaml` unter `assets` ergänzen und die
Tabelle oben fortschreiben. Näheres in `tool/bible_import/README.md`.
