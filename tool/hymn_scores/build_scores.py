"""Erzeugt die Notenbilder und trägt sie in assets/eg_lieder.json ein.

    python fetch_midi.py       # Vorlagen laden (einmalig)
    python build_scores.py     # SVG erzeugen, Lieder zuordnen, Übersicht schreiben

Je Commons-Datei entsteht ein Notenbild der Melodie (erste Strophe,
einstimmig) unter assets/hymn_scores/. Lieder mit derselben Melodie teilen
sich das Bild. In eg_lieder.json kommt je Lied nur das Feld „scores“ hinzu;
alle übrigen Felder bleiben unverändert. docs/hymn-scores/integration.md
hält fest, was integriert wurde und was nicht.
"""

import collections
import html
import json
import re
import unicodedata
import urllib.parse

from common import DOCS, HYMNS, INVENTORY_JSON, ROOT, SNAPSHOT, load_hymns, norm
from engrave import render, to_mei
from fetch_midi import MIDI_DIR, usable
from melody import extract
from midi import read_midi

ASSET_DIR = ROOT / "assets" / "hymn_scores"
ASSET_PREFIX = "assets/hymn_scores/"

DIRECT = "EG-Nummer in Dateibeschreibung"


def slug(title):
    text = title[len("File:"):-len(".mid")].lower().replace("ß", "ss")
    text = text.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


_VOWELS = re.compile(r"[aeiouyäöü]+")
_ONE_SYLLABLE = re.compile(r"ei|ai|au|eu|äu|ie|ee|aa|oo|ey|ay|.")


def syllables(hymn):
    """Geschätzte Silbenzahl der ersten Strophe; 0, wenn kein Text vorliegt.

    Gezählt werden Vokale; Doppellaute und Dehnungen gelten als eine Silbe
    („treuen“ = eu + e = zwei Silben).
    """
    if not hymn["lyrics"]:
        return 0
    text = hymn["lyrics"][0]["text"].lower()
    return sum(len(_ONE_SYLLABLE.findall(group)) for group in _VOWELS.findall(text))


def select_files(hymn, files):
    """Wählt aus den Treffern des Inventars die zum Lied passenden Dateien.

    Eine ausdrückliche EG-Nummer in der Dateibeschreibung geht vor Titel-
    und Melodieverweisen; Kanon-Dateien gehören nur zu Kanons; nennt die Quelle
    unter einer Nummer zwei verschiedene Stücke, zählt das mit dem Liedtitel.
    """
    canons = [f for f in files if "kanon" in f["datei"].lower()]
    if "kanon" in hymn["title"].lower():
        chosen = canons or files
    else:
        chosen = [f for f in files if f not in canons]
    if any(f["zuordnung"] == DIRECT for f in chosen):
        chosen = [f for f in chosen if f["zuordnung"] == DIRECT]
    same_title = [f for f in chosen if norm(f["datei"][5:-4]) == norm(hymn["title"])]
    if same_title and len(same_title) < len(chosen):
        chosen = same_title
    return chosen


