# Geschützte Vorlesungsunterlagen

Folien, Abschriften, Zusammenfassungen, Fragen, Dozentenangaben und
Lesepläne aus Lehrveranstaltungen sind nur für ausdrücklich freigeschaltete
Konten sichtbar. Für alle anderen gibt es diese Inhalte in der App nicht:
keine Knöpfe, keine gesperrten Karten, keine Hinweise oder Fehlermeldungen.

## Was geschützt ist

| Bereich | Inhalt (Pfad in den Unterlagen) |
|---|---|
| Altes Testament (Vorlesung) und Grundlagen der Bibelkunde (Übung) | `old_testament/` – course.json, terms.json, units/, slides/ |
| Kirchengeschichte (Vorlesung und Proseminar) | `church_history/` – epochs, themes, entries, lectures, seminar, slides/ |
| Leseplan zur Übung Bibelkunde AT | `reading_plans/course-bibelkunde-at-wise-2026.json` |
| „Info & Quellen“ beider Bereiche (mit Dozentennamen) | `info/old_testament.json`, `info/church_history.json` |

Ohne Freigabe ausgeblendet: Startseite (Knöpfe, Streak-Zeilen), Bibelkunde
(„Grundlagen der Bibelkunde“, „Leseplan zur Übung“), Leseplan-Übersicht
(„Zu Lehrveranstaltungen“), „Über die App“, „Lernfortschritt
zurücksetzen“, Deep Links `/old-testament` und `/church-history`.

**Nicht betroffen** ist der Stundenplan (UnivIS-Katalog über
`api/catalog`, synthetischer Katalog, eigene Einträge unter
`users/{uid}/timetable`): Er hat eigene Modelle und Dozentenfelder und wurde
nicht verändert. Ebenso alle übrigen Bereiche (Perikopenquiz, Bücher,
Sprachen, Logik, Bibel, Kirchenväter …). Der eigene Lernstand in
Kirchengeschichte und Altem Testament (`users/{uid}/quiz_settings/…`)
bleibt gespeichert, auch ohne Freigabe.

## Wie es funktioniert

- Die Unterlagen liegen **nicht** im App-Bundle und nicht im Repository,
  sondern in Firestore: je Datei ein Dokument
  `lecture_materials/<Pfad mit ~ statt />` (`path`, `contentType`, `data` als
  Bytes), dazu `lecture_materials/manifest` mit der Dateiliste.
- `firestore.rules` erlaubt nur `get` (einzeln, kein Auflisten) und nur,
  wenn das **signierte ID-Token** des Kontos in
  `lecture_access/allowlist` steht: die Konto-ID in `uids` oder die
  E-Mail-Adresse in `emails` – diese nur mit `email_verified == true`.
  Schreiben ist für Clients verboten; die Freigabeliste ist für Clients
  weder lesbar noch änderbar. Fehlt die Liste, ist niemand freigeschaltet.
- Die App (`lib/services/lecture_materials/lecture_materials.dart`) liest
  bei jeder Anmeldung, jedem Kontowechsel und jeder Token-Erneuerung
  (etwa stündlich) das Manifest **vom Server**. Nur wenn das gelingt, gelten
  die Unterlagen als verfügbar. Ablehnung, Fehler oder offline → nicht
  verfügbar. Es gibt keinen lokalen Schalter.
- Daten und Folienbilder lädt die App erst danach, unter ihren bisherigen
  Pfaden (`assets/old_testament/…`); IDs, Bildpfade und Lernstände bleiben
  gleich. Zwischenspeicher (Dateien, dekodierte Bilder, geladene Daten)
  werden beim Entzug, Abmelden oder Kontowechsel verworfen.

## Freischalten und Freigabe entziehen

Nur wer Zugriff auf das Firebase-Projekt hat (Console bzw. Dienstkonto),
kann die Liste ändern. Die App muss dafür nicht geändert werden.

**In der Firebase Console:** Firestore Database → Daten →
`lecture_access` → `allowlist`:

- Freischalten: im Feld `emails` (Array) einen Eintrag mit der
  E-Mail-Adresse **in Kleinbuchstaben** hinzufügen. Für Konten ohne
  bestätigte E-Mail-Adresse (z. B. Telefon-Login) stattdessen die Konto-ID
  (Authentication → Nutzer → „Nutzer-UID“) im Feld `uids` eintragen.
