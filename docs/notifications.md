# Benachrichtigungen

## Grundsatz

| Kanal | Zweck | Inhalt |
|---|---|---|
| **Home / Trainer** | persönlicher Lernstatus | Streak, Tagesziel, Fortschritt |
| **Glocke** (In-App) | dauerhafte App-Nachrichten | neue Inhalte, System, Account, Mitteilungen |
| **Push** | zeitabhängige Erinnerungen | nur Streak-Erinnerungen, neue Inhalte, wichtige Systemnachrichten |
| **E-Mail** | sehr selten, bewusst ausgelöst | wichtige Mitteilungen von theologie.app |

Die Glocke zeigt **nie** Streaks, Tagesziele, Lernfortschritt oder fällige
Wiederholungen. Es gibt **keine** allgemeinen Lernerinnerungen und keine
Push-Erinnerungen an fällige Wiederholungen. Firebase-Auth-Mails (Passwort,
E-Mail-Bestätigung) laufen weiterhin separat über Firebase Auth.

## Datenmodell (Firestore)

```
notifications/{id}                     globale Nachricht (alle Nutzer + Gäste)
users/{uid}/inbox/{id}                 persönliche Nachricht (z. B. Account & Sicherheit)
users/{uid}/notification_state/inbox   Lesestatus der Glocke
users/{uid}.notification_settings      Push-/E-Mail-Einstellungen
users/{uid}/push_tokens/{token}        FCM-Tokens (vorbereitet)
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
`/latin/vocabulary`, `/calendar`, `/hymns`, `/confessions`, `/settings`,
`/settings/notifications`, `/account`. Unbekannte Pfade werden nicht
angezeigt. Derselbe Wert wird später im FCM-Datenfeld `link` verwendet.

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

Clients können `notifications/` und `users/{uid}/inbox/` nicht beschreiben
(siehe `firestore.rules`). Persönliche Account-Nachrichten schreibt später
ausschließlich der Server (Admin SDK). Die Regeln müssen manuell in der
Console eingetragen werden.

## Einstellungen

`users/{uid}.notification_settings`:

```
push:  { enabled: false, streakReminders: true, newContent: false, systemMessages: true }
email: { announcements: false }
utcOffsetMinutes: 120
```

Push und E-Mail sind Opt-in. Die Glocke hängt nicht von diesen
Einstellungen ab.

## Push aktivieren (noch offen)

FCM ist noch nicht eingebunden. Nötige Schritte:

1. `firebase_messaging` hinzufügen, Web-Push-Zertifikat (VAPID-Key) in der
   Console erzeugen und `web/firebase-messaging-sw.js` anlegen.
2. Wenn der Nutzer Push einschaltet: Berechtigung anfragen, Token holen und
   mit `PushTokenRegistry.register` speichern; bei `onTokenRefresh`
   erneut registrieren; beim Ausschalten bzw. Abmelden `unregister`.
3. Beim Tippen auf eine Push-Nachricht `AppDeepLink.parse(data["link"])`
   mit `openDeepLink` öffnen und die Nachricht (`data["notificationId"]`)
   als gelesen markieren.
4. Versand serverseitig (Admin SDK, z. B. Cloud Function oder
   Vercel-Cron): nur an Tokens mit `push.enabled` **und** passender
   Unterkategorie senden; von FCM als ungültig gemeldete Tokens löschen.

Bis dahin zeigt die Einstellungsseite einen Hinweis, dass Push noch
eingerichtet wird. Die Auswahl wird trotzdem gespeichert.

### Regeln für Streak-Erinnerungen (serverseitig)

Grundlage sind die vorhandenen Dokumente `users/{uid}/streaks/{trackId}`.
Die Streak-Logik wird nicht dupliziert, sondern nur gelesen. Die
Kalendertage sind lokale Tage des Nutzers (`utcOffsetMinutes`).

Eine Erinnerung für einen Track wird nur gesendet, wenn **alle** Bedingungen
erfüllt sind:

- `push.enabled` und `push.streakReminders` sind aktiv,
- es gibt eine **laufende** Streak: `lastCompletedDate` = gestern (lokal),
- das heutige Ziel ist noch nicht erreicht,
- für diesen Track wurde heute noch keine Erinnerung gesendet
  (höchstens eine je Track und Tag, z. B. am frühen Abend lokaler Zeit).

Ohne laufende Streak gibt es **keine** Erinnerung: Sie wäre eine allgemeine
Lernerinnerung.

Beispieltext: „Dein Griechisch-Streak wartet – dir fehlen noch 3 richtige
Antworten.“ (fehlend = Tagesziel − `todayCorrectAnswers`, falls
`lastActivityDate` = heute).

Streak-Erinnerungen erscheinen nicht in der Glocke.

## E-Mail

Nur Nachrichten mit `channels.email: true`, die bewusst veröffentlicht
werden, und nur an Nutzer mit `email.announcements: true`. Sie werden nie
automatisch aus App-Ereignissen erzeugt. Der Versand erfolgt serverseitig
(noch nicht implementiert).
