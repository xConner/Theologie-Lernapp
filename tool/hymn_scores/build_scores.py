"""Erzeugt die Notenbilder und trägt sie in assets/eg_lieder.json ein.

    python fetch_midi.py       # Vorlagen laden (einmalig)
    python build_scores.py     # SVG erzeugen, Lieder zuordnen, Übersicht schreiben

Je Lied und Vorlage entsteht ein Notenbild der Melodie mit der ersten
Strophe unter den Noten (assets/hymn_scores/eg<Nr>_<Melodie>.svg). Lässt
sich der Text den Tönen nicht gesichert zuordnen oder hat das Lied in der
App keinen Text, gibt es das Bild der Melodie allein
(assets/hymn_scores/<Melodie>.svg); Lieder mit derselben Melodie teilen es
sich. In eg_lieder.json kommt je Lied nur das Feld „scores“ hinzu; alle
übrigen Felder bleiben unverändert. docs/hymn-scores/integration.md hält
fest, was integriert wurde und was nicht.
"""

import collections
import html
import json
import re
import unicodedata
import urllib.parse

from common import DOCS, HYMNS, INVENTORY_JSON, ROOT, SNAPSHOT, load_hymns, norm
from engrave import render, systems_start_words, to_mei
from fetch_midi import MIDI_DIR
from melody import extract
from midi import read_midi
from syllables import split_stanza
from underlay import align

ASSET_DIR = ROOT / "assets" / "hymn_scores"
ASSET_PREFIX = "assets/hymn_scores/"

DIRECT = "EG-Nummer in Dateibeschreibung"

CATEGORIES = {
    1: "Noten mit unterlegtem Text (erste Strophe)",
    2: "Noten ohne Textunterlegung: Silbenzuordnung nicht gesichert",
    3: "Noten ohne Textunterlegung: kein Liedtext in der App",
    4: "Vorlage vorhanden, aber nicht zuverlässig verarbeitbar",
    5: "Keine Vorlage in den recherchierten Quellen",
}


def slug(title):
    text = title[len("File:"):-len(".mid")].lower().replace("ß", "ss")
    text = text.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def first_stanza(hymn):
    """Silben der ersten Strophe je Zeile; leer, wenn kein Text vorliegt."""
    if not hymn["lyrics"]:
        return []
    return split_stanza(hymn["lyrics"][0]["text"])


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


