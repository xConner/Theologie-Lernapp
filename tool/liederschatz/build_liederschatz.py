"""Erzeugt die Recherchedaten zum Geistlichen Liederschatz (docs/liederschatz).

Gemeint ist das Gesangbuch der evangelisch-lutherischen Brüdergemeinden
(Textausgabe 1989, Notenausgabe 2000, 1300 Nummern), nicht der Berliner
„Geistliche Liederschatz“ von 1832 aus assets/hymnals/catalog.json.

Ohne Netz. Grundlage sind die am 2026-10-24 abgerufenen Rohdaten unter
`quellen/` und Daten, die schon im Repository liegen:

* `quellen/inhaltsverzeichnis_evangeliums_net.tsv`: alle 1306 Zeilen der
  Liederbuchseite auf evangeliums.net (Nummer, Titel, Textangabe, Liedseite).
* `quellen/stichprobe_liedseiten.tsv`: 30 einzeln geprüfte Liedseiten.
* `quellen/suchtreffer.tsv`: Liedseiten, deren GLS-Nummer ein Suchtreffer
  wörtlich zeigte.
* `assets/eg_lieder.json`, `docs/hymn-scores/eg_noten_inventar.json` und
  `docs/hymn-scores/quellen_snapshot.json`: Titelabgleich mit dem EG,
  Notenquellen dieser anderen Ausgabe und Lebensdaten aus Wikidata.

Liedtexte und Noten werden weder geladen noch geschrieben. Die App liest
keine dieser Dateien.

    python tool/liederschatz/build_liederschatz.py
"""

import csv
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = Path(__file__).resolve().parent / "quellen"
TOC = SOURCES / "inhaltsverzeichnis_evangeliums_net.tsv"
SAMPLE = SOURCES / "stichprobe_liedseiten.tsv"
SEARCH_HITS = SOURCES / "suchtreffer.tsv"
EG_HYMNS = ROOT / "assets" / "eg_lieder.json"
EG_INVENTORY = ROOT / "docs" / "hymn-scores" / "eg_noten_inventar.json"
EG_SNAPSHOT = ROOT / "docs" / "hymn-scores" / "quellen_snapshot.json"
OUT = ROOT / "docs" / "liederschatz"

RETRIEVED = "2026-10-24"
WORK_ID = "gls_bg"
BOOK_PAGE = (
    "https://www.evangeliums.net/lieder/liederbuch_geistlicher_liederschatz.html"
)
NUMBERS = 1300

# Wie docs/hymn-scores: Wer bis Ende 1955 gestorben ist, ist seit dem
# 1.1.2026 gemeinfrei. Eine Angabe mit Jahr bis 1850 kann von niemandem
# stammen, der 1956 noch lebte.
LAST_FREE_DEATH_YEAR = 1955
SAFE_WORK_YEAR = 1850

# Liedseiten ohne Liedtext laut Inhaltsverzeichnis (Spalte text_verfuegbar
# der Abrufdatei auf dem Rechner des Nutzers).
WITHOUT_TEXT = {343, 344, 447, 563}

# Die einzigen Statuswerte. Jeder wird nur gesetzt, wenn er geprüft wurde.
STATUSES = [
    "verified_match",
    "text_found",
    "notation_found",
    "complete_notation_found",
    "license_verified",
    "rights_review_required",
    "not_found",
]


def norm(text):
    """Vergleichsform eines Titels: ohne Klammerzusatz, Satzzeichen, Umlaute."""
    text = re.sub(r"\([^)]*\)", " ", text)
    text = text.lower().replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def read_tsv(path):
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_json(name, data):
    path = OUT / name
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    return path


def song_records(rows):
    """Zeilen des Inhaltsverzeichnisses → Liedeinträge mit stabiler ID.

    Gleiche Nummer und gleiche Liedseite ist eine doppelte Zeile und wird
    zusammengefasst. Gleiche Nummer mit verschiedenen Liedern bekommt die
    Zusätze a, b in der Reihenfolge der Liederbuchseite; verschmolzen wird
    nichts.
    """
    by_number = defaultdict(list)
    for row in rows:
        by_number[int(row["nr"])].append(row)
    missing = set(range(1, NUMBERS + 1)) - set(by_number)
    extra = set(by_number) - set(range(1, NUMBERS + 1))
    if missing or extra:
        sys.exit(f"Nummern fehlen {sorted(missing)} oder zu viel {sorted(extra)}")

    url_numbers = defaultdict(set)
    for row in rows:
        url_numbers[row["url"]].add(int(row["nr"]))

    records = []
    for number in sorted(by_number):
        entries = []
        for row in by_number[number]:
            same = next((e for e in entries if e["url"] == row["url"]), None)
            if same:
                same["zeilen"] += 1
            else:
                entries.append({**row, "zeilen": 1})
        for index, row in enumerate(entries):
            suffix = "abcdefgh"[index] if len(entries) > 1 else ""
            notes = []
            if row["zeilen"] > 1:
                notes.append(
                    f"Steht {row['zeilen']}-mal mit derselben Liedseite im "
                    "Inhaltsverzeichnis; als ein Eintrag geführt."
                )
            if len(entries) > 1:
                others = [e["titel"] for e in entries if e is not row]
                notes.append(
                    f"Unter Nr. {number} führt evangeliums.net noch: "
                    + "; ".join(others)
                    + ". Zusatzlied oder Datenbankfehler, am Buch zu prüfen."
                )
            shared = sorted(url_numbers[row["url"]] - {number})
            if shared:
                notes.append(
                    "Dieselbe Liedseite steht auch unter Nr. "
                    + ", ".join(map(str, shared))
                    + ". Doppelaufnahme im Buch oder Zuordnungsfehler, am "
                    "Buch zu prüfen."
                )
            records.append(
                {
                    "id": f"{WORK_ID}.{number:04d}{suffix}",
                    "nummer": number,
                    "nummer_zusatz": suffix or None,
                    "titel": row["titel"],
                    "textangabe": row["autoren"],
                    "liedseite": row["url"],
                    "gleiche_liedseite_wie_nr": shared,
                    "zeilen_im_verzeichnis": row["zeilen"],
                    "hinweise": notes,
                }
            )
    return records


