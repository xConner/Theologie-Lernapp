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
from wiki_match import load_sources, melody_from, sizes_for, to_syllables

ASSET_DIR = ROOT / "assets" / "hymn_scores"
ASSET_PREFIX = "assets/hymn_scores/"

DIRECT = "EG-Nummer in Dateibeschreibung"

CATEGORIES = {
    1: "Verifiziert: Textunterlegung stimmt mit einer Vorlage überein",
    2: "Digitalisiert und geprüft: gedruckte Vorlage digitalisiert und abgeglichen",
    3: "Syllabisch eindeutig: jede Silbe genau ein Ton (ohne Vorlagenabgleich)",
    4: "Teilweise ungeklärt: Noten ohne Textunterlegung",
    5: "Noten ohne Textunterlegung: kein Liedtext in der App",
    6: "Vorlage vorhanden, aber nicht zuverlässig verarbeitbar",
    7: "Keine geeignete Quelle gefunden",
}

WIKI_LICENSE = "CC BY-SA 4.0"
WIKI_LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"


def slugify(text):
    text = text.lower().replace("ß", "ss")
    text = text.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def wiki_url(source):
    return f"https://{source['wiki']}/w/index.php?oldid={source['revid']}"


def wiki_credit(source, identical):
    where = "deutschen" if source["wiki"].startswith("de.") else "englischen"
    stanza = "" if identical else ", dort an einer anderen Strophe"
    return (
        f"Textunterlegung nach dem Notensatz im {where} Wikipedia-Artikel "
        f"„{source['title']}“{stanza} ({WIKI_LICENSE})"
    )