def main():
    hymns = load_hymns()
    by_id = {h["id"]: h for h in hymns}
    inventory = json.loads(INVENTORY_JSON.read_text(encoding="utf-8"))
    commons = json.loads(SNAPSHOT.read_text(encoding="utf-8"))["commons"]["files"]

    # --- Lied → Dateien ---
    wanted = {}
    for row in inventory:
        if usable(row) and row["commons_dateien"]:
            wanted[row["eg_nummer"]] = select_files(
                by_id[row["eg_nummer"]], row["commons_dateien"]
            )

    # --- Datei → Melodie ---
    # Die Strophenlänge wird am Text jedes zugeordneten Liedes bestimmt; bei
    # Abweichungen entscheidet das Lied, das die Quelle selbst nennt.
    users = collections.defaultdict(list)
    for number, files in wanted.items():
        for file in files:
            users[file["datei"]].append((number, file))

    melodies = {}
    file_notes = {}
    for title, entries in sorted(users.items()):
        path = MIDI_DIR / f"{entries[0][1]['sha1']}.mid"
        if not path.exists():
            file_notes[title] = "Vorlage nicht geladen (fetch_midi.py)"
            continue
        try:
            midi = read_midi(path)
        except ValueError as error:
            file_notes[title] = f"Vorlage nicht lesbar: {error}"
            continue
        candidates = []
        for number, file in entries:
            count = syllables(by_id[number])
            if not count:
                continue
            melody = extract(midi, count)
            if melody is not None:
                candidates.append(
                    (file["zuordnung"] != DIRECT, melody.note_count, number, melody)
                )
        if not candidates:
            file_notes[title] = "erste Strophe nicht sicher abgrenzbar"
            continue
        lengths = collections.Counter(c[1] for c in candidates)
        candidates.sort(key=lambda c: (c[0], -lengths[c[1]], c[1], c[2]))
        melody = candidates[0][3]
        # Einzelne Atempausen sind zu erwarten; geht mehr nicht auf, ist der
        # Rhythmus der Vorlage so nicht lesbar.
        if melody.uneven > max(2, melody.note_count // 25):
            file_notes[title] = (
                f"Rhythmus nicht sicher lesbar ({melody.uneven} von "
                f"{melody.note_count} Tonabständen gehen im Raster nicht auf)"
            )
            continue
        melodies[title] = melody

    # --- Notenbilder ---
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    assets = {}
    for title, melody in melodies.items():
        try:
            svg = render(to_mei(melody))
        except ValueError as error:
            file_notes[title] = f"Notensatz fehlgeschlagen: {error}"
            continue
        name = slug(title) + ".svg"
        (ASSET_DIR / name).write_text(svg, encoding="utf-8", newline="\n")
        assets[title] = name
    for stale in ASSET_DIR.glob("*.svg"):
        if stale.name not in assets.values():
            stale.unlink()

    # --- Zuordnung in die Lieddaten ---
    report = []
    for row in inventory:
        number = row["eg_nummer"]
        hymn = by_id[number]
        hymn.pop("scores", None)
        scores = []
        problems = []
        for file in wanted.get(number, []):
            title = file["datei"]
            if title not in assets:
                problems.append(
                    f"{title[5:]}: {file_notes.get(title, 'nicht verarbeitet')}"
                )
                continue
            melody = melodies[title]
            count = syllables(hymn)
            if count and not (
                melody.note_count / 2.2 <= count <= melody.note_count / 0.9
            ):
                problems.append(
                    f"{title[5:]}: {melody.note_count} Töne passen nicht zu "
                    f"{count} Silben der ersten Strophe"
                )
                continue
            source = commons[title]
            scores.append(
                {
                    "id": assets[title][: -len(".svg")],
                    "asset": ASSET_PREFIX + assets[title],
                    "format": "svg",
                    "kind": "melody",
                    "label": title[len("File:"):-len(".mid")],
                    "source": {
                        "name": "Wikimedia Commons",
                        "file": title,
                        "url": "https://commons.wikimedia.org/wiki/"
                        + urllib.parse.quote(title.replace(" ", "_"), safe=":/(),"),
                        "author": html.unescape(source["artist"]),
                        "license": source["license"],
                        "licenseUrl": source["license_url"] or "",
                        "sha1": source["sha1"],
                        "match": file["zuordnung"],
                    },
                }
            )
        if scores:
            hymn["scores"] = scores

        if scores:
            category, note = 1, "; ".join(problems)
        elif problems and all("passen nicht" in p for p in problems):
            category, note = 3, "; ".join(problems)
        elif problems:
            category, note = 5, "; ".join(problems)
        elif usable(row):
            # nutzbar laut Inventar, aber nur als LilyPond in Wikipedia
            category = 2
            note = f"{row['beste_notenquelle']}: nicht verarbeitet"
        else:
            category = 4
            note = row["nutzbarkeit"]
            if row["beste_notenquelle"]:
                note += f" (Quelle vorhanden: {row['beste_notenquelle']})"
        report.append(
            {
                "eg_nummer": number,
                "titel": hymn["title"],
                "kategorie": category,
                "noten": [s["id"] for s in scores],
                "hinweis": note,
            }
        )

    HYMNS.write_text(
        json.dumps(hymns, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n"
    )
    (DOCS / "integration.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    write_overview(report, melodies, assets)
    counts = collections.Counter(r["kategorie"] for r in report)
    size = sum(f.stat().st_size for f in ASSET_DIR.glob("*.svg"))
    print(
        f"{len(assets)} Notenbilder ({size // 1024} KB), "
        f"Kategorien: {dict(sorted(counts.items()))}"
    )


CATEGORIES = {
    1: "Noten integriert und in der App verfügbar",
    2: "Notenquelle vorhanden, aber nicht beschafft oder nicht verarbeitet",
    3: "Noten konnten dem Lied nicht eindeutig zugeordnet werden",
    4: "Keine geeignete Notendatei in den recherchierten Quellen",
    5: "Noten vorhanden, Darstellung noch nicht zuverlässig",
}


def table(report, category):
    rows = ["| EG | Titel | Hinweis |", "|---|---|---|"]
    rows += [
        f"| {r['eg_nummer']} | {r['titel']} | {r['hinweis']} |"
        for r in report
        if r["kategorie"] == category
    ]
    return rows


def write_overview(report, melodies, assets):
    counts = collections.Counter(r["kategorie"] for r in report)
    reasons = collections.Counter(
        r["hinweis"].split(" (Quelle")[0] for r in report if r["kategorie"] == 4
    )
    with_source = sum(
        "Quelle vorhanden" in r["hinweis"] for r in report if r["kategorie"] == 4
    )
    metered = sum(1 for title in assets if melodies[title].meter)
    warned = sorted(
        (title[5:-4], "; ".join(melodies[title].warnings))
        for title in assets
        if any("Raster" in w for w in melodies[title].warnings)
    )
    lines = [
        "# Integrierte Noten: Übersicht",
        "",
        "Automatisch erzeugt von `tool/hymn_scores/build_scores.py` – nicht von Hand ändern.",
        "",
        f"{len(report)} Lieder des Stammteils, {len(assets)} Notenbilder "
        f"({metered} mit Taktstrichen, {len(assets) - metered} in freiem Rhythmus).",
        "",
        "| Kategorie | Bedeutung | Lieder |",
        "|---|---|---|",
    ]
    lines += [f"| {k} | {v} | {counts[k]} |" for k, v in CATEGORIES.items()]
    lines += ["", "Kategorie 4 im Einzelnen:", ""]
    lines += [f"- {reason}: {count}" for reason, count in reasons.most_common()]
    lines += [
        f"- davon mit einer Quelle, die laut Inventar nicht vorgesehen ist: {with_source}",
        "",
        "## Kategorie 2 – Quelle vorhanden, nicht verarbeitet",
        "",
        *table(report, 2),
        "",
        "## Kategorie 3 – nicht eindeutig zuordenbar",
        "",
        *table(report, 3),
        "",
        "## Kategorie 5 – noch nicht zuverlässig",
        "",
        *table(report, 5),
        "",
        "## Kategorie 1 mit Einschränkung",
        "",
        "Lieder mit Noten, bei denen eine weitere Fassung nicht verarbeitet wurde:",
        "",
        "| EG | Titel | Hinweis |",
        "|---|---|---|",
    ]
    lines += [
        f"| {r['eg_nummer']} | {r['titel']} | {r['hinweis']} |"
        for r in report
        if r["kategorie"] == 1 and r["hinweis"]
    ]
    lines += [
        "",
        "## Notenbilder mit Rasterwarnung",
        "",
        "Hier gingen einzelne Tonabstände der Vorlage nicht im Raster auf (meist",
        "Atempausen); die Notenwerte an diesen Stellen bitte gegenlesen.",
        "",
    ]
    lines += [f"- {name}: {warning}" for name, warning in warned]
    lines += ["", "## Kategorie 4 – EG-Nummern", ""]
    lines += [", ".join(str(r["eg_nummer"]) for r in report if r["kategorie"] == 4)]
    (DOCS / "integration.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8", newline="\n"
    )


if __name__ == "__main__":
    main()