def years(text):
    return [int(y) for y in re.findall(r"\b(1[0-9]{3}|20[0-2][0-9])\b", text)]


def people(text):
    """Personennamen einer Textangabe, ohne Jahre und Ortsangaben."""
    text = re.sub(r"\([^)]*\)", " ", text)
    parts = re.split(r"\s*(?:/|,|;| und | u\. a\.)\s*", text)
    names = []
    for part in parts:
        part = re.sub(r"\b\d{4}\b", "", part).strip(" .")
        if part and part not in {"Unbekannt", "Aus der Bibel", "u. a"}:
            names.append(part)
    return names


def author_rights(text, persons):
    """Einschätzung zum Textdichter. Sagt nichts über die GLS-Fassung."""
    death = []
    unresolved = []
    for name in people(text):
        candidates = [
            c for c in persons.get(name, {}).get("candidates", []) if c.get("died")
        ]
        if len(candidates) == 1:
            death.append((name, candidates[0]["died"], candidates[0]["id"]))
        else:
            unresolved.append(name)
    work_years = years(text)
    late = [d for d in death if d[1] > LAST_FREE_DEATH_YEAR]
    if late:
        return "geschuetzt", "; ".join(
            f"{n} (gest. {y}, Wikidata {q})" for n, y, q in late
        )
    if work_years and max(work_years) > LAST_FREE_DEATH_YEAR:
        return "geschuetzt", f"Werkjahr {max(work_years)} nach {LAST_FREE_DEATH_YEAR}"
    if not people(text):
        return "ungeklaert", "Textdichter unbekannt oder nicht genannt"
    if not unresolved:
        return "gemeinfrei", "; ".join(
            f"{n} (gest. {y}, Wikidata {q})" for n, y, q in death
        )
    if work_years and max(work_years) <= SAFE_WORK_YEAR:
        return "gemeinfrei", (
            f"Werkjahr {max(work_years)} (bis {SAFE_WORK_YEAR}); Lebensdaten "
            "nicht abgeglichen"
        )
    return "ungeklaert", "Lebensdaten von " + ", ".join(unresolved) + " nicht belegt"


