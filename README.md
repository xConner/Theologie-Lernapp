<p align="center">
  <img src="web/icons/Icon-192.png" alt="Logo von theologie.app" width="96">
</p>

# theologie.app

**Eine kostenlose, offene Lernapp für christliche Theologie, Bibelkunde und alte Sprachen.**

**[App öffnen](https://www.theologie.app/)** · **[Community auf Discord](https://discord.gg/vkk2f7RTMe)**

theologie.app richtet sich an Theologiestudierende und alle, die sich mit Bibel, alten Sprachen und kirchlichen Texten beschäftigen. Die App läuft im Browser und lässt sich auch ohne Konto als Gast nutzen. Sie ist Open Source und kommt ohne Paywall und ohne Werbung aus.

Der Schwerpunkt liegt auf aktivem Lernen: Die Trainer fragen ab, merken sich deinen Lernstand und wiederholen Inhalte in wachsenden Abständen.

> **Status:** In aktiver Entwicklung. Vieles funktioniert, manches ist noch unfertig.

## Funktionen

**Lernen**

- **Perikopenquiz** – zu einem Perikopentitel die passende Bibelstelle nennen; die abgefragte Perikope lässt sich direkt im Bibel-Reader nachlesen.
- **Altgriechisch** – Vokabeltrainer, Grammatiktrainer (Formen bestimmen), Vokabel- und Grammatikübersichten, griechische Bildschirmtastatur.
- **Latein** – Vokabeltrainer mit Zusatzformen und Genus sowie Vokabelübersicht.
- **Texte auswendig lernen** – Gebete, liturgische Texte und Bekenntnisse abschnittsweise lernen: vom Mitlesen über Lücken und Anfangsbuchstaben bis zum freien Aufsagen oder Schreiben.

**Lesen und Nachschlagen**

- **Bibel** – Reader mit mehreren Ausgaben in Deutsch, Englisch, Griechisch und Latein, mit Perikopenüberschriften, Stellen- und Textsuche; ohne Internetverbindung lesbar ([Quellen](docs/bible-sources.md)).
- **Bekenntnisse und Gebete** – die altkirchlichen Symbole, das Konkordienbuch und Gebete in mehreren Sprachfassungen.
- **Liturgischer Kalender** – Sonn- und Feiertage mit Farbe, Wochenspruch, Lesungen und Predigttext (bisher ein Teil des Jahres 2026).
- **Evangelisches Gesangbuch** – Lieder nach EG-Nummer, mit Suche; bei einem Teil der Lieder wie im Gesangbuch mit Noten und unterlegtem Text ([Quellen](docs/hymn-scores/README.md)).

Dazu kommen Lernstatistik, Streaks sowie ein helles und ein dunkles Design. Woher die Inhalte eines Bereichs stammen, steht in der App jeweils hinter dem Info-Symbol.

## Community und Mitmachen

Fragen, Ideen, Rückmeldungen oder Lust mitzuarbeiten? Komm gern auf unseren Discord-Server:

**[discord.gg/vkk2f7RTMe](https://discord.gg/vkk2f7RTMe)**

Dort lernst du die Community kennen und erreichst mich direkt. Beiträge sind willkommen – ob fachliche Korrektur, Idee oder Code –, und was sich wo am besten einbringen lässt, klären wir am einfachsten im Gespräch.

Fehler kannst du außerdem direkt in der App über das Info-Symbol eines Bereichs melden oder als [Issue](https://github.com/xConner/Theologie-Lernapp/issues) auf GitHub. Sicherheitslücken bitte nicht öffentlich, sondern wie in [SECURITY.md](SECURITY.md) beschrieben.

## Hinweis zur KI-Unterstützung

Die App wird zu großen Teilen mit KI-Unterstützung entwickelt; das gilt für den Quellcode und teilweise für die Aufbereitung von Inhalten. Trotz Prüfung können Fehler enthalten sein. Verlass dich bei theologischen und sprachlichen Inhalten nicht blind auf die App und zieh für wissenschaftliches Arbeiten eine zitierfähige Ausgabe heran. Wenn dir etwas falsch vorkommt, melde es gern.

## Für Entwickler

- **Flutter / Dart** (Dart SDK ab 3.12.2), ausgeliefert als Web-App
- **Firebase** für Konten und Lernstände; im Gastmodus bleibt alles lokal im Browser
- **Vercel-Funktionen** in [`api/`](api/), die griechische Flexionsformen aus Wiktionary auslesen und Push-Erinnerungen versenden ([Einrichtung](docs/notifications.md))
- **Inhalte als JSON** in [`assets/`](assets/)

```bash
git clone https://github.com/xConner/Theologie-Lernapp.git
cd Theologie-Lernapp
flutter pub get
flutter run -d chrome
```

Vor einem Pull Request bitte `flutter analyze` und `flutter test` ausführen. Einen Überblick über den Aufbau gibt [`docs/architecture.md`](docs/architecture.md). Bei größeren Vorhaben lohnt sich vorher eine kurze Absprache auf Discord.

## Lizenz

Der Quellcode ist öffentlich einsehbar; eine Lizenzdatei ist noch nicht hinterlegt, die Nutzungsbedingungen für Code und Inhalte sind also noch nicht festgelegt. Einzelne Inhalte stammen aus fremden Quellen und haben eigene Bedingungen, etwa die Bibelausgaben ([Quellen](docs/bible-sources.md)) und Wiktionary-Texte (CC BY-SA 4.0).
