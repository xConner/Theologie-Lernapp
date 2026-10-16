# Philosophie – Einführung in die Logik

Lernbereich unter **Philosophie** auf der Startseite. Weitere philosophische
Module werden als Eintrag in `PhilosophyHomeScreen.areas`
(`lib/screens/philosophy/philosophy_home_screen.dart`) ergänzt.

## Inhalte

| Was | Ort |
|---|---|
| Lektionen, Lernziele, typische Fehler, Übungen, Übungsklausur | `assets/logic/course.json` |
| Lehrtexte (eigenes Textformat, siehe `lib/models/logic/lesson_text.dart`) | `assets/logic/lessons/*.txt` |
| Modell und Laden | `lib/models/logic/`, `lib/services/logic/logic_course_loader.dart` |

Die Lehrtexte sind für die App eigens formuliert und folgen inhaltlich,
in Reihenfolge, Begriffen und Schreibweise einem universitären
Einführungskurs (neun Lektionen: Syntax, Semantik, Folgerung, drei
Beweislektionen, drei Lektionen Prädikatenlogik). Das Kursmaterial selbst
ist nicht Teil des Repositorys; Beispiele und Übungen sind abgewandelt.
Ergänzende Erläuterungen stehen in Kästen `::: explanation` und werden in
der App als „Erläuterung (ergänzend)“ gekennzeichnet.

Übungen haben stabile IDs (`l2.k1.iii`, `exam.4`); daran hängt der
Fortschritt. IDs nicht umbenennen, sonst gehen gespeicherte Antworten
verloren. Herkunft je Übung: `course` (Kursübung, abgewandelt), `extra`
(Zusatzübung).

## Logik-Engine (`lib/services/logic/`)

| Datei | Aufgabe |
|---|---|
| `formula.dart` | Formeln AL/PL, Gleichheit bis auf gebundene Variablen, doppelte Negation |
| `formula_parser.dart` | Grammatik des Kurses (Klammern nur um zweistellige Formen, Klammerersparnisregel), verständliche Fehlerbegründungen |
| `semantics.dart` | Wahrheitstafeln (Zeilen 1 1, 1 0, 0 1, 0 0), Einordnung, Folgerung, Gegenbeispiele |
| `proof_rules.dart` | Argumente und ihre Verfügbarkeit je Lektion (`ProofSystem`) |
| `proof_checker.dart` | Beweisprüfung Zeile für Zeile inkl. Abhängigkeitsspalte; Fehler werden wie in den Bewertungshinweisen eingeordnet (leicht/schwer/semantisch) |
| `exercise_evaluation.dart` | Bewertung je Aufgabentyp (Formalisierung über Äquivalenz, nicht über Zeichenketten) |
| `exercise_generator.dart` | Zusatzübungen; jede wird vor der Ausgabe geprüft, Beweise durch den Beweisprüfer |
| `logic_progress_store.dart` | Fortschritt in `users/{uid}/quiz_settings/logic_course` bzw. lokal (Gast) |

Ab Lektion 6 dürfen doppelte Negationen stillschweigend ergänzt oder
gestrichen werden (Argumente 6.2); der Prüfer vergleicht dann bis auf
doppelte Negationen. Bei +∀ verlangt er zusätzlich, dass das Individuum in
∀xAx nicht mehr vorkommt; bei -∃, dass es weder in ∃xAx, B noch in den
übrigen Annahmen vorkommt.

## Fortschritt

`LogicProgressStore` speichert geöffnete und als bearbeitet markierte
Lektionen sowie je Übung die Zahl richtiger/falscher Antworten und das
letzte Ergebnis. Zurücksetzen: Einstellungen → Lernbereich zurücksetzen →
„Einführung in die Logik“ (`ProgressArea.logic`); „Alle Lernfortschritte
zurücksetzen“ umfasst den Bereich. Gastdaten werden bei der Anmeldung mit
übernommen.

## Tests

`test/logic/logic_course_content_test.dart` prüft den gesamten Inhalt: jede
Formel, Wahrheitstafel und jeden Beweis im Lehrtext, alle Musterlösungen,
die Wohldefiniertheit aller Aufgaben und erzeugte Übungen. Nach jeder
Änderung an `assets/logic/` ausführen.