def main():
    rows = read_tsv(TOC)
    if len(rows) != 1306:
        sys.exit(f"Inhaltsverzeichnis hat {len(rows)} statt 1306 Zeilen")
    records = song_records(rows)
    by_url = defaultdict(list)
    for record in records:
        by_url[record["liedseite"]].append(record)

    sample = {int(r["nr"]): r for r in read_tsv(SAMPLE)}
    hits = {
        (int(r["nr"]), r["slug"]) for r in read_tsv(SEARCH_HITS) if r["nr"].isdigit()
    }

    eg = json.loads(EG_HYMNS.read_text(encoding="utf-8"))
    inventory = {r["eg_nummer"]: r for r in json.loads(
        EG_INVENTORY.read_text(encoding="utf-8")
    )}
    eg_by_title = defaultdict(list)
    for hymn in eg:
        eg_by_title[norm(hymn["title"])].append(hymn)
    persons = json.loads(EG_SNAPSHOT.read_text(encoding="utf-8"))["persons"]

    songs, text_sources, notation_sources, rights, review = [], [], [], [], []
    for record in records:
        nr = record["nummer"]
        sid = record["id"]
        page_slug = record["liedseite"].rsplit("/", 1)[1].removesuffix(".html")
        checked = sample.get(nr)
        if checked and norm(checked["title"]) != norm(record["titel"]):
            checked = None
        verified = None
        if checked and checked["nr_laut_seite"] == str(nr):
            verified = "Liedseite nennt die Nummer (Stichprobe, einzeln abgerufen)"
        elif (nr, page_slug) in hits:
            verified = "Liedseite nennt die Nummer (Suchtreffer)"

        song = {
            **record,
            "incipit_vermutet": re.sub(r"\s*\([^)]*\)", "", record["titel"]).strip(),
            "sprache_im_gls": "de",
            "werk": WORK_ID,
            "originalsprache": None,
            "ausgabe_nummerierung": (
                "Nummer laut evangeliums.net (Liederbuch mit Jahr 2000); "
                "Textausgabe 1989 und Notenausgabe 2000 nicht am Buch verglichen"
            ),
            "melodieangabe": checked["melodie"] if checked else None,
            "alternative_melodie": (checked["alternative_melodie"] or None) if checked else None,
            "strophen_laut_liedseite": checked["strophen"] if checked else None,
            "jahr": max(years(record["textangabe"]), default=None),
            "quelle_verzeichnis": BOOK_PAGE,
            "abgerufen": RETRIEVED,
        }
        songs.append(song)

        has_text = nr not in WITHOUT_TEXT
        text_sources.append(
            {
                "lied": sid,
                "quelle": "evangeliums_net",
                "url": record["liedseite"],
                "text_angezeigt": has_text,
                "geprueft_durch": (
                    "Liedseite einzeln abgerufen" if checked
                    else "Kennzeichen im Inhaltsverzeichnis"
                ),
                "fassung": "nicht mit dem gedruckten GLS verglichen",
                "nutzungsrecht": "keine Lizenz angegeben",
            }
        )

        candidates = []
        for hymn in eg_by_title.get(norm(record["titel"]), []):
            row = inventory.get(hymn["id"], {})
            candidates.append(
                {
                    "lied": sid,
                    "andere_ausgabe": True,
                    "ausgabe": "Evangelisches Gesangbuch (Stammteil)",
                    "eg_nummer": hymn["id"],
                    "zuordnung": "gleicher Titel (normalisiert); Melodie und Satz im GLS ungeprüft",
                    "melodieangabe_eg": hymn.get("melody"),
                    "melodie_status_eg": row.get("melodie_status"),
                    "beste_notenquelle": row.get("beste_notenquelle"),
                    "fundstelle": row.get("fundstelle"),
                    "format": row.get("format"),
                    "umfang": row.get("umfang"),
                    "lizenz": row.get("lizenz"),
                    "nutzbarkeit_eg": row.get("nutzbarkeit"),
                    "in_app_noten_eg": bool(hymn.get("scores")),
                }
            )
        notation_sources.extend(candidates)

        author_status, author_reason = author_rights(record["textangabe"], persons)
        rights.append(
            {
                "lied": sid,
                "textdichter_status": author_status,
                "textdichter_begruendung": author_reason,
                "melodie_status": "ungeklaert",
                "melodie_begruendung": (
                    "Melodieangabe nur aus der Stichprobe; Lebensdaten nicht abgeglichen"
                    if checked else "keine Melodieangabe erhoben"
                ),
                "gls_fassung": (
                    "Rechteklärung erforderlich: Textfassung (Überarbeitung 2020) "
                    "und Notensatz 2000 können eigene Rechte haben; Ausgabe "
                    "und Verzeichnis als Sammlung bzw. Datenbank geschützt"
                ),
                "lizenz": None,
                "in_app_erlaubt": False,
            }
        )

        status = []
        if verified:
            status.append("verified_match")
        if has_text:
            status.append("text_found")
        if any(c["fundstelle"] for c in candidates):
            status.append("notation_found")
        status.append("rights_review_required")
        if not has_text and "notation_found" not in status:
            status.append("not_found")
        review.append(
            {
                "lied": sid,
                "status": status,
                "nummer_belegt_durch": ["Inhaltsverzeichnis evangeliums.net"]
                + ([verified] if verified else []),
                "nicht_geprueft": [
                    "Abgleich mit dem gedruckten Buch",
                    "Textfassung des GLS",
                    "Melodie und Satz der Notenausgabe 2000",
                ],
            }
        )

    OUT.mkdir(parents=True, exist_ok=True)
    write_json("lieder.json", songs)
    write_json("textquellen.json", text_sources)
    write_json("notenquellen.json", notation_sources)
    write_json("rechte.json", rights)
    write_json("pruefstatus.json", review)

    counts = Counter(s for r in review for s in r["status"])
    summary = {
        "abgerufen": RETRIEVED,
        "zeilen_im_verzeichnis": len(rows),
        "nummern": NUMBERS,
        "eintraege": len(records),
        "status": {s: counts.get(s, 0) for s in STATUSES},
        "textdichter_status": dict(Counter(r["textdichter_status"] for r in rights)),
        "notenkandidaten_eg": len(notation_sources),
        "notenkandidaten_mit_freier_lizenz": sum(
            1 for c in notation_sources
            if c["nutzbarkeit_eg"] == "frei integrierbar"
        ),
    }
    write_json("abdeckung.json", summary)
    print(json.dumps(summary, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
