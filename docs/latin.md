# Latein: Wortschatz und Grammatik

Stand: Oktober 2026.

## Lehrbuch hinter der Vokabelliste

Die Vokabelliste (`assets/latin_vocabulary.json`) nennt ihr Lehrbuch nicht.
Sie folgt nach unserer Prüfung **„prima. Latein lernen“, Band 1**
(C.C. Buchner, Bamberg 2020; herausgegeben von Clement Utz und Andrea
Kammerer; ISBN 978-3-661-40501-8). Band 1 enthält die Lektionen 1–14 mit
ihren Wortschätzen, Band 2 die Lektionen 15–28.

| App | Lehrbuch |
|---|---|
| Schritt 1–3 | Lektion 1–3 |
| Unter-Schritt 1–3 | Wortschatzteile einer Lektion |

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

* Lektionen 4–14 (Band 1) und 15–28 (Band 2) fehlen. Ihre Wortlisten sind
  urheberrechtlich geschützte Verlagsmaterialien und im Netz nur als
  unvollständige, von Nutzern abgetippte Lernkarten zu finden. Wörter aus
  allgemeinem Lateinwissen wurden bewusst nicht als „aus dem Lehrbuch“
  ergänzt.
* Die Recherche lief in einer Umgebung mit eingeschränktem Netzzugang:
  Seiten von Verlag, Quizlet, Wiktionary und Wörterbüchern waren direkt
  nicht abrufbar, nur Zusammenfassungen von Suchergebnissen.
* Zum Ergänzen genügt es, die Wortschatzseiten der weiteren Lektionen (aus
  dem eigenen Buch) bereitzustellen. Neue Einträge bekommen fortlaufende
  IDs ab 103; Schritt = Lektion, Unter-Schritt = Wortschatzteil.

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
