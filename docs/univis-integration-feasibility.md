# UnivIS-Anbindung: Machbarkeitsprüfung

Stand: 14.10.2026. Ziel: Veranstaltungen aus UnivIS (zuerst CAU Kiel)
automatisch in der App suchen, filtern und in einen persönlichen
Stundenplan übernehmen, ohne dass Studierende UnivIS öffnen oder etwas
exportieren.

Kennzeichnung in diesem Bericht:

* **Bestätigt** – selbst geprüft oder in einer offiziellen Quelle belegt.
* **Indiziert** – durch öffentlich indexierte Kieler URLs oder Clients
  Dritter belegt, aber nicht selbst live abgerufen.
* **Annahme** – plausibel, noch ungeprüft.
* **Offen** – ließ sich nicht klären.

## 1. Kurzfazit

**Ein automatischer Abruf ohne manuellen Export ist technisch realistisch,
konnte aus dieser Umgebung aber nicht live bestätigt werden.**

* UnivIS hat mit der **PRG-Schnittstelle** (`https://<host>/prg?search=…`)
  eine dokumentierte, anmeldefreie Abfrageschnittstelle mit XML-Ausgabe
  (`show=xml`). Die CAU dokumentiert sie selbst für das Einbinden in eigene
  Webseiten (bestätigt, Quellen in Abschnitt 2).
* Für Kiel sind reale PRG-Abfragen auf Veranstaltungen mit Semester- und
  Einrichtungsfilter öffentlich indexiert, z. B.
  `https://univis.uni-kiel.de/prg?search=lectures&sem=2025w&number=080063`
  (indiziert). Die Abfrage deckt den **Katalog** ab, nicht nur einzelne
  Stundenpläne.
* **Nicht getestet:** Die Ausführungsumgebung dieser Prüfung darf
  `univis.uni-kiel.de` (wie alle Hochschul-Hosts) nicht erreichen
  (Egress-Proxy: `403` beim CONNECT, Abschnitt 4). Ob Kiel `show=xml`
  tatsächlich ausliefert und welche Felder enthalten sind, ist daher
  **offen**. Ein fertiges Testskript dafür liegt bei (`tool/univis/`).
* Rechtlich gibt es **keine auffindbaren Nutzungsbedingungen** für
  automatisierte Abrufe oder Weitergabe. Vor einer dauerhaften Nutzung ist
  eine **Rückfrage bei der CAU** nötig (Entwurf in Abschnitt 9).
* **Lebensdauer begrenzt:** Die CAU plant, UnivIS mit dem
  Veranstaltungsmanagement von HISinOne abzulösen (nach der
  Prüfungsverwaltung, deren Umstellung laut Gemeinsamem Prüfungsamt bis
  spätestens WiSe 2029/30 laufen soll). Die Anbindung muss deshalb hinter
  einem austauschbaren Adapter liegen.

**Empfehlung:** Ansatz B (PRG/XML) über einen serverseitigen Adapter,
parallel Ansatz E (Freigabe bei der CAU anfragen). Kein HTML-Scraping.

## 2. Geprüfte Quellen

Weil die Hosts nicht direkt erreichbar waren, stammen die Angaben aus der
Websuche (Inhalte indexierter Seiten) und aus dem Quelltext eines
veröffentlichten Clients (npm-Paket). Seiten der CAU zur UnivIS-Schnittstelle
sind teils viele Jahre alt.

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
| `search` | `lectures`, `persons`, `departments`, `rooms`, `calendar`, `allocations` u. a. („grundsätzlich alle UnivIS-Daten“) | bestätigt (Doku) |
| Parameter für `lectures` | `department`, `chapter`, `name`, `shortname`, `number`, `sws`, `bonus`, `malus`, `ectscredits`, `lecturer`, `room`, `noimports`, `type`, `keywords`, `path`, `id`, `evaluation`, `allocation` (nur mit `show=xml`) | bestätigt (Kieler Überblicksseite) |
| `show` | u. a. `llong`, `compact`, `info`, `short`, `xml` | `llong`/`compact`/`info` in Kieler URLs indiziert, `short` im Kieler Beispiel; `xml` laut Kieler Doku vorhanden (`allocation` „nur bei show=xml“), live **offen** |
| `sem` | `<Jahr>w` / `<Jahr>s`, z. B. `2025w` = WS 2025/26, `2025s` = SS 2025; ohne Angabe das aktuelle Semester | indiziert (Kieler URLs) |
| `number` | Organisationsnummer der Einrichtung, z. B. `080063`, `200409` | indiziert |
| `lang=en`, `noimports=1`, `nolinks=1` | Sprache, ohne Querverweise, ohne Links | bestätigt (Doku) |

