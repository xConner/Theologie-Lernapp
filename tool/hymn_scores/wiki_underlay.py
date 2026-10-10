"""Liest aus den LilyPond-Notensätzen der Wikipedia die Textunterlegung ab.

Viele Liedartikel enthalten Noten als LilyPond-Quelltext mit unterlegtem
Text. Statt den Quelltext nachzubauen, wird er von LilyPond selbst übersetzt;
ein Listener (underlay_listener.ly) protokolliert dabei Töne und Silben mit
ihrem Zeitpunkt. Daraus ergibt sich für die Stimme, unter der der Text steht:
Tonfolge, Tondauern und die Zahl der Töne je Silbe.

    python wiki_underlay.py          # Artikel laden, übersetzen, auswerten

Braucht LilyPond 2.24 unter build/hymn_scores/lilypond/ (oder LILYPOND in
der Umgebung). Ergebnis: build/hymn_scores/wiki_underlay.json – nur
abgeleitete Angaben, kein Artikeltext. build_scores.py übernimmt daraus eine
Unterlegung nur, wenn Tonfolge und Silbenzahl zum Lied der App passen.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from common import BUILD, SNAPSHOT, api

LISTENER = Path(__file__).resolve().parent / "underlay_listener.ly"
OUTPUT = BUILD / "wiki_underlay.json"
PAGES = BUILD / "wiki_pages.json"


def lilypond():
    if os.environ.get("LILYPOND"):
        return os.environ["LILYPOND"]
    found = sorted((BUILD / "lilypond").glob("lilypond-*/bin/lilypond*"))
    if not found:
        raise SystemExit("LilyPond fehlt: nach build/hymn_scores/lilypond/ entpacken")
    return str(found[-1])


def fetch_pages():
    """Deutsche Liedartikel des Stammteils und ihre englischen Entsprechungen."""
    entries = json.loads(SNAPSHOT.read_text(encoding="utf-8"))["dewiki"]["entries"]
    wanted = {}  # Titel → EG-Nummern
    for number, entry in entries.items():
        if "article" in entry:
            wanted.setdefault(entry["article"]["title"], []).append(int(number))

    pages = []
    titles = sorted(wanted)
    english = {}
    for start in range(0, len(titles), 40):
        chunk = titles[start : start + 40]
        query = api(
            "de.wikipedia.org",
            action="query",
            formatversion=2,
            titles="|".join(chunk),
            prop="revisions|langlinks",
            rvprop="content|ids",
            rvslots="main",
            lllang="en",
            lllimit=500,
        )["query"]
        for page in query["pages"]:
            if page.get("missing"):
                continue
            revision = page["revisions"][0]
            pages.append(
                {
                    "wiki": "de.wikipedia.org",
                    "title": page["title"],
                    "revid": revision["revid"],
                    "numbers": wanted[page["title"]],
                    "text": revision["slots"]["main"]["content"],
                }
            )
            for link in page.get("langlinks", []):
                english[link["title"]] = wanted[page["title"]]

    titles = sorted(english)
    for start in range(0, len(titles), 40):
        chunk = titles[start : start + 40]
        query = api(
            "en.wikipedia.org",
            action="query",
            formatversion=2,
            titles="|".join(chunk),
            prop="revisions",
            rvprop="content|ids",
            rvslots="main",
            redirects=1,
        )["query"]
        renamed = {r["to"]: r["from"] for r in query.get("redirects", [])}
        for page in query["pages"]:
            if page.get("missing"):
                continue
            revision = page["revisions"][0]
            origin = renamed.get(page["title"], page["title"])
            pages.append(
                {
                    "wiki": "en.wikipedia.org",
                    "title": page["title"],
                    "revid": revision["revid"],
                    "numbers": english.get(origin, english.get(page["title"], [])),
                    "text": revision["slots"]["main"]["content"],
                }
            )
    return pages


def score_blocks(text):
    """LilyPond-Blöcke eines Artikels mit Text unter den Noten."""
    for match in re.finditer(r"<score([^>]*)>(.*?)</score>", text, re.S):
        attributes, body = match.group(1), match.group(2)
        if "lang=" in attributes and "lilypond" not in attributes:
            continue
        if not re.search(r"addlyrics|lyricmode|lyricsto", body):
            continue
        if not re.search(r"\braw\b", attributes):
            # Kurzform: MediaWiki setzt den Inhalt selbst in eine Partitur.
            body = "\\score {\n" + body + "\n\\layout { }\n}\n"
        yield body


def run(body, exe):
    """Übersetzt einen Block und liefert die protokollierten Ereignisse."""
    folder = Path(tempfile.mkdtemp(prefix="underlay_"))
    try:
        source = f'\\include "{LISTENER.as_posix()}"\n' + body
        (folder / "score.ly").write_text(source, encoding="utf-8")
        try:
            subprocess.run(
                [exe, "-dno-print-pages", "-dbackend=null", "score.ly"],
                cwd=folder,
                capture_output=True,
                timeout=120,
            )
        except subprocess.TimeoutExpired:
            return []
        events = folder / "events.tsv"
        if not events.exists():
            return []
        rows = []
        for line in events.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split("\t")
            if len(parts) >= 4:
                rows.append((float(parts[0]), parts[1], int(parts[2]), parts[4:]))
        return rows
    finally:
        shutil.rmtree(folder, ignore_errors=True)


def analyse(events):
    """Unterlegte Stimme eines Blocks: Töne, Silben und Töne je Silbe.

    Mehrere Textzeilen unter denselben Noten (Wiederholung) ergeben
    `repeat`: die Zahl der Töne, die zweimal gesungen werden.
    """
    lyric_contexts = {}
    for moment, kind, context, fields in events:
        if kind == "lyric":
            lyric_contexts.setdefault(context, []).append([moment, fields[-1], False])
        elif kind == "hyphen" and context in lyric_contexts:
            lyric_contexts[context][-1][2] = True
    if not lyric_contexts:
        return None
    ordered = sorted(lyric_contexts.items())
    first = ordered[0][1]
    starts = sorted({m for m, _, _ in first})

    # Stimmen: je Kontext die Töne nach Einsatz; bei Akkorden der oberste.
    voices = {}
    ties = set()
    for moment, kind, context, fields in events:
        if kind == "note":
            voice = voices.setdefault(context, {})
            pitch, length = int(fields[0]), float(fields[1])
            if moment not in voice or pitch > voice[moment][0]:
                voice[moment] = (pitch, length)
        elif kind == "rest":
            voices.setdefault(context, {}).setdefault(("rest", moment), float(fields[0]))
        elif kind == "tie":
            ties.add((context, moment))
    # Die unterlegte Stimme hat an jedem Silbeneinsatz einen Ton; unter
    # mehreren die höchste.
    candidates = []
    for context, voice in voices.items():
        onsets = {m for m in voice if not isinstance(m, tuple)}
        if onsets and all(m in onsets for m in starts):
            mean = sum(voice[m][0] for m in onsets) / len(onsets)
            candidates.append((mean, context))
    if not candidates:
        return None
    context = max(candidates)[1]
    voice = voices[context]

    # Übergebundene Töne zusammenziehen.
    tones = []  # [Einsatz, Tonhöhe oder None, Dauer]
    tied = False
    for key in sorted(voice, key=lambda k: (k[1] if isinstance(k, tuple) else k)):
        if isinstance(key, tuple):
            tones.append([key[1], None, voice[key]])
            tied = False
            continue
        pitch, length = voice[key]
        if tied and tones and tones[-1][1] == pitch:
            tones[-1][2] += length
        else:
            tones.append([key, pitch, length])
        tied = (context, key) in ties

    notes = [t for t in tones if t[1] is not None]
    onsets = [t[0] for t in notes]
    if any(m not in onsets for m in starts):
        return None  # Silbe auf einem angebundenen Ton: nicht auswertbar
    if onsets.index(starts[0]) != 0:
        return None  # Vorspiel ohne Text
    groups = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else float("inf")
        groups.append(sum(1 for m in onsets if start <= m < end))

    # Zweite Textzeile unter dem Anfang: Diese Töne werden wiederholt.
    repeat = 0
    if len(ordered) > 1:
        second = ordered[1][1]
        second_starts = {m for m, _, _ in second}
        if second_starts and second_starts <= set(starts) and min(second_starts) == starts[0]:
            covered = sum(1 for s in starts if s <= max(second_starts))
            repeat = sum(groups[:covered])
    return {
        "tones": [[t[1], t[2]] for t in tones],
        "groups": groups,
        "syllables": [[text, hyphen] for _, text, hyphen in first],
        "second": [[text, hyphen] for _, text, hyphen in ordered[1][1]] if repeat else [],
        "repeat": repeat,
    }


def key_of(body):
    """Vorzeichen der Tonart, wenn sie unverändert gilt (keine Transposition)."""
    if "\\transpose" in body:
        return None
    match = re.search(r"\\key\s+([a-h](?:is|es|s)?)\s*\\(major|minor|dorian|mixolydian|phrygian|aeolian|ionian)", body)
    if not match:
        return None
    german = '"deutsch"' in body
    name, mode = match.groups()
    fifths = {"c": 0, "g": 1, "d": 2, "a": 3, "e": 4, "b": 5, "f": -1}
    if german:
        name = {"h": "b", "b": "bes", "es": "ees", "as": "aes"}.get(name, name)
    base = fifths.get(name[0])
    if base is None:
        return None
    if name[1:] in ("is",):
        base += 7
    elif name[1:] in ("es", "s"):
        base -= 7
    shift = {"major": 0, "ionian": 0, "minor": -3, "aeolian": -3, "dorian": -2,
             "mixolydian": -1, "phrygian": -4}[mode]
    return base + shift


def time_of(body):
    """Taktart, wenn der Notensatz genau eine nennt und im Takt steht."""
    times = set(re.findall(r"\\time\s+(\d+)/(\d+)", body))
    if len(times) != 1 or "cadenzaOn" in body:
        return None
    numerator, denominator = times.pop()
    return [int(numerator), int(denominator)]


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    if PAGES.exists():
        pages = json.loads(PAGES.read_text(encoding="utf-8"))
    else:
        pages = fetch_pages()
        PAGES.write_text(json.dumps(pages, ensure_ascii=False), encoding="utf-8")
    exe = lilypond()
    results = []
    for page in pages:
        for index, body in enumerate(score_blocks(page["text"])):
            found = analyse(run(body, exe))
            status = "ausgewertet" if found else "nicht auswertbar"
            print(f"{page['wiki'][:2]} {page['title']} [{index}]: {status}")
            if not found:
                continue
            results.append(
                {
                    "wiki": page["wiki"],
                    "title": page["title"],
                    "revid": page["revid"],
                    "block": index,
                    "numbers": page["numbers"],
                    "key": key_of(body),
                    "time": time_of(body),
                    **found,
                }
            )
    OUTPUT.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(results)} Notensätze mit Unterlegung aus {len(pages)} Artikeln")


if __name__ == "__main__":
    main()
