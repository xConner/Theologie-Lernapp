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
- **Volltext nur bei geklärten Rechten.** Eine Fassung wird mit Text
  ausgeliefert, wenn alle Übersetzer eindeutig in der GND stehen und vor
  1956 gestorben sind (70 Jahre nach dem Tod, Stand 2026; `publicDomain`)
  oder eine Nutzungserlaubnis der Rechteinhaber vorliegt (`permission`).
  Für die deutschen BKV-Fassungen hat der Betreiber der App (Conner) am
  24.10.2026 erklärt, diese Erlaubnis aller Rechteinhaber zu haben; die
  Belege liegen bei ihm, eingetragen ist das als `default` in
  `tool/fathers/curation/rights.json`. Die App nennt bei jeder Fassung, ob
  sie gemeinfrei ist oder mit Erlaubnis erscheint. Texte unklarer Herkunft
  (ohne Übersetzer und Ausgabe) werden nicht übernommen.
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

Dazu die BKV-Texte, die als EPUB-Export vorliegen (von Hand
heruntergeladen, weil `robots.txt` KI-Agenten die Exporte sperrt; Import
siehe `tool/fathers/README.md`):

| Werk | Fassung (BKV) | Übersetzer | Rechte |
|---|---|---|---|
| Ambrosius, Exameron (CPL 123) | BKV 1. Reihe, Bd. 17, München 1914 | Joh. Ev. Niederhuber † 1932 | gemeinfrei |
| Basilius, Homilien über das Hexaemeron (CPG 2835) | BKV 1. Reihe, Bd. 47, 1925 | in der Ausgabe nicht genannt | Nutzungserlaubnis |
| Basilius, Einleitung zum Hexaemeron (Einleitung der Ausgabe, kein Text des Basilius; ohne Bibelstellen-Zuordnungen) | ebd. | – | Nutzungserlaubnis |
| Gregor von Nyssa, Über die Ausstattung des Menschen (CPG 3154) | BKV 1. Serie, Bd. 24, Kempten 1874 | Heinrich Hand | Nutzungserlaubnis |

Beim Exameron nennen die Überschriften der Ausgabe die ausgelegten
Verse („IV. Kapitel. ‚Im Anfang‘ (Gen 1,1)“); daraus entstehen die
Zuordnungen „Auslegung des Abschnitts“. Bei Basilius und Gregor fehlen
solche Angaben; dort gibt es nur Zitate und Verweise aus den Anmerkungen.

Auf Conners ausdrücklichen Wunsch aufgenommen, aber deutlich
gekennzeichnet: Johannes Chrysostomus, Homilien 1–3 über die Genesis (CPG
4409), aus drei PDF-Drucken einer Webseite (`tool/fathers/pdf_text.py`,
Angaben in `curation/pdf_texts.json`). Die Drucke nennen weder Übersetzer
noch Vorlage; ihr Wortlaut folgt der englischen Übersetzung von R. C. Hill
(1986) und ist vermutlich maschinell übertragen. Die App zeigt die Fassung
als „Übersetzung unbekannter Herkunft“ (`TextKind.unknownTranslation`) mit
dieser Erklärung; die Zwischenüberschriften der Drucke entfallen, die
Bibelstellen der Drucke (englische Zählung) sind umgerechnet und haben
höchstens mittlere Sicherheit.

Der ältere Weg über einzelne Abschnittsseiten der BKV (10-s-Takt, PC des
Nutzers) ist im Import weiter enthalten, wird aber nicht mehr verfolgt.

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
