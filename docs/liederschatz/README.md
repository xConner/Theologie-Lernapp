# Geistlicher Liederschatz (Brüdergemeinden): Recherchedaten

Rechercheergebnis vom 2026-10-24 zum *Geistlichen Liederschatz* der
evangelisch-lutherischen Brüdergemeinden (Textausgabe 1989, Notenausgabe 2000,
1300 Lieder). Nicht gemeint ist der gleichnamige Berliner Liederschatz von
1832 aus `assets/hymnals/catalog.json` (siehe `docs/hymnals.md`).

Die App liest keine dieser Dateien. Sie enthalten keine Liedtexte und keine
Noten, nur Verzeichnisangaben, Links und Prüfvermerke. Nichts davon ist für die
App freigegeben.

Bericht: [abschlussbericht.md](abschlussbericht.md).

## Dateien

| Datei | Inhalt | erzeugt |
|---|---|---|
| `bibliografie.json` | Werk, Ausgaben, Abgrenzung gleichnamiger Werke | von Hand |
| `quellen.json` | untersuchte Quellen, Zugriffsweg, nicht erreichbare Quellen | von Hand |
| `lizenzen.json` | Rechte- und Lizenzangaben der Quellen (nur wörtlich belegte) | von Hand |
| `lieder.json` | ein Datensatz je Lied | Skript |
| `textquellen.json` | Textfundstelle je Lied | Skript |
| `notenquellen.json` | Notenkandidaten aus dem EG (andere Ausgabe) | Skript |
| `rechte.json` | Einschätzung je Lied, `in_app_erlaubt` immer `false` | Skript |
| `pruefstatus.json` | Status je Lied, Belege, offene Prüfungen | Skript |
| `abdeckung.json` | Zählung der Status | Skript |

Die Skriptdateien erzeugt `python tool/liederschatz/build_liederschatz.py`
aus den Rohdaten unter `tool/liederschatz/quellen/` und den EG-Daten des
Repositorys, ohne Netz. `test/liederschatz_research_test.dart` prüft sie.

## IDs

`gls_bg.NNNN` mit der vierstelligen GLS-Nummer, z. B. `gls_bg.0001`. Führt
evangeliums.net unter einer Nummer zwei verschiedene Lieder (Nr. 108, 116, 153,
201), heißen sie `gls_bg.0108a` und `gls_bg.0108b` in der Reihenfolge der
Liederbuchseite. Zeilen mit gleicher Nummer und gleicher Liedseite (Nr. 182,
459) sind ein Eintrag. Steht dieselbe Liedseite unter zwei Nummern (83/230,
108/502, 340/357, 878/936), bleiben es zwei Einträge mit Verweis
(`gleiche_liedseite_wie_nr`). Zusammengeführt wird nichts.

## Status

Jeder Status steht nur, wenn die Bedingung geprüft wurde.

| Status | Bedingung |
|---|---|
| `verified_match` | Die Liedseite selbst nennt diese GLS-Nummer (30 einzeln abgerufene Liedseiten, 87 Suchtreffer). Nicht gegen das gedruckte Buch geprüft. |
| `text_found` | evangeliums.net zeigt auf der Liedseite einen Text. Die Fassung ist nicht mit dem GLS verglichen. |
| `notation_found` | Für ein EG-Lied mit gleichem Titel gibt es eine Notenquelle (andere Ausgabe; Melodie im GLS ungeprüft). |
| `complete_notation_found` | Notensatz der GLS-Ausgabe gefunden. Bisher bei keinem Lied. |
| `license_verified` | Lizenz für die Nutzung in der App belegt. Bisher bei keinem Lied. |
| `rights_review_required` | Rechteklärung erforderlich. Bei allen Liedern. |
| `not_found` | Weder Text noch Notenquelle gefunden. |
