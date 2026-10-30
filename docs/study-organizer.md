# Studiumsorganisation: Aufgaben, Kalender, Notizen

Der Startbildschirm-Knopf „Studiumsorganisation“ öffnet `OrganizerScreen`
(`lib/screens/organizer/`) mit vier Reitern: Übersicht, Aufgaben, Kalender,
Notizen. Stundenplan, Veranstaltungssuche und Studienunterlagen
(`StudyOrganizationScreen`) liegen eine Ebene tiefer (Symbol oben rechts).
Für Studium und Privates gleichermaßen gedacht, bewusst ohne
Projektmanagement-Ballast.

## Bausteine

| Datei | Inhalt |
| --- | --- |
| `lib/models/organizer/organizer_items.dart` | `OrgTask`, `OrgEvent`, `OrgNote`, `OrgArea` (Zuordnung), `OrgConfig`, `OrgLink`, `OrgSource`, IDs |
| `lib/services/organizer/org_dates.dart` | `OrgDate`/`OrgTime` (Wanduhrzeit), deutscher Datumsparser |
| `lib/services/organizer/recurrence.dart` | Wiederholung von Terminen (täglich/wöchentlich/monatlich/jährlich, Intervall, Ende, Ausnahmen) |
| `lib/services/organizer/organizer_store.dart` | Speicher: Firestore bzw. Gastmodus, Gast-Übernahme |
| `lib/services/organizer/organizer_controller.dart` | Zustand, Abfragen (Aufgabenansichten, Kalenderzeitraum, Erinnerungen, Notizsuche), Änderungen |
| `lib/services/organizer/seminar_import.dart` | Seminarplan → Kandidaten, Abgleich, Übernahme |
| `lib/services/organizer/import_sources.dart` | Bekannte Pläne (Proseminar, Leseplan zur Übung, eingefügter Text) |
| `lib/services/organizer/reading_tasks.dart` | Tagespensum der Kurs-Lesepläne als Aufgabe |
| `lib/services/organizer/learning_signals.dart` | Tagesziele der Lernbereiche (Streaks) |

## Speicherung und Synchronisation

- Konto: `users/{uid}/organizer/{id}`, ein Dokument je Aufgabe, Termin,
  Notiz, Zuordnung, Seminarplan-Einstellung und `config`. Getrennt vom
  Lernfortschritt. Regel in `firestore.rules` (`isUserCollection`),
  Kontolöschung in `AccountDeletionService.userCollections`.
- Gast: SharedPreferences `guest.v1.organizer`; nach der Anmeldung
  übernimmt `OrganizerGuestMigration` fehlende Dokumente (vorhandene bleiben
  unverändert) und leert den lokalen Speicher.
- Geschrieben werden nur geänderte Felder (`set(merge: true)`): Ändern zwei
  Geräte verschiedene Felder desselben Eintrags, bleiben beide Änderungen
  erhalten. Offline puffert Firestore die Schreibvorgänge; die Oberfläche
  zeigt Änderungen sofort (ausstehende Schreibvorgänge überlagern den
  Serverstand). Scheitert ein Schreiben, erscheint ein Hinweis.
- Neue Einträge bekommen zufällige IDs, übernommene Einträge
  deterministische (`OrgIds.stable`, FNV-Hash mit `_mul32`, damit Web und
  Android dieselbe ID errechnen; mit dart2js geprüft). Zwei Geräte, die
  denselben Plan übernehmen, schreiben also dasselbe Dokument statt zweier.
- Standard-Zuordnungen (Allgemein, Lehrveranstaltungen, Bibelkunde,
  Griechisch, Latein, Philosophie, Kirchengeschichte, Privat, Einkauf)
  haben feste IDs und werden einmal angelegt (`config.seeded`).

## Datum und Zeitzone

Termine und Fälligkeiten sind Wanduhrzeiten (`yyyy-MM-dd`, `HH:MM`) ohne
Zeitzone: Ein Termin um 10:15 bleibt 10:15, auch über die Zeitumstellung
und auf Geräten in anderer Zeitzone. Datumsrechnung läuft über UTC-Tage
(keine 23-/25-Stunden-Tage). Der Controller stellt sich um Mitternacht auf
den neuen Tag um (Timer), „Heute“, „Überfällig“ und das Lesepensum
wechseln ohne Neustart.

## Aufgaben

