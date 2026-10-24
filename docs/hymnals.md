# Gesangbücher und Liedsammlungen

Stand: 16. Oktober 2026. **Keine Rechtsberatung.** Ergänzt
[`hymn-scores/README.md`](hymn-scores/README.md), das die Noten des Stammteils
beschreibt.

## Überblick

| Sammlung | Stand | In der App | Grundlage |
|---|---|---|---|
| EG – Stammteil (Nr. 1–535) | vollständig | 535 Lieder, 446 mit Text, 336 mit Noten | `assets/eg_lieder.json` (unverändert) |
| EG – Regionalteil Niedersachsen und Bremen | teilweise | 8 Lieder, nur Nummer, Titel, Melodieangabe | Commons-Dateibeschreibungen |
| EG – Regionalteil Bayern und Thüringen | teilweise | 5 Lieder, ebenso | Commons-Dateibeschreibungen |
| EG – Regionalteil Rheinland, Westfalen und Lippe | teilweise | 2 Lieder, ebenso | Commons-Dateibeschreibungen |
| EG – Regionalteil Baden und Pfalz | teilweise | 1 Lied, ebenso | Commons-Dateibeschreibung („Baden/Pfalz“) |
| EG – Regionalteil Nordelbien (Nordkirche: Hamburg, Schleswig-Holstein) | noch nicht integriert | nur Beschreibung | keine zulässige Quelle mit Nummern |
| EG – Regionalteil Mecklenburg und Pommern (Nordkirche) | noch nicht integriert | nur Beschreibung | keine zulässige Quelle |
| Ergänzungsheft zum EG (EG.E, 2018) | teilweise | 15 von 32 Liedern, nur Nummer und Titel | Wochenlieder im liturgischen Kalender der App |
| Geistlicher Liederschatz (Brüdergemeinden) | teilweise | 1300 Nummern (1304 Einträge) mit Titel, Textdichter, Melodieangabe und Text (außer Nr. 343, 344, 447, 563), ohne Noten | evangeliums.net; Texte freigegeben von der Kirchlichen Gemeinschaft |

„Stand“ steht so auch in der App (`status` in `assets/hymnals/catalog.json`);
ein Test hält fest, dass er zu den Daten passt (vollständig = alle Lieder,
noch nicht integriert = keine Lieder).

## Regionalteile

Das EG erscheint in regionalen Ausgaben: Stammteil Nr. 1–535, ab Nr. 536 ein
Regionalteil der jeweiligen Landeskirche(n). Die Regionalteile haben
unterschiedlichen Umfang und Aufbau (teils mit liturgischen Stücken in
eigenen Nummernbereichen, etwa „786.5“).

**Rechtslage.** Der Nachdruck des EG oder einzelner Stücke bedarf der
Genehmigung der Herausgeber; die Texte und Notensätze der Regionalteile
sind überwiegend neueren Datums und geschützt. Ein offener Datensatz mit
Inhaltsverzeichnis, Texten oder Noten eines Regionalteils wurde nicht
gefunden. Nicht verwendet wurden deshalb: Verlagsausgaben, das lizenzpflichtige
digitale Gesangbuch der EKD, Begleitbücher, Scans gedruckter Ausgaben,
Liederdatenbanken Dritter.

**Was integriert ist.** Die Commons-Kategorie „Melodies from Evangelisches
Gesangbuch“ (schon Quelle der Stammteil-Noten) nennt bei einigen Dateien
Ausgabe und Nummer eines Regionalteils, etwa „Harre, meine Seele, Evang.
Gesangbuch (Niedersachsen) 593“. Nur diese Angaben werden übernommen –
Nummer, Titel (aus dem Dateinamen), Melodieangabe der Datei und, wo die
Beschreibung ihn nennt, der Dichter. Jedes Lied trägt den Wortlaut der
Beschreibung als Beleg (`source.statement`), sichtbar in der Liedansicht.

**Was fehlt.** Texte und Noten: Die Fassung der Regionalteile liegt nicht
vor, und ein Text aus anderer Quelle könnte von ihr abweichen. Noten aus den
Commons-Dateien wären bei gemeinfreien Melodien möglich (wie im Stammteil),
brauchen aber die MIDI-Dateien und den Weg aus `tool/hymn_scores`; die
Unterlegung der ersten Strophe setzt einen Text der richtigen Fassung voraus.
Lieder ohne Nummer in der Quelle („Der Tag, der ist so freudenreich“ –
Regionalteile Baden/Elsass/Lothringen, Nordelbien, Pfalz, Württemberg;
„Vom Himmel hoch, o Engel, kommt“; „Wer leben will wie Gott“) und eine
Melodie, die die Quelle nur als Melodie für einen anderen Text nennt
(„O Gott, du frommer Gott“, dritte Melodie, Bayern/Thüringen 643), sind
nicht aufgenommen.