def acceptable(melody):
    """Einzelne Atempausen sind zu erwarten; geht mehr nicht auf, ist der
    Rhythmus der Vorlage so nicht lesbar."""
    return melody.uneven <= max(2, melody.note_count // 25)


def main():
    hymns = load_hymns()
    by_id = {h["id"]: h for h in hymns}
    inventory = json.loads(INVENTORY_JSON.read_text(encoding="utf-8"))
    commons = json.loads(SNAPSHOT.read_text(encoding="utf-8"))["commons"]["files"]

    # --- Lied → Dateien ---
    wanted = {
        row["eg_nummer"]: select_files(by_id[row["eg_nummer"]], row["commons_dateien"])
        for row in inventory
        if row["commons_dateien"]
    }
    users = collections.defaultdict(list)
    for number, files in wanted.items():
        for file in files:
            users[file["datei"]].append((number, file))

    # --- Datei → Melodie ---
    # Die Strophenlänge wird am Text jedes zugeordneten Liedes bestimmt; bei
    # Abweichungen entscheidet das Lied, das die Quelle selbst nennt. Nur wenn
    # kein Lied mit Text darauf zeigt, wird ohne Text abgegrenzt.
    midis = {}
    shared = {}  # Datei → Melodie, die alle Lieder ohne eigenen Textsatz zeigen
    own = {}  # (Lied, Datei) → Melodie, abgegrenzt am Text dieses Liedes
    file_notes = {}
    for title, entries in sorted(users.items()):
        path = MIDI_DIR / f"{entries[0][1]['sha1']}.mid"
        if not path.exists():
            file_notes[title] = "Vorlage nicht geladen (fetch_midi.py)"
            continue
        try:
            midi = midis[title] = read_midi(path)
        except ValueError as error:
            file_notes[title] = f"Vorlage nicht lesbar: {error}"
            continue
        candidates = []
        for number, file in entries:
            count = sum(map(len, first_stanza(by_id[number])))
            if not count:
                continue
            melody = extract(midi, count)
            if melody is not None:
                own[(number, title)] = melody
                candidates.append(
                    (file["zuordnung"] != DIRECT, melody.note_count, number, melody)
                )
        if candidates:
            lengths = collections.Counter(c[1] for c in candidates)
            candidates.sort(key=lambda c: (c[0], -lengths[c[1]], c[1], c[2]))
            melody = candidates[0][3]
        else:
            melody = extract(midi, 0)
        if melody is None:
            file_notes[title] = "erste Strophe nicht sicher abgrenzbar"
        elif not acceptable(melody):
            file_notes[title] = (
                f"Rhythmus nicht sicher lesbar ({melody.uneven} von "
                f"{melody.note_count} Tonabständen gehen im Raster nicht auf)"
            )
        else:
            shared[title] = melody

    # --- Notenbilder und Zuordnung in die Lieddaten ---
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    written = {}

    midword = []  # Bilder, in denen ein System mitten im Wort beginnt

    def write(name, melody, syllables=None):
        if name not in written:
            mei = to_mei(melody, syllables)
            svg = render(mei)
            if syllables and not systems_start_words(svg, syllables):
                # Im Takt kann das System an einem Taktstrich mitten im Wort
                # umbrechen; dann nur an den Zeilenenden des Textes.
                svg = render(mei, breaks="encoded")
                if not systems_start_words(svg, syllables):
                    midword.append(name)
            (ASSET_DIR / name).write_text(svg, encoding="utf-8", newline="\n")
            written[name] = melody
        return ASSET_PREFIX + name

    report = []
    for row in inventory:
        number = row["eg_nummer"]
        hymn = by_id[number]
        hymn.pop("scores", None)
        lines = first_stanza(hymn)
        count = sum(map(len, lines))
        scores = []
        problems = []
        for file in wanted.get(number, []):
            title = file["datei"]
            if title not in shared:
                problems.append(f"{title[5:]}: {file_notes.get(title, 'nicht verarbeitet')}")
                continue

            # Mit Text: die am eigenen Text abgegrenzte Melodie und, wenn die
            # Silben gesichert zuzuordnen sind, das Bild mit Unterlegung.
            melody = shared[title]
            syllables = None
            if count:
                mine = own.get((number, title))
                if mine is not None and acceptable(mine):
                    melody = mine
                if not (melody.note_count / 2.2 <= count <= melody.note_count / 0.9):
                    problems.append(
                        f"{title[5:]}: {melody.note_count} Töne passen nicht zu "
                        f"{count} Silben der ersten Strophe"
                    )
                    continue
                syllables = align(melody, lines)
            try:
                if syllables:
                    asset = write(f"eg{number:03d}_{slug(title)}.svg", melody, syllables)
                else:
                    asset = write(f"{slug(title)}.svg", shared[title])
            except ValueError as error:
                problems.append(f"{title[5:]}: Notensatz fehlgeschlagen ({error})")
                continue

            source = commons[title]
            score = {
                "id": slug(title),
                "asset": asset,
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
            if syllables:
                # Diese Strophe steht unter den Noten.
                score["underlay"] = {"stanza": hymn["lyrics"][0]["stanza"]}
            scores.append(score)
        if scores:
            hymn["scores"] = scores

        note = "; ".join(problems)
        if any("underlay" in s for s in scores):
            category = 1
        elif scores and count:
            category = 2
        elif scores:
            category = 3
        elif problems:
            category = 4
        elif row["beste_notenquelle"]:
            category = 4
            note = f"{row['beste_notenquelle']}: nicht verarbeitet"
        else:
            category = 5
        report.append(
            {
                "eg_nummer": number,
                "titel": hymn["title"],
                "kategorie": category,
                "noten": [s["id"] for s in scores],
                "unterlegt": [s["id"] for s in scores if "underlay" in s],
                "melodie_laut_recherche": row["melodie_status"],
                "hinweis": note,
            }
        )

    for stale in ASSET_DIR.glob("*.svg"):
        if stale.name not in written:
            stale.unlink()
    HYMNS.write_text(
        json.dumps(hymns, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n"
    )
    (DOCS / "integration.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    write_overview(report, written, midword)
    counts = collections.Counter(r["kategorie"] for r in report)
    size = sum(f.stat().st_size for f in ASSET_DIR.glob("*.svg"))
    print(
        f"{len(written)} Notenbilder ({size // 1024} KB), "
        f"Kategorien: {dict(sorted(counts.items()))}"
    )


def table(rows):
    lines = ["| EG | Titel | Hinweis |", "|---|---|---|"]
    lines += [f"| {r['eg_nummer']} | {r['titel']} | {r['hinweis']} |" for r in rows]
    return lines


def numbers(rows):
    return ", ".join(str(r["eg_nummer"]) for r in rows) or "–"


def write_overview(report, written, midword):
    counts = collections.Counter(r["kategorie"] for r in report)
    with_notes = [r for r in report if r["noten"]]
    released = [r for r in with_notes if r["melodie_laut_recherche"] != "gemeinfrei"]
    metered = sum(1 for melody in written.values() if melody.meter)
    warned = sorted(
        (name, "; ".join(w for w in melody.warnings if "Raster" in w))
        for name, melody in written.items()
        if any("Raster" in w for w in melody.warnings)
    )
    lines = [
        "# Integrierte Noten: Übersicht",
        "",
        "Automatisch erzeugt von `tool/hymn_scores/build_scores.py` – nicht von Hand ändern.",
        "",
        f"{len(report)} Lieder des Stammteils, davon {len(with_notes)} mit Noten in der App. "
        f"{len(written)} Notenbilder ({metered} mit Taktstrichen, "
        f"{len(written) - metered} in freiem Rhythmus).",
        "",
        "| Kategorie | Bedeutung | Lieder |",
        "|---|---|---|",
    ]
    lines += [f"| {k} | {v} | {counts[k]} |" for k, v in CATEGORIES.items()]
    lines += [
        "",
        "## Kategorie 2 – Silbenzuordnung nicht gesichert",
        "",
        "Die Vorlagen enthalten keinen Text. Unterlegt wird nur, wenn die Silben",
        "den Tönen nach festen Regeln restlos zuzuordnen sind (siehe README,",
        "Abschnitt 7). Bei diesen Liedern hat die Melodie mehr Töne als die",
        "Strophe Silben, und wo die Melismen liegen, geht aus der Vorlage nicht",
        "hervor. Die App zeigt die Noten und darunter den Text.",
        "",
        numbers([r for r in report if r["kategorie"] == 2]),
        "",
        "## Kategorie 3 – kein Liedtext in der App",
        "",
        numbers([r for r in report if r["kategorie"] == 3]),
        "",
        "## Kategorie 4 – Vorlage nicht zuverlässig verarbeitbar",
        "",
        *table([r for r in report if r["kategorie"] == 4]),
        "",
        "## Kategorie 5 – keine Vorlage",
        "",
        numbers([r for r in report if r["kategorie"] == 5]),
        "",
        "## Lieder mit Noten, bei denen eine weitere Fassung fehlt",
        "",
        *table([r for r in with_notes if r["hinweis"]]),
        "",
        "## Vom Projektinhaber freigegeben",
        "",
        "Bei diesen Liedern führt die Recherche die Melodie als geschützt oder",
        "ungeklärt. Die Noten sind auf Freigabe des Projektinhabers integriert,",
        "der die Rechte nach eigener Angabe geklärt hat.",
        "",
        "| EG | Titel | Melodie laut Recherche |",
        "|---|---|---|",
    ]
    lines += [
        f"| {r['eg_nummer']} | {r['titel']} | {r['melodie_laut_recherche']} |"
        for r in released
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
    lines += [
        "",
        "## Notenbilder, in denen ein System mitten im Wort beginnt",
        "",
        ", ".join(sorted(midword)) or "–",
    ]
    (DOCS / "integration.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8", newline="\n"
    )


if __name__ == "__main__":
    main()
