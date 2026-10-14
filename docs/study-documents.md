# Studienunterlagen (Studiumsorganisation)

Die App zeigt im Bereich „Studienunterlagen“ offizielle Dokumente der
Theologischen Fakultät und der CAU Kiel. Sie **verlinkt nur** auf die
Originalquellen und speichert keine Kopien.

## Datenquelle

`assets/study/documents.json` – einzige Stelle mit Dokumentdaten:

| Feld | Bedeutung |
| --- | --- |
| `programs` | Studiengänge (`dka`, `lehramt`, `ma-re`) und übergreifende Geltungsbereiche (`zwei-faecher`, `bama`, `alle`) |
| `groups[].documents[]` | Dokument: `id`, `title` (Linktext der Fundstelle), `officialTitle` (Titel im Dokument), `description`, `programs`, `publisher`, `url`, `sourcePage`, `format` (`page` für Webseiten), `status`, `version`, `validity` |
| `status` | `current` – die Fundstelle führt es als geltend/aktuell; `older` – es gibt eine neuere Fassung für denselben Studiengang; `unclear` – nicht sicher feststellbar (in der App „Gültigkeit prüfen“) |
| `checkedAt` | Datum der letzten Prüfung |

Grundsätze: Nur Angaben, die auf der Fundstelle bzw. der ersten Seite des
Dokuments stehen. Widersprüche werden im Feld `validity` genannt, nicht
geglättet (Beispiel: Die Lehramtsseite verlinkt die FPO 2025 unter der
Bezeichnung „Fachprüfungsordnung (2023)“). Die App übernimmt nur HTTPS-Links
auf `uni-kiel.de` und die Nordkirche (`isOfficialUrl`).

## Prüfung

`.github/workflows/study-documents.yml` ruft jede URL (Dokument und
Fundstelle) einmal ab und protokolliert Status, Inhaltstyp, Seitentitel und
bei PDFs den Anfang der ersten Seite (`pdftotext`, E-Mail-Adressen
entfernt). Der Workflow läuft bei Änderungen der Liste und wöchentlich;
ein nicht erreichbarer Link lässt ihn fehlschlagen.

Stand 14.10.2026 (Lauf 38600446016): 64 URLs, alle HTTP 200; Titel und
Studiengang auf der ersten PDF-Seite abgeglichen.

Neue Dokumente finden: Workflow manuell starten mit
`file = tool/study_documents/candidates.json` und `discover = true` – dann
listet er die auf den Übersichtsseiten der Fakultät verlinkten Dokumente.

## Aktualisieren

1. Übersichtsseiten prüfen (Workflow mit `discover`, siehe oben):
   Pfarramt/Diplom, Lehramt, Master Religion und Ethik, Prüfungsamt,
   amtliche Bekanntmachungen.
2. Einträge in `documents.json` ändern; ältere Fassungen auf `older` setzen
   statt zu löschen, solange sie verlinkt sind (Studierende nach früheren
   Ordnungen).
3. `checkedAt` setzen, Workflow-Ergebnis abwarten,
   `flutter test test/study_organization_services_test.dart` (prüft
   Vollständigkeit, Kennungen und Domains).

## Bekannte Lücken (Stand 14.10.2026)

* Ein Studienverlaufsplan zum Master Religion und Ethik nach FPO 2023 ist
  auf der Fakultätsseite nicht verlinkt (nur zur FPO 2019 bzw. die
  allgemeine Studiengangsseite).
* Ob Modulhandbuch und Studienverlaufspläne des Master of Education zur
  FPO 2023 auch für die FPO 2025 gelten, sagt die Fakultätsseite nicht.
* Inkrafttreten der FPO 2025 und der Zwei-Fächer-Prüfungsordnung 2027 sind
  nicht aus den Fundstellen, nur aus den Dokumenten selbst ersichtlich; die
  App kennzeichnet sie daher mit „Gültigkeit prüfen“.
* Graecums- und Hebraicumsordnung: Die Fakultätsseite nennt keinen Stand.
* Eine eigene Seite zu Studiengangwechsel/Anerkennung gibt es nicht; die
  App verlinkt die Formulare des Prüfungsamts und die Anerkennungssatzung.
