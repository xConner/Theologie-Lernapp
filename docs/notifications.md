# Benachrichtigungen

## Grundsatz

| Kanal | Zweck | Inhalt |
|---|---|---|
| **Home / Trainer** | persönlicher Lernstatus | Streak, Tagesziel, Fortschritt |
| **Glocke** (In-App) | dauerhafte App-Nachrichten | neue Inhalte, System, Account, Mitteilungen |
| **Push** | zeitabhängige Erinnerungen | tägliche Erinnerung an Offenes (Bibellese, Leseplan, Texte, Trainer), neue Inhalte, wichtige Systemnachrichten |
| **E-Mail** | sehr selten, bewusst ausgelöst | wichtige Mitteilungen von theologie.app |

Die Glocke zeigt **nie** Streaks, Tagesziele, Lernfortschritt oder fällige
Wiederholungen. Erinnerungen an den Lernstand gibt es nur als Push, nur auf
Wunsch und höchstens einmal am Tag. Firebase-Auth-Mails (Passwort,
E-Mail-Bestätigung) laufen weiterhin separat über Firebase Auth.

## Datenmodell (Firestore)

```
notifications/{id}                     globale Nachricht (alle Nutzer + Gäste)
users/{uid}/inbox/{id}                 persönliche Nachricht (z. B. Account & Sicherheit)
users/{uid}/notification_state/inbox   Lesestatus der Glocke
users/{uid}.notification_settings      Push-/E-Mail-Einstellungen
users/{uid}/push_tokens/{id}           Push-Abonnement je Gerät
```

Nachrichtenfelder (global und persönlich gleich):

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `category` | string | ja | `content` · `system` · `account` (nur persönlich) · `announcement` |
| `title` | string | ja | kurz, ohne sensible Kontodaten |
| `body` | string | nein | |
| `createdAt` | timestamp | ja | Sortierung und Lesestatus |
| `expiresAt` | timestamp | nein | danach nicht mehr in der Glocke |
| `deepLink` | string | nein | App-Pfad (siehe unten) oder `https://…` |
| `priority` | string | nein | `normal` (Standard) · `high` |
| `channels` | map | nein | `{inApp: true, push: false, email: false}` |

Eine Nachricht ist **ein** Objekt. `channels` legt fest, über welche Kanäle
es ausgeliefert wird; Push und E-Mail erzeugen keine zweite Nachricht.
Ungültige Dokumente (z. B. unbekannte Kategorie, fehlendes `createdAt`)
werden von der App ignoriert.

**Lesestatus:** Statt einer Kopie jeder Nachricht je Nutzer gibt es ein
Dokument je Nutzer mit einer Marke `readUpTo` (alles bis zu diesem
`createdAt` ist gelesen) und wenigen Einzelmarkierungen `readKeys`. Das
Öffnen der Glocke setzt die Marke auf die neueste angezeigte Nachricht.
Gäste speichern den Lesestatus lokal.

**Deep Links** (`lib/services/notifications/app_deep_link.dart`):
`/perikopen`, `/greek`, `/greek/vocabulary`, `/greek/grammar`, `/latin`,
`/latin/vocabulary`, `/calendar`, `/hymns`, `/confessions`, `/prayers`,
`/memorize`, `/bible`, `/bible/plan/<Plan-ID>`, `/settings`,
`/settings/notifications`, `/account` sowie `/` (Startseite). Unbekannte
Pfade werden nicht angezeigt. Derselbe Wert steht im Feld `link` einer
Push-Nachricht.

## Nachricht veröffentlichen

Firebase Console → Firestore → Collection `notifications` → Dokument
hinzufügen, z. B.:

```
category:  "content"
title:     "Neue griechische Vokabeln"
body:      "40 neue Vokabeln wurden hinzugefügt."
createdAt: <jetzt, Typ timestamp>
deepLink:  "/greek/vocabulary"
```

Mit `channels: {push: true}` geht die Nachricht (Kategorie `content` oder
`system`) beim nächsten Lauf des Versands zusätzlich einmal als Push an alle
Konten, die diese Mitteilungen eingeschaltet haben; der Server vermerkt das
im Feld `pushSentAt`.

Clients können `notifications/` und `users/{uid}/inbox/` nicht beschreiben
(siehe `firestore.rules`). Persönliche Account-Nachrichten schreibt später
ausschließlich der Server (Admin SDK). Die Regeln müssen manuell in der
Console eingetragen werden.

## Einstellungen

`users/{uid}.notification_settings`:

