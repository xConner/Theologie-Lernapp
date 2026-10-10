# Noten zum Evangelischen Gesangbuch

Stand: 10. Oktober 2026. **Keine Rechtsberatung.** Die Einstufungen der
Recherche (Abschnitte 1–6) sind eine automatische Vorprüfung nach den unten
genannten Regeln. Abschnitt 7 beschreibt, was davon in der App umgesetzt ist.

| Datei | Inhalt |
|---|---|
| [`integration.md`](integration.md) / [`.json`](integration.json) | je Lied: Noten in der App oder Grund, warum nicht (erzeugt) |
| [`eg_noten_inventar.csv`](eg_noten_inventar.csv) / [`.json`](eg_noten_inventar.json) | je Lied: Angaben, Rechtsstatus, beste Quelle, Fundstelle, Lizenz, Empfehlung |
| [`auswertung.md`](auswertung.md) | Zahlen und Listen aus dem Inventar (erzeugt) |
| [`quellen_snapshot.json`](quellen_snapshot.json) | Stand der Quellen: Versionskennungen, Prüfsummen, Lizenzangaben, Lebensdaten |
| [`tool/hymn_scores/`](../../tool/hymn_scores/README.md) | Skripte, mit denen alles erzeugt wurde |

## 1. Ausgangslage in der App (vor der Umsetzung)

- **Daten:** eine Datei, `assets/eg_lieder.json`, 535 Einträge. Sie decken den
  Stammteil lückenlos ab (EG 1–535); Regionalteile fehlen.
- **Kennung:** `id` ist die EG-Nummer. Eine davon unabhängige Lied- oder
  Melodiekennung gibt es nicht.
- **Felder:** `title`, `text` (Textangabe), `melody` (Melodieangabe), `lyrics`,
  `tags`, `bibleReferences`, `explanation`. Text- und Melodieangabe sind
  Freitext der Form „Name (Jahr) , Name (Jahr)“. Bei 154 Liedern enthält
  `melody` kein Jahr; bei 111 davon steht dort der Titel eines anderen Liedes
  des Stammteils, dessen Melodie gesungen wird. Sterbejahre, Melodienamen
  als eigenes Feld oder Zahn-Nummern sind nicht erfasst.
- **Texte:** 446 Lieder zeigen einen Text, bei 89 ist `lyrics` leer („aus
  urheberrechtlichen Gründen nicht verfügbar“). Die Herkunft der Texte ist im
  Projekt nicht dokumentiert (`lib/info/app_info.dart`).
  `docs/content-rights-review.md` nennt noch „0 Lieder ohne Text“ und ist
  insoweit veraltet.
- **Musikalische Daten:** keine – weder Notenbilder noch Audio, PDF, MusicXML,
  ABC oder LilyPond. Es gibt auch kein Feld, über das einem Lied weitere
  Ressourcen zugeordnet werden könnten.
- **Auslieferung:** `HymnService` lädt die Datei aus dem App-Bundle. Firebase
  ist an den Lieddaten nicht beteiligt; es gibt nichts zu synchronisieren.

## 2. Rechtlicher Rahmen (Deutschland)

