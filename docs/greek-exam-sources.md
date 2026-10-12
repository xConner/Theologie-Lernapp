# Klausurersteller: Textquellen, Morphologie, Wörterbücher

Stand der Prüfung: 12. Oktober 2026. **Keine Rechtsberatung** – die Angaben
geben die Lizenzhinweise der Quellen wieder.

Die Daten liegen unter `assets/greek_corpus/` und werden mit
`tool/greek_exam_corpus/` erzeugt (README dort). Die App ruft beim Erstellen
oder Austauschen einer Klausur keine externen Dienste auf.

## Eingebundene Quellen

| Bestandteil | Quelle | Lizenz | Verwendung |
|---|---|---|---|
| NT-Text | SBL Greek New Testament (2010), Wortlaut wie in MorphGNT | CC BY 4.0 (laut SBL/eBible.org; die MorphGNT-Dokumentation nennt noch die ältere SBLGNT-EULA) | Text der NT-Klausuren; dieselbe Ausgabe wie `grcsbl` im Bibel-Reader |
| NT-Morphologie | MorphGNT SBLGNT 6.12, Commit `aaed91e5` ([github.com/morphgnt/sblgnt](https://github.com/morphgnt/sblgnt)); Zitierweise: Tauber, J. K., Hg. (2017), DOI 10.5281/zenodo.376200 | CC BY-SA 3.0 | Wortart, Bestimmung und Grundform jeder Form, im Kontext |
| LXX-Text | Septuaginta nach Brenton (1851), Text der App (`assets/bible/grcbrent`, eBible.org) | gemeinfrei | Text der LXX-Klausuren |
| Formenindex, Bedeutungen (en) | Englisches Wiktionary, Auszug von kaikki.org (Wiktextract) | CC BY-SA 4.0 / GFDL | Flexionstabellen für die LXX-Bestimmung, englische Bedeutungen, Deklinationsklassen |
| Bedeutungen (de) | Deutsches Wiktionary, Auszug von kaikki.org | CC BY-SA 4.0 / GFDL | deutsche Bedeutungen außerhalb der Vokabelliste |
| Bedeutungen (de) | Vokabelliste der App (`assets/greek_vocabulary.json`) | – | bevorzugte Quelle der Vokabelhilfen, mit Lernschritt |

**ShareAlike.** Die erzeugten Dateien unter `assets/greek_corpus/`
(Bestimmungen, Index, Lexikon) sind Bearbeitungen von MorphGNT bzw.
Wiktionary und stehen deshalb ebenfalls unter CC BY-SA. Die App nennt die
Quellen in jeder Klausur („Text, Analyse und Quellen“).

## Wie die Formen bestimmt werden

**Neues Testament – im Kontext.** Jede Form trägt die Bestimmung aus
MorphGNT (137 554 Wörter, 7 927 Verse; Verse, die das SBLGNT nicht enthält,
fehlen). Zusätzlich speichert der Import alle weiteren formal möglichen
Bestimmungen derselben Form (andere Belege im NT, Wiktionary-Tabellen
desselben Lemmas): ἦν ist im Kontext 3. Sg., formal auch 1. Sg. Die
Antwortprüfung lässt jede formal mögliche Bestimmung gelten und nennt die
des Kontexts.

**Septuaginta – formal, ohne Kontext.** Für die Septuaginta gibt es keine
frei weitergebbare morphologische Analyse (siehe unten). Jede Form wird
deshalb über einen Formenindex bestimmt:

1. alle im NT belegten Bestimmungen der Form (MorphGNT), ergänzt um weitere
   Bestimmungen desselben Lemmas aus Wiktionary-Tabellen;
2. sonst die Wiktionary-Flexionstabellen allein (nur attische, Koine- und
   dialektfreie Tabellen; keine epischen oder ionischen Formen, kein Dual);
3. sonst geregelte Schreibvarianten: bewegliches ν (ἐλάλησε = ἐλάλησεν),
   Krasis mit Iota subscriptum (κᾀγώ = κἀγώ);
4. sonst: großgeschrieben mitten im Satz → „vermutlich Eigenname“, im
   übrigen **unbestimmt**.

Ergebnis des Imports: 577 359 Wörter, davon 88,3 % formal bestimmt (40 %
davon mehrdeutig, z. B. τοῦ m./n., φῶς Nom./Akk./Vok.), 3,2 % vermutete
Eigennamen, 8,5 % unbestimmt (vor allem seltene Wörter, Komposita ohne
Tabelle, zusammengeschriebene Wendungen wie διατοῦτο). 6 553 von 28 597
Versen sind vollständig bestimmt.

**Mehrdeutigkeit wird nicht aufgelöst.** Jede Regel läuft „sicher“ (alle
Bestimmungen der Form erfüllen sie) und „möglich“ (eine erfüllt sie). Ein
erforderliches Phänomen braucht einen sicheren Beleg; ein ausgeschlossenes
darf nicht einmal möglich sein, und dafür muss jedes Wort des Abschnitts
bestimmt sein. Für Ausschlüsse kommen in der Septuaginta daher nur
vollständig bestimmte Abschnitte in Frage; die App sagt das, wenn deshalb
kein Text gefunden wird.

## Zuverlässigkeit der Filter

* **Zuverlässig** (aus Bestimmung bzw. Grundform): Modi, Tempora, Genera
  Verbi, Person/Numerus, Partizipien nach Kasus/Numerus/Genus, Aorist
  Passiv, Wurzelaorist, εἰμί, -μι-Verben, Verba contracta, Deponentien,
  Suppletivformen, οἶδα, Verben mit Genitiv-/Dativrektion (nur das Verb),
  besondere Nomina, πολύς/μέγας, Komparativ/Superlativ, Zahlwörter,
  Vokativ, Artikel und Pronomen, Relativsatz, Bedingungs-, Final-,
  Konsekutiv-, Kausal-, Temporalkonjunktionen, Negationen, οὐ μή,
  Präpositionen mit mehreren Kasus. Im NT gilt „zuverlässig“ mit der
  Genauigkeit von MorphGNT; in der LXX mit der Vollständigkeit des
  Formenindex.
* **Regelbasiert** (nur forderbar, Belege werden angezeigt): starker
  Aorist (Verbliste des Aoristblatts), Deklinationsklassen der Nomen
  (Wiktionary), Genitivus absolutus, Participium coniunctum, Partizip mit
  Artikel, Umschreibung mit εἰμί, AcI, substantivierter Infinitiv,
  Präposition + Artikel + Infinitiv, Ergänzungsinfinitiv, verallgemeinernder
  Relativsatz, Realis, Eventualis, Irrealis, Potentialis, indirekte Rede mit
  ὅτι, indirekte Frage, Adhortativ, Prohibitiv, Deliberativ, Wunschoptativ,
  Präposition mit Genitiv/Dativ/Akkusativ, attributive Stellung. Die Regeln
  arbeiten ohne Syntaxbaum und innerhalb eines Verses; sie sind an echten
  Versen getestet (`test/greek_exam_corpus_test.dart`).
* **Nicht verfügbar:** NcI, Accusativus absolutus, prädikative Stellung,
  Hyperbaton – ohne Syntaxanalyse nicht verlässlich erkennbar.

## Vokabelhilfen

Bekannt ist ein Wort, wenn eine seiner möglichen Grundformen zu den
gewählten Lernschritten der Vokabelliste gehört. Zuordnung über die
Grundform (Akzente bleiben, Attisch/Koine: γίγνομαι = γίνομαι, θάλαττα =
θάλασσα; mediale Formen finden auch den Eintrag auf -ομαι). Bedeutungen in
dieser Reihenfolge: Vokabelliste (auch aus späteren Schritten), deutsches
Wiktionary, englisches Wiktionary (gekennzeichnet). Von 7 423 Grundformen
beider Korpora haben 819 eine deutsche und 5 020 eine englische Bedeutung
aus Wiktionary; dazu kommen die Wörter der Vokabelliste. Mehrdeutige
Formen zeigen alle möglichen Grundformen, unbestimmte Formen werden als
solche genannt.

## Geprüft und nicht integriert

| Quelle | Grund |
|---|---|
| CATSS/CCAT LXX-Morphologie (Rahlfs) und Ableitungen (eliranwong/LXX-Rahlfs-1935, CenterBLC/LXX) | Nutzung an eine Nutzererklärung des CCAT gebunden; keine Erlaubnis zur Weitergabe in einer App ermittelt. Rahlfs-Hanhart ist urheberrechtlich geschützt. |
| Swete-LXX (First1KGreek, nathans/lxx-swete) | Frei (CC BY-SA 4.0), aber ohne Morphologie und eine andere Textausgabe als der Text der App. |
| Pape, Griechisch-deutsches Handwörterbuch (1914), über cld.bbaw.de | Der Text ist gemeinfrei, die dort verwendete Digitalisierung stammt aber von A. Charbonnet (Eulexis) ohne angegebene Lizenz; der Dienst ist nach eigener Angabe in einer Testphase. Als Quelle deutscher Bedeutungen wünschenswert, sobald die Lizenz geklärt ist. |
| Bailly (2020) | CC BY-NC-ND 4.0, französisch. |

## Aktualisieren

```
dart run tool/greek_exam_corpus/fetch_sources.dart --force
dart run tool/greek_exam_corpus/build_corpus.dart
flutter test test/greek_exam_corpus_test.dart
```
