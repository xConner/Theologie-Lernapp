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
| Formenindex | Englisches Wiktionary, Auszug von kaikki.org (Wiktextract) | CC BY-SA 4.0 / GFDL | Flexionstabellen für die LXX-Bestimmung, Deklinationsklassen. Englische Bedeutungen werden nicht übernommen. |
| Bedeutungen (de) | Vokabelliste der App (`assets/greek_vocabulary.json`) | – | bevorzugte Quelle der Vokabelhilfen, mit Lernschritt |
| Bedeutungen (de) | Redaktionelle Angaben (`tool/greek_exam_corpus/german_glosses.json`) | Teil der App | häufige Wörter in der Bedeutung des biblischen Griechisch; Korrekturen der automatischen Kürzung |
| Bedeutungen (de) | Deutsches Wiktionary, Auszug von kaikki.org | CC BY-SA 4.0 / GFDL | eingetragene Übersetzungen, sonst Bedeutungsangaben |
| Bedeutungen (de) | Pape, Griechisch-deutsches Handwörterbuch, 3. Aufl. 1914 (bearb. von M. Sengebusch); digitale Fassung von Chaeréphon (A. Charbonnet), abgerufen über das Classical Language Dictionary der BBAW ([cld.bbaw.de](https://cld.bbaw.de/documentation/dictionaries)) | Wörterbuchtext gemeinfrei; Bereitstellung laut BBAW CC BY 4.0 | hervorgehobene Übersetzungen am Artikelanfang, gekürzt und in heutige Rechtschreibung gebracht |

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
  Verbi, Aorist
  Passiv, Wurzelaorist, εἰμί, -μι-Verben, Verba contracta, Deponentien,
  Suppletivformen, οἶδα, Verben mit Genitiv-/Dativrektion (nur das Verb),
  besondere Nomina, πολύς/μέγας, Komparativ/Superlativ, Zahlwörter,
  Pronomen, Relativsatz, Bedingungs-, Final-,
  Konsekutiv-, Kausal-, Temporalkonjunktionen, zusammengesetzte Negationen, οὐ μή,
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
  attributive Stellung. Die Regeln
  arbeiten ohne Syntaxbaum und innerhalb eines Verses; sie sind an echten
  Versen getestet (`test/greek_exam_corpus_test.dart`).
* **Nicht verfügbar:** NcI, Accusativus absolutus, prädikative Stellung,
  Hyperbaton – ohne Syntaxanalyse nicht verlässlich erkennbar.

**Keine Filter für Grunddimensionen.** Ein Filter bildet einen eigenständig
gelernten Stoffbereich ab. Einzelne Personen, Numeri, Kasus und Genera
(früher „1. Person“, „Partizip im Genitiv“, „Vokativ“, „Präposition mit
Dativ“) sowie Artikel, οὐ und μή sind keine Filter mehr: Wer Präsens
zulässt, bekommt alle Personen und Numeri des Präsens. Gespeicherte
Anforderungen an diese Filter entfallen beim Lesen
(`GrammarPhenomena.retiredFilters`), der Stoff ist danach uneingeschränkt
erlaubt.

## Vokabelhilfen

Die Hilfen sind ausschließlich deutsch, kurz (höchstens drei Bedeutungen je
Grundform) und stehen nur bei Wörtern, die nicht vorausgesetzt werden.

**Was als bekannt gilt** (`VocabularyKnowledge`):

1. der Artikel – immer;
2. Wörter der Vokabelliste, wenn ihr Lernschritt gewählt ist. Zuordnung über
   die Grundform (Akzente bleiben, Attisch/Koine: γίγνομαι = γίνομαι,
   θάλαττα = θάλασσα; mediale Formen finden auch den Eintrag auf -ομαι);
3. elementare Funktionswörter, die in der Vokabelliste fehlen
   (`ElementaryWords`: Personal-, Demonstrativ-, Relativ-, Interrogativ-,
   Indefinit-, Reflexiv-, Reziprok- und Possessivpronomen, καί, δέ, οὐ, μή
   …). Sie werden über die Formenlehre gelernt; ist ein Pronomen in der
   Vokabelliste einem Schritt zugeordnet, entscheidet der Schritt;
4. gängige biblische Eigennamen (`BiblicalNames`: Jesus, Maria, Josef, die
   Apostel und Mitarbeiter, geläufige Namen des Alten Testaments, Orte und
   Gruppen). Geprüft wird die Grundform bzw. bei unbestimmten Formen der
   Septuaginta eine deklinierte Form eines Namens der Liste – nie die
   Großschreibung allein. Andere Eigennamen erhalten die Hilfe „Eigenname“.

**Woher die Bedeutung kommt** (in dieser Reihenfolge): Vokabelliste (auch aus
späteren Schritten), redaktionelle Angaben, deutsches Wiktionary, Pape. Das
Lexikon (`assets/greek_corpus/lexicon.json`) nennt je Eintrag seine Quelle
(`src`: e, w, p) und enthält keine englischen Angaben. Fehlt eine deutsche
Quelle, bleibt die Grundform **ungelöst**: Die Klausur nennt die Grundform mit
dem Hinweis „keine gesicherte deutsche Angabe – bitte nachschlagen“.

**Kürzung** (`gloss_shortener.dart`): Klammerzusätze, Gebrauchshinweise und
Erklärungen in Satzlänge entfallen; die ersten drei kurzen Bedeutungen
bleiben. Aus Pape werden nur die kursiv gesetzten Übersetzungen am
Artikelanfang gelesen, ohne Belegstellen, Etymologie und
Beispielübersetzungen. Pape beginnt mit der klassischen Grundbedeutung;
für häufige Wörter des biblischen Griechisch steht deshalb die
redaktionelle Angabe (δόξα: „Herrlichkeit, Ehre“ statt „Meinung“). Bei
selteneren Wörtern kann die Pape-Angabe altertümlich oder für den Text
unpassend sein; Korrekturen gehören in `german_glosses.json`.

**Mehrdeutige Formen** zeigen alle möglichen Grundformen mit ihrer eigenen
Bedeutung (im NT ist die Grundform durch den Kontext bestimmt); Homonyme mit
mehreren Pape-Artikeln erhalten die Grundbedeutung jedes Artikels.
Verschiedene Formen derselben Grundform erhalten eine gemeinsame Hilfe.

**Stand des Lexikons (12. Oktober 2026):** 1 200 Grundformen mit
redaktioneller Angabe, 523 aus dem deutschen Wiktionary, 1 446 aus Pape.
Der Pape-Import (`fetch_pape.dart`) fragt die Grundformen nach Häufigkeit
ab und war zu diesem Stand für die 3 286 häufigsten der 6 805
kleingeschriebenen Grundformen abgeschlossen; die übrigen 3 743 Grundformen
(3,3 % der Wortbelege beider Korpora, überwiegend seltene Wörter der
Septuaginta) sind ungelöst, bis der Import zu Ende gelaufen ist. Er setzt
beim nächsten Start fort; danach `build_lexicon.dart` ausführen.
Großgeschriebene Grundformen außerhalb von `BiblicalNames` erhalten keine
Übersetzung, sondern den Hinweis „Eigenname“.

## Wörterbuch des Kurses: Gemoll

Gemoll, Griechisch-deutsches Schul- und Handwörterbuch: Die Erstausgabe
(1908) ist gemeinfrei (W. Gemoll † 1934), liegt aber nur als Scan ohne
verlässlichen, strukturierten Volltext vor; die heute im Unterricht
verwendete Neubearbeitung (10. Aufl. 2006, Oldenbourg) ist urheberrechtlich
geschützt und nicht frei verfügbar. Gemoll ist deshalb nicht eingebunden.
Pape ist das nächstliegende gemeinfreie griechisch-deutsche Wörterbuch mit
maschinenlesbarem Text.

## Geprüft und nicht integriert

| Quelle | Grund |
|---|---|
| CATSS/CCAT LXX-Morphologie (Rahlfs) und Ableitungen (eliranwong/LXX-Rahlfs-1935, CenterBLC/LXX) | Nutzung an eine Nutzererklärung des CCAT gebunden; keine Erlaubnis zur Weitergabe in einer App ermittelt. Rahlfs-Hanhart ist urheberrechtlich geschützt. |
| Swete-LXX (First1KGreek, nathans/lxx-swete) | Frei (CC BY-SA 4.0), aber ohne Morphologie und eine andere Textausgabe als der Text der App. |
| Gemoll, Griechisch-deutsches Schul- und Handwörterbuch | Siehe oben: Erstausgabe nur als Scan, Neubearbeitung geschützt. |
| Deutsches Wiktionary, deutsche Einträge mit altgriechischer Übersetzung (Rückrichtung) | Frei, aber 3,1 GB Auszug und unsichere Zuordnung bei Homonymen; bei Bedarf als weitere Quelle möglich. |
| Bailly (2020) | CC BY-NC-ND 4.0, französisch. |

## Aktualisieren

```
dart run tool/greek_exam_corpus/fetch_sources.dart --force
dart run tool/greek_exam_corpus/fetch_pape.dart      # nur fehlende Grundformen
dart run tool/greek_exam_corpus/build_corpus.dart
dart run tool/greek_exam_corpus/build_lexicon.dart   # nur das Lexikon
flutter test test/greek_exam_corpus_test.dart
```
