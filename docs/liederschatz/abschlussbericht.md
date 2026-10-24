# Geistlicher Liederschatz: Abschlussbericht der Recherche

Stand: 2026-10-24. Daten: `docs/liederschatz/` (siehe [README](README.md)).

**Kurz:** Alle 1300 Nummern des Buchs sind mit Titel, Textangabe und Link
erfasst (1304 Einträge). Für 1300 Einträge zeigt evangeliums.net einen Text.
Noten der GLS-Ausgabe gibt es online nicht. Für 73 Einträge gibt es
Notenquellen aus dem Evangelischen Gesangbuch, also aus einer anderen
Ausgabe. Für kein Lied ist eine Lizenz zur Nutzung in der App belegt. Nichts
wurde in die App übernommen.

## 1. Identifikation des Werks

Gemeint ist der *Geistliche Liederschatz* der evangelisch-lutherischen
Brüdergemeinden (Conners Entscheidung vom 2026-10-24).

- Herausgeber: Kirchliche Gemeinschaft der evangelisch-lutherischen
  Brüdergemeinden e.V., Am Haintor 13, 37242 Bad Sooden-Allendorf, info@kg-bsa.de.
  Früher als Kirchliche Gemeinschaft der Ev.-Luth. Deutschen aus Russland e.V.
- Inhalt: 1300 Lieder, Choräle und vor allem Erweckungslieder vom 18. bis
  Anfang des 20. Jahrhunderts. Sie stammen aus Liederbüchern der
  deutschsprachigen Gemeinden in der ehemaligen Sowjetunion.
- Ausgaben:
  - Textausgabe 1989: 21 Auflagen mit etwa 100.000 Exemplaren (WLB Stuttgart
    1989-502).
  - Notenausgabe 2000, „meist vierstimmige Sätze“: wieder lieferbar (WLB
    2000-001).
  - Jubiläumsausgabe 2020: die Lieder sind dieselben, die Texte „überarbeitet
    und … ergänzt“.
- ISBN: keine online angegeben. Amazon führt den Textband unter der ASIN
  B004EC3E8A.
- Nicht gemeint ist der Berliner *Geistliche Liederschatz* (Samuel Elsner,
  1832 ff.). Er hat einen anderen Bestand, eine andere Nummerierung und keine
  Noten. Er steht als eigener Eintrag im App-Katalog und bleibt unverändert.
  Ebenfalls nicht gemeint sind die Drittanbieter-Apps (Mogelnitzki,
  Gräfenstein).
- Hauptgrundlage der Nummern ist das Verzeichnis auf evangeliums.net, das als
  Jahr 2000 nennt. Ob Text- und Notenausgabe dieselben Nummern haben, ist nicht
  am Buch geprüft.

Details: `bibliografie.json`.

## 2. Wichtigste Quellen