Indexierte Kieler Abfragen (nicht selbst abgerufen):

* `https://univis.uni-kiel.de/prg?search=lectures&sem=2025w&number=080063`
* `https://univis.uni-kiel.de/prg?search=lectures&number=200409&lang=en&show=llong&noimports=1&sem=2025s`
* `https://univis.uni-kiel.de/prg?department=Pharmazeutisches+Institut&search=lectures&type=v`
* `https://univis.uni-kiel.de/prg?search=rooms&name=%5EWSP&show=compact`
* `http://univis.uni-kiel.de/prg?search=persons&fullname=…&show=info` (von der Theologischen Fakultät verlinkt)

### XML-Format

Bestätigt (Handbuch Kap. 19): Jeder Datensatz trägt ein `key`-Attribut;
Verweise (Lehrperson einer Veranstaltung, Raum eines Termins) sind leere
`UnivISRef`-Elemente mit `type` und `key`; ein Dokument enthält alle
referenzierten Datensätze. Wiederholungsmuster von Terminen sind kodiert
(Abschnitt 19.4). Eine DTD beschreibt den genauen Aufbau. Die
Weboberfläche lässt Personen ohne Veröffentlichungszustimmung aus.

Annahme (aus Clients Dritter, nicht gegen Kiel geprüft): Wurzel `<UnivIS>`
mit `<Lecture>`, `<Person>`, `<Room>`; in `Lecture` u. a. `name`, `short`,
`id`, `type`, `sws`, `ects_cred`, `orgname`, `summary`,
`dozs/doz/UnivISRef`, `terms/term` mit `repeat`, `starttime`, `endtime`,
`startdate`, `enddate`, `exclude`, `room/UnivISRef`.

### Weitere Formate

* **XML-Export der Oberfläche** („Extras“): nur wenn die Installation ihn
  aktiviert; nutzerseitig, kein Mehrwert gegenüber PRG.
* **iCal**: UnivIS bietet für gesammelte Veranstaltungen „Ausgabe als
  iCal“ (Beispiel Uni Bamberg). Das ist ein nutzerseitiger Export aus
  einer Sitzungssammlung, kein Katalog-Feed.
* **Script `exportxml`**: läuft nur auf dem UnivIS-Server, also nur über
  die Betreiber (relevant für Ansatz E).
* **JSON, RSS, OAI**: keine Belege gefunden.
* **`/formbot/…`**: HTML-Seiten der Oberfläche mit kodierten Pfaden –
  nicht als Schnittstelle gedacht.

## 4. Testresultate

| Test | Ergebnis |
|---|---|
| `curl https://univis.uni-kiel.de/` | **fehlgeschlagen**: `CONNECT tunnel failed, response 403` (Egress-Policy dieser Umgebung, nicht UnivIS) |
| ebenso `www.uni-kiel.de`, `univis.fau.de`, `univis.uni-erlangen.de`, `de.wikipedia.org` | 403 – alle nicht freigegebenen Hosts gesperrt |
| Abruf über das Web-Abruf-Werkzeug | `getaddrinfo ENOTFOUND` für alle Hochschul-Hosts (gleiche Sperre) |
| `node tool/univis/univis_probe.mjs --sem 2026w --param name=Theologie` mit Proxy | `Proxy response (403) !== 200 when HTTP Tunneling` |
| Parser gegen synthetische Fixture (`node --test tool/univis/univis_parser.test.mjs`) | 8/8 bestanden |
| Bestehende API-Tests (`node --test api/_lib/*.test.mjs`) | 24/24 bestanden (unverändert) |

Damit sind **nicht** belegt: Semesterliste, Suche, Detaildaten,
Terminauflösung, Räume, Dozenten und Aktualisierung für ein konkretes
Semester. Kein Ergebnis wurde simuliert; die Fixture ist ausdrücklich
synthetisch und prüft nur den Parser.

Der Prototyp ist so gebaut, dass ein einziger Aufruf von einem Rechner mit
Zugang alle offenen Strukturfragen beantwortet: HTTP-Status, Content-Type,
Cache-Header, Inventar der tatsächlich vorkommenden Elemente, Kennzahlen
(Veranstaltungen ohne Termin/Lehrperson, Termine mit Uhrzeit/Raum,
unaufgelöste Verweise, unbekannte Wiederholungsmuster) und eine kleine
Stichprobe. Anleitung: `tool/univis/README.md`.

