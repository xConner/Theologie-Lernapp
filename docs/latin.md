# Latein: Wortschatz und Grammatik

Stand: 21. Oktober 2026.

## Lehrbuch hinter der Vokabelliste

Die Vokabelliste (`assets/latin_vocabulary.json`) nennt ihr Lehrbuch nicht.
Sie folgt nach unserer Prüfung **„prima. Latein lernen“, Band 1**
(C.C. Buchner, Bamberg 2020; herausgegeben von Clement Utz und Andrea
Kammerer; ISBN 978-3-661-40501-8). Band 1 enthält die Lektionen 1–14 mit
ihren Wortschätzen, Band 2 die Lektionen 15–28.

| App | Lehrbuch |
|---|---|
| Schritt 1–13 | Lektion 1–13 |
| Unter-Schritt 1–3 (nur Lektion 1–3) | Wortschatzteile einer Lektion |
| Unter-Schritt 1 (Lektion 4–13) | ganze Lektion; Wortschatzteile unbekannt |

**Belege**

* Thematische Übereinstimmung: Die Lektionen 1–4 von prima. erzählen einen
  Kriminalfall um das Pferd Incitatus (Verlagskonzeption Band 1). Der
  Wortschatz von Schritt 1–2 passt genau dazu: equus, victor, victōria,
  circus, furtum, mercātor, clāmor.
* Eine von Nutzern erstellte Lernkartenliste „Prima. 2. Lektion Teil 2“
  (quizlet.com) enthält dieselben, eher seltenen Wörter wie Schritt 2.2 der
  App (nōn iam, iō „hurra“, iterum, itaque, exspectāre) und dieselbe
  Gliederung in Teile.

**Verlässlichkeit:** mittel bis hoch. Die Wortlisten des Verlags waren
nicht frei zugänglich; geprüft wurde nur an Teilauszügen (Lernkarten von
Nutzern) und an der Verlagskonzeption. Andere Buchner-Lehrwerke (prima
nova, prima brevis, ROMA) weichen in Wortauswahl oder Lektionszählung ab.

## Abgleich des Wortschatzes

* Lektion 1–3 (IDs 1–102): Der Abgleich mit den zugänglichen Auszügen
  ergab kein fehlendes Wort. Gegen die vollständige Verlagsliste ließ sich
  das nicht prüfen.
* Korrigiert: ID 33 „hic“ ist das Adverb „hier“ und wird mit langem i
  geschrieben (hīc), anders als das Pronomen hic, haec, hoc.
* IDs bleiben unverändert, damit gespeicherte Lernstände ihrem Wort
  zugeordnet bleiben (Test `test/latin_vocabulary_test.dart`).

**Lücken**

* Lektion 4–13 sind seit dem 21. Oktober 2026 enthalten (siehe unten).
  Es fehlen Lektion 14 (Band 1) und 15–28 (Band 2).
* Die Recherche lief in einer Umgebung mit eingeschränktem Netzzugang:
  Seiten von Verlag, Quizlet, Wiktionary und Wörterbüchern waren direkt
  nicht abrufbar, nur Zusammenfassungen von Suchergebnissen.
* Zum Ergänzen genügt es, die Wortschatzseiten der weiteren Lektionen (aus
  dem eigenen Buch) bereitzustellen. Neue Einträge bekommen fortlaufende
  IDs ab 418; Schritt = Lektion, Unter-Schritt = Wortschatzteil.

**Zweite Recherche (19. Oktober 2026)**

Ziel war der Wortschatz der Lektionen 4–28. Ergebnis: Es kam keine Vokabel
hinzu, weil sich keine Lektion zuverlässig rekonstruieren ließ.

* Erreichbar war nur die Websuche, die Titel und kurze Ausschnitte liefert.
  Direkt abrufen ließ sich keine Quelle: Verlag (ccbuchner.de), Quizlet,
  karteikarte.com, phase-6, card2brain, Studydrive, Knowunity, Wordwall,
  latin-is-simple, Wiktionary, Wikibooks, archive.org sowie die Suchmaschinen
  Google, Bing und DuckDuckGo wurden vom Netzwerk der Umgebung abgewiesen
  (HTTP 403 bzw. DNS-Fehler). GitHub ist nur für dieses Repository
  freigegeben.
* Bestätigt: Eine Quizlet-Liste „prima. Vokabeln Lektion 1“ (37 Karten) hat
  dieselbe Größe wie Schritt 1 der App (37 Wörter). Eine Liste „prima.1
  Lektion 4“ (28 Karten) existiert; in Ausschnitten erscheinen gaudium,
  timor, porta, simul und sceleratus. Ein Schulcurriculum nennt für
  Lektion 4 den Titel „Incitatus ist der Größte!“ und den Ablativ.
* Nicht verwertbar: Die Ausschnitte zeigen je Liste nur wenige Wörter,
  widersprechen sich zwischen Suchläufen und mischen die Ausgaben prima A,
  prima nova, prima brevis und prima. (2020), die andere Lektionszählungen
  haben. Wortschatzteile (Unter-Schritte) waren nirgends erkennbar.
* Fünf Wörter einer Lektion mit erfundenem Wortschatzteil hätten im
  Trainer eine vollständige Lektion vorgetäuscht. Deshalb wurde nichts
  übernommen.
* Für spätere Ergänzungen ist nichts im Code anzupassen: Trainer und
  Übersicht lesen Schritte und Unter-Schritte aus den Daten, neue Schritte
  sind im Trainer automatisch aktiv, Lernstände hängen an der ID (Test
  „eine neue Lektion erscheint ohne Codeänderung im Filter“).

## Lektion 4–13 (ergänzt am 21. Oktober 2026)