```
push:  { enabled: false,
         bibleReading: true, readingPlan: true, memorization: true, trainers: true,
         newContent: false, systemMessages: true }
email: { announcements: false }
reminderMinutes:  1080              gewünschte Uhrzeit (Minuten ab Mitternacht, Ortszeit)
timeZone:         "Europe/Berlin"   IANA-Zeitzone des Geräts
utcOffsetMinutes: 120               Ersatz, falls die Zeitzone unbekannt ist
nextReminderAt:   <timestamp>       nächste Erinnerung; fehlt, wenn Push aus ist
lastReminderDate: "2026-10-10"      schreibt nur der Server
```

Push und E-Mail sind Opt-in. Die Glocke hängt nicht von diesen
Einstellungen ab. Uhrzeit und Kategorien gelten für das Konto, das
Ein-/Ausschalten für das jeweilige Gerät: `push.enabled` bleibt wahr, solange
mindestens ein Gerät des Kontos Push empfängt.

## Push

### Technik

Standard-**Web-Push** (Push-API, VAPID) statt Firebase Cloud Messaging:

* Ein Weg für alle Plattformen. Der Browser liefert beim Abonnieren die
  Adresse seines Push-Dienstes (Chrome/Android: Google, Firefox: Mozilla,
  Safari/iOS: Apple, Edge: Microsoft); der Server sendet dorthin.
* Kein weiteres Flutter-Plugin und kein Firebase-SDK im Service Worker. FCM
  verwendet im Web dieselbe Push-API und bräuchte für den Versand ebenfalls
  einen Server mit Dienstkonto – das Dienstkonto dient hier nur dem Lesen
  von Firestore.
* Die Nachricht ist bis zum Gerät verschlüsselt; der Push-Dienst sieht den
  Inhalt nicht.

| Aufgabe | Ort |
|---|---|
| Service Worker: Nachricht anzeigen, Klick an die App melden | `web/push-sw.js` |
| Browser-APIs (Berechtigung, Abonnement, Zeitzone, Links) | `lib/services/notifications/push_platform*.dart` |
| Ein-/Ausschalten, Abgleich beim Start, Abmelden | `lib/services/notifications/push_service.dart` |
| Abonnements im Konto | `lib/services/notifications/push_token_registry.dart` |
| Einstellungen | `lib/screens/notification_settings_screen.dart` |
| Entscheidung, woran erinnert wird (reine Funktionen, Tests) | `api/_lib/reminders.ts`, `api/_lib/reminders.test.mjs` |
| Versand (Admin SDK, Web-Push) | `api/_lib/push.ts`, `api/send-reminders.ts` |
| Testbenachrichtigung für das eigene Konto | `api/push-test.ts` |
| Zeitplaner | `.github/workflows/push-reminders.yml` |

Der Service Worker hat einen eigenen Geltungsbereich (`push/`) und wird erst
registriert, wenn der Nutzer Push einschaltet. Erst dann fragt der Browser
nach der Berechtigung.

### Unterstützte Plattformen

| Plattform | Voraussetzung |
|---|---|
| Android (Chrome, Edge, Firefox, Samsung Internet), auch als installierte Web-App | Benachrichtigungen für den Browser im System erlaubt |
| iPhone/iPad | iOS/iPadOS ab 16.4 **und** theologie.app zum Home-Bildschirm hinzugefügt; im Browser-Tab gibt es keinen Web-Push |
| Desktop: Chrome, Edge, Firefox | Browser muss laufen (ggf. im Hintergrund) |
| Safari unter macOS | ab Safari 16 (macOS 13) |
| In-App-Browser, ältere Browser | kein Push – die App zeigt einen Hinweis; Glocke und Streak-Anzeige bleiben |

### Ablauf des Versands

Der Zeitplaner ruft etwa alle 15 Minuten `GET /api/send-reminders` mit
`Authorization: Bearer <CRON_SECRET>` auf. Der Endpunkt

1. liest nur Konten mit `nextReminderAt <= jetzt` (ein Lauf ohne fällige
   Konten kostet einen Lesezugriff),
2. setzt je Konto in einer Transaktion `nextReminderAt` auf die nächste
   gewünschte Uhrzeit in der Zeitzone des Nutzers und `lastReminderDate` auf
   den lokalen Tag – dadurch nie doppelt, auch bei gleichzeitigen Läufen,
3. liest `streaks/*` und (für Lesepläne) `bible_reading/plan_*` sowie den
   Leseverlauf des Jahres,
4. sendet **eine** Nachricht an alle Geräte des Kontos, falls etwas offen
   ist, und löscht Abonnements, die der Push-Dienst als abgelaufen meldet
   (404/410).

Eine Erinnerung, die mehr als drei Stunden überfällig ist (Ausfall), wird
übersprungen statt nachts nachgeholt.

