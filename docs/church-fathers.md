# Kirchenväter & Schriften

Bibliothek christlicher Autoren mit Suche, Filtern und Volltexten
gemeinfreier deutscher Übersetzungen; im Bibel-Reader dazu die
Versdetailansicht (Kirchenväter zur Stelle, verwandte Bibelstellen,
Perikopenkontext). Datenformat und Import: `tool/fathers/README.md`.

## Grundsätze

- **Nichts erfinden.** Texte, Ausgaben, Übersetzer und Bibelstellen-Zuordnungen
  stammen aus den Ausgaben selbst. Gibt es zu einem Vers keine Zuordnung,
  zeigt die App „noch kein Abschnitt“ und keinen Ersatz.
- **Keine KI-Texte.** Es gibt keine automatischen Übersetzungen oder
  Zusammenfassungen. Englische Kirchenväter-Texte werden nicht übersetzt.
- **Volltext nur bei geklärten Rechten.** Eine Fassung wird nur dann mit
  Text ausgeliefert, wenn alle Übersetzer eindeutig in der GND stehen und vor
  1956 gestorben sind (70 Jahre nach dem Tod, Stand 2026) oder eine
  begründete Ausnahme in `tool/fathers/curation/rights.json` steht. Sonst
  erscheinen nur Angaben und der Link zur Quelle.
- **Werk und Auszug getrennt.** Eine Zuordnung zeigt auf Absätze eines
  Abschnitts einer bestimmten Fassung; die Versdetailansicht zeigt einen
  gekürzten Auszug und führt zum vollständigen Werk an dieser Stelle.
- **Eine Referenzlogik.** Bibelstellen sind `BibleReference` in USFM-Kennung
  und deutscher Zählung der Perikopenliste; Umrechnung in die Zählung der
  gelesenen Ausgabe über `ListVersification`. Es gibt keine eigene
  Bibeldatenbank.
- **Kein Server.** Alles liegt unter `assets/fathers/` und wird erst bei
  Bedarf geladen (Web: je Datei ein Abruf; Android: aus dem Paket).

## Aufbau in der App

| Aufgabe | Ort |
|---|---|
| Modell: Autor, Werk, Fassung, Zuordnung, Inhaltsverzeichnis, Abschnitt, verwandte Stelle | `lib/models/fathers/fathers.dart` |
| Laden bei Bedarf, Zwischenspeicher (höchstens 12 Textdateien), Suche in einer Fassung | `lib/services/fathers/fathers_repository.dart` |
| Bibliothek: Suche, Filter (Gruppe, Epoche, Sprache, Gattung, nur lesbare) | `lib/screens/fathers/fathers_home_screen.dart` |
| Autor, Werk (Fassungen, Inhalt, Bibelstellen, Suche), Abschnitt | `lib/screens/fathers/author_screen.dart`, `work_screen.dart` |
| Volltextsuche über alle lesbaren Fassungen | `lib/screens/fathers/fulltext_search_screen.dart` |
| Versdetailansicht (aus dem Reader) | `lib/screens/fathers/verse_detail_sheet.dart` |
| Karten, Herkunftsangaben, Kennzeichen | `lib/widgets/fathers/fathers_widgets.dart` |
| Antippen eines Verses | `lib/widgets/bible/bible_chapter_view.dart` (`onVerseTap`) |
| Perikope eines Verses, synoptische Parallelen | `lib/services/bible/pericope_headings.dart` (`containing`, `sameIdElsewhere`) |
| Zählung der Ausgabe → Listenzählung | `lib/services/bible/versification_map.dart` (`toList`) |

Im Reader öffnet die Versnummer immer die Versdetailansicht, der Verstext
ebenfalls, solange er nicht hervorgehoben ist (dort bleibt das Antippen zum
Aufheben der Hervorhebung).

## Zuordnungsmodell

