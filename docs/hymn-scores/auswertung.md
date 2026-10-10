# Auswertung des Noten-Inventars

Automatisch erzeugt von `tool/hymn_scores/build_inventory.py` – nicht von Hand ändern.
Automatische Vorprüfung, **keine rechtliche Bewertung**; Regeln und Grenzen stehen in `README.md`.

Stand der Quellen: {"commons": "2026-10-10", "dewiki": "2026-10-10", "open_hymnal": "2026-10-10", "persons": "2026-10-10"}; Stichjahr der Schutzfristen: 2026 (gemeinfrei bei Tod bis 1955).

## Zahlen

- Lieder im Bestand (EG-Stammteil): **535**, davon 446 mit angezeigtem Text
- Melodie gemeinfrei (belegt): **378**, geschützt: 123, ungeklärt: 34
- davon Melodiezuordnung von Hand (`manual_overrides.json`): 19
- Lieder mit mindestens einer gefundenen Notenquelle: **351**
- davon mit gemeinfreier Melodie: **313**
- „frei integrierbar“ (Melodie gemeinfrei, Datei CC0/gemeinfrei): **287**

### Kategorien

| Kategorie | Bedeutung | Lieder |
|---|---|---|
| 1 | Text und Melodie gemeinfrei | 339 |
| 2 | Text gemeinfrei, Melodie geschützt oder ungeklärt | 24 |
| 3 | Melodie gemeinfrei, Text geschützt oder ungeklärt | 39 |
| 4 | Melodie alt, aber spätere Bearbeitung geschützt oder ungeklärt | 14 |
| 5 | Rechte nicht ausreichend geklärt | 47 |
| 6 | Text und Melodie geschützt | 72 |

### Nutzbarkeit

| Nutzbarkeit | Lieder |
|---|---|
| frei integrierbar | 287 |
| nicht ohne Lizenz (Melodie geschützt) | 123 |
| Melodie gemeinfrei, Notenquelle fehlt | 65 |
| ungeklärt | 34 |
| unter Bedingungen nutzbar (Namensnennung, ggf. Weitergabe unter gleichen Bedingungen) | 26 |

### Beste Notenquelle

| Quelle | Lieder |
|---|---|
| Wikimedia Commons (MIDI, Peter Gerloff) | 347 |
| (keine gefunden) | 184 |
| Wikipedia (LilyPond im Artikeltext) | 4 |

### Abdeckung je Quelle (unabhängig vom Rechtsstatus)

- Wikimedia Commons, MIDI: 347 Lieder (283 Dateien in der Kategorie)
- Wikipedia-Artikel vorhanden: 187 Lieder, mit LilyPond-Noten im Artikel: 42
- Open Hymnal (Melodiename gleich Liedtitel): 51 Lieder (305 ABC-Dateien im Projekt)

## Lieder ohne geeignete Noten (EG-Nummern)

**Melodie gemeinfrei, aber keine Notenquelle gefunden:** 34, 59, 60, 68, 86, 87, 92, 96, 104, 111, 141, 143, 151, 156, 160, 167, 172, 177, 192, 195, 204, 207, 219, 221, 230, 233, 238, 245, 246, 247, 248, 249, 252, 253, 264, 266, 274, 276, 282, 284, 290, 298, 307, 308, 309, 318, 323, 355, 356, 393, 401, 405, 414, 415, 439, 451, 458, 459, 460, 461, 462, 471, 476, 497, 529

**Melodie mit ungeklärtem Rechtsstatus:** 3, 18, 47, 48, 49, 53, 54, 55, 89, 98, 113, 116, 135, 186, 187, 188, 189, 198, 225, 250, 267, 286, 336, 337, 342, 433, 434, 455, 465, 481, 507, 513, 515, 517

**Melodie geschützt:** 2, 15, 16, 17, 20, 21, 26, 28, 40, 50, 51, 52, 56, 57, 64, 65, 93, 94, 95, 97, 118, 132, 153, 154, 168, 169, 170, 171, 173, 174, 175, 176, 178, 181, 182, 184, 199, 201, 208, 209, 210, 212, 226, 228, 229, 235, 236, 237, 239, 254, 260, 261, 268, 269, 270, 272, 277, 278, 285, 287, 291, 292, 305, 306, 310, 311, 312, 313, 314, 315, 319, 332, 334, 338, 339, 340, 348, 359, 360, 378, 380, 381, 382, 383, 400, 408, 409, 411, 416, 417, 418, 419, 420, 424, 425, 426, 427, 428, 429, 431, 432, 435, 436, 448, 452, 453, 454, 456, 457, 463, 466, 483, 486, 487, 489, 491, 492, 493, 499, 509, 510, 533, 534

**Spätere Bearbeitung geschützt oder ungeklärt (Kategorie 4):** 3, 26, 40, 48, 95, 135, 319, 332, 383, 400, 418, 507, 510, 517

**Melodie nur von Hand zugeordnet (zu prüfen):** 38, 76, 90, 127, 140, 142, 195, 247, 248, 281, 300, 375, 387, 391, 413, 415, 488, 524, 529

## Ungeklärte Melodien im Einzelnen