**Norddeutscher Kontext.** In der Nordkirche gelten die Ausgaben der
früheren Landeskirchen weiter: Nordelbien (Hamburg, Schleswig-Holstein) sowie
Mecklenburg und Pommern. Beide sind verzeichnet, aber ohne Lieder, weil keine
frei nutzbare Quelle ihre Nummern nennt. Niedersachsen/Bremen ist der
nächstgelegene Regionalteil mit Einträgen.

Weitere Regionalausgaben (u. a. Hessen, Kurhessen-Waldeck, Sachsen,
Württemberg, Mitteldeutschland, Österreich, Reformierte) sind im Katalog noch
nicht angelegt: Die Recherche konnte ihre genaue Zahl und Abgrenzung nicht
aus einer Primärquelle belegen (14 Ausgaben laut Sekundärquellen).

## Ergänzungsheft (EG.E)

„Ergänzungsheft zum Evangelischen Gesangbuch“ zur Perikopenordnung von 2018:
32 neue Wochenlieder, die nicht im Stammteil stehen (Zentrum Verkündigung der
EKHN, „Informationen zu den neuen Wochenliedern“). Die Lieder sind neuere
Werke und geschützt. Die App verzeichnet Nummer und Titel der 15 Lieder, die
ihr liturgischer Kalender nennt; der Test „Ergänzungsheft“ prüft, dass beides
übereinstimmt. Weitere Ergänzungshefte und Beihefte einzelner Landeskirchen
sind nicht aufgenommen (keine zulässige Quelle).

## Geistlicher Liederschatz

Gemeint ist das Gesangbuch der evangelisch-lutherischen Brüdergemeinden
(Kirchliche Gemeinschaft e.V., Bad Sooden-Allendorf): Textausgabe 1989,
Notenausgabe 2000, Jubiläumsausgabe 2020, 1300 Lieder. Bibliografie,
Quellen und Prüfstatus stehen in `docs/liederschatz/`.

**Rechte.** Conner am 24. Oktober 2026: „Die Kirchliche Gemeinschaft hat mir
die Texte für die App freigegeben.“ Darauf beruht die Übernahme der Texte; ein
schriftlicher Beleg liegt im Repository nicht vor. Fünf Texte sind jünger als
1957 (Nr. 224, 323, 346, 567, 1211); ob die Freigabe auch Rechte Dritter
(Verlage, Erben) abdeckt, ist am Einzelfall zu prüfen.

**Was integriert ist.** `assets/hymnals/geistlicher_liederschatz.json`
erzeugt `python tool/liederschatz/build_liederschatz.py`:

- Grundlage für jede Nummer sind Nummer, Titel und Textdichter aus dem
  Inhaltsverzeichnis von evangeliums.net.
- Liedtext und Melodieangabe kommen von der jeweiligen Liedseite
  (`tool/liederschatz/quellen/liedtexte.json`, abgerufen am 24. Oktober 2026).
  Der Wortlaut kann von der gedruckten Ausgabe abweichen. Alternative
  Textfassungen der Seite sind nicht übernommen; was beim Übernehmen bereinigt
  wurde, steht beim Lied (`lyricsNote`).
- Vier Seiten zeigen keinen Text (Nr. 343, 344, 447, 563).
- Unter Nr. 108, 116, 153 und 201 führt die Quelle je zwei Lieder. Das zweite
  heißt in der App „108a“ usw.
- Noten fehlen; die Notenausgabe 2000 liegt nicht digital vor.

**Nicht gemeint: Berliner Liederschatz.** Der Katalogeintrag
`geistlicher_liederschatz` beschrieb bis dahin ein anderes Werk mit gleichem
Titel. Die Angaben dazu bleiben hier zur Abgrenzung:

*Geistlicher Liederschatz. Sammlung der vorzüglichsten
geistlichen Lieder für Kirche, Schule und Haus und alle Lebensverhältnisse*,
Berlin: Samuel Elsner 1832 (xxxi, 920, 72 S.; mit Dichterbiographien und
Gebeten), der sogenannte Berliner Liederschatz. Weitere Auflagen: 2. Aufl.
1840 (XVI, 800 S.), 1842, 1846 (xvi, 816 S.). Der Herausgeber starb 1856; das
Werk ist gemeinfrei. Es enthält Texte, keine Noten.

Ähnliche Titel, nicht gemeint: Albert Knapp, *Evangelischer Liederschatz für
Kirche und Haus* (1837 ff.); *Christen-Lieder … Evangelischer Liederschatz für
Kirche, Schule und Haus* (Stuttgart: Steinkopf 1841).

Digitalisate: HathiTrust (Ausgabe 1832), Internet Archive (`geiliede00berl`,
Ausgabe 1846), Münchener Digitalisierungszentrum (`bsb10592427`), Google
Books (HathiTrust Record/009717778, BSB bsb10592427, Google Books
id=6CsLAAAAYAAJ). Die Nutzungsbedingungen
der Digitalisate sind je Bibliothek zu prüfen (der Text selbst ist frei).

