# UnivIS-Anbindung: Machbarkeitsprüfung

Stand: 14.10.2026. Ziel: Veranstaltungen aus UnivIS (zuerst CAU Kiel)
automatisch in der App suchen, filtern und in einen persönlichen
Stundenplan übernehmen, ohne dass Studierende UnivIS öffnen oder etwas
exportieren.

Kennzeichnung in diesem Bericht:

* **Live bestätigt** – am 14.10.2026 selbst gegen `univis.uni-kiel.de`
  abgerufen (Abschnitt 4).
* **Bestätigt** – in einer offiziellen Quelle belegt.
* **Indiziert** – durch öffentlich indexierte Kieler URLs oder Clients
  Dritter belegt, aber nicht selbst abgerufen.
* **Annahme** – plausibel, noch ungeprüft.
* **Offen** – ließ sich nicht klären.

## 1. Kurzfazit

**Ja: Der automatische Abruf ohne manuellen Export funktioniert. Er ist
live bestätigt.**

* `https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&department=010000000`
  liefert ohne Anmeldung den Katalog der **Theologischen Fakultät für das
  WS 2026/27** als XML: 150 Veranstaltungen, 207 Termine, 408 KB, ~1,2 s
  (live bestätigt).
* Die Organisationsnummer `010000000` stammt aus UnivIS selbst
  (`search=departments`, Element `orgnr`), nicht geraten.
* Titel, Typ, SWS, Veranstaltungsnummer, Gliederung des
  Vorlesungsverzeichnisses, Lehrpersonen, Räume, Uhrzeiten, wöchentliche
  und einzelne Termine sowie Ausnahmedaten sind maschinenlesbar und
  vollständig über Verweise auflösbar (0 offene Verweise).
* Die PRG-Schnittstelle ist von der CAU selbst für das Einbinden in eigene
  Webseiten dokumentiert. **Nutzungsbedingungen für Dritte gibt es keine
  auffindbaren**; vor einer dauerhaften Nutzung ist eine **Rückfrage bei der
  CAU** nötig (Entwurf in Abschnitt 9).
* **Lebensdauer begrenzt:** Die CAU plant, UnivIS mit dem
  Veranstaltungsmanagement von HISinOne abzulösen (nach der
  Prüfungsverwaltung, deren Umstellung laut Gemeinsamem Prüfungsamt bis
  spätestens WiSe 2029/30 laufen soll). Die Anbindung muss deshalb hinter
  einem austauschbaren Adapter liegen.
* Die Cloud-Entwicklungsumgebung erreicht UnivIS nicht (Netzwerksperre);
  die Live-Tests liefen deshalb über GitHub Actions
  (`.github/workflows/univis-probe.yml`).

**Empfehlung:** Ansatz B (PRG/XML) über einen serverseitigen Adapter,
parallel Ansatz E (Freigabe bei der CAU anfragen). Kein HTML-Scraping.

## 2. Geprüfte Quellen

Die Dokumentationsseiten waren aus der Entwicklungsumgebung nicht direkt
erreichbar; ihre Angaben stammen aus der Websuche (Inhalte indexierter
Seiten) und aus dem Quelltext eines veröffentlichten Clients (npm-Paket).
Seiten der CAU zur UnivIS-Schnittstelle sind teils viele Jahre alt. Die
Schnittstelle selbst ist live geprüft (Abschnitt 4).

**UnivIS an der CAU**

| Quelle | Inhalt |
|---|---|
| https://univis.uni-kiel.de/ | UnivIS der CAU („Produkt der Config Informationstechnik eG“) |
| https://www.uni-kiel.de/univis-kiel-misc/prg/ | Kieler Doku „PRG Schnittstelle“ |
| https://www.uni-kiel.de/univis-kiel-misc/prg/prg.htm | „Einbinden von Univis Daten in eigene Internetseite mittels PRG-Schnittstelle“ |
| https://www.uni-kiel.de/univis-kiel-misc/prg/prg_ueberblick.htm | Aufbau der Abfragen, Module und Parameter |
| http://www.uni-kiel.de/univis-kiel-misc/prg/org_nummern.htm | Eindeutige Abfragen über neunstellige Organisationsnummern |
| http://www.uni-kiel.de/univis-kiel-misc/prg/prg_type.htm | Suche nach Veranstaltungstypen (`type=`) |
| https://univis.uni-kiel.de/userman.pdf | Benutzerhandbuch (Redesign); XML-Export „sofern in der Installation konfiguriert“ |
| http://www.uni-kiel.de/univis-kiel-misc/ansprechpartner.html | UnivIS-Ansprechpartner der CAU |
| https://univis.uni-kiel.de/formbot/dsc_3Danew_2Fkontakt | Kontakt: UnivIS-Projektgruppe, `univis@univis.uni-kiel.de` |
| https://www.rz.uni-kiel.de/de/angebote/univis/univis | Rechenzentrum: UnivIS als Online-Vorlesungsverzeichnis |