| EG | Titel | Melodieangabe | Grund |
|---|---|---|---|
| 3 | Gott, heilger Schöpfer aller Stern | Kempten (1000) , AÖL (1971) | Kempten (Werkjahr 1000); AÖL (1971, Urheber nicht ermittelt) |
| 18 | Seht, die gute Zeit ist nah (Kanon) | Tschechien | Tschechien (ohne Jahr, Urheber nicht ermittelt) |
| 47 | Freu dich, Erd und Sternenzelt | Böhmen , Leitmeritz (1844) | Böhmen (ohne Jahr, Urheber nicht ermittelt); Leitmeritz (Werkjahr 1844) |
| 48 | Kommet, ihr Hirten, ihr Männer und Fraun | Olmütz (1847) , Leipzig (1870) | Olmütz (Werkjahr 1847); Leipzig (1870, Urheber nicht ermittelt) |
| 49 | Der Heiland ist geboren (Freut euch von Herzen) | Innsbruck (1881) | Innsbruck (1881, Urheber nicht ermittelt) |
| 53 | Als die Welt verloren, Christus ward geboren | Polen (1853) | Polen (1853, Urheber nicht ermittelt) |
| 54 | Hört, der Engel helle Lieder | Frankreich | Frankreich (ohne Jahr, Urheber nicht ermittelt) |
| 55 | O Bethlehem, du kleine Stadt | O Little Town Of Bethlehem | O Little Town Of Bethlehem (ohne Jahr, Urheber nicht ermittelt) |
| 89 | Herr Jesu, deine Angst und Pein | Aus tiefer Not schrei ich zu dir | Aus tiefer Not schrei ich zu dir (ohne Jahr, Urheber nicht ermittelt) |
| 98 | Korn, das in die Erde, in den Tod versinkt | Now the green blade rises | Now the green blade rises (ohne Jahr, Urheber nicht ermittelt) |
| 113 | O Tod, wo ist dein Stachel nun? | Nun freue dich, du Christenheit | Nun freue dich, du Christenheit (ohne Jahr, Urheber nicht ermittelt) |
| 116 | Er ist erstanden, Halleluja | Tansania | Tansania (ohne Jahr, Urheber nicht ermittelt) |
| 135 | Schmückt das Fest mit Maien | Christian Friedrich Witt (1715) , Arnold Mendelssohn (1905) , Paul Kretzschmar (1947) | Christian Friedrich Witt (1660–1717, Wikidata Q92064); Arnold Mendelssohn (1855–1933, Wikidata Q537538); Paul Kretzschmar (Sterbejahr nicht ermittelt) |
| 186 | Unser Vater im Himmel, geheiligt werde dein Name | Ostkirchlich | Ostkirchlich (ohne Jahr, Urheber nicht ermittelt) |
| 187 | Unser Vater im Himmel, geheiligt werde dein Name | Ostkirchlich | Ostkirchlich (ohne Jahr, Urheber nicht ermittelt) |
| 188 | Vater unser, Vater im Himmel (Calypso) | Westindien | Westindien (ohne Jahr, Urheber nicht ermittelt) |
| 189 | Geheimnis des Glaubens | Liturgie | Liturgie (ohne Jahr, Urheber nicht ermittelt) |
| 198 | Herr, dein Wort, die edle Gabe | O, gesegnetes Regieren | O, gesegnetes Regieren (ohne Jahr, Urheber nicht ermittelt) |
| 225 | Komm, sag es allen weiter | Go tell it on the mountain | Go tell it on the mountain (ohne Jahr, Urheber nicht ermittelt) |
| 250 | Ich lobe dich von ganzer Seelen | Nun saget Dank und lobt den Herren | Nun saget Dank und lobt den Herren (ohne Jahr, Urheber nicht ermittelt) |
| 267 | Herr, du hast darum gebetet | Gottes Führung fordert Stille | Gottes Führung fordert Stille (ohne Jahr, Urheber nicht ermittelt) |
| 286 | Singt, singt dem Herren neue Lieder | Nun saget Dank und lobt den Herren | Nun saget Dank und lobt den Herren (ohne Jahr, Urheber nicht ermittelt) |
| 336 | Danket, danket dem Herrn (Kanon) | überliefert | überliefert (ohne Jahr, Urheber nicht ermittelt) |
| 337 | Lobet und preiset, ihr Völker, den Herrn (Kanon) | überliefert | überliefert (ohne Jahr, Urheber nicht ermittelt) |
| 342 | Es ist das Heil uns kommen her | Nun freue dich, du Christenheit | Nun freue dich, du Christenheit (ohne Jahr, Urheber nicht ermittelt) |
| 433 | Wir wünschen Frieden euch allen | Israel | Israel (ohne Jahr, Urheber nicht ermittelt) |
| 434 | Schalom chaverim (Kanon) | Israel | Israel (ohne Jahr, Urheber nicht ermittelt) |
| 455 | Morgenlicht leuchtet | Schottisches Volkslied | Schottisches Volkslied (ohne Jahr, Urheber nicht ermittelt) |
| 465 | Komm, Herr Jesu, sei du unser Gast (Kanon) | überliefert | überliefert (ohne Jahr, Urheber nicht ermittelt) |
| 481 | Nun sich der Tag geendet | O Welt, ich muss dich lassen | O Welt, ich muss dich lassen (ohne Jahr, Urheber nicht ermittelt) |
| 507 | Himmels Au, licht und blau | Luxemburg (1847) , Paderborn (1852) | Luxemburg (Werkjahr 1847); Paderborn (1852, Urheber nicht ermittelt) |
| 513 | Das Feld ist weiß | Königsberg (1885) | Königsberg (1885, Urheber nicht ermittelt) |
| 515 | Laudato si, o mi Signore (Sei gepriesen, du hast die Welt erschaffen) | Italien | Italien (ohne Jahr, Urheber nicht ermittelt) |
| 517 | Ich wollt, dass ich daheime wär | Straßburg (1430) , Friedrich Hommel (1864) | Straßburg (Werkjahr 1430); Friedrich Hommel (Sterbejahr nicht ermittelt) |