def slug(title):
    return slugify(title[len("File:"):-len(".mid")])


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

    wiki = load_sources()
    report = []
    comparisons = []  # (Lied, Regel und Quelle stimmen überein?, mit Melisma?)
    for row in inventory:
        number = row["eg_nummer"]
        hymn = by_id[number]
        hymn.pop("scores", None)
        lines = first_stanza(hymn)
        count = sum(map(len, lines))
        stanza = hymn["lyrics"][0]["text"] if hymn["lyrics"] else ""
        sources = wiki.get(number, [])
        scores = []
        problems = []
        open_melisma = False
        for file in wanted.get(number, []):
            title = file["datei"]
            if title not in shared:
                problems.append(f"{title[5:]}: {file_notes.get(title, 'nicht verarbeitet')}")
                continue

            # Mit Text: die am eigenen Text abgegrenzte Melodie. Unterlegt
            # wird, wenn eine Quelle die Zuordnung belegt oder jede Silbe
            # genau einen Ton hat – Melismen werden nie nur erschlossen.
            melody = shared[title]
            syllables = None
            underlay = None
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
                by_rule = align(melody, lines)
                hit = sizes_for(melody, stanza, lines, sources)
                if hit:
                    used_lines, sizes, source, identical = hit
                    syllables = to_syllables(used_lines, sizes)
                    underlay = {
                        "status": "verified",
                        "credit": wiki_credit(source, identical),
                        "url": wiki_url(source),
                    }
                    if by_rule:
                        comparisons.append(
                            (
                                number,
                                [x.notes for x in by_rule] == sizes,
                                any(x.notes > 1 for x in by_rule),
                            )
                        )
                elif by_rule and all(x.notes == 1 for x in by_rule):
                    syllables = by_rule
                    underlay = {"status": "syllabic"}
                elif melody.note_count > count:
                    open_melisma = True
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
            if underlay:
                # Diese Strophe steht unter den Noten.
                score["underlay"] = {"stanza": hymn["lyrics"][0]["stanza"], **underlay}
            scores.append(score)

        # Keine unterlegten Noten aus den Commons-Vorlagen: Unterlegt ein
        # Wikipedia-Notensatz genau den Text der App, wird er selbst gesetzt.
        if count and not any("underlay" in x for x in scores):
            for source in sources:
                built = melody_from(source, stanza, lines)
                if built is None:
                    continue
                name = "wikipedia_" + slugify(source["title"])
                try:
                    asset = write(f"eg{number:03d}_{name}.svg", *built)
                except ValueError as error:
                    problems.append(f"{source['title']}: Notensatz fehlgeschlagen ({error})")
                    continue
                where = "de" if source["wiki"].startswith("de.") else "en"
                scores = [
                    {
                        "id": name,
                        "asset": asset,
                        "format": "svg",
                        "kind": "melody",
                        "label": source["title"],
                        "source": {
                            "name": f"Wikipedia ({where})",
                            "file": source["title"],
                            "url": wiki_url(source),
                            "author": "Notensatz im Wikipedia-Artikel, Autoren siehe Versionsgeschichte",
                            "license": WIKI_LICENSE,
                            "licenseUrl": WIKI_LICENSE_URL,
                            "sha1": "",
                            "match": "Liedartikel zur EG-Nummer",
                        },
                        "underlay": {
                            "stanza": hymn["lyrics"][0]["stanza"],
                            "status": "verified",
                            "credit": "Noten und Textunterlegung aus dem Wikipedia-Artikel",
                            "url": wiki_url(source),
                        },
                    }
                ]
                break
        if scores:
            hymn["scores"] = scores

        note = "; ".join(problems)
        states = {x["underlay"]["status"] for x in scores if "underlay" in x}
        if "verified" in states:
            category = 1
        elif "syllabic" in states:
            category = 3
        elif scores and count:
            category = 4
            reason = (
                "mehr Töne als Silben; wo die Melismen liegen, belegt keine Quelle"
                if open_melisma
                else "Silben und Töne lassen sich nicht eindeutig zuordnen"
            )
            note = "; ".join(filter(None, [reason, note]))
        elif scores:
            category = 5
        elif problems:
            category = 6
        elif row["beste_notenquelle"]:
            category = 6
            note = f"{row['beste_notenquelle']}: nicht verarbeitet"
        else:
            category = 7
        report.append(
            {
                "eg_nummer": number,
                "titel": hymn["title"],
                "kategorie": category,
                "status": CATEGORIES[category].split(":")[0],
                "noten": [x["id"] for x in scores],
                "unterlegt": [x["id"] for x in scores if "underlay" in x],
                "quelle_unterlegung": next(
                    (x["underlay"].get("url", "") for x in scores if "underlay" in x), ""
                ),
                # Töne des unterlegten Notenbildes und Silben der Strophe
                "toene": next(
                    (
                        written[x["asset"].rsplit("/", 1)[-1]].note_count
                        for x in scores
                        if "underlay" in x
                    ),
                    None,
                ),
                "silben": count,
                "melodie_laut_recherche": row["melodie_status"],
                "hinweis": note,
            }
        )

    used = {x["asset"].rsplit("/", 1)[-1] for h in hymns for x in h.get("scores", [])}
    for stale in ASSET_DIR.glob("*.svg"):
        if stale.name not in used:
            stale.unlink()
    written = {name: melody for name, melody in written.items() if name in used}
    HYMNS.write_text(
        json.dumps(hymns, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n"
    )
    (DOCS / "integration.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    write_overview(report, written, midword, comparisons)
    counts = collections.Counter(r["kategorie"] for r in report)
    size = sum(f.stat().st_size for f in ASSET_DIR.glob("*.svg"))
    print(
        f"{len(written)} Notenbilder ({size // 1024} KB), "
        f"Kategorien: {dict(sorted(counts.items()))}"
    )


def write_overview(report, written, midword, comparisons):
    counts = collections.Counter(r["kategorie"] for r in report)
    with_notes = [r for r in report if r["noten"]]
    released = [r for r in with_notes if r["melodie_laut_recherche"] != "gemeinfrei"]
    metered = sum(1 for melody in written.values() if melody.meter)
    warned = sorted(
        (name, "; ".join(w for w in melody.warnings if "Raster" in w))
        for name, melody in written.items()
        if any("Raster" in w for w in melody.warnings)
    )
    agree = sum(1 for _, same, _ in comparisons if same)
    with_melisma = [c for c in comparisons if c[2]]
    lines = [
        "# Integrierte Noten: Übersicht",
        "",
        "Automatisch erzeugt von `tool/hymn_scores/build_scores.py` – nicht von Hand ändern.",
        "",
        f"{len(report)} Lieder des Stammteils, davon {len(with_notes)} mit Noten in der App "
        f"und {counts[1] + counts[2] + counts[3]} mit unterlegter erster Strophe. "
        f"{len(written)} Notenbilder ({metered} mit Taktstrichen, "
        f"{len(written) - metered} in freiem Rhythmus).",
        "",
        "| Kategorie | Status | Lieder |",
        "|---|---|---|",
    ]
    lines += [f"| {k} | {v} | {counts[k]} |" for k, v in CATEGORIES.items()]
    lines += [
        "",
        "Als vollständig geprüft gelten nur die Kategorien 1 und 2. Kategorie 3",
        "ist ohne Vorlage unterlegt, weil die Zuordnung dort zwingend ist: gleich",
        "viele Töne wie Silben, kein Melisma möglich. Melismen werden nie aus",
        "Zahl oder Dauer der Töne erschlossen.",
        "",
        "## Gegenprobe der Regel an den Quellen",
        "",
        f"Für {len(comparisons)} Lieder liegen sowohl die regelbasierte Zuordnung als auch",
        f"eine Quelle vor; in {agree} Fällen stimmen sie überein"
        f" ({len(with_melisma)} davon mit Melismen). Abweichend: "
        + (", ".join(f"EG {n}" for n, same, _ in comparisons if not same) or "keine")
        + ".",
        "",
        "## Status je Lied",
        "",
        "| EG | Titel | Status | Quelle der Unterlegung / Hinweis |",
        "|---|---|---|---|",
    ]
    lines += [
        f"| {r['eg_nummer']} | {r['titel']} | {r['status']} | "
        f"{r['quelle_unterlegung'] or r['hinweis']} |"
        for r in report
    ]
    lines += [
        "",
        "## Vom Projektinhaber freigegeben",
        "",
        "Bei diesen Liedern führt die Recherche die Melodie als geschützt oder",
        "ungeklärt. Die Noten sind auf Freigabe des Projektinhabers integriert,",
        "der die Rechte nach eigener Angabe geklärt hat.",
        "",
        ", ".join(f"{r['eg_nummer']} ({r['melodie_laut_recherche']})" for r in released) or "–",
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