- Entziehen: den Eintrag löschen. Ab sofort scheitert jeder neue Abruf;
  die App blendet die Bereiche spätestens bei der nächsten
  Token-Erneuerung (≤ 1 Stunde) oder beim nächsten Start aus.

**Per Skript** (Dienstkonto, siehe unten):

```bash
npm ci
export GOOGLE_APPLICATION_CREDENTIALS=/pfad/zum/dienstkonto.json
node tool/lecture_materials/lecture_materials.mjs grant name@example.org
node tool/lecture_materials/lecture_materials.mjs grant uid:KONTO-ID
node tool/lecture_materials/lecture_materials.mjs revoke name@example.org
node tool/lecture_materials/lecture_materials.mjs list
```

Statt `GOOGLE_APPLICATION_CREDENTIALS` geht auch `FIREBASE_SERVICE_ACCOUNT`
(JSON oder Base64, wie bei den Vercel-Funktionen). Ein Schlüssel lässt sich
in der Firebase Console unter Projekteinstellungen → Dienstkonten →
„Neuen privaten Schlüssel generieren“ erzeugen; nie ins Repository legen.

## Einrichtung (einmalig)

1. **Regeln:** `firestore.rules` in der Firebase Console unter Firestore
   Database → Regeln einfügen und veröffentlichen (dieses Projekt hat kein
   Firebase-CLI-Setup).
2. **Freigabe:** `node tool/lecture_materials/lecture_materials.mjs grant
   connerverlinden@gmail.com` – oder in der Console das Dokument
   `lecture_access/allowlist` mit dem Feld `emails` (Array) =
   `["connerverlinden@gmail.com"]` anlegen.
3. **Unterlagen hochladen:** das Verzeichnis `lecture_materials/` (privat,
   nicht im Repository) ins Repository-Hauptverzeichnis legen und
   `node tool/lecture_materials/lecture_materials.mjs upload` ausführen.

Bis Schritt 1–3 erledigt sind, sieht niemand die Bereiche – auch
freigeschaltete Konten nicht.

## Unterlagen ändern oder ergänzen

Die Dateien liegen lokal in `lecture_materials/` (in `.gitignore`), mit
demselben Aufbau wie früher unter `assets/`. Neue Einheiten, Sitzungen
oder Folien dort anlegen (siehe [old-testament.md](old-testament.md),
[church-history.md](church-history.md)), Tests ausführen und erneut
`upload` aufrufen. `upload` schreibt alle Dateien, zuletzt das Manifest,
und löscht Dokumente nicht mehr vorhandener Dateien. Höchstens 900 KB je
Datei.

**Tests:** Die Inhaltstests (`test/old_testament`, `test/church_history`,
Leseplan zur Übung) lesen die Dateien aus `lecture_materials/` (oder
`LECTURE_MATERIALS_DIR`) und werden ohne sie übersprungen. Die Tests der
Freigabe selbst laufen immer: `test/lecture_materials_test.dart` und im
Firestore-Emulator `test/firestore_rules/lecture_materials.test.mjs`.

## Grenzen

- Das Repository ist öffentlich. Alle Unterlagen, die vor dem 2026-10-26
  eingecheckt waren, stehen weiter in der **Git-Historie** und in Forks
  bzw. Klonen. Das lässt sich nur durch Umschreiben der Historie (Force
  Push) oder ein privates Repository beheben.
- Ältere **Vercel-Deployments** (eigene `*.vercel.app`-Adressen) liefern
  ihr damaliges Bundle mit den Unterlagen weiter aus, bis sie gelöscht oder
  per Deployment Protection geschützt sind. Ebenso können Browser-Caches
  und bereits heruntergeladene Kopien nicht zurückgeholt werden.
- Der Quellcode ist öffentlich: Wer ihn liest, sieht, dass es die Bereiche
  und die Freigabe gibt – nicht aber deren Inhalte.
- Auf Android/iOS speichert Firestore gelesene Dokumente im Gerätecache.
  Die App liest immer vom Server, ein entzogenes Konto kann also nichts
  Neues abrufen; der Cache eines zuvor freigeschalteten Geräts wird aber
  nicht aktiv gelöscht. (Im Web ist dieser Cache aus.)