| Quelle | Ergebnis | Eignung |
|---|---|---|
| [evangeliums.net, Liederbuchseite](https://www.evangeliums.net/lieder/liederbuch_geistlicher_liederschatz.html) | vollständiges Verzeichnis (1306 Zeilen), Texte auf den Liedseiten, 337 MP3, **keine Noten** | sehr ergiebig für Bestand und Zuordnung; keine Nutzungsrechte |
| [kirchlichegemeinschaft.de](https://kirchlichegemeinschaft.de/geistlicher-liederschatz/) | Ausgaben, Bezug; keine ISBN, keine Rechteangaben | richtige Stelle für die Rechteklärung |
| `docs/hymn-scores` (EG-Inventar, Commons-Schnappschuss) | Notenquellen mit Lizenz für gleichnamige EG-Lieder | brauchbar als Melodiequelle, wenn die GLS-Melodie übereinstimmt |
| Websuche | 87 Liedseiten mit GLS-Nummer, Bibliotheks- und Händlerangaben | Gegenprobe zur Nummernzuordnung |

Die Arbeitsumgebung konnte archive.org, HathiTrust, die BSB, Google Books,
hymnary.org, Wikipedia/Commons und evangeliums.net nicht erreichen.
evangeliums.net und den Verlag habe ich deshalb von Conners Rechner aus
abgerufen, mit höchstens einer Anfrage pro Sekunde und ohne Login. Ich habe
nicht das ganze Internet durchsucht. Was untersucht wurde und was nicht
erreichbar war, steht in `quellen.json`.

## 3. Liedverzeichnis

`lieder.json` enthält einen Datensatz je Lied. Jeder hat eine stabile ID
(`gls_bg.0001` … `gls_bg.1300`, mit a/b bei doppelt belegten Nummern) und
diese Felder: Nummer, Titel, vermutetes Incipit, Textangabe mit Jahr und
Liedseite. Melodieangabe und Strophenzahl stehen nur bei den 30 einzeln
geprüften Liedseiten. Die Hinweise nennen Auffälligkeiten des Verzeichnisses:

- Nr. 108, 116, 153 und 201 führen je zwei verschiedene Lieder. Das ist
  entweder ein Zusatzlied oder ein Datenbankfehler.
- Nr. 182 und 459 stehen doppelt mit derselben Liedseite.
- Dieselbe Liedseite steht unter zwei Nummern bei 83/230, 108/502, 340/357
  und 878/936.

Diese Fälle sind getrennt geführt und nicht zusammengeführt.

## 4. Gefundene Texte und Notensätze

| | Einträge |
|---|---|
| Einträge (Nummern 1–1300) | 1304 (1300) |
| Nummer durch die Liedseite bestätigt (`verified_match`) | 116 |
| Text auf evangeliums.net (`text_found`) | 1300 |
| Kein Text (Nr. 343, 344, 447, 563; Texte des 20. Jh.) | 4 |
| Notenquelle aus dem EG, andere Ausgabe (`notation_found`) | 73 (60 davon im EG-Inventar „frei integrierbar“; fast immer MIDI). Titelgleich mit dem EG sind 77. |
| Nur Melodieangabe (Stichprobe) | 30 |
| Vollständiger GLS-Notensatz (`complete_notation_found`) | 0 |
| Lizenz für die App belegt (`license_verified`) | 0 |
| Rechteklärung erforderlich (`rights_review_required`) | 1304 |
| Weder Text noch Noten (`not_found`) | 4 |

## 5. Abdeckung

Das Verzeichnis von evangeliums.net deckt alle 1300 Nummern ab, die der Verlag
angibt. Die Bestandsabdeckung ist damit vollständig, aber nur aus einer
Quelle belegt. 116 Zuordnungen sind zusätzlich durch die Liedseite bestätigt,
die aber zur selben Website gehört. Ein Abgleich mit dem gedruckten Buch
fehlt; ohne ihn bleiben die Fälle aus Abschnitt 3 offen.

Die Texte auf evangeliums.net sind nicht mit der GLS-Fassung verglichen, die
seit 2020 überarbeitet ist. Bei den Noten liegt die Abdeckung der GLS-Ausgabe
bei null. Die 73 EG-Notenquellen decken knapp 6 % ab, und ob die Melodie gleich ist,
muss je Lied geprüft werden. Der Bestand besteht zum großen Teil aus
Erweckungsliedern, die nicht im EG stehen. Die häufigsten Textdichter sind
Gebhardt (145), Magaret (85) und Rauschenbusch (72), 233 Texte sind ohne
Verfasser.

## 6. Rechte und Lizenzen

- evangeliums.net nennt keine Nutzungsbedingungen. Das Impressum sucht
  „rechtefreien Content“, und Texte des 20. Jahrhunderts blendet die Seite aus.
  Für das Verzeichnis kann das Datenbankherstellerrecht gelten. Die Kopie im
  Repository dient nur der Recherche und gehört nicht in die App.
- Der Verlag hat nur einen allgemeinen Website-Hinweis: „nur für den privaten,
  nicht kommerziellen Gebrauch“. Zu Texten und Noten sagt er nichts.
- Die Notensätze von 2000 und die Textbearbeitungen von 2020 können eigene
  Rechte haben, auch wenn das Original gemeinfrei ist. Das Buch ist als
  Sammlung geschützt.
- Einschätzung zu den Textdichtern (`rechte.json`):
  - 223 gemeinfrei, belegt durch das Wikidata-Todesjahr oder ein Werkjahr bis
    1850.
  - 8 geschützt, mit einem Werkjahr oder Todesjahr nach 1955 (z. B. Beuerle,
    Hänssler, Haas).
  - 1073 ungeklärt, weil die Lebensdaten nicht abgeglichen sind oder der
    Verfasser unbekannt ist.
- MP3-Aufnahmen: Sermon-Online und Gemeinde Gottes Eppingen haben sie zur
  Verfügung gestellt. Eine Lizenz gibt es nicht, und der Player sperrt den
  Download.
- Keine Lizenz ist erfunden: `lizenz` ist überall `null`, und `in_app_erlaubt`
  ist überall `false`. Details stehen in `lizenzen.json`.

## 7. Wichtigste Lücken

- Es gibt keinen Notensatz der GLS-Ausgabe online, und die Notenausgabe 2000
  ist nur gedruckt erhältlich.
- Für 1231 Einträge fehlt jede Notenquelle, vor allem für die
  Erweckungslieder von Gebhardt, Magaret, Rauschenbusch, Röhl und anderen
  sowie für Sankey-Melodien.
- Melodieangaben fehlen außerhalb der Stichprobe.
- Die vier Texte Nr. 343, 344, 447 und 563 fehlen.
- Die Angaben zur Jubiläumsausgabe 2020 fehlen (die Seiten geben 404 zurück),
  ebenso die ISBN.
- Die Lebensdaten von 270 Textdichtern sind nicht abgeglichen.

## 8. Empfehlung

1. **Beim Verlag nachfragen** (info@kg-bsa.de): Darf eine kostenlose
   Open-Source-App Nummern, Texte und Noten verwenden? Gibt es eine
   ISBN oder Unterlagen zur Ausgabe 2020? Ohne Zusage bleiben Text und Noten
   aus der App heraus.
2. **Lebensdaten aus Wikidata abgleichen** für alle Textdichter, wie beim
   EG-Inventar. Das entscheidet bei vielen Liedern über „gemeinfrei“.
3. **Melodieangaben ergänzen**: Die Liedseiten nennen Melodie und alternative
   Melodie. Abruf wie bisher langsam und vom Rechner des Nutzers aus.
4. **Am gedruckten Buch prüfen**: die doppelten Nummern, die
   Textfassungen und ob die Melodie der 73 EG-Notenquellen übereinstimmt.
5. **Erst danach integrieren**: Ein Katalogeintrag mit Nummer und Titel ist
   denkbar, sobald die Nutzung des Verzeichnisses geklärt ist. Melodien nur
   gemeinfreie und selbst gesetzt (wie bei `docs/hymn-scores`), nie Satzbilder
   aus der Notenausgabe.
