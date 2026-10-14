# UnivIS-Anbindung: Machbarkeitsprüfung

Stand: 14.10.2026 (Phase 2 – Backend-Datenverarbeitung – in Abschnitt 11). Ziel: Veranstaltungen aus UnivIS (zuerst CAU Kiel)
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
  und einzelne Termine sowie Ausschlussangaben sind maschinenlesbar und
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
`startdate`/`enddate` 62; `exclude` 65 (durchweg das Kennzeichen `vac`, kein
Datum – Abschnitt 11.3).

Wiederholungscodes (Häufigkeit):

| Code | n | Deutung |
|---|---|---|
| `w1 <Tag>` | 142 | wöchentlich; Tag 1 = Mo … 5 = Fr (**live bestätigt**: `w1 4` ↔ Klartext „Do 16:15-17:45“) |
| `w2 <Tag>` | 1 | 14-täglich (Annahme aus dem Muster) |
| `s1` | 50 | Einzeltermin, Datum in `startdate` = `enddate` (live bestätigt) |
| `bd <Tage>` | 8 | Block an den genannten Wochentagen innerhalb `startdate`–`enddate` (**live bestätigt**, Abschnitt 11.3) |
| `b1` | 4 | durchgehender Block von Startdatum/-zeit bis Enddatum/-zeit (**live bestätigt**) |
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
| 38571975156 | dieselben zwei Anfragen, erweitertes Inventar | wie oben; Protokoll enthielt einen Freitext mit Kontaktdaten – **Lauf gelöscht** (Abschnitt 11.1) |
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
* **Blocktermine** (`bd`, `b1`): gegen die Klartextansicht geprüft
  (Abschnitt 11.3). `w2` (14-täglich) kommt einmal vor; die Startwoche ist
  offen.
* **Absagen**: `exclude` enthält in Kiel keine Daten, sondern durchweg das
  Kennzeichen `vac` (vorlesungsfreie Zeit). Einzelne Ausfalltermine sind im
  Theologie-Katalog nicht eingetragen; ob kurzfristige Absagen je gepflegt
  werden, ist offen.
* **Stabile Kennungen**: Die Schlüssel sind sprechend
  (`Lecture.theol.altte.relig.bibelk`) und wirken aus dem Titel abgeleitet;
  ob sie über Semester und Umbenennungen stabil bleiben, ist offen.
* **Freitexte mit Kontaktdaten**: `time_description` (und ggf. `kontakt`,
  `organizational`) enthält in Kiel teils private E-Mail-Adressen. Solche
  Felder nicht übernehmen oder nur verlinken. **Vorfall:** Das öffentliche
  Protokoll von Lauf 38571975156 enthielt den Anfang einer solchen Adresse.
  Der Lauf ist gelöscht (geprüft, Abschnitt 11.1); die Skripte geben keine
  Freitexte mehr aus.
* **Umlaute in Parametern**: UTF-8-kodierte Umlaute finden nichts;
  Organisationsnummern statt Namen verwenden.
* **Netzwerk**: Die Claude-Cloud-Umgebung erreicht UnivIS nicht; GitHub
  Actions schon. Vercel: ungeklärt, weil Previews geschützt sind
  (Abschnitt 11.6).
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
3. ~~Parser ergänzen~~ – erledigt: `api/_lib/catalog/` (Abschnitt 11).
4. **Prüfen, ob Vercel UnivIS erreicht** (vorbereitet, braucht das
   Bypass-Secret, Abschnitt 11.6), dann Prototyp-Endpunkt
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
sobald die Workflow-Datei im Hauptzweig liegt). Modus `catalog` führt das
Backend auf echten Daten aus und zeigt nur Kennzahlen; das Protokoll ist
öffentlich und enthält keine Personen und keine Freitexte.

**E. Protokoll mit Kontaktdaten löschen** – erledigt (Lauf 38571975156
ist gelöscht, Abschnitt 11.1).

**F. Vercel-Erreichbarkeit freischalten (einmalig, ohne Programmierung)**

1. Vercel → Projekt „theologie-lernapp“ → Settings → Deployment Protection →
   „Protection Bypass for Automation“ → Secret erzeugen und kopieren.