### Woran erinnert wird

Der Server berechnet keinen Lernstand neu. Er liest ab, was die App
gespeichert hat; die Kalendertage sind lokale Tage des Nutzers.

| Kategorie | Erinnerung, wenn … | Ziel beim Antippen |
|---|---|---|
| Bibelleseplan (`readingPlan`) | ein begonnener Plan nicht pausiert und nicht abgeschlossen ist (`complete`) und heute keine Lesung daraus bestätigt wurde | der Plan (`/bible/plan/<id>`) |
| Bibellese (`bibleReading`) | Track `bible` heute nicht erreicht (`lastCompletedDate` ≠ heute); entfällt, wenn schon an eine Planlesung erinnert wird | Bibel-Startseite |
| Texte auswendig lernen (`memorization`) | Track `memorization` heute nicht erreicht | `/memorize` |
| Sprachtrainer und Perikopenquiz (`trainers`) | Track `greek`, `latin` bzw. `perikope` heute nicht erreicht | `/greek`, `/latin`, `/perikopen` |

Zusätzlich gilt überall: Der Bereich wurde in den letzten 14 Tagen genutzt
(letzte Aktivität des Tracks bzw. letzte Änderung des Plans). Wer einen
Bereich nie oder länger nicht nutzt, wird daran nicht erinnert.

Für Vokabeln und Perikopen gibt es **keine** Erinnerung an einzelne fällige
Wiederholungen: `SpacedRepetition` kennt keinen Fälligkeitstermin, sondern
gewichtet die Auswahl fortlaufend. Maßgeblich ist deshalb das Tagesziel des
jeweiligen Tracks.

Liegt genau ein Grund vor, nennt die Nachricht ihn und führt in den Bereich.
Bei mehreren Gründen gibt es eine zusammengefasste Nachricht („Heute noch
offen“ mit den Bereichen), die zur Startseite führt. Ein Leseplan-Link,
dessen Plan inzwischen beendet wurde, öffnet die Bibel-Startseite.

### Einrichtung (einmalig)

Ohne diese Schritte zeigt die Einstellungsseite, dass Push noch
eingerichtet wird; alles andere funktioniert unverändert.

1. **VAPID-Schlüsselpaar erzeugen:** `npx web-push generate-vapid-keys`.
2. **Dienstkonto:** Firebase Console → Projekteinstellungen → Dienstkonten →
   „Neuen privaten Schlüssel generieren“ (JSON-Datei, nicht ins Repository).
3. **Vercel → Project → Settings → Environment Variables** (Production):

   | Variable | Wert |
   |---|---|
   | `FIREBASE_SERVICE_ACCOUNT` | Inhalt der JSON-Datei (roh oder Base64) |
   | `WEB_PUSH_PUBLIC_KEY` | öffentlicher VAPID-Schlüssel |
   | `WEB_PUSH_PRIVATE_KEY` | privater VAPID-Schlüssel |
   | `WEB_PUSH_SUBJECT` | `mailto:`-Adresse oder `https://www.theologie.app` |
   | `CRON_SECRET` | langer Zufallswert, z. B. `openssl rand -hex 32` |

4. **Öffentlichen Schlüssel in die App:** beim Build
   `--dart-define=WEB_PUSH_PUBLIC_KEY=<öffentlicher Schlüssel>` übergeben
   (oder als Standardwert in `PushService.defaultPublicKey` eintragen – er
   ist nicht geheim).
5. **GitHub → Settings → Secrets and variables → Actions:** Secret
   `CRON_SECRET` mit demselben Wert wie bei Vercel. Optional die Variable
   `PUSH_REMINDER_URL`, falls der Endpunkt nicht unter
   `https://www.theologie.app/api/send-reminders` liegt.
6. Neu ausliefern, in der App Push einschalten und
   „Testbenachrichtigung senden“ antippen.

GitHub startet geplante Läufe oft einige Minuten verspätet und pausiert sie
in Repositories ohne Aktivität nach 60 Tagen (dann unter „Actions“ wieder
einschalten). Im Pro-Tarif von Vercel kann stattdessen ein Cron in
`vercel.json` denselben Endpunkt aufrufen; im Hobby-Tarif ist dort nur ein
Lauf am Tag möglich. Wird ein VAPID-Schlüssel ersetzt, abonniert die App
beim nächsten Einschalten neu.

## E-Mail

Nur Nachrichten mit `channels.email: true`, die bewusst veröffentlicht
werden, und nur an Nutzer mit `email.announcements: true`. Sie werden nie
automatisch aus App-Ereignissen erzeugt. Der Versand erfolgt serverseitig
(noch nicht implementiert).