| Feld | Bedeutung |
|---|---|
| Art (`k`) | `sectionCommentary` – die Ausgabe nennt den ausgelegten Abschnitt; `verseCommentary` – Stellenangabe innerhalb dieses Abschnitts; `quotation` – Zitat/Anspielung mit Stellenangabe der Ausgabe; `reference` – „vgl.“-Verweis; `suggested` – vorgesehen für fremde Datensätze, derzeit nicht verwendet |
| Herkunft (`m`) | `editionHeading` (Überschrift/Einleitung der Ausgabe), `editionCitation` (Stellenangabe in Text oder Anmerkung), `manual` (redaktionell) |
| Sicherheit (`c`) | `high` eindeutig; `medium` Psalm nach Vulgata-Zählung umgerechnet, „Ebd.“; `low` 1/2 Kön. ohne erkennbare Zählweise |
| Prüfung (`review`) | gesetzt, wenn eine Zuordnung redaktionell geprüft ist |
| Rechte | stehen an der Fassung (`rights`, `rightsNote`), nicht an der Zuordnung |

## Quellenmatrix

Stand der Recherche: 24.10.2026. Abrufe von Hosts, die aus der Cloud nicht
erreichbar sind, liefen über eine Remote-Control-Sitzung auf dem PC des
Nutzers.

| Quelle | Inhalt | Rechte / Bedingungen | Verwendung |
|---|---|---|---|
| Bibliothek der Kirchenväter, bkv.unifr.ch (Univ. Freiburg/Schweiz) | 817 Werke, 1650 Fassungen, davon 617 deutsch (BKV 1831–1938); Text je Abschnittsseite | Anbieter hält die Texte nach seinem Wissen für urheberrechtsfrei, übernimmt aber keine Gewähr. `robots.txt` sperrt KI-Agenten für `/files/` (EPUB/RTF/PDF), Scans und `/loris/`, Crawl-delay 10 s | Katalog vollständig vorgesehen; Volltext nur gemeinfreier Fassungen (GND-Prüfung der Übersetzer). Abruf nur der erlaubten Abschnittsseiten im 10-s-Takt, keine Exporte |
| Catena Bible (catenabible.com, AD30 Inc.) | englische Väterzitate je Vers | keine Lizenz- oder API-Angabe; proprietäre App; `robots.txt` erlaubt nur `Claude-User` | nur als Vorbild für die Bedienung; keine Daten übernommen |
| HistoricalChristianFaith Commentaries-Database (GitHub) | englische Väterzitate je Vers | gemischt: gemeinfreie Übersetzungen und urheberrechtlich geschützte Auszüge („fair use“) | nicht übernommen (englisch, Rechte gemischt) |
| OpenBible.info Cross References | 344 799 Verweise mit Nutzerbewertung, KJV-Zählung | CC BY, Kopf „#www.openbible.info CC-BY 2024-11-04“ | 198 933 Verweise mit mindestens 3 Stimmen, je Vers höchstens 60, in deutsche Zählung umgerechnet; Quelle in der App genannt |
| STEPBible-Daten | Lexika, Morphologie | CC BY | kein Väter- oder Verweisdatensatz; nicht verwendet |
| GND (lobid.org) | Lebensdaten der Übersetzer | CC0 | Rechteprüfung der Übersetzungen |
| Perikopenliste der App (`assets/perikopen.json`) | Perikopen, synoptische Zuordnung | eigene Daten | Perikopenkontext, synoptische Parallelen |
| Bekenntnisse der App (`assets/confessions.json`) | Konkordienbuch | siehe `docs/content-rights-review.md` | Verweise aus Luthers und Melanchthons Werken auf die vorhandenen Texte |

## Autoren