**Warum er nicht integriert war:** Die Digitalisate sind Seitenscans in Fraktur;
eine maschinenlesbare, geprüfte Abschrift mit Liednummern gibt es nicht.
Texte aus dem Gedächtnis, aus anderen Ausgaben oder aus heutigen Gesangbüchern
einzusetzen, hätte eine andere Fassung als die des Liederschatzes ergeben. Bei
dieser Umsetzung waren die Bibliotheksserver zudem aus der Arbeitsumgebung
nicht erreichbar.

## Datenmodell

`assets/hymnals/catalog.json` beschreibt Gruppen und Sammlungen:

| Feld | Bedeutung |
|---|---|
| `id` | eindeutige Kennung, `eg` = Stammteil |
| `group` / `part` | Gruppe (`eg`, `other`) und Art (`core`, `regional`, `supplement`, `collection`) |
| `title`, `fullTitle`, `shortTitle` | Anzeige; `shortTitle` in Suchergebnissen und Filtern |
| `numberPrefix` | „EG“, „EG.E“ … |
| `region`, `edition`, `year`, `expectedCount` | Angaben zur Ausgabe, soweit belegt |
| `asset` | Datei mit den Liedern; fehlt bei Sammlungen ohne Lieder |
| `status`, `statusNote`, `description` | Stand der Integration und Begründung |
| `lyricsNote` | Hinweis bei Liedern ohne Text |
| `sources` | Quellen und Digitalisate mit Lizenzangabe |

Die Lieder jeder Sammlung haben das Format von `assets/eg_lieder.json`
(unverändert). Neu und optional sind:

| Feld | Bedeutung |
|---|---|
| `number` | Nummer in der Sammlung als Text („786.5“); fehlt sie, gilt `id` (Stammteil) |
| `workId` | gleiche Kennung = sicher dasselbe Lied in einer anderen Sammlung |
| `lyricsNote` | eigener Hinweis, warum kein Text angezeigt wird |
| `source` | Herkunft der Angaben: `name`, `file`, `url`, `statement` (Wortlaut), `license` |

In der App ist `Hymn.key` (`<Sammlung>:<Nummer>`) über alle Sammlungen
eindeutig; `Hymn.id` bleibt die EG-Nummer des Stammteils, damit Kalender,
Deep Links und gespeicherte Einstellungen unverändert funktionieren.

**Fassungen.** Jede Fassung bleibt ein eigener Eintrag mit eigener Nummer und
Quelle; nichts wird zusammengeführt. `workId` verknüpft Fassungen, wenn ihre
Identität belegt ist – derzeit nur „Bevor des Tages Licht vergeht“
(Niedersachsen/Bremen 786.5, Bayern/Thüringen 665: dieselbe Commons-Datei
nennt beide Nummern). Die Liedansicht zeigt dann „Auch enthalten in“.
Gleiche Nummer oder ähnlicher Titel allein verknüpft nicht.
`tool/hymnals/build_hymnals.py` meldet Titel, die auch im Stammteil
vorkommen; derzeit keine.

## Suche

`HymnSearchIndex` (`lib/services/hymn_search.dart`) durchsucht alle geladenen
Lieder: Nummer (auch mit Vorsatz: „EG 23“, „EG.E 10“, „786,5“), Titel,
Liedanfang, alle Strophen, Text- und Melodieangabe, Schlagworte und
Bibelstellen. Groß-/Kleinschreibung, Umlaute (ü = u = ue) und Satzzeichen
spielen keine Rolle; mehrere Wörter müssen alle vorkommen. Rangfolge: genaue
Nummer, Titel, Liedanfang, Angaben, Liedtext; bei Treffern im Text steht die
Fundstelle („Str. 3: …“) im Ergebnis. Gleichwertige Treffer folgen der
Reihenfolge des Katalogs.

Die globale Suche („Gesangbücher“ auf dem Startbildschirm) zeigt bei jedem
Treffer die Sammlung. Filter: Alle, Evangelisches Gesangbuch, Stammteil,
Regionalteile, je Regionalteil, Ergänzungsheft, Geistlicher Liederschatz.
Jede Sammlung hat zusätzlich ihre eigene Liste mit derselben Suche. Lässt
sich eine Sammlung nicht laden, nennt die Übersicht sie; die übrigen bleiben
durchsuchbar.

## Noten und erste Strophe

Unverändert der Weg des Stammteils (`HymnScoreView`, Feld `scores`): Noten
als SVG in der Textfarbe des Themes, die erste Strophe nur dann unter den
Noten, wenn die Silbenzuordnung belegt oder zwingend ist, die übrigen
Strophen nummeriert darunter. Neue Sammlungen nutzen denselben Viewer, sobald
ihre Lieder `scores` tragen. Derzeit hat keines der neuen Lieder Noten oder
Text; die Ansicht zeigt dann Nummer, Sammlung, Angaben, den Hinweis und die
Quelle – keine Umschaltung, kein leerer Platzhalter.

## Erzeugen

```
python tool/hymnals/build_hymnals.py
```

Ohne Netz, aus `docs/hymn-scores/quellen_snapshot.json` und
`assets/liturgical_calendar_2026.json`. Das Skript bricht ab, wenn eine
Beschreibung die eingetragene Nummer nicht wörtlich enthält.
