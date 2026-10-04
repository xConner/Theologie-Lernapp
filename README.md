<p align="center">
  <img src="web/icons/Icon-192.png" alt="Logo von theologie.app" width="96">
</p>

# theologie.app

**Eine freie Lernapp für christliche Theologie – offen entwickelt, offen zum Mitmachen.**

Perikopen, Altgriechisch, Latein, Gebete und Bekenntnisse: nicht nur nachlesen, sondern aktiv lernen und behalten.

**[theologie.app ausprobieren](https://www.theologie.app/)** · [Fehler melden](https://github.com/xConner/Theologie-Lernapp/issues) · [Mitmachen](#mitmachen)

> **Status:** In aktiver Entwicklung. Vieles funktioniert, manches ist unfertig – und einiges ist sicher noch falsch. Genau deshalb ist jede Rückmeldung hilfreich.

## Was ist theologie.app?

theologie.app ist eine Lernapp für Theologiestudierende und alle, die sich mit Bibel, alten Sprachen und kirchlichen Texten beschäftigen. Sie läuft im Browser, kostet nichts und lässt sich auch ohne Konto als Gast nutzen.

Der Schwerpunkt liegt auf **aktivem Lernen**: Die Trainer fragen ab, merken sich deinen Lernstand und wiederholen Inhalte in wachsenden Abständen (Spaced Repetition). Dazu kommen Bereiche zum Nachschlagen.

Der Quellcode ist öffentlich, damit Inhalte und Lernlogik überprüfbar sind und jeder etwas verbessern kann.

## Aktuelle Bereiche

| Bereich | Worum geht es? | Wie kannst du helfen? |
| --- | --- | --- |
| **Perikopenquiz** | Zu einem Perikopentitel die passende Bibelstelle nennen | Stellen und Titel prüfen, Herkunft der Liste dokumentieren |
| **Altgriechisch** | Vokabeltrainer, Grammatiktrainer (Formen bestimmen), Grammatikübersichten, griechische Bildschirmtastatur | Vokabeln und Formen prüfen, falsche Bestimmungen melden |
| **Latein** | Vokabeltrainer mit Zusatzformen und Genus | Vokabeln prüfen und ergänzen, Ideen für einen Grammatiktrainer |
| **Texte auswendig lernen** | Gebete und Bekenntnisse abschnittsweise lernen: Mitlesen, Lücken, Anfangsbuchstaben, freies Aufsagen oder Schreiben | Lernablauf testen, Abschnittseinteilung prüfen, weitere Texte vorschlagen |
| **Gebete & Bekenntnisse** | Texte in mehreren Sprachfassungen zum Nachlesen | Texte, Übersetzungen und Quellenangaben prüfen |
| **Liturgischer Kalender** | Sonn- und Feiertage mit Farbe, Wochenspruch, Lesungen und Predigttext (bisher nur ein Teil von 2026) | Daten ergänzen und kontrollieren |
| **Evangelisches Gesangbuch** | Lieder nach EG-Nummer, mit Suche | Angaben prüfen, Schlagworte und Bibelstellen ergänzen |
| **App insgesamt** | Lernstatistik, Streaks, helles und dunkles Design | Ausprobieren, Bedienung testen, Bugs melden, Features bauen |

Woher die Daten eines Bereichs stammen – und wo das noch nicht dokumentiert ist –, steht in der App jeweils hinter dem Info-Symbol.

## Mitmachen

**Du musst nicht programmieren können, um mitzuhelfen.** Ein gemeldeter Tippfehler in einer Vokabel ist genauso ein Beitrag wie ein neues Feature.

- **Du nutzt die App einfach:** Probiere sie aus und melde, was nicht funktioniert, unklar ist oder umständlich wirkt.
- **Du kennst dich in Theologie oder alten Sprachen aus:** Prüfe Vokabeln, Formen, Übersetzungen, Bibelstellen und Texte. Fachliche Korrekturen sind das, was dem Projekt am meisten fehlt.
- **Du recherchierst gern:** Bei mehreren Datensätzen ist die Quelle noch nicht dokumentiert. Ausgaben, Belege und fehlende Daten nachzutragen hilft sehr.
- **Du hast eine Idee:** Ein neuer Lernmodus, ein weiterer Inhalt, eine bessere Bedienung – schreib sie auf, auch wenn sie noch unfertig ist.
- **Du lernst gerade programmieren:** Klone das Repository, ändere eine Kleinigkeit und stelle einen kleinen Pull Request. Coding-Assistenten sind dabei ausdrücklich willkommen (siehe [unten](#mit-ki-coding-tools-mitarbeiten)).
- **Du kannst programmieren:** Bugs beheben, Features entwickeln, Oberfläche verbessern, Tests schreiben, Architektur aufräumen.

## Hinweis zur KI-Unterstützung

> **Diese App wird zu großen Teilen mit KI-Unterstützung entwickelt.** Das gilt für den Quellcode und teilweise auch für Inhalte. Trotz Prüfung können deshalb Fehler enthalten sein: im Code, in der Oberfläche, in Vokabeln, Übersetzungen, grammatischen Formen, Bibelstellen, Quellenangaben und Erklärungen.

Verlass dich bei theologischen, sprachlichen und historischen Inhalten also nicht blind auf die App, und ziehe für wissenschaftliches Arbeiten eine zitierfähige Ausgabe heran.

Das ist kein Makel, den wir verstecken wollen, sondern der Grund, warum gemeinsames Prüfen hier so viel bringt: **Wenn dir etwas falsch vorkommt, melde es bitte.**

## Fehler, Ideen & Feedback

Es gibt zwei Wege:

- **In der App:** Über das Info-Symbol eines Bereichs kannst du einen Fehler direkt melden – auch als Gast. Der Zusammenhang (z. B. die betroffene Vokabel) wird dabei mitgeschickt.
- **Auf GitHub:** Öffne ein [Issue](https://github.com/xConner/Theologie-Lernapp/issues/new) – für Fehler genauso wie für Ideen und Wünsche.

Für eine Fehlermeldung reichen ein paar Zeilen:

- Was ist passiert?
- Was hast du erwartet?
- Wo tritt es auf (Bereich, Vokabel, Bibelstelle …)?
- Falls möglich: Screenshot oder Fehlermeldung

Sicherheitslücken bitte nicht öffentlich melden, sondern wie in [SECURITY.md](SECURITY.md) beschrieben.

## Für Entwickler

**Technik in Kürze**

- **Flutter / Dart** (Dart SDK ab 3.12.2), ausgeliefert als Web-App
- **Firebase** für Konten (Authentication) und Lernstände (Cloud Firestore); im Gastmodus bleibt alles lokal im Browser
- **Vercel-Funktionen** in [`api/`](api/) (TypeScript), die griechische Flexionsformen aus Wiktionary auslesen
- **Inhalte als JSON** in [`assets/`](assets/) – Vokabeln, Perikopen, Gebete, Bekenntnisse, Kalender, Lieder

**Lokal starten**

```bash
git clone https://github.com/xConner/Theologie-Lernapp.git
cd Theologie-Lernapp
flutter pub get
flutter run -d chrome
```

Die Firebase-Konfiguration liegt im Repository und ist derzeit nur für Web eingerichtet; die Ordner für andere Plattformen sind noch ungenutztes Flutter-Grundgerüst. Vor einem Pull Request bitte prüfen:

```bash
flutter analyze
flutter test
```

**Wo liegt was?**

| Ordner | Inhalt |
| --- | --- |
| `lib/screens/` | Oberflächen der einzelnen Bereiche |
| `lib/services/`, `lib/algorithms/` | Lernlogik, Antwortprüfung, Spaced Repetition |
| `lib/info/` | Beschreibung und Quellenangaben aller Bereiche |
| `assets/` | Lerninhalte als JSON |
| `test/` | Tests |
| `docs/` | Hintergrund, vor allem [`architecture.md`](docs/architecture.md) |

### Mit KI-Coding-Tools mitarbeiten

Du musst kein erfahrener Flutter-Entwickler sein. Du kannst das Repository mit einem Coding-Assistenten deiner Wahl erkunden und kleinere Änderungen ausprobieren. Lies vorher [`docs/architecture.md`](docs/architecture.md), teste die Änderung lokal und sieh dir das Ergebnis selbst an, bevor du es einreichst – besonders bei Inhalten: Eine KI darf nie als Quelle für Vokabeln, Formen oder Texte dienen.

### Ablauf

1. Repository ansehen und eine **kleine** Änderung auswählen
2. Lokal umsetzen und ausprobieren
3. `flutter analyze` und `flutter test` laufen lassen
4. Pull Request öffnen und kurz beschreiben, was sich ändert und warum

Bei größeren Vorhaben lohnt sich vorher ein Issue, damit keine Arbeit ins Leere läuft.

## Lizenz

Das Repository enthält derzeit **noch keine Lizenzdatei**. Der Quellcode ist öffentlich einsehbar, die Nutzungsbedingungen für Code und Inhalte sind aber noch nicht festgelegt. Einzelne Inhalte stammen aus fremden Quellen und haben eigene Bedingungen, etwa Wiktionary-Texte (CC BY-SA 4.0).