**UnivIS allgemein (andere Installationen, gleiche Software)**

| Quelle | Inhalt |
|---|---|
| https://univis.uni-luebeck.de/userman/usermanch19.html | Handbuch Kap. 19 „XML-Schnittstelle“ (19.4 Kodierung von Wiederholungsmustern, 19.5 XML-Elemente) |
| https://univis.uni-luebeck.de/userman/usermanse98.html | Aufbau der XML-Dokumente: `key`-Attribut, Verweise über `UnivISRef type=… key=…`, Dokumente sind „immer komplett“ |
| https://univis-med.fau.de/userman/usermanse96.html | Script-Schnittstelle (`exportxml`, nur auf dem Server, Detailstufen 1–5) |
| https://www4.cs.fau.de/~wawi/UnivIS/talks/mainz.pdf | Vortrag Config eG: „Exportschnittstelle (PRG): direkte Suchanfragen, Inhalte in Webseiten einbetten, XML-Export und XSLT“ |
| http://www.config.de/UnivIS/ex.shtml | Hersteller Config eG |
| https://github.com/RRZE-Webteam/rrze-univis | WordPress-Plugin der FAU, das UnivIS-Daten über PRG einbindet |
| https://github.com/uniba-mi/baula | Studienplaner der Uni Bamberg; nutzt `prg?search=lectures&show=xml&sem=` und wandelt das XML in JSON |
| npm `univis-api` 0.0.3 (MIT, https://github.com/fekide/univis-api) | Client für PRG mit `show=xml`, nennt `univis.uni-kiel.de` als unterstützte Domain |

**Ablösung durch HISinOne**

| Quelle | Inhalt |
|---|---|
| https://www.uni-kiel.de/hisinone-info/de/EXA | Veranstaltungsmanagement nach der Prüfungsverwaltung, „damit verbunden ist auch die Ablösung von UnivIS“ |
| https://www.gpa.uni-kiel.de/de/pruefende/glossar/exa-hisinone | Umstellung der Prüfungsverwaltung seit SoSe 2025, spätestens bis WiSe 2029/30 |
| https://www.uni-kiel.de/hisinone-info/de/aktuelle-informationen | Projektstand HISinOne an der CAU, Kontakt `hisinone@uv.uni-kiel.de` |
| https://www.uni-kiel.de/gf-praesidium/en/services-and-organisational-support/dates/semester-and-lecture-periods | Vorlesungszeit WiSe 2026/27: 12.10.2026–12.02.2027 |

## 3. Nachgewiesene Schnittstellen

### PRG-Schnittstelle (`/prg`)

Allgemeiner Aufbau laut Kieler Doku (bestätigt):

```
https://univis.uni-kiel.de/prg?search=<modul>&<parameter>=<wert>&show=<format>&sem=<semester>
```

| Element | Werte | Status |
|---|---|---|
| `search` | `lectures`, `departments` | **live bestätigt** |
| | `persons`, `rooms`, `calendar`, `allocations` u. a. („grundsätzlich alle UnivIS-Daten“) | bestätigt (Doku) |
| `show` | `xml` (Antwort `text/xml`, UTF-8), `llong` (HTML) | **live bestätigt** |
| | `compact`, `info`, `short` | indiziert |
| `sem` | `2026w` = WS 2026/27 | **live bestätigt** |
| | `<Jahr>s` = Sommersemester; ohne Angabe das aktuelle Semester | indiziert / Doku |
| `department` | neunstellige Organisationsnummer, z. B. `010000000` (Theologische Fakultät) | **live bestätigt** |
| | Name statt Nummer (`department=Theologische Fakultät`) | **live: liefert HTML statt XML** – nicht verwenden |
| `number` | sechsstellige **Veranstaltungsnummer**, z. B. `010076` | **live bestätigt** |
| `name` (bei `departments`) | Teilstring, ohne Umlaute (`Theologische`) | **live bestätigt**; mit „ä“ (UTF-8-kodiert) leere Antwort |
| `noimports=1` | ohne Querverweise | live verwendet (bei `departments`) |
| weitere Parameter für `lectures` | `chapter`, `name`, `shortname`, `sws`, `bonus`, `malus`, `ectscredits`, `lecturer`, `room`, `type`, `keywords`, `path`, `id`, `evaluation`, `allocation` (nur mit `show=xml`), `lang=en`, `nolinks=1` | bestätigt (Kieler Überblicksseite), nicht live geprüft |

Korrektur gegenüber der ersten Fassung: `number=080063` in indexierten
URLs ist eine Veranstaltungs-, keine Organisationsnummer.

Organisationsnummern der Fakultät (live, `search=departments&name=Theologische`):

| Einrichtung | `key` | `orgnr` |
|---|---|---|
| Theologische Fakultät | `Org.theol` | `010000000` |
| Bibliothek der Theologischen Institute | `Org.theol.bibli` | `010210000` |

### XML-Format (live bestätigt, WS 2026/27, Theologische Fakultät)

Wurzel `<UnivIS>` mit `Lecture` (150), `Person` (40), `Room` (18),
`Title` (36, Gliederungspunkte des Vorlesungsverzeichnisses), `Event` (1).
Jeder Datensatz trägt ein `key`-Attribut; Verweise sind leere
`UnivISRef`-Elemente mit `type` und `key`, alle referenzierten Datensätze
stehen im selben Dokument.

`Lecture` (Anzahl der Veranstaltungen mit dem Element):

| Element | n | Bedeutung |
|---|---|---|
| `name` | 150 | Titel; enthält in Kiel die **Modulkürzel** in Klammern, z. B. „Bibelkunde Altes Testament (DKA-Ein-ÜAT, DKA-AT1-Bib, …)“ |
| `number` | 150 | Veranstaltungsnummer (`010076`) |
| `id` | 150 | interne Nummer (`42685235`) |
| `type` | 150 | Kürzel, z. B. `UE`, `RV` |
| `sws` | 145 | Semesterwochenstunden |
| `orgname`, `orgunits` | 150 | anbietende Einrichtung |
| `dozs` | 150 | Lehrpersonen (Verweise) |
| `terms` | 140 | Termine |
| `classification` | 149 | Verweis auf Gliederungspunkt, z. B. „4. Altes Testament“, „3. Fachergänzung“ |
| `startdate`, `enddate` | 129/128 | Zeitraum der Veranstaltung |
| `summary`, `literature`, `organizational` | 119/65/60 | Beschreibungstexte |
| `time_description` | 132 | **Freitext** (in Kiel Anmeldehinweise, teils mit Kontaktdaten) – keine Zeitangabe |
| `import_parent_id` | 70 | aus einer anderen Einrichtung übernommen („importiert“) |
| weitere | | `ordernr`, `turnout`, `schein`, `benschein`, `comment`, `erasmus`, `kontakt`, `studgen`, `englisch`, `praesenz` |

Nicht vorhanden: `ects_cred` (ECTS fehlen in diesem Katalog), `short`.

`term` (207 Termine): `repeat`, `starttime`, `endtime`, `room` je 205;
`startdate`/`enddate` 62; `exclude` (Ausnahmedatum) 65.

Wiederholungscodes (Häufigkeit):

| Code | n | Deutung |
|---|---|---|
| `w1 <Tag>` | 142 | wöchentlich; Tag 1 = Mo … 5 = Fr (**live bestätigt**: `w1 4` ↔ Klartext „Do 16:15-17:45“) |
| `w2 <Tag>` | 1 | 14-täglich (Annahme aus dem Muster) |
| `s1` | 50 | Einzeltermin, Datum in `startdate` = `enddate` (live bestätigt) |
| `bd <Tage>` | 8 | Block an den genannten Wochentagen innerhalb `startdate`–`enddate` (Annahme) |
| `b1` | 4 | Block (Annahme) |
| fehlt | 2 | kein Muster |

### Weitere Formate

* **XML-Export der Oberfläche** („Extras“): nutzerseitig, kein Mehrwert
  gegenüber PRG.
* **iCal**: UnivIS bietet für gesammelte Veranstaltungen „Ausgabe als
  iCal“ (Beispiel Uni Bamberg) – nutzerseitiger Export, kein Katalog-Feed.
* **Script `exportxml`**: läuft nur auf dem UnivIS-Server, also nur über
  die Betreiber (relevant für Ansatz E).
* **JSON, RSS, OAI**: keine Belege gefunden.
* **`/formbot/…`**: HTML-Seiten der Oberfläche – nicht als Schnittstelle
  gedacht.

## 4. Testresultate

**Entwicklungsumgebung (Claude-Cloud):**

| Test | Ergebnis |
|---|---|
| `curl https://univis.uni-kiel.de/` | `CONNECT tunnel failed, response 403` (Netzwerksperre der Umgebung, nicht UnivIS) |
| ebenso `www.uni-kiel.de`, andere UnivIS-Hosts, Web-Abruf-Werkzeug | 403 bzw. `ENOTFOUND` |
| Parser-Tests (`node --test tool/univis/univis_parser.test.mjs`) | 9/9 bestanden (synthetische Fixture) |
| Bestehende API-Tests (`node --test api/_lib/*.test.mjs`) | 24/24 bestanden (unverändert) |

**Live über GitHub Actions** (Workflow „UnivIS-Abruftest“, öffentliche
Protokolle; Lehrpersonen geschwärzt, keine Rohdaten gespeichert):

| Lauf | Anfrage | Ergebnis |
|---|---|---|
| [38571341714](https://github.com/xConner/Theologie-Lernapp/actions/runs/38571341714) | `search=departments&name=Theologische Fakultät` (UTF-8) | 200, `text/xml`, leer (160 B) – Umlaut |
| | `search=lectures&department=Theologische Fakultät` | 200, aber `text/html` statt XML |
| [38571543838](https://github.com/xConner/Theologie-Lernapp/actions/runs/38571543838) | `search=departments&name=Theologische&noimports=1` | 200, `text/xml`, 48 KB: 2 `Org`, 48 `Person`; `orgnr` 010000000 |
| [38571688314](https://github.com/xConner/Theologie-Lernapp/actions/runs/38571688314) | `search=lectures&show=xml&sem=2026w&department=010000000` | **200, `text/xml`, 407 619 B, 1,2 s** |
| 38571975156 | dieselben zwei Anfragen, erweitertes Inventar | wie oben; Protokoll enthält einen Freitext mit Kontaktdaten (siehe Abschnitt 5) |
| [38572194090](https://github.com/xConner/Theologie-Lernapp/actions/runs/38572194090) | `search=lectures&number=010076&sem=2026w&show=llong` | 200, HTML; Klartext „Do 16:15-17:45“ = XML `w1 4` |

Insgesamt 9 Anfragen an UnivIS, je Lauf höchstens zwei mit 5 s Pause.

Kennzahlen des Katalogabrufs (WS 2026/27, Theologische Fakultät):

| Kennzahl | Wert |
|---|---|
| Veranstaltungen / ohne Titel / ohne Schlüssel / doppelte Schlüssel | 150 / 0 / 0 / 0 |
| ohne Termine (z. B. „nach Vereinbarung“) | 10 |
| ohne Lehrperson | 0 |
| Termine / mit Uhrzeit / mit aufgelöstem Raum | 207 / 205 / 205 |
| unaufgelöste Verweise | 0 |
| unbekannte Wiederholungscodes | 0 (alle gedeutet, 2 ohne Code) |
| HTTP-Cache-Header | kein `ETag`, kein `Last-Modified`, `Cache-Control: private` |

Beispiel (gekürzt, Lehrperson weggelassen):

```json
{
  "sourceKey": "Lecture.theol.altte.relig.bibelk",
  "number": "010076",
  "name": "Bibelkunde Altes Testament (DKA-Ein-ÜAT, DKA-AT1-Bib, EvRel-BA-Ein-ÜAT, …)",
  "type": "UE", "sws": "2",
  "orgName": "Religionsgeschichte des Alten Testaments und Archäologie Syrien-Palästina",
  "startDate": "2026-10-18", "endDate": "2027-02-07",
  "classification": [{ "key": "Title.theol._3alte", "title": "4. Altes Testament" }],
  "sessions": [{
    "repeat": { "kind": "weekly", "intervalWeeks": 1, "weekdays": [4], "raw": "w1 4" },
    "startTime": "16:15", "endTime": "17:45",
    "room": { "short": "OS75/S2 - R.26", "name": "Seminarraum R.26" }
  }]
}
```

Damit ist für ein konkretes Semester belegt: Liste der Veranstaltungen,
strukturierte Details, wiederkehrende und einzelne Termine, Räume,
Lehrpersonen, Uhrzeiten. Suche per Suchbegriff ist über `name=` dokumentiert,
aber nicht live geprüft; für die App ist ohnehin die Suche im
zwischengespeicherten Katalog vorgesehen.

## 5. Grenzen

* **Keine Änderungsmarker**: Kein `ETag`/`Last-Modified` – Änderungen
  erkennt nur der Vergleich mit dem letzten Stand (Hash je Veranstaltung).
* **Doppelte Einträge durch Importe**: 70 Veranstaltungen sind aus anderen
  Einrichtungen importiert; dieselbe Veranstaltung kann unter mehreren
  Schlüsseln erscheinen (Beispiel: „Bibelkunde Altes Testament“ zweimal mit
  gleicher Nummer `010076` und gleichem Termin). Für die App nach
  `number` + Terminen zusammenführen.
* **Module/Studiengänge**: Kein eigenes Feld. Die Modulkürzel stehen im
  Titel in Klammern (z. B. `DKA-AT1-Bib`), die Gliederung des
  Vorlesungsverzeichnisses steht in `classification`. Ein Modulfilter ist
  damit möglich, hängt aber an der Pflegedisziplin der Einrichtungen.
* **ECTS** fehlen im Katalog der Theologie.
* **Blocktermine** (`bd`, `b1`): Deutung plausibel, nicht gegen Klartext
  geprüft. `w2` (14-täglich) kommt einmal vor; die Startwoche ist offen.
* **Absagen**: Ausnahmedaten (`exclude`) werden gepflegt (65 Termine);
  ob kurzfristige Absagen zuverlässig eingetragen werden, hängt von den
  Einrichtungen ab.
* **Stabile Kennungen**: Die Schlüssel sind sprechend
  (`Lecture.theol.altte.relig.bibelk`) und wirken aus dem Titel abgeleitet;
  ob sie über Semester und Umbenennungen stabil bleiben, ist offen.
* **Freitexte mit Kontaktdaten**: `time_description` (und ggf. `kontakt`,
  `organizational`) enthält in Kiel teils private E-Mail-Adressen. Solche
  Felder nicht übernehmen oder nur verlinken. **Vorfall:** Das öffentliche
  Protokoll von Lauf 38571975156 enthält den Anfang einer solchen Adresse
  (in UnivIS öffentlich sichtbar). Das Skript schwärzt Freitexte inzwischen;
  das Protokoll dieses Laufs sollte gelöscht werden (Abschnitt 10).
* **Umlaute in Parametern**: UTF-8-kodierte Umlaute finden nichts;
  Organisationsnummern statt Namen verwenden.
* **Netzwerk**: Die Claude-Cloud-Umgebung erreicht UnivIS nicht; GitHub
  Actions und (vermutlich) Vercel schon. Vercel ist nicht geprüft.
* **CORS**: nicht geprüft; für die Web-App ist ohnehin ein Server-Adapter
  nötig.
* **Anmeldung**: PRG ist anonym. Belegungen/Anmeldungen laufen über
  OLAT/HISinOne und sind kein Gegenstand dieser Anbindung.
* **Ablösung**: UnivIS wird an der CAU mittelfristig durch HISinOne ersetzt.
* **Rechtliches**: keine Nutzungsbedingungen, Lizenz- oder Quellenhinweise
  zur PRG-Ausgabe auffindbar.

## 6. Vergleich der Ansätze

| | A Offizielle API | B PRG/XML | C HTML-Scraping | D Exporte | E Freigabe/Kooperation |
|---|---|---|---|---|---|
| Verfügbarkeit | keine eigene REST/JSON-API; PRG ist die dokumentierte Schnittstelle | dokumentiert, anonym | technisch möglich | nur nutzerseitig (iCal, XML-Extras) | über `univis@univis.uni-kiel.de` anfragbar |
| Zuverlässigkeit | – | hoch (seit ~2003 stabil, von Hochschulen selbst genutzt) | gering (`formbot`-URLs, Layout) | mittel | hoch |
| Datenabdeckung | – | Katalog je Semester/Einrichtung, Termine, Räume, Dozenten (live bestätigt) | was die Seite zeigt | nur Ausgewähltes | ggf. vollständig (`exportxml`) |
| Aktualisierbarkeit | – | beliebig, eigener Takt | beliebig | manuell | nach Vereinbarung |
| Wartung | – | gering bis mittel (ein Parser je Format) | hoch | hoch (Nutzer) | gering |
| Kosten | – | gering (Vercel/Actions im vorhandenen Tarif) | gering | – | Abstimmungsaufwand |
| Datenschutz | – | nur veröffentlichte Daten; Minimierung möglich | ebenso, aber unscharf | Nutzer lädt hoch | vertraglich klärbar |
| Rechtliche Belastbarkeit | – | mittel; Zweck „Einbinden in eigene Seiten“ dokumentiert, Dritte nicht ausdrücklich geregelt | gering | hoch (Nutzer handelt selbst) | hoch |

A entfällt mangels eigener API; PRG übernimmt diese Rolle. D erfüllt das
Ziel „ohne manuellen Export“ nicht. C wird nicht empfohlen.

**Empfehlung:** B als Datenquelle, abgesichert durch E. Bis zur Antwort der
CAU nur zurückhaltende Tests, keine öffentliche Funktion.

## 7. Vorgeschlagene Architektur

```
UnivIS (PRG, show=xml)                    später: HISinOne, andere UnivIS
        │  1 Anfrage je Einrichtung/Semester (Theologie: ~400 KB), 1×/Tag
        ▼
Katalog-Adapter  (Node, tool/univis → api/_lib/catalog/)
  • Quelle je Hochschule: UnivisSource { host, semesters, departments[] }
  • parse → normalize → validate (univis_parser.mjs)
  • Änderungserkennung gegen den letzten Stand
        │  Admin SDK (Service-Account nur als Secret)
        ▼
Firestore (öffentlich lesbar, nur Server schreibt)
  catalog_sources/{sourceId}                         Hochschule, Semester, Stand
  catalog_sources/{sourceId}/semesters/{sem}/lectures/{lectureId}
        │  Lesezugriff, Suche/Filter im Client
        ▼
Flutter-App
  CatalogRepository  ─┐
  TimetableStore.forUser(uid)  → users/{uid}/timetable/{entryId}  oder lokal (Gast)
  Screens: Suche, Filter, Detail, Stundenplan (Woche), Konflikte
```

**Abruf und Takt.** Ein geplanter GitHub-Actions-Lauf (wie
`.github/workflows/push-reminders.yml`, da Vercel-Cron im Hobby-Tarif nur
einen Lauf pro Tag erlaubt) stößt einmal täglich nachts die Synchronisation
an; im Semester ggf. zweimal. Anfragen nacheinander mit Pause (z. B. 2 s),
Zeitlimit und erkennbarem User-Agent. UnivIS sendet weder `ETag` noch
`Last-Modified`; der Adapter vergleicht deshalb Hashes je Veranstaltung.
Abfrage je Einrichtung über die Organisationsnummer (`department=010000000`)
statt über Namen. Für die ganze Theologie genügt eine Anfrage pro Semester.

**Warum Firestore statt Live-Proxy.** Ein Live-Proxy nach dem Muster von
`api/greek-noun.ts` (mit CDN-Cache) wäre einfacher, kann aber keine
Änderungen gegenüber dem Vorstand erkennen und belastet UnivIS mit jeder
Cache-Lücke. Ein Theologie-Katalog umfasst wenige hundert Veranstaltungen je
Semester – Firestore-Lesekosten bleiben klein. Für den ersten Prototyp ist
der Proxy dennoch der schnellste Weg (Plan, Schritt 3).

**Kennungen.**
`lectureId = <sourceId>:<sem>:<UnivIS-key>` (z. B.
`cau-univis:2026w:Lecture.theol.altte.relig.bibelk`); `sessionId =
<lectureId>#<Hash aus repeat, starttime, endtime, startdate, room>`.
Importierte Doppel (gleiche `number`, gleiche Termine) werden zu einem
Eintrag zusammengeführt. Weil Termine kein eigenes Kennungselement haben (live:
nur `repeat`, Zeiten, Daten, `room`, `exclude`), wird eine Änderung von Zeit oder Raum als „Termin
geändert“ erkannt, indem der Adapter alte und neue Termine je Veranstaltung
paarweise zuordnet.

**Trennung von Katalog und Stundenplan.** Der Katalog wird nur vom Server
geschrieben (`allow write: if false` wie bei `notifications`). Der
persönliche Eintrag `users/{uid}/timetable/{entryId}` enthält `lectureId`,
die gewählten `sessionId`s, einen **Schnappschuss** (Titel, Zeiten, Raum zum
Zeitpunkt des Hinzufügens) sowie eigene Felder (Farbe, Notiz, ausgeblendet).
Eine Katalogaktualisierung ändert den Eintrag nie; die App vergleicht
Schnappschuss und Katalog und zeigt „geändert/abgesagt/entfallen“ an, bis
der Nutzer bestätigt. Für den Gastmodus ein lokaler Store nach dem Muster
`ExamStore.forUser`. Neue Collection in `firestore.rules`
(`isUserCollection`), `AccountDeletionService.userCollections` und der Liste
oben in `firestore.rules` eintragen.

**Änderungen, Absagen.** Fehlt eine Veranstaltung im neuen Abruf, wird sie
als `status: removed` markiert statt gelöscht (Schutz gegen Teilausfälle:
liefert ein Abruf deutlich weniger Datensätze als zuvor, wird er verworfen).
Ausnahmen (`exclude`) und Einzeltermine werden beim Auflösen der Termine
berücksichtigt.

**Konflikterkennung.** Termine je Semester über die Vorlesungszeit
(Kiel WiSe 2026/27: 12.10.2026–12.02.2027, zentral gepflegt statt aus
UnivIS geraten) zu konkreten Zeitfenstern expandieren, Ausnahmen abziehen,
Überschneidungen paarweise prüfen. Reine Funktion ohne UI, gut testbar.

**Filter.** Möglich (live bestätigt): Semester, Einrichtung
(`orgname`/Organisationsnummer), Gliederungspunkt (`classification`, z. B.
„4. Altes Testament“), Veranstaltungstyp, Lehrperson, Wochentag, Uhrzeit,
Volltext im Titel, Modulkürzel (aus dem Titel). Nicht möglich: ECTS.

**Datenminimierung.** Übernommen werden Titel, Nummer, Typ, SWS,
Einrichtung, Gliederung, Termine, Räume und von Lehrpersonen nur Titel und
Name. Freitextfelder (`time_description`, `kontakt`, `organizational`,
`summary`) werden nicht gespeichert; die Detailansicht verlinkt für sie auf
UnivIS.

**Erweiterbarkeit.** `CatalogSource`-Schnittstelle mit Implementierungen
je System (UnivIS mit hochschulspezifischer Konfiguration: Host,
Semesterkennungen, Einrichtungsliste, Typ-Kürzel; später HISinOne). Die App
kennt nur das normalisierte Format.

## 8. Umsetzungsplan

1. ~~Live-Test~~ – erledigt (Abschnitt 4).
2. **Anfrage an die CAU** (Abschnitt 9) senden; bis zur Antwort keine
   öffentliche Funktion und keine regelmäßigen Abrufe.
3. **Parser ergänzen**: Zusammenführen importierter Doppel, Modulkürzel aus
   dem Titel, Termin-Expansion über die Vorlesungszeit (inkl. `exclude`,
   `bd`), Konfliktprüfung – als reine, getestete Funktionen.
4. **Prüfen, ob Vercel UnivIS erreicht**, dann Prototyp-Endpunkt
   `api/univis-lectures.ts` (über `guarded`), fest eingeschränkt auf Host
   und Organisationsnummer, mit
   `Cache-Control: s-maxage=86400, stale-while-revalidate`; Tests wie
   `api/_lib/handlers.test.mjs` mit Fixture.
5. **Flutter, lesend**: `CatalogRepository`, Suchscreen mit Semester- und
   Einrichtungsauswahl, Detailansicht, Quellenhinweis „Daten: UnivIS der
   CAU Kiel“ mit Stand.
6. **Stundenplan**: `TimetableStore.forUser`, Firestore-Regeln,
   Kontolöschung, Konfliktprüfung, Wochenansicht.
7. **Synchronisation** in Firestore mit Änderungserkennung, geplanter Lauf
   über GitHub Actions, Hinweise auf geänderte Einträge.
8. **Ausbau**: weitere Einrichtungen/Hochschulen über Konfiguration;
   HISinOne-Adapter, sobald die CAU das Veranstaltungsmanagement umstellt.

## 9. Offene Fragen

1. Ist ein regelmäßiger automatisierter Abruf (≈ einmal täglich, wenige
   Dutzend Anfragen) erlaubt, gibt es Lastgrenzen oder einen bevorzugten
   Weg (z. B. `exportxml`-Datei)?
2. Dürfen die Daten in einer kostenlosen Open-Source-App angezeigt und
   zwischengespeichert werden, und in welcher Form ist die Quelle zu nennen?
   Bestehen Rechte an der Datenbank (Datenbankherstellerrecht), die einer
   Weitergabe entgegenstehen?
3. Dürfen Namen von Lehrpersonen übernommen werden (nur, was UnivIS ohnehin
   öffentlich zeigt)?
4. Bleiben UnivIS-Schlüssel über Bearbeitungen stabil? Werden Absagen in
   UnivIS gepflegt? Wie sind `bd`/`b1`/`w2` genau zu lesen (Handbuch 19.4)?
5. Wann wird das Veranstaltungsmanagement in HISinOne produktiv, und wird es
   eine vergleichbare öffentliche Schnittstelle geben?

Datenschutz: Die App übernähme nur öffentlich angezeigte Daten und von
Personen nur Schlüssel und Anzeigenamen (keine Telefonnummern, E-Mail,
Sprechzeiten). Persönliche Stundenpläne liegen wie alle Lernstände unter
`users/{uid}` und werden bei der Kontolöschung entfernt. Die
Datenschutzerklärung der App müsste den Katalog als Datenquelle nennen.
Rechtsfragen werden hier nicht beantwortet, sondern an die CAU gestellt.

**Entwurf der Anfrage** an `univis@univis.uni-kiel.de` (UnivIS-Projektgruppe;
in Kopie ggf. `hisinone@uv.uni-kiel.de` für Frage 5):

> Betreff: Nutzung der UnivIS-PRG-Schnittstelle für eine studentische Lern-App
>
> Sehr geehrte Damen und Herren,
>
> wir entwickeln die kostenlose Open-Source-Lernapp „theologie.app“ für
> Theologiestudierende. Wir möchten Studierenden ermöglichen, Veranstaltungen
> der CAU aus UnivIS in der App zu suchen und in einen persönlichen
> Stundenplan zu übernehmen. Dafür würden wir die öffentliche
> PRG-Schnittstelle (`/prg?search=lectures&show=xml&department=010000000`,
> eine Anfrage je Semester) etwa einmal täglich abfragen, die Daten
> zwischenspeichern und mit Quellenangabe anzeigen. Personenbezogene Daten
> würden wir auf die öffentlich angezeigten Namen der Lehrenden beschränken;
> Freitexte mit Kontaktangaben übernehmen wir nicht.
>
> 1. Ist eine solche regelmäßige automatisierte Nutzung zulässig, und gibt es
>    Vorgaben zu Abrufhäufigkeit oder Last?
> 2. Gibt es Nutzungsbedingungen oder eine gewünschte Form der Quellenangabe?
> 3. Gibt es einen bevorzugten Weg, etwa einen regelmäßigen XML-Export?
> 4. Ist absehbar, wann UnivIS durch HISinOne abgelöst wird und ob es dort
>    eine vergleichbare Schnittstelle geben wird?
>
> Vielen Dank und freundliche Grüße

## 10. Testplan ohne Programmierkenntnisse

Alles im Browser, ohne Konto, ohne Installation.

**A. Katalog ansehen (1 Minute)**

1. Diese Adresse im Browser öffnen:
   `https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&department=010000000`
2. Erwartet: eine lange, strukturierte Textseite (XML), die mit `<UnivIS`
   beginnt und Einträge `<Lecture key="Lecture.theol…">` enthält.
3. Mit Strg+F nach „Bibelkunde“ suchen: Darunter stehen `<repeat>w1 4</repeat>`,
   `<starttime>16:15</starttime>`, `<endtime>17:45</endtime>`.

**B. Wochentag gegenprüfen (1 Minute)**

1. `https://univis.uni-kiel.de/prg?search=lectures&number=010076&sem=2026w&show=llong`
   öffnen.
2. Erwartet: normale UnivIS-Seite zur „Bibelkunde Altes Testament“ mit
   „Do 16:15 - 17:45“. Das bestätigt: `w1 4` = donnerstags.

**C. Einen anderen Fachbereich oder ein anderes Semester testen**

* Andere Einrichtung: `https://univis.uni-kiel.de/prg?search=departments&name=Philosoph&show=xml&noimports=1`
  öffnen, im Ergebnis die Zahl bei `<orgnr>` ablesen und in A statt
  `010000000` einsetzen. Suchbegriffe ohne Umlaute verwenden.
* Anderes Semester: in A `2026w` durch z. B. `2026s` (SoSe 2026) ersetzen.

**D. Wiederholung über GitHub (optional)**

Auf GitHub unter „Actions“ → „UnivIS-Abruftest“ → „Run workflow“ (erscheint,
sobald die Workflow-Datei im Hauptzweig liegt). Modus `probe` ruft den
Katalog ab und zeigt Kennzahlen; das Protokoll ist öffentlich, Lehrpersonen
und Freitexte sind geschwärzt.

**E. Protokoll mit Kontaktdaten löschen (einmalig)**

Auf GitHub: Actions → „UnivIS-Abruftest“ → Lauf
`38571975156` („Matched the UnivIS parser to the real Kiel response…“)
öffnen → oben rechts „…“ → „Delete workflow run“.