**Quelle:** zehn PDF-Ausdrucke der Quizlet-Lernkarten „prima.kompakt
Lektion 4“ bis „Lektion 13“, die Conner im Projekt hochgeladen und zur
Übernahme freigegeben hat. Jeder Ausdruck beginnt mit Seite 2; was auf
Seite 1 stand, ist nicht bekannt. Lektion 4 der Vorlage enthält gaudium,
timor, porta, simul und scelerātus, dieselben Wörter, die eine Suche für
„prima.1 Lektion 4“ zeigte. Die Lektionszählung von prima.kompakt passt
damit nach unserer Annahme zu prima. Band 1.

**Übernahme**

* 315 neue Einträge, IDs 103–417, Schritt = Lektion, Unter-Schritt 1. Die
  Vorlage gliedert die Lektionen nicht in Wortschatzteile.
* Bedeutungen, Genus und Zusatzformen wie in der Vorlage. Die Zusatzform
  wechselt wie im Buch: Lektion 4–7 1. Person Singular, ab Lektion 8 mit
  Perfekt (teneō, tenuī); Nomen ab Lektion 6 mit Genitiv, in Lektion 4–5
  ohne Zusatzform; Adjektive mit Femininum und Neutrum.
* Längenzeichen hat die Vorlage nicht; sie wurden nach dem Wörterbuch
  ergänzt.
* Berichtigte Tippfehler der Vorlage: homie → hodiē, tempo → temptō,
  tuuus → tuus, dicessi → discessī, consuli → cōnsuluī, villa (Genitiv) →
  vīllae, sententia (Genitiv) → sententiae, erbärmlichkeit → erbärmlich.
* Übersetzungen mit Komma („der, die, das erste“) sind gekürzt („der
  erste“) oder aufgeteilt, weil der Trainer Kommas als Trennung zwischen
  Bedeutungen liest. Bei prīmus, quī und is steht die vollständige Angabe
  in der Notiz.
* Nomen mit zwei Genera (parēns, comes) haben das Genus „m/f“; der Trainer
  akzeptiert dort m, f und m/f.
* Possessiv- und Relativpronomen stehen mit allen Formen im Lemma
  (meus, mea, meum; quī, quae, quod).

**Wiederholungen (29 Karten):** Die Vorlage wiederholt Wörter, meist mit
Perfektstamm (Lektion 11: dīcere, dīxī …). Damit kein Wort doppelt im
Trainer erscheint, bleibt der frühere Eintrag; die neue Angabe steht in
seiner Notiz („Stammformen: dīcō, dīxī (Lektion 11)“). Das betrifft auch
Wörter aus Lektion 1–3 (esse, vidēre, venīre …) und in mit Ablativ
(Lektion 4) beim Eintrag in. gaudēre (Lektion 4) wiederholt Lektion 1
ohne neue Angabe. Die Perfektformen fragt der Vokabeltrainer deshalb
nicht ab.

**Grammatiktrainer:** Die Einstellung „Nur Wörter aus dem Wortschatz“
nutzt weiterhin die Wörter der Lektionen 1–3; die Musterwörter (rēx, urbs,
mittere …) sind nicht mit den neuen Einträgen verknüpft.

## Grammatikübersicht und Grammatiktrainer

Die Formen werden in `lib/services/latin/grammar/latin_morphology.dart`
aus Grundform, Stamm und Endungen gebildet; esse, posse, īre, velle und
die Pronomen sind Tabellen. Übersicht und Trainer verwenden dieselben
Paradigmen. `test/latin_grammar_morphology_test.dart` prüft sie gegen
Standardparadigmen.

Die Wörter stehen in `latin_grammar_words.dart`: Substantive und Verben
aus dem Wortschatz (mit `vocabularyId`) und zusätzliche Musterwörter für
Stoff, den der Wortschatz der Lektionen 1–3 noch nicht abdeckt (rēx,
urbs, senātus, rēs, mittere, capere, Adjektive …). Mit „Nur Wörter aus dem
Wortschatz“ übt der Trainer nur die erste Gruppe.

**Reihenfolge:** Die Themen für Lektion 1–3 sind aus dem Wortschatz
erschlossen (welche Formen er voraussetzt), nicht aus den
Grammatikkapiteln des Buchs. Die weiteren Themen folgen der üblichen
Reihenfolge der Schulgrammatik und sind als „weiterführend“ markiert.

**Antwortprüfung** (`latin_grammar_answer_check.dart`)

* Groß-/Kleinschreibung zählt nicht, j gilt als i, zerlegte Längenzeichen
  (Vokal + U+0304) werden zusammengesetzt.
* Längenzeichen sind beim Bilden freiwillig. Gesetzte Längen müssen aber
  die gefragte Form treffen: vēnit (Perfekt) ist für venit (Präsens)
  falsch. Mit „Längenzeichen verlangen“ zählen nur exakte Formen.
* Nebenformen (amāris/amāre, -ērunt/-ēre) sind gleichwertig.
* Eine falsche Eingabe, die eine andere Form desselben Worts ist, wird
  benannt („Akkusativ Singular“); weicht sie nur um einen Buchstaben ab
  und ist keine Form des Worts, gilt sie als vermutlicher Tippfehler.
* Beim Bestimmen zählt jede für die Form mögliche Bestimmung (servī: Gen.
  Sg. oder Nom. Pl.), aber keine Mischung aus zweien.

**Lernstand:** `users/{uid}/quiz_settings/latin_grammar` (Karten je Thema,
Wort und Merkmal sowie Antworten je Thema) und
`quiz_settings/latin_grammar_settings`; im Gastmodus lokal. Getrennt vom
Altgriechisch-Trainer (Collection `grammar`). Zurücksetzen: in den
Einstellungen „Lateinische Grammatik“ oder je Thema in der
Fortschrittsansicht.