2. GitHub → Repository → Settings → Secrets and variables → Actions →
   „New repository secret“, Name `VERCEL_AUTOMATION_BYPASS_SECRET`, Wert
   einfügen.
3. Actions → „UnivIS-Abruftest“ → „Run workflow“, Modus `vercel` (sobald
   die Workflow-Datei im Hauptzweig liegt; sonst genügt mir ein Hinweis, dann
   starte ich den Lauf).

## 11. Phase 2: Backend-Datenverarbeitung

Ziel: robuste, getestete Verarbeitung ohne Flutter-Oberfläche und ohne
regelmäßigen Abruf. Ort: `api/_lib/catalog/` (TypeScript wie die übrigen
Serverfunktionen, `cheerio` als vorhandene Abhängigkeit).

### 11.1 Ausgangslage und Datenschutzprüfung

* Branch `claude/clever-albattani-rt4952`, sauber, gleich `origin`.
* **Lauf 38571975156 ist gelöscht – geprüft:** Die GitHub-API liefert für
  ihn `404`, die übrigen Läufe `200`; die Laufliste des Workflows enthält
  nur noch die Läufe 1, 2, 3 und 5.
* Workflow und Skripte geprüft und verschärft:
  - `probe` gibt keine Stichproben mehr aus (nur Inventar und Kennzahlen).
  - `univis_find_department.mjs` gibt von Einrichtungen nur `id`, `name`,
    `name_en`, `orgnr`, `ordernr`, `url` aus (Positivliste).
  - `univis_check_schedule.mjs` gibt nur Folgen aus einer festen Wortliste
    aus (Wochentage, Daten, Uhrzeiten, „Block“, „ab“, „bis“ …); Namen und
    Freitexte können so nicht ins Protokoll.
  - `catalog_stats.mjs` und der Vercel-Endpunkt geben nur Zählungen und
    Veranstaltungsnummern aus.
  - Ältere Läufe (1–3, 5) enthalten Titel, Räume, Einrichtungen und
    Organisationsnummern, aber keine Personen oder Freitexte.

### 11.2 Datenmodell (`model.ts`)

| Typ | Inhalt | Quellbezug |
|---|---|---|
| `Semester` | Semester, Vorlesungszeit, unterrichtsfreie Zeiten, Zeitzone, Beleg | gepflegt in `semesters.ts` (CAU WS 2026/27: 01.10.–31.03., Vorlesungen 12.10.–12.02., frei 21.12.–03.01.) |
| `Course` | Titel, Nummer, Modulkürzel, Typ, SWS, ECTS, Einrichtungen, Gliederung, Lehrpersonen, Terminregeln, Zeitraum, Detail-URL | `sources[]`: **alle** Quellkennungen, auch zusammengeführter Dubletten |
| `SessionRule` | Terminangabe wie in der Quelle (Art, Intervall, Wochentage, Zeiten, Zeitraum, Ausfalldaten, Ausschluss-Kennzeichen, Raum, Rohwert) | `raw` (z. B. `w1 4`); `id` aus dem Inhalt, ohne Ausfälle |
| `Occurrence` | konkreter Termin `[start, end)` mit Offset (Europe/Berlin), Raum, `scheduled`/`cancelled` | `id = <ruleId>@<Datum>` |
| `Person` | nur Anzeigename (Titel, Vor-, Nachname) | `source` |
| `Room` | Kurz- und Langname, `online` | `source` |
| `Provenance` | Quelle, System, Hochschule, URL, Abrufzeit, SHA-256 der Antwort | – |
| `ScheduleIssue` | Hinweis/Warnung je Veranstaltung und Regel | – |
| `CatalogSnapshot` | alles zusammen, plus `mergedDuplicates` und `possibleDuplicates` | – |

Freitexte (`time_description`, `kontakt`, `organizational`, `summary`,
`literature`, `comment`) werden nicht übernommen; Personen ohne Verweis
aus einer Veranstaltung fallen weg.

### 11.3 Terminauflösung (`schedule.ts`, `time.ts`)

