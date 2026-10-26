# Vorlesungsunterlagen nur für freigeschaltete Konten

Die Bereiche mit Lehrveranstaltungsunterlagen sind nur für ausdrücklich
freigeschaltete Konten sichtbar. Für alle anderen gibt es sie in der App
nicht: keine Knöpfe, keine gesperrten Karten, keine Hinweise oder
Fehlermeldungen.

## Betroffene Bereiche

| Bereich | Daten |
|---|---|
| Altes Testament (Vorlesung) und Grundlagen der Bibelkunde (Übung) | `assets/old_testament/` |
| Kirchengeschichte (Vorlesung und Proseminar) | `assets/church_history/` |
| Leseplan zur Übung Bibelkunde AT | `assets/reading_plans/course-*.json` |

Ohne Freigabe ausgeblendet: Startseite (Knöpfe, Streak-Zeilen), Bibelkunde
(„Grundlagen der Bibelkunde“, „Leseplan zur Übung“), Leseplan-Übersicht
(„Zu Lehrveranstaltungen“), „Über die App“, „Lernfortschritt
zurücksetzen“, Deep Links `/old-testament` und `/church-history`. Direkt
aufgerufene Seiten der Bereiche schließen sich ohne Hinweis.

**Nicht betroffen:** der Stundenplan (UnivIS-Katalog, synthetischer
Katalog, eigene Einträge) und alle übrigen Bereiche. Der eigene Lernstand
in Kirchengeschichte und Altem Testament bleibt gespeichert.

## Wie es funktioniert

- Die Freigabeliste steht in Firestore unter `lecture_access/allowlist`:
  `emails` (Array, Kleinbuchstaben) und/oder `uids` (Array von Konto-IDs).
- `firestore.rules` erlaubt das Lesen von `lecture_access/check` (das
  Dokument muss nicht existieren) nur, wenn das **signierte ID-Token** des
  Kontos in der Liste steht: Konto-ID in `uids` oder E-Mail-Adresse in
  `emails` mit `email_verified == true`. Die Liste selbst ist für Clients
  weder lesbar noch schreibbar.
- Die App (`lib/services/lecture_materials/lecture_materials.dart`) liest
  bei jeder Anmeldung, jedem Kontowechsel und jeder Token-Erneuerung (etwa
  stündlich) `lecture_access/check` vom Server. Nur wenn das gelingt, zeigt
  sie die Bereiche und gibt deren Daten frei. Ablehnung, Fehler, Gast oder
  abgemeldet → ausgeblendet. Es gibt keinen lokalen Schalter.

## Freischalten und Freigabe entziehen

In der **Firebase Console** → Firestore Database → Daten →
`lecture_access` → `allowlist`:

- Freischalten: im Array `emails` die E-Mail-Adresse in Kleinbuchstaben
  ergänzen (Konto muss per Google angemeldet sein oder die Adresse bestätigt
  haben). Für Konten ohne E-Mail (Telefon-Login) die Konto-ID aus
  Authentication → Nutzer im Array `uids` eintragen.
- Entziehen: den Eintrag löschen. Die App blendet die Bereiche beim nächsten
  Laden bzw. spätestens nach einer Stunde aus.

Oder per Skript mit einem Dienstkonto (Projekteinstellungen → Dienstkonten
→ „Neuen privaten Schlüssel generieren“; nie ins Repository legen):

```bash
npm ci
export GOOGLE_APPLICATION_CREDENTIALS=/pfad/zum/dienstkonto.json
node tool/lecture_materials/lecture_materials.mjs grant name@example.org
node tool/lecture_materials/lecture_materials.mjs revoke name@example.org
node tool/lecture_materials/lecture_materials.mjs list
```

Einmalig nötig: `firestore.rules` in der Console unter Firestore Database →
Regeln veröffentlichen und `lecture_access/allowlist` mit
`emails: ["connerverlinden@gmail.com"]` anlegen.

## Grenzen

Die Unterlagen liegen weiterhin im App-Bundle und im Repository. Sie sind
in der Oberfläche verborgen, aber wer die Asset-URLs der Website
(`/assets/assets/old_testament/…`) oder das Repository kennt, kann sie
direkt abrufen. Für echten Schutz müssten die Dateien aus Bundle und
Repository heraus (z. B. das Repository privat machen und die Dateien
serverseitig ausliefern).

Tests: `test/lecture_materials_test.dart` (App) und im Firestore-Emulator
`test/firestore_rules/lecture_materials.test.mjs` (Regeln).
