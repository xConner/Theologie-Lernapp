# Sicherheitsrichtlinie

## Sicherheitslücken melden

Bitte melde vermutete Sicherheitslücken **nicht** über öffentliche Issues,
Pull Requests oder Diskussionen.

Nutze stattdessen die private Meldefunktion von GitHub:
**Security → Report a vulnerability** in diesem Repository
(„Private vulnerability reporting“).

<!-- Betreiber: Private vulnerability reporting unter Settings → Security
     aktivieren. Optional zusätzlich eine Kontaktadresse angeben:
     [E-Mail-Adresse für Sicherheitsmeldungen ergänzen] -->

Hilfreich sind:

- betroffener Bereich (Web-App, API unter `/api/`, Firestore-Regeln, …),
- Schritte zur Reproduktion,
- mögliche Auswirkungen.

Bitte teste nur mit deinem eigenen Konto, greife nicht auf fremde Daten zu
und führe keine Tests durch, die den Betrieb beeinträchtigen (z. B.
Lasttests, Massenanfragen, Spam über das Meldeformular).

Das Projekt wird nebenbei betreut; eine Rückmeldung kann einige Tage dauern.
Es gibt kein Bug-Bounty-Programm.

## Unterstützte Versionen

Unterstützt wird nur die aktuell unter https://www.theologie.app
veröffentlichte Version.

## Hinweis zur Firebase-Konfiguration

Die Firebase-Web-Konfiguration in `lib/firebase_options.dart` (u. a. der
API-Key) ist **kein Geheimnis**; sie ist in jeder Firebase-Web-App öffentlich
sichtbar. Der Zugriffsschutz erfolgt über Firebase Authentication und die
Firestore-Sicherheitsregeln (`firestore.rules`). Meldungen, die sich allein
auf die Sichtbarkeit dieser Werte beziehen, sind daher keine Sicherheitslücke.