Deutung, live gegen die Klartextansicht (`show=llong`) geprüft (Lauf
[38575633585](https://github.com/xConner/Theologie-Lernapp/actions/runs/38575633585)):

| Angabe | Klartext in UnivIS | Auflösung |
|---|---|---|
| `w1 4` (010076) | „Do 16:15 - 17:45, vom 18.10.2026 bis 7.2.2027“ | jeder Donnerstag im **Veranstaltungszeitraum** ∩ Vorlesungszeit, ohne unterrichtsfreie Zeit |
| Veranstaltungs-`startdate`/`enddate` | „vom … bis …“ (oben) | begrenzt wöchentliche Regeln (bestätigt; zunächst fälschlich nur gemeldet) |
| `w2 2` (010000) | „… Woche Di 18:15 - 19:45, vom 18.10.2026 bis 7.2.2027“ | **keine Termine** – Startwoche nicht angegeben (`biweekly-phase-unknown`) |
| `bd 1,2,3,4,5` (010032) | „Blockveranstaltung 12.10.2026 - 16.10.2026, 9:00 - 17:00“ | die Wochentage im Zeitraum |
| `bd 1,2,3,4` (010036) | „Blockveranstaltung 5.10.2026 - 8.10.2026, 9:00 - 15:00“ | dto. |
| `b1` (010008) | „Blockveranstaltung 5.2.2027 9:15 - 8.2.2027 19:45“ | **ein** durchgehender Zeitraum (`block-continuous`) |
| `s1` | Einzeltermin | genau das Datum |
| `exclude` = `vac` (24 Regeln) | – | vorlesungsfreie Zeit ausgenommen; entspricht der Standardauflösung, daher ohne Wirkung |
| `exclude` = Datum | – (in Kiel nicht belegt) | Termin bleibt sichtbar, Status `cancelled` |

Weitere Regeln: Zeitzone Europe/Berlin über `Intl` (Zeitumstellung
25.10.2026 und 28.03.2027 getestet; nicht existierende Ortszeiten ergeben
keinen Termin). Termine außerhalb des Semesters werden verworfen
(`outside-semester`). Fehlende Uhrzeiten, Ende vor Beginn, unbekannte
Muster, Einzeltermine ohne Datum oder mit Zeitraum, Blöcke ohne Zeitraum:
keine Termine, sondern eine Warnung. Ausfalldaten ohne passenden Termin
und unbekannte Ausschluss-Kennzeichen: Hinweis. Ausfallangaben in
unbekanntem Format werden als Strukturwarnung gemeldet, nie still
verworfen (das war zuvor der Fall).

Feiertage: Im WS 2026/27 fällt in Schleswig-Holstein kein Feiertag auf
einen Vorlesungstag außerhalb der Weihnachtspause (31.10. ist ein
Samstag). Für andere Semester müssen sie in `Semester.breaks` gepflegt
werden.

### 11.4 Dubletten und Überschneidungen (`dedupe.ts`, `overlap.ts`)

Zusammengeführt wird nur, was eindeutig gleich ist: (1) Import-Verknüpfung
`import_parent_id` → `id` **und** gleiche Termine, oder (2) gleiche Nummer
**und** gleicher (normalisierter) Titel **und** gleiche, nicht leere
Termine samt Raum. Hauptfassung ist die nicht importierte; alle
Quellkennungen, Einrichtungen, Gliederungspunkte und Lehrpersonen bleiben
erhalten. Gleiche Nummer mit abweichendem Titel oder abweichenden
Terminen (Parallelgruppen) bleibt getrennt und wird als
`possibleDuplicates` gemeldet; ähnliche Titel allein führen nie zusammen.

Überschneidungen: halboffene Intervalle `[start, end)` in echter Zeit
(UTC-Millisekunden) – direkt aufeinanderfolgende Termine kollidieren
nicht, abgesagte zählen nicht, Überschneidungen innerhalb einer
Veranstaltung werden als `sameCourse` gekennzeichnet.
`overlapsBetween(occurrences, courseIds)` liefert die Konflikte eines
Stundenplans je Sitzung.

### 11.5 Ergebnis auf echten Daten

`catalog_stats.mjs` in GitHub Actions, je eine Anfrage, nur Kennzahlen
(Läufe [38575289543](https://github.com/xConner/Theologie-Lernapp/actions/runs/38575289543),
[38576150730](https://github.com/xConner/Theologie-Lernapp/actions/runs/38576150730)):

| Kennzahl | WS 2026/27, Theologische Fakultät |
|---|---|
| Veranstaltungen in der Antwort | 150 |
| nach Dublettenprüfung | **89** |
| importiert / Ursprung in derselben Antwort | 70 / 61 |
| zusammengeführt | 34 Gruppen (19 über Import, 15 über Import und Nummer+Titel+Termine) |
| mögliche Dubletten (bewusst getrennt) | 0 |
| Terminregeln (nach Zusammenführung) | 103: 79 wöchentlich, 1 × 14-täglich, 6 Blöcke, 16 Einzeltermine, 1 ohne Muster |
| aufgelöste Termine | **1149** (vor Anwendung des Veranstaltungszeitraums 1298) |
| abgesagte Termine | 0 (keine Ausfalldaten gepflegt) |
| Veranstaltungen ohne Termine | 12: 10 ohne Terminangabe, 1 × 14-täglich ohne Startwoche, 1 ohne Uhrzeit |
| Strukturwarnungen | 0 |
| Veranstaltungen mit Modulkürzeln | 58 von 89 |

Die neun Importe ohne Ursprung in der Antwort stammen aus Einrichtungen
außerhalb der Fakultät; sie bleiben eigene Einträge.

### 11.6 Serverzugriff (Vercel) und Adapter

* `api/univis-reachability.ts`: antwortet nur in Preview-Deployments (in
  Produktion `404`), nur `GET`, höchstens eine UnivIS-Anfrage pro Minute
  und Instanz, Antwort nur Kennzahlen. Getestet mit gefälschtem `fetch`.
* **Ergebnis: Ob Vercel UnivIS erreicht, ist weiterhin offen.** Das Preview
  wurde gebaut (Vercel-Status `success`), ist aber durch **Vercel
  Authentication** geschützt: Der Aufruf aus GitHub Actions erhielt `302`
  („Protected by Vercel Authentication“), die Funktion lief nicht, es ging
  keine Anfrage an UnivIS (Lauf
  [38574515340](https://github.com/xConner/Theologie-Lernapp/actions/runs/38574515340)).
  Der Schutz wurde nicht umgangen. Der Workflow-Modus `vercel` nutzt den
  offiziellen Weg „Protection Bypass for Automation“, sobald das Secret
  `VERCEL_AUTOMATION_BYPASS_SECRET` gesetzt ist (Abschnitt 10F).
  Indiz, kein Beleg: Bestehende Vercel-Funktionen (`api/greek-noun.ts`)
  rufen externe Seiten ab; GitHub-Runner (Azure) erreichen UnivIS.
* Adapter-Schnittstelle (`source.ts`):

  ```ts
  interface CatalogSource {
      sourceId; system; institution; semesters;
      fetchRaw(query: { semesterId; organizationId }): Promise<RawResponse>; // genau eine Anfrage
      parse(body, query): ParsedCatalog;                                   // ohne Netzwerk
  }
  buildSnapshot(source, query, raw, fetchedAt) // rein: parse → dedupe → resolve
  loadCatalog(source, query)                   // fetchRaw + buildSnapshot
  ```

  `UnivisSource` (Host, Semester, Organisationsnummer geprüft; Zeitlimit,
  Größenlimit, Zeichensatz) ist die einzige UnivIS-spezifische Stelle
  neben `univis/parse.ts`. Ein HISinOne-Adapter implementiert dieselbe
  Schnittstelle; Modell, Auflösung, Dubletten, Überschneidungen und alles
  darüber bleiben unverändert.
* **Kein regelmäßiger Abruf eingerichtet.** Der Workflow hat keinen
  Zeitplan; er läuft nur manuell oder beim Ändern der Workflow-Datei auf
  einem `claude/`-Branch (dann eine Anfrage).

### 11.7 Tests

| Suite | Ergebnis |
|---|---|
| `node --test api/_lib/catalog/catalog.test.mjs` | 31/31 |
| `node --test api/_lib/handlers.test.mjs` | 14/14 |
| `node --test api/_lib/reminders.test.mjs` | 10/10 |
| `node --test tool/univis/univis_parser.test.mjs` | 9/9 |

Abgedeckt: Zeitzone und Zeitumstellung, Wochentage (1 = Mo), mehrere
Wochentage, 14-täglich mit/ohne Startdatum, Einzel- und Blocktermine
(auch durchgehend über mehrere Tage), Weihnachtspause, Veranstaltungs-
zeitraum, Semestergrenzen, Ausfälle (Datum, Kennzeichen, unbekanntes
Format), stabile Kennungen, Dubletten (Import, Nummer+Titel+Termine,
Parallelgruppen, ähnliche Titel), Überschneidungen (teilweise, enthalten,
drei gleichzeitig, direkt anschließend, abgesagt, über die Zeitumstellung),
fehlerhafte und unvollständige XML (HTML, leer, abgeschnitten, ohne
Kennung/Titel, unbekannte Verweise), Datenschutz (keine Freitexte, keine
unbenutzten Personen), Adapter (eine Anfrage, Parameterprüfung,
ISO-8859-1, HTTP-Fehler) und der Vercel-Endpunkt (Produktion, Methode,
Drosselung, nur Kennzahlen, Netzfehler). Gegenprobe: Zwei absichtlich
eingebaute Fehler (Weihnachtspause verschoben, Berührung als
Überschneidung) ließen 5 bzw. 2 Tests scheitern.

Testdaten: `fixtures/synthetic-catalog.xml` (erfunden) und
`fixtures/kiel-2026w-excerpt.xml` (aus dem öffentlichen, geschwärzten
Protokoll rekonstruiert; Lehrpersonen synthetisch). Flutter-Code wurde
nicht geändert; `flutter analyze` war daher nicht nötig.

### 11.8 Offene Punkte

1. **Nutzungsrechte** (Abschnitt 9) – unverändert offen; Anfrage an die CAU
   noch nicht gestellt.
2. **Vercel-Erreichbarkeit** – braucht das Bypass-Secret (Abschnitt 10F).
3. **14-täglich ohne Startwoche** (010000): UnivIS nennt die Startwoche
   nicht. Denkbar ist „ab Beginn des Veranstaltungszeitraums“; das ist
   nicht belegt, daher keine Termine. Klärung bei der CAU (Handbuch 19.4).
4. **`vac`**: Bedeutung aus dem Namen erschlossen; die Auflösung wäre auch
   ohne diese Deutung gleich.
5. **Einzelne Ausfälle**: Im Theologie-Katalog nicht gepflegt; ob Absagen
   je über UnivIS kommen, ist offen. Die App braucht dafür ggf. einen
   Hinweis „Kurzfristige Änderungen siehe OLAT/UnivIS“.
6. **Stabilität der UnivIS-Schlüssel** über Semester und Bearbeitungen.
7. **Feiertage** anderer Semester in `semesters.ts` pflegen.

### 11.9 Empfohlene nächste Phase

1. CAU-Anfrage (Abschnitt 9) senden; Secret für den Vercel-Test anlegen und
   den Modus `vercel` einmal ausführen.
2. Nach Freigabe: Lesender Endpunkt `api/catalog.ts` auf Basis von
   `loadCatalog` mit CDN-Cache (`s-maxage=86400`) – oder, falls Vercel UnivIS
   nicht erreicht, Erzeugung des Katalogs in GitHub Actions und Ablage in
   Firestore (`catalog_sources/…`, nur Server schreibt).
3. Änderungserkennung zwischen zwei Snapshots (gleiche `Occurrence.id`,
   anderer Inhalt → „geändert“; fehlend → „entfallen“) als reine Funktion.
4. Danach erst Flutter: Datenmodell in Dart spiegeln, Suche/Filter,
   Stundenplan unter `users/{uid}/timetable` mit Schnappschuss und
   `overlapsBetween`-Logik.
