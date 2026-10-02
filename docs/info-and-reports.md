# Info, Quellen und Fehlermeldungen

## Grundsatz

- Informationen sind auffindbar, stehen aber nicht im Weg: kein Banner, kein
  Hinweis beim Lernen, kein zusätzlicher Klick im Quiz.
- **Keine erfundenen Quellen.** In `AppModules` steht nur, was im Projekt
  belegt ist. Unbekannte Herkunft bleibt `origin: null`; die App zeigt dann
  „Die Herkunft dieses Datensatzes ist derzeit im Projekt nicht dokumentiert.“
- Quelle und Aufbereitung sind getrennt: KI ist nie die „Quelle“, sondern
  steht – wenn bekannt – in `aiNote`.

## Bausteine

| Datei | Inhalt |
|---|---|
| `lib/info/module_info.dart` | `ModuleInfo`, `SourceInfo` |
| `lib/info/app_info.dart` | `AppInfo` (Name, Version, Repository), `AppModules` (alle Bereiche) |
| `lib/widgets/info_report.dart` | `InfoButton`, `InfoReportFooter`, `showModuleInfo`, `showReportDialog`, `ReportDialog` |
| `lib/screens/about_screen.dart` | „Über die App“ (Einstellungen → Info & Hilfe) |
| `lib/services/reports/report.dart` | `Report`, `ReportContext`, `ReportCategory`, `ReportKind` |
| `lib/services/reports/report_service.dart` | `ReportService`, `ReportSender`, `FirestoreReportSender` |

## Neuen Screen anbinden

1. Bereich in `AppModules` anlegen (oder einen vorhandenen verwenden).
2. Im Screen einbauen:

```dart
// AppBar mit freiem Platz
actions: [
  InfoButton(
    module: AppModules.prayers,
    reportDetails: () => {"Gebet": prayer.id},
  ),
  const SettingsButton(),
],

// Trainer mit voller AppBar: am Ende des Inhalts
InfoReportFooter(module: AppModules.latinVocabulary, reportDetails: ...),
```

`reportDetails` liefert nur, was für die Fehlersuche nötig ist (Eintrags-ID,
abgefragte Form, Eingabe). Keine Kontodaten, keine eigenen Merkhilfen, und
die Lösung erst nach dem Prüfen (das Formular zeigt den Kontext an).

Hat der Screen einen globalen Tastatur-Listener für Enter, muss dieser
`infoReportOverlayOpen` beachten (siehe die Trainer).

## Meldungen (Firestore)

```
reports/{id}
  kind         "report"            ("feedback" ist vorgesehen, aber noch nicht erlaubt)
  category     bug · content · reference · translation · source · display · other
  description  string, 3–2000 Zeichen
  area         ModuleInfo.id, z. B. "pericope_quiz" ("general" = ohne Bereich)
  areaTitle    Anzeigename des Bereichs
  context      Zeilen "Schlüssel: Wert", höchstens 1500 Zeichen
  appVersion   z. B. "1.0.0+1"
  platform     z. B. "web (android)"
  createdAt    Serverzeit
```

Bewusst **nicht** enthalten: UID, E-Mail-Adresse, Name, Standort,
Browserkennung, Merkhilfen.

Meldungen lesen: Firebase Console → Firestore → `reports`. Clients können
die Collection nur beschreiben (`create`), nicht lesen, ändern oder löschen
(siehe `firestore.rules`; die Regeln müssen manuell in der Console
eingetragen werden – vorher schlägt das Senden fehl und die App bietet an,
die Meldung als Text zu kopieren).

### Missbrauch

- Regeln lassen nur die bekannten Felder mit begrenzten Längen zu.
- Die App sendet höchstens eine Meldung alle 30 Sekunden (nur clientseitig).
- Eine serverseitige Begrenzung gibt es nicht: Da auch Gäste melden dürfen
  und App Check nicht aktiv ist, kann die Collection von außen beschrieben
  werden. Abhilfe bei Bedarf: App Check aktivieren und erzwingen oder
  Meldungen über eine Serverfunktion mit Rate-Limit annehmen
  (`ReportService.sender` austauschen, das Formular bleibt unverändert).

## App-Version

`AppInfo.version` muss `version` in `pubspec.yaml` entsprechen; ein Test
prüft das.