Getrennt eingeordnet (`AuthorCategory`): Kirchenväter (bis etwa 750),
mittelalterliche Theologen, Reformatoren, lutherische Theologen nach der
Reformation. Die BKV-Autoren gelten als Kirchenväter, sofern
`curation/bkv_authors.json` nichts anderes sagt; die übrigen Autoren pflegt
`curation/later_authors.json` (Anselm, Bernhard, Petrus Lombardus, Thomas,
Nikolaus von Lyra; Luther, Melanchthon, Bugenhagen, Calvin; Chemnitz,
Johann Gerhard, Bengel). Ihre Werke sind derzeit nur verzeichnet, außer
den Bekenntnisschriften, die auf den Bereich Bekenntnisse verweisen.

## Stand der Daten und Beschaffungsliste

Ausgeliefert sind derzeit:

- die redaktionell gepflegten Autoren und Werke (12 Autoren, 25 Werke, davon
  6 mit Verweis auf die Bekenntnisse),
- die verwandten Bibelstellen (OpenBible, 66 Bücher mit Verweisen).

**Noch nicht ausgeliefert: die BKV-Texte.** Der Abruf der freigegebenen
Abschnittsseiten läuft auf dem PC des Nutzers (etwa 3 900 Seiten im
10-s-Takt). Ausgewählt nach Rechtelage und Nutzen für die Auslegung:

| Werk (Schlüssel der BKV) | Übersetzer (GND) | Lage |
|---|---|---|
| Tertullian (CPL 7) | Karl Adam Heinrich Kellner † 1915 | gemeinfrei |
| Justin, Apologien (CPG 1073a/b) | Gerhard Rauschen † 1917 | gemeinfrei |
| Augustinus, Vorträge über das Johannesevangelium (CPL 278) | Thomas Specht † 1918 | gemeinfrei |
| Ambrosius, Lukaskommentar (CPL 143) und CPL 123 | Johann Ev. Niederhuber † 1932 | gemeinfrei |
| Johannes Chrysostomus (CPG 4427) | Josef Jatsch † 1932 | gemeinfrei |
| Irenäus, Gegen die Häresien (CPG 1306) | Ernst Klebba † 1930 | gemeinfrei |
| Augustinus (CPL 251) | Alfred Hofmann (1879–1950) – GND-Zuordnung nur wahrscheinlich | bis zur Klärung nur Link (`curation/rights.json`) |

Ob ein Werk als ganz oder teilweise lesbar gilt, entscheidet der Import nach
den tatsächlich abgerufenen Abschnitten (`availability`).

Nicht übernommen, weil der Übersetzer nach 1955 starb (Baur, Haeuser,
Stegmann, Fritz Hofmann), nicht eindeutig bestimmbar ist (Zeller, Julius
Baer, Steeger) oder nicht genannt wird (Basilius, Hexaemeron; Gregor von
Nyssa, Vaterunser; Augustinus, De doctrina christiana und Enchiridion).
In der BKV nicht deutsch vorhanden: CPL 279, CPL 274, CPG 4425, CPG 4409,
Gregor d. Gr., Homiliae in Evangelia.

Für die späteren Autoren fehlen geprüfte gemeinfreie Ausgaben in
maschinenlesbarer Form (z. B. Luther-Auslegungen der Walch-Ausgabe,
Bengels Gnomon in einer deutschen Übersetzung des 19. Jahrhunderts). Sie sind Kandidaten für
eine spätere Beschaffung; bis dahin sind die Werke nur verzeichnet.

## Grenzen

- Die Zuordnung „Auslegung des Abschnitts“ setzt voraus, dass die Ausgabe
  den ausgelegten Abschnitt am Anfang einer Einheit nennt („Über die Stelle
  …“, „… bis dahin …“). Ausgaben ohne solche Angabe liefern nur Zitate und
  Verweise.
- Psalmen nach Vulgata-Zählung werden kapitelweise umgerechnet; Vulg. Ps 9,
  113–115 und 146/147 lassen sich ohne hebräische Angabe nicht sicher
  zuordnen und entfallen.
- Verwandte Stellen (OpenBible) sind gemeinschaftlich bewertete Vorschläge,
  keine Auslegung; die App zeigt die Bewertung.