Ansichten Heute, Demnächst (14 Tage), Überfällig, alle offenen, Erledigte;
Filter nach Zuordnung oder Studium/Privat. Abhaken mit einem Tipp, Löschen
mit Rückgängig. Optionale Wiederholung (täglich, werktags, wöchentlich,
monatlich): Beim Abhaken entsteht die nächste Aufgabe mit fester ID
`<id>|next`, ein erneutes Abhaken auf einem zweiten Gerät erzeugt also
keine zweite.

Lernbereich-Aufgaben (z. B. „Griechisch üben“) können an ein Tagesziel
(`trackId`) gebunden werden: Ist das Tagesziel erreicht, hakt sich die
Aufgabe selbst ab. Nur in diese Richtung.

## Kalender

Monat, Woche, Tag und Liste. Arten: Vorlesung, Seminar, Prüfung/Klausur,
Abgabe, Bibelkunde, Gottesdienst, Privat, Sonstiges und eigene. Prüfungen
und Abgaben sind hervorgehoben und stehen mit Countdown in der Übersicht;
„Lernaufgaben planen“ legt verknüpfte Aufgaben vor dem Termin an.
Wiederholungen: einzelner Termin bearbeiten/löschen (Ausnahme + eigene
Kopie), ab hier beenden oder ganze Serie. Sitzungen des Stundenplans
erscheinen schreibgeschützt (abschaltbar), damit nichts doppelt
eingetragen wird.

Erinnerungen erscheinen in der App (Übersicht), nicht als Push: Die App hat
kein Plugin für lokale Benachrichtigungen, und der Server-Push läuft nur
täglich – minutengenaue Erinnerungen wären unzuverlässig.

## Notizen

Titel und Text mit einfacher Struktur (Überschriften, Listen,
Checklisten, **fett**), automatisches Speichern (0,7 s nach der letzten
Eingabe und beim Verlassen), Suche, Zuordnung, Schlagwörter, Anheften,
Archivieren. Verknüpfungen zu Bibelstellen, App-Bereichen, Aufgaben,
Terminen und anderen Notizen; Rückverweise werden angezeigt. Ein
fremdes Update (anderes Gerät) übernimmt der Editor nur, solange lokal
nichts ungespeichert ist.

## Seminarpläne übernehmen

Quellen: Proseminar Kirchengeschichte (`assets/church_history/seminar.json`,
Abschnitte „Aufgaben zur N. Sitzung“), Lesepläne zu Lehrveranstaltungen
(Sitzungen, Meilensteine als Prüfung) – beide nur mit Freigabe der
Vorlesungsunterlagen – sowie eingefügter Text (Daten wie „5.11.“ oder
„12. November“, sonst erste Sitzung + Rhythmus). Erkannt werden nur
Sitzungstermine, Vorbereitungsaufgaben (Lektüre, Referat, Abgabe …) und
Fristen; Rahmentext wird übergangen.

Ablauf: Vorschau mit Auswahl und Bearbeitung je Eintrag, dann Übernahme.
Jeder Kandidat hat einen festen Schlüssel und einen Fingerabdruck. Der
Abgleich kennt neu, geändert, Konflikt (lokal bearbeitet und im Plan
geändert), unverändert, entfallen und verworfen. Erledigte und von Hand
bearbeitete Einträge werden nie überschrieben; gelöschte bleiben als
Grabstein, damit sie nicht wiederkommen. Vergangenes ist nicht
vorausgewählt. „Automatisch übernehmen“ (je Plan) übernimmt beim Öffnen nur
Neues und Änderungen unberührter Einträge; sonst zeigt die Übersicht einen
Hinweis auf Änderungen.

## Leseplan als Aufgabe

Das heutige Pensum begonnener Kurs-Lesepläne (Bibelkunde) erscheint unter
„Heute“, Rückstände als „Nachholen“. Diese Aufgaben werden nicht
gespeichert, sondern aus `BibleReadingService` berechnet: Sind die Kapitel
im Leseplan gelesen, ist die Aufgabe erledigt. Abhaken in der
Aufgabenliste ist bewusst nicht möglich, damit kein Kapitel als gelesen
gilt, das nicht gelesen wurde; „Lesen“ öffnet den Leser. Pausierte Pläne
erscheinen nicht. Der Leseplan selbst bleibt unverändert.

## Tests

`test/organizer/`: Logik (CRUD, Wiederholung, Sync zweier Geräte,
offline, Datum/Zeitumstellung, IDs), Seminar-Import (Erkennung, Abgleich,
Duplikate, Bearbeitetes), Leseplan-Aufgaben, Oberfläche.
