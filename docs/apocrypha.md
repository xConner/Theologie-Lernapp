# Apokryphen & außerkanonische Schriften

Eigener Hauptbereich neben „Bibel“ (Auftrag Conner, 29.10.2026) für
Schriften außerhalb des protestantischen Kanons: Apokryphen bzw.
Deuterokanonen des Alten Testaments, jüdische Pseudepigraphen und
Apokalypsen, außerkanonische Evangelien, Apostolische Väter,
Kirchenordnungen, Apostelakten und Schriften aus Nag Hammadi.
Datenformat und Import: `tool/apocrypha/README.md`.

## Grundsätze

- **Keine erfundenen oder geschützten Texte.** Volltext nur aus gemeinfreien
  Ausgaben oder offen lizenzierten Digitalisaten (`publicDomain`,
  `openLicense`, `permission`). Das Repository ist öffentlich; geschützte
  Übersetzungen (z. B. Littmann, Jubiläen; Charlesworth, Oden Salomos;
  alle Übersetzungen des Judasevangeliums) erscheinen nur als Verweis.
- **Keine KI-Übersetzungen.** Die ChatGPT-Übertragungen der
  HistoricalChristianFaith-Sammlung sind ausgeschlossen (Prüfung im
  Import-Skript und im Test).
- **„Apokryph“ ist kein neutraler Begriff.** Bei den Deuterokanonen steht
  der Status je Kirche mit deren eigener Bezeichnung (lutherisch
  „Apokryphen“, katholisch „deuterokanonisch“, orthodox
  „Anagignoskomena“ …). Die Kategorie heißt „Apokryphen /
  Deuterokanonen (AT)“.
- **Pseudepigraphen**: Der Name im Titel ist die Zuschreibung, nicht der
  Verfasser (`attribution.assessment = pseudepigraph`).
- **Einordnung in drei Stufen**: gesichert, wahrscheinlich, umstritten
  (`assessments`). Zusammenfassungen und Einordnungen sind redaktionell
  (mit KI-Unterstützung formuliert, im Infodialog vermerkt).
- **Werk, Ausgabe, Übersetzung und Digitalisat getrennt**: Das Werk trägt
  Datierung, Ursprache, Überlieferung und Erhaltung; jede Fassung trägt
  Übersetzer, Herausgeber, Ausgabe, Jahr, Vorlage, digitale Quelle (Repository
  mit Commit), Rechte, Lizenz, Pflichtnachweis und Umfang.
- **Unvollständiges ist gekennzeichnet**: Erhaltung des Werks
  (`preservation`) und Umfang der Fassung (`coverage` mit
  `coverageNote`) sind getrennt. Der Leser zeigt bei unvollständigen
  Fassungen einen Hinweis.
- **Kein doppelter Text**: Septuaginta- und Vulgata-Fassungen verweisen auf
  `assets/bible/grcbrent` bzw. `assets/bible/latVUC`; ein Werk in mehreren
  Kategorien liegt einmal vor.

## Aufbau in der App

| Aufgabe | Ort |
|---|---|
| Modell (Werk, Fassung, Kanon, Inhaltsverzeichnis) | `lib/models/apocrypha/apocrypha.dart` |
| Laden, Filter, Suche, Volltextsuche | `lib/services/apocrypha/apocrypha_repository.dart` |
| Leseposition, Merkliste, Lesezeichen, Ansicht | `lib/services/apocrypha/apocrypha_user_data.dart` (`quiz_settings/apocrypha_reading`) |
| Übersicht, Filter, Volltextsuche | `lib/screens/apocrypha/apocrypha_home_screen.dart` |
| Werkseite | `lib/screens/apocrypha/apocrypha_work_screen.dart` |
| Leser mit Fassungswechsel und Vergleich | `lib/screens/apocrypha/apocrypha_reader_screen.dart` |
| Infodialog | `AppModules.apocrypha` in `lib/info/app_info.dart` |

Die Startansicht zeigt „Weiterlesen“, die Merkliste und die zehn Gruppen
statt einer langen Liste; Suche oder Filter wechseln zur Trefferliste.
Filter: Gruppe (Evangelien, Apostolische Väter, Apokalypsen,
Pseudepigraphen, Nag Hammadi …), Herkunft (jüdisch/christlich), Epoche,
Sprache einer Fassung, Zahl der Übersetzungen, Volltext, Originaltext,
vollständig, fragmentarisch.

Der Leser stellt im Vergleich gleich nummerierte Verse nebeneinander (ab
700 px Breite in zwei Spalten, sonst untereinander). Ohne gemeinsame
Zählung stehen beide Texte als Ganzes nebeneinander. Langes Tippen auf einen
Vers setzt ein Lesezeichen. Griechisch steht in Tinos, Koptisch und Ge'ez in
Noto Sans Coptic/Ethiopic (OFL, `assets/fonts/NotoSans-OFL.txt`). Unter
jedem Abschnitt steht der Lizenznachweis der Fassung.

## Bestand (29.10.2026)

70 Werke, 44 mit Text in der App, 94 Fassungen mit Text, 36 Verweise.
Werke ohne freien Text haben einen Verweis auf eine Übersichtsseite (Early
Christian/Jewish Writings, Coptic SCRIPTORIUM) und einen Grund
(`noTextReason`). Die deutschen BKV-Fassungen der Apostolischen Väter
(Zeller 1918) sind verzeichnet; der Text folgt, sobald die EPUBs vorliegen
(Nutzungserlaubnis wie bei den Kirchenvätern, `docs/church-fathers.md`).

Offene Ergänzungen mit gemeinfreien Vorlagen, die in dieser Umgebung nicht
abrufbar waren: ANF 8/9 (Petrus- und Paulusapokalypse, Kindheitsevangelium
des Thomas, Nikodemusevangelium, Paulus und Thekla), M. R. James 1924,
Charles 1913 (2. Henoch, 2./3. Baruch), Harris 1909 (Oden Salomos),
Pistis Sophia (Coptic SCRIPTORIUM).