| Frage | Regel | Folge für uns |
|---|---|---|
| Schutzdauer | 70 Jahre nach dem Tod des Urhebers, Fristende am Jahresende ([§ 64](https://www.gesetze-im-internet.de/urhg/__64.html), [§ 69 UrhG](https://www.gesetze-im-internet.de/urhg/__69.html)) | 2026 ist gemeinfrei, wer bis 1955 gestorben ist |
| Lied mit Text | Wurden Text und Musik eigens füreinander geschaffen, zählt der Tod des Längerlebenden ([§ 65 Abs. 3](https://www.gesetze-im-internet.de/urhg/__65.html)) | Bei Liedern ab etwa 1880 genügt ein gemeinfreier Komponist allein nicht |
| Anonyme Werke | 70 Jahre nach Veröffentlichung, mit Ausnahmen ([§ 66](https://www.gesetze-im-internet.de/urhg/__66.html)) | „überliefert“ oder Ortsangaben nach 1850 gelten hier als ungeklärt |
| Bearbeitung | Eigener Schutz für Sätze, Harmonisierungen, schöpferische Melodiefassungen ([§ 3](https://www.gesetze-im-internet.de/urhg/__3.html)) | Alte Melodie ≠ freie Notenausgabe |
| Wissenschaftliche Ausgabe | 25 Jahre ab Erscheinen ([§ 70](https://www.gesetze-im-internet.de/urhg/__70.html)); Erstausgabe nachgelassener Werke 25 Jahre ([§ 71](https://www.gesetze-im-internet.de/urhg/__71.html)) | Kritische Neuausgaben nicht als Vorlage nehmen |
| Sammlung | Auswahl und Anordnung können geschützt sein ([§ 4](https://www.gesetze-im-internet.de/urhg/__4.html), [§ 87a](https://www.gesetze-im-internet.de/urhg/__87a.html)) | Betrifft das EG als Ganzes, auch die Nummernfolge – unabhängig von den Noten zu klären |
| Notenstich | Kein eigenes Schutzrecht für den bloßen Satz gemeinfreier Musik; das Kopierverbot für Noten ([§ 53 Abs. 4](https://www.gesetze-im-internet.de/urhg/__53.html)) betrifft geschützte Werke | Trotzdem keine fremden Notenbilder übernehmen, sondern selbst setzen |

Daraus folgt der sicherste Weg: **die gemeinfreie Melodie selbst neu setzen**
(nur Tonhöhen und Dauern, eigener Notensatz) und dabei nichts aus einer
geschützten Ausgabe übernehmen – keinen Satz, keine Begleitung, kein Notenbild.
Das EG selbst ist keine freie Vorlage: Der Nachdruck des Stammteils oder
einzelner Stücke bedarf laut Rechtevermerk der Genehmigung der EKD, und einige
Melodien stehen dort in einer neueren Fassung (in den Angaben erkennbar an
späten Zusätzen wie „AÖL (1971)“ oder einem Bearbeiter des 20. Jahrhunderts).

### Regeln der automatischen Einstufung

1. Melodieverweise werden aufgelöst (Lied → Lied mit derselben Melodie).
2. Jede genannte Person wird in Wikidata gesucht. Ein Treffer zählt nur, wenn
   Name, Lebenszeit (passend zum Werkjahr) und Beschreibung (Dichter,
   Komponist, Theologe …) passen. Mehrere passende Personen sind nur dann ein
   Beleg, wenn alle zum selben Ergebnis führen.
3. **gemeinfrei:** alle Beteiligten bis 1955 gestorben, oder Werkjahr bis 1850.
4. **geschützt:** ein Beteiligter nach 1955 gestorben, vermutlich lebend, oder
   Werkjahr ab 1956.
5. **ungeklärt:** alles andere (kein Jahr, „überliefert“, Länderangabe,
   Person nicht gefunden).

Nicht geprüft werden § 65 Abs. 3, die Richtigkeit der Angaben in
`eg_lieder.json` selbst und die Frage, ob die EG-Fassung einer alten Melodie
schöpferisch bearbeitet ist. 19 Melodieverweise auf Lieder außerhalb des
Stammteils sind von Hand aufgelöst (`tool/hymn_scores/manual_overrides.json`)
und im Inventar mit „manuell“ gekennzeichnet.

## 3. Ergebnis in Zahlen

Alle Zahlen stammen aus dem tatsächlich durchgeführten Abgleich
([`auswertung.md`](auswertung.md)).

| | Lieder |
|---|---|
| untersucht | 535 |
| Melodie gemeinfrei (nach den Regeln oben) | 378 |
| Melodie geschützt | 123 |
| Melodie ungeklärt | 34 |
| mindestens eine Notenquelle gefunden | 351 |
| … davon mit gemeinfreier Melodie | 313 |
| **„frei integrierbar“** (Melodie gemeinfrei und Datei CC0/gemeinfrei) | **287** |
| unter Bedingungen (Vorlage CC BY / CC BY-SA) | 26 |
| Melodie gemeinfrei, aber keine Quelle gefunden | 65 |

Von den 287 beruhen 273 auf automatisch belegten und 14 auf von Hand
zugeordneten Melodien; bei 264 ist auch der Text gemeinfrei und in der App
vorhanden. Die 287 Lieder verteilen sich auf 198 verschiedene Dateien, weil
viele Texte dieselbe Melodie haben. **Von einem Menschen rechtlich und
musikalisch gegengeprüft ist bisher keines** – „frei integrierbar“ heißt:
besteht die automatische Vorprüfung.

## 4. Quellen

### Wikimedia Commons – Hauptquelle

[Category:Melodies from "Evangelisches Gesangbuch"](https://commons.wikimedia.org/wiki/Category:Melodies_from_%22Evangelisches_Gesangbuch%22):
283 MIDI-Dateien, fast alle von Peter Gerloff (Benutzer „Rabanus Flavus“)
selbst gesetzt und hochgeladen. Lizenz je Datei laut Commons: 251 × CC0,
13 × gemeinfrei, 15 × CC BY-SA 3.0, 3 × CC BY 3.0, 1 × CC BY 4.0.

- **Inhalt:** vierstimmiger Satz, Melodie in der Oberstimme; kein Text.
- **Abgleich:** 229 Dateien nennen in der Beschreibung eine Stammteil-Nummer
  („Evang. Gesangbuch 66“); das ist automatisch auswertbar. Treffer für
  347 Lieder: 256 über die Nummer, 22 über Titel oder Wikipedia-Artikel,
  69 über den Melodieverweis.
- **Fassung:** Die Dateien sind ausdrücklich den EG-Liedern zugeordnet, teils
  mit eigener „(EG)“-Variante. Ob Rhythmus und Tonart der Fassung im
  Gesangbuch entsprechen, wurde nicht geprüft.
- **Grenzen:** Die Lizenz gilt für Satz und Datei des Hochladenden, nicht für
  die Melodie. 36 Treffer betreffen Melodien, die hier als geschützt oder
  ungeklärt gelten (etwa EG 154, 435, 454) – die CC0-Angabe macht sie nicht
  frei. MIDI enthält oft weder Takt- noch Tonart und keine Notenschreibweise;
  eine Umwandlung braucht Nacharbeit. In zwei Stichproben lag die Melodie
  einmal in einer eigenen Spur, einmal mit anderen Stimmen zusammen.
- **Regionalteile:** 36 Dateien der Kategorie gehören zu keinem Stammteil-Lied,
  viele nennen eine Regionalteil-Nummer. Die Quelle trägt also auch später.

### Deutschsprachige Wikipedia

[Liste der Kirchenlieder im Evangelischen Gesangbuch](https://de.wikipedia.org/wiki/Liste_der_Kirchenlieder_im_Evangelischen_Gesangbuch)
(Version 269509944): 187 Stammteil-Lieder haben einen Artikel, 42 davon
enthalten Noten als LilyPond-Quelltext (`<score>`). Lizenz der Artikeltexte:
CC BY-SA 4.0 (Namensnennung, Weitergabe unter gleichen Bedingungen). Die
Blöcke enthalten teils nur die Melodie, teils fremde Sätze (etwa Silcher bei
EG 1). Nur für vier Lieder (EG 2, 22, 43, 337) ist das die einzige Quelle.
Wertvoll sind die Artikel vor allem als Beleg für Melodiegeschichte und
Fassungen. Das Repository hat noch keine Lizenzdatei; ob CC-BY-SA-Material
darin weitergegeben werden kann, ist vorher zu entscheiden.

### Open Hymnal Project

[openhymnal.org](http://openhymnal.org/), Spiegel
[mzealey/openhymnal](https://github.com/mzealey/openhymnal) (Commit
`d35811b`, Januar 2017; die Website wird weiter gepflegt): 305 ABC-Dateien,
vierstimmig, mit englischen Texten. Das Projekt versteht seine Inhalte als
frei weiterverwendbar; eine Lizenzdatei hat der Spiegel nicht, und maßgeblich
ist dort die Rechtslage der USA. Über gleichlautende Melodienamen finden sich
51 Lieder des Stammteils – **alle sind schon durch Commons gedeckt**. Die
Fassungen sind oft die im englischen Sprachraum üblichen (ausgeglichener
Rhythmus). Nutzen: Vorlage für sauberes ABC, Gegenprobe.

### Zahn, Die Melodien der deutschen evangelischen Kirchenlieder (1889–1893)

Sechs Bände, digitalisiert von der Bayerischen Staatsbibliothek, z. B.
[Band 1](https://archive.org/details/1508283124bsb11304498) auf archive.org.
Johannes Zahn starb 1895; das Werk ist gemeinfrei. Es bietet die Melodien
einstimmig nach den ältesten Drucken und ist die naheliegende Vorlage für die
65 Lieder mit gemeinfreier Melodie ohne gefundene Datei sowie zum Gegenlesen.
Nur Scans, kein maschinenlesbarer Bestand; die Melodien müssten abgeschrieben
werden. Ein Abgleich mit der Liedliste wurde nicht durchgeführt.

### Geprüft, aber nicht als Grundlage geeignet oder nicht abgeglichen

| Quelle | Befund |
|---|---|
| Bach-Choräle ([craigsapp/bach-370-chorales](https://github.com/craigsapp/bach-370-chorales), music21) | Sätze gemeinfrei, Lizenz der Datensätze nicht eindeutig (GitHub: „other“); Melodien in Bachs Fassung, nicht in der des EG. Allenfalls später für vierstimmige Sätze. |
| IMSLP, CPDL (ChoralWiki), Mutopia | Lizenz je Ausgabe verschieden; einzelne Choräle, keine Zuordnung zu EG-Nummern. Nicht systematisch abgeglichen. |
| Hymnary.org, CCEL | Automatischer Abruf wird abgewiesen (HTTP 403); Seitenscans mit je eigenem Rechtsstatus. Nicht abgeglichen. |
| Wikibooks „Liederbuch“ | 142 Seiten mit LilyPond-Noten (CC BY-SA), überwiegend Volkslieder. Nicht abgeglichen. |
| Digitalisate historischer Gesangbücher (DDB, BSB, Landesbibliotheken) | Für Einzelfälle brauchbar; Nutzungsbedingungen der Digitalisate je Bibliothek prüfen. Kein Datensatz. |
| Evangelisches Gesangbuch, Begleitbücher, Verlagsausgaben | Geschützte Ausgaben; keine Vorlage. |

Einen offenen, maschinenlesbaren Datensatz, der den Stammteil als Noten
(ABC, MusicXML, LilyPond) abdeckt, hat die Recherche nicht gefunden. Am
nächsten kommt die Commons-Kategorie.

## 5. Format für die App

| | ABC | MusicXML | LilyPond | fertiges SVG | PDF | MIDI |
|---|---|---|---|---|---|---|
| Größe je Melodie (grobe Richtwerte) | < 1 KB | 20–100 KB | 1–2 KB | 20–80 KB | 30–100 KB | 2–8 KB |
| von Hand pflegbar, im Diff lesbar | sehr gut | kaum | gut | nein | nein | nein |
| mehrstimmig | bis vierstimmiger Choral gut | sehr gut | sehr gut | – | – | ja, ohne Notenbild |
| Darstellung in Flutter | nur über Vorab-Rendern oder WebView | Pakete vorhanden, jung | nur Vorab-Rendern | `flutter_svg`, alle Plattformen | Zusatzpaket | keine |
| kleine Bildschirme, Zoom | Umbruch beim Rendern wählbar | abhängig vom Paket | Umbruch beim Rendern wählbar | scharf, zoombar | starrer Umbruch | – |
| Integrationsaufwand | gering | hoch | mittel (Werkzeug im Build) | gering | mittel | – |

**Empfehlung:** ABC als gepflegte Quelle im Repository, daraus beim Import
SVG erzeugen (abc2svg oder abcm2ps, schmale Seitenbreite für Telefone) und in
der App mit `flutter_svg` in einem `InteractiveViewer` anzeigen. Das läuft
ohne Netz auf allen Plattformen der App, die Quelle bleibt prüfbar, und die
MIDI-Vorlagen lassen sich mit `midi2abc` vorbefüllen. `flutter_svg` wäre eine
neue Abhängigkeit. Die Bundle-Größe (grob 200 Melodien × 20–80 KB) sollte am
Pilot gemessen werden. Laufzeit-Renderer (`verovio_flutter` – nur Android,
iOS, Web; `flutter_notemus`, `crisp_notation`) sind jung und erst sinnvoll,
wenn Transponieren oder Mitlaufen gewünscht ist; MusicXML erst, wenn
vierstimmige Sätze aus fremden Beständen übernommen werden sollen.

## 6. Vorgehen

1. **Regeln abnehmen.** Die Einstufungsregeln und den Weg „eigener Notensatz
   der gemeinfreien Melodie“ einmal fachkundig bestätigen lassen; dabei auch
   die Lizenz des Repositorys festlegen.
2. **Datenmodell.** Melodien bekommen eine eigene Kennung, unabhängig von der
   EG-Nummer (viele Lieder teilen eine Melodie; Regionalteile und ein neues
   Gesangbuch nummerieren anders). Vorschlag: `assets/hymn_scores/<melodie>.abc`
   und eine Zuordnung Lied → Melodie mit Herkunftsnachweis (Quelle, Prüfsumme,
   Lizenz, geprüft von/am). Für Regionalteile die Liedkennung um den Teil
   erweitern statt neue Nummernkreise zu erfinden.
3. **Pilot** mit 10–20 Liedern der Kategorie 1: Melodie aus der Commons-Datei
   übernehmen, als ABC setzen, an Zahn gegenlesen, rendern, in der App zeigen.
4. **Stufe 1 – 287 Lieder (198 Dateien):** Commons CC0/gemeinfrei, Melodie
   gemeinfrei. Halbautomatisch: MIDI → ABC-Rohfassung → Durchsicht.
5. **Stufe 2 – 26 Lieder:** Vorlage unter CC BY/CC BY-SA (24 Commons-Dateien,
   2 Wikipedia-Artikel). Die Melodie
   ist gemeinfrei; wird nur sie neu gesetzt, sollte die Dateilizenz nicht
   greifen – sicherer ist, Quelle und Lizenz zu nennen oder gleich nach Zahn
   zu setzen.
6. **Stufe 3 – 65 Lieder:** Melodie gemeinfrei, keine Datei. Nach Zahn oder
   einem gemeinfreien Gesangbuchdruck selbst setzen.
7. **Stufe 4 – 34 Lieder:** ungeklärt. Je Lied Urheber und Sterbejahr
   ermitteln (Liste mit Gründen in `auswertung.md`), dann neu einstufen.
8. **Stufe 5 – 123 Lieder:** Melodie geschützt. Nur mit Genehmigung der
   Rechteinhaber (meist Verlage) oder gar nicht. Jährlich neu auswerten:
   Zum Jahreswechsel werden weitere Melodien frei (EG 154 voraussichtlich 2029).
9. **Fortschritt:** Das Inventar ist die Liste. Für die Integration kommt je
   Lied ein Prüfvermerk hinzu; `test/hymn_scores_inventory_test.dart` hält
   fest, dass nichts als frei geführt wird, was die Daten nicht hergeben.
10. **Änderungen der Quellen:** `fetch_sources.py` erneut laufen lassen; der
    Diff von `quellen_snapshot.json` zeigt geänderte Prüfsummen, Lizenzen und
    Artikelversionen.

Notenunterlegung mit Text ist nur bei Liedern sinnvoll, deren Text ebenfalls
gemeinfrei ist (Kategorie 1: 339 Lieder); sonst die Melodie ohne Text zeigen.

## 7. Umsetzung in der App

Ziel ist die Ansicht eines aufgeschlagenen Gesangbuchs: Noten, darunter die
erste Strophe Silbe für Silbe, die übrigen Strophen nummeriert darunter. Die
Zahlen stehen in [`integration.md`](integration.md).

**Welche Lieder:** alle, denen das Inventar eine Commons-Vorlage zuordnet.
Der Projektinhaber hat die recherchierten Vorlagen freigegeben und die Rechte
nach eigener Angabe geklärt; Lieder, deren Melodie die Recherche als
geschützt oder ungeklärt führt, sind in `integration.md` eigens aufgelistet.
Liedtexte wurden nicht ergänzt: Wo die App keinen Text zeigt, stehen die
Noten ohne Text.

**Vom MIDI zum Notenbild** (`tool/hymn_scores/build_scores.py`):

1. `fetch_midi.py` lädt die Vorlagen nach `build/hymn_scores/midi/` und
   verwirft Dateien, deren Prüfsumme nicht zum Quellen-Schnappschuss passt.
2. `melody.py` zieht die Melodie der ersten Strophe heraus. Die Vorlagen sind
   mehrstrophige vierstimmige Sätze; genommen wird die Oberstimme bis zu der
   Stelle, an der die Melodie neu ansetzt. Die Silbenzahl der ersten
   Textstrophe grenzt die Suche ein. Was sich nicht sicher abgrenzen lässt
   (Vorspiele, Oberstimmen, Wechselgesänge), wird nicht integriert.
3. `syllables.py` zerlegt die erste Strophe in Sprechsilben (regelbasiert,
   mit einer Ausnahmeliste), `underlay.py` ordnet sie den Tönen zu.
4. `engrave.py` setzt Melodie und Text mit [Verovio](https://www.verovio.org/)
   als SVG: Bindebögen und Haltestriche bei Melismen, Trennstriche im Wort,
   Umbruch an den Zeilenenden des Textes (im Takt auch mitten im Takt, wie
   im Gesangbuch bei Auftakten), nie mitten im Wort. Taktstriche stehen nur,
   wo die Vorlage eine Taktart nennt und die Töne restlos in Takte passen.

**Silbenzuordnung – was gesichert ist und was nicht:** Die Vorlagen enthalten
keinen Text und keine Bögen. Unterlegt wird deshalb nur, wenn die Zuordnung
aufgeht:

- gleich viele Töne wie Silben: jede Silbe ein Ton;
- mehr Töne als Silben: nur, wenn kurze Töne die Überzahl restlos erklären
  (zwei kurze Töne auf einem Grundschlag; ein einzelner kurzer Ton nach
  einem längeren) oder eine gleich lange, bereits gelöste Zeile denselben
  Silbenrhythmus vorgibt;
- Zeilen enden, wo die Vorlage hörbar Luft lässt; in ein Wort darf keine
  Luft fallen.

Melismen aus gleich langen Tönen (etwa zwei Viertel auf einer Silbe) sind
aus den Vorlagen nicht zu erkennen. Solche Lieder bekommen die Melodie ohne
Text und einen Hinweis; der Liedtext steht dann wie bisher darunter. Geraten
wird nicht. Um diese Lieder zu unterlegen, braucht es je Lied die Angabe, auf
welchen Silben die Melismen liegen.

**Daten:** Jedes Lied in `assets/eg_lieder.json` kann ein Feld `scores`
tragen – eine Liste aus `id` (Kennung der Melodie), `asset`, `format`,
`kind`, `label`, `source` (Datei, Adresse, Urheber, Lizenz, Prüfsumme, Art
der Zuordnung) und, wenn Text unter den Noten steht, `underlay` mit der
Nummer der Strophe. Bilder mit Text gehören zu einem Lied
(`eg<Nr>_<Melodie>.svg`), Bilder ohne Text teilen sich Lieder gleicher
Melodie (`<Melodie>.svg`). Alle übrigen Felder schreibt das Skript
unverändert zurück.

**App:** `HymnDetailScreen` zeigt bei Liedern mit Noten die Umschaltung
„Nur Text“ / „Text und Noten“; die Wahl liegt in den `SharedPreferences`
(`HymnSettings`). `HymnScoreView` zeichnet die Bilder mit `flutter_svg` in
der Textfarbe des Themes, nennt darunter Vorlage und Lizenz und öffnet auf
Tipp eine vergrößerbare Ansicht. Steht eine Strophe unter den Noten, wird
sie darunter nicht wiederholt. Der Text in den Bildern ist echter Text in
der Schrift Tinos (`assets/fonts`, SIL OFL 1.1); Verovio hat mit ihren
Maßen gesetzt, darum liegt sie der App bei. Das Bild wird nur als Ganzes
skaliert, Silben und Noten können sich nicht gegeneinander verschieben.

**Geprüft:** Tests vergleichen für jedes Bild mit Text die Silben in
Leserichtung mit der ersten Strophe (vollständig, in Reihenfolge), prüfen,
dass kein Notensystem mitten im Wort beginnt, und lassen `flutter_svg` jedes
Bild lesen. Die laufende Web-App wurde in Chrome an mehreren Liedern
angesehen (schmal und breit, hell und dunkel, mit und ohne Unterlegung).

**Grenzen und bekannte Probleme:**

- Noten und Silbenzuordnung sind automatisch erzeugt und nicht einzeln am
  Gesangbuch Korrektur gelesen.
- Tonart und Notenwerte folgen der Vorlage, nicht dem Gesangbuch; Fermaten
  und Atemzeichen fehlen, Schlusstöne sind auf einen einfachen Notenwert
  gekürzt. Die meisten Bilder stehen in freiem Rhythmus ohne Taktstriche.
- Die Silbentrennung ist regelbasiert; die Trennstelle kann von der
  Schreibweise im Gesangbuch abweichen (etwa „Fen-ster“).
- Unterlegt ist nur die erste Strophe.
- Sehr lange Textzeilen werden in der Mitte an einer Wortgrenze auf zwei
  Notensysteme verteilt.
- Offen: die Lieder der Kategorien 2, 4 und 5 in `integration.md`.