Um den Test in dieser Cloud-Umgebung nachzuholen, muss
`univis.uni-kiel.de` in den Netzwerkeinstellungen der Umgebung unter
„Allowed domains“ freigegeben werden
(https://code.claude.com/docs/en/cloud-environments#network-access).

## 5. Grenzen

* **Live-Struktur offen**: Ob Kiel `show=xml` ausliefert, welche Felder
  gefüllt sind und wie Wiederholungen tatsächlich kodiert sind.
* **Module/Studiengänge**: PRG kennt `chapter`/`path` (Gliederung des
  Vorlesungsverzeichnisses) und laut Handbuch UnivIS-Module (19.5.1). Ob
  Kiel Module in UnivIS pflegt oder nur in HISinOne/Modulhandbüchern, ist
  offen. Ein Studiengangsfilter ist daher nicht gesichert.
* **Einzeltermine und Ausfälle**: Ausnahmen (`exclude`) und Einzeltermine
  sind wahrscheinlich, aber unbestätigt. Ob kurzfristige Absagen in UnivIS
  gepflegt werden, hängt von den Einrichtungen ab.
* **Stabile Kennungen**: Ob `key` einer Veranstaltung über Semester und
  Bearbeitungen hinweg stabil bleibt, ist offen. Termine haben vermutlich
  keinen eigenen Schlüssel.
* **CORS**: Ob UnivIS CORS-Header sendet, ist unbekannt; für die Web-App ist
  ohnehin ein Server-Adapter nötig.
* **Anmeldung**: PRG ist anonym; Daten, die nur angemeldet sichtbar sind
  (z. B. Personen ohne Veröffentlichungszustimmung), werden nicht genutzt.
  Belegungen/Anmeldungen laufen an der CAU über HISinOne und sind kein
  Gegenstand dieser Anbindung.
* **Ablösung**: UnivIS wird an der CAU mittelfristig durch HISinOne ersetzt.
* **Rechtliches**: keine Nutzungsbedingungen, Lizenz- oder Quellenhinweise
  zur PRG-Ausgabe auffindbar; Impressum/Datenschutzseite von
  univis.uni-kiel.de konnten nicht eingesehen werden.

## 6. Vergleich der Ansätze

| | A Offizielle API | B PRG/XML | C HTML-Scraping | D Exporte | E Freigabe/Kooperation |
|---|---|---|---|---|---|
| Verfügbarkeit | keine eigene REST/JSON-API; PRG ist die dokumentierte Schnittstelle | dokumentiert, anonym | technisch möglich | nur nutzerseitig (iCal, XML-Extras) | über `univis@univis.uni-kiel.de` anfragbar |
| Zuverlässigkeit | – | hoch (seit ~2003 stabil, von Hochschulen selbst genutzt) | gering (`formbot`-URLs, Layout) | mittel | hoch |
| Datenabdeckung | – | Katalog je Semester/Einrichtung, Termine, Räume, Dozenten (Details offen) | was die Seite zeigt | nur Ausgewähltes | ggf. vollständig (`exportxml`) |
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
        │  wenige Anfragen je Einrichtung/Semester, 1×/Tag + ETag
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
Zeitlimit, erkennbarem User-Agent, bedingten Anfragen, wenn UnivIS
`ETag`/`Last-Modified` sendet (offen). Abfrage je Einrichtung (`number=`)
statt Namenssuche, damit Ergebnisse eindeutig sind.

**Warum Firestore statt Live-Proxy.** Ein Live-Proxy nach dem Muster von
`api/greek-noun.ts` (mit CDN-Cache) wäre einfacher, kann aber keine
Änderungen gegenüber dem Vorstand erkennen und belastet UnivIS mit jeder
Cache-Lücke. Ein Theologie-Katalog umfasst wenige hundert Veranstaltungen je
Semester – Firestore-Lesekosten bleiben klein. Für den ersten Prototyp ist
der Proxy dennoch der schnellste Weg (Plan, Schritt 3).

**Kennungen.**
`lectureId = <sourceId>:<sem>:<UnivIS-key>` (z. B.
`cau-univis:2026w:Lecture.theol...`); `sessionId = <lectureId>#<Hash aus
repeat, starttime, endtime, startdate, room>`. Weil Termine keinen eigenen
Schlüssel haben (Annahme), wird eine Änderung von Zeit oder Raum als „Termin
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

**Filter.** Sicher möglich: Semester, Einrichtung (Organisationsnummer),
Veranstaltungstyp, Lehrperson, Wochentag, Uhrzeit, Volltext im Titel.
Abhängig von den Live-Daten: Modul, Studiengang, ECTS.

**Erweiterbarkeit.** `CatalogSource`-Schnittstelle mit Implementierungen
je System (UnivIS mit hochschulspezifischer Konfiguration: Host,
Semesterkennungen, Einrichtungsliste, Typ-Kürzel; später HISinOne). Die App
kennt nur das normalisierte Format.

## 8. Umsetzungsplan

1. **Live-Test** von einem Rechner mit Zugang (oder nach Freigabe des Hosts
   in der Cloud-Umgebung): `univis_probe.mjs` für 2026w mit einer
   theologischen Einrichtung; Parser anhand von `inventory` und
   `unknownRepeatValues` korrigieren; Ergebnis hier nachtragen.
2. **Anfrage an die CAU** (Abschnitt 9) senden; bis zur Antwort keine
   öffentliche Funktion.
3. **Prototyp-Endpunkt** `api/univis-lectures.ts` (über `guarded`), fest
   eingeschränkt auf Host und Einrichtungsliste, mit
   `Cache-Control: s-maxage=86400, stale-while-revalidate`; Tests wie
   `api/_lib/handlers.test.mjs` mit Fixture.
4. **Flutter, lesend**: `CatalogRepository`, Suchscreen mit Semester- und
   Einrichtungsauswahl, Detailansicht, Quellenhinweis „Daten: UnivIS der
   CAU Kiel“ mit Stand.
5. **Stundenplan**: `TimetableStore.forUser`, Firestore-Regeln,
   Kontolöschung, Konfliktprüfung, Wochenansicht.
6. **Synchronisation** in Firestore mit Änderungserkennung, geplanter Lauf
   über GitHub Actions, Hinweise auf geänderte Einträge.
7. **Ausbau**: weitere Einrichtungen/Hochschulen über Konfiguration;
   HISinOne-Adapter, sobald die CAU das Veranstaltungsmanagement umstellt.

## 9. Offene Fragen

1. Liefert `univis.uni-kiel.de/prg?…&show=xml` XML aus, und mit welchen
   Feldern und Wiederholungscodes? (Test Schritt 1)
2. Ist ein regelmäßiger automatisierter Abruf (≈ einmal täglich, wenige
   Dutzend Anfragen) erlaubt, gibt es Lastgrenzen oder einen bevorzugten
   Weg (z. B. `exportxml`-Datei)?
3. Dürfen die Daten in einer kostenlosen Open-Source-App angezeigt und
   zwischengespeichert werden, und in welcher Form ist die Quelle zu nennen?
   Bestehen Rechte an der Datenbank (Datenbankherstellerrecht), die einer
   Weitergabe entgegenstehen?
4. Dürfen Namen von Lehrpersonen übernommen werden (nur, was UnivIS ohnehin
   öffentlich zeigt)?
5. Bleiben UnivIS-Schlüssel über Bearbeitungen stabil? Werden Absagen in
   UnivIS gepflegt?
6. Wann wird das Veranstaltungsmanagement in HISinOne produktiv, und wird es
   eine vergleichbare öffentliche Schnittstelle geben?

Datenschutz: Die App übernähme nur öffentlich angezeigte Daten und von
Personen nur Schlüssel und Anzeigenamen (keine Telefonnummern, E-Mail,
Sprechzeiten). Persönliche Stundenpläne liegen wie alle Lernstände unter
`users/{uid}` und werden bei der Kontolöschung entfernt. Die
Datenschutzerklärung der App müsste den Katalog als Datenquelle nennen.
Rechtsfragen werden hier nicht beantwortet, sondern an die CAU gestellt.

**Entwurf der Anfrage** an `univis@univis.uni-kiel.de` (UnivIS-Projektgruppe;
in Kopie ggf. `hisinone@uv.uni-kiel.de` für Frage 6):

> Betreff: Nutzung der UnivIS-PRG-Schnittstelle für eine studentische Lern-App
>
> Sehr geehrte Damen und Herren,
>
> wir entwickeln die kostenlose Open-Source-Lernapp „theologie.app“ für
> Theologiestudierende. Wir möchten Studierenden ermöglichen, Veranstaltungen
> der CAU aus UnivIS in der App zu suchen und in einen persönlichen
> Stundenplan zu übernehmen. Dafür würden wir die öffentliche
> PRG-Schnittstelle (`/prg?search=lectures&show=xml`) für ausgewählte
> Einrichtungen etwa einmal täglich abfragen, die Daten
> zwischenspeichern und mit Quellenangabe anzeigen. Personenbezogene Daten
> würden wir auf die öffentlich angezeigten Namen der Lehrenden beschränken.
>
> 1. Ist eine solche regelmäßige automatisierte Nutzung zulässig, und gibt es
>    Vorgaben zu Abrufhäufigkeit oder Last?
> 2. Gibt es Nutzungsbedingungen oder eine gewünschte Form der Quellenangabe?
> 3. Gibt es einen bevorzugten Weg, etwa einen regelmäßigen XML-Export?
> 4. Ist absehbar, wann UnivIS durch HISinOne abgelöst wird und ob es dort
>    eine vergleichbare Schnittstelle geben wird?
>
> Vielen Dank und freundliche Grüße
