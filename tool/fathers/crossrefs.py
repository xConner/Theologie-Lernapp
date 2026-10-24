"""OpenBible.info Cross References → assets/fathers/xrefs/<BUCH>.json

Aufruf:
    python3 tool/fathers/crossrefs.py <cross_references.txt>

Quelle: https://www.openbible.info/labs/cross-references/ (CC BY). Die
Datei zählt englisch (KJV); jede Stelle wird in die deutsche Zählung der
Perikopenliste übertragen (siehe common.Versification). Stellen, die sich
nicht sicher übertragen lassen, entfallen und werden gezählt.

Behalten werden Verweise ab MIN_VOTES Stimmen, je Vers höchstens PER_VERSE
(die bestbewerteten). Die Quelle nennt keine Art des Bezugs; die App
kennzeichnet alle als „verwandte Stelle“.
"""

from __future__ import annotations

import collections
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import ASSETS, Versification, write_json  # noqa: E402

MIN_VOTES = 3
PER_VERSE = 60

OSIS = {
    "Gen": "GEN", "Exod": "EXO", "Lev": "LEV", "Num": "NUM", "Deut": "DEU",
    "Josh": "JOS", "Judg": "JDG", "Ruth": "RUT", "1Sam": "1SA", "2Sam": "2SA",
    "1Kgs": "1KI", "2Kgs": "2KI", "1Chr": "1CH", "2Chr": "2CH", "Ezra": "EZR",
    "Neh": "NEH", "Esth": "EST", "Job": "JOB", "Ps": "PSA", "Prov": "PRO",
    "Eccl": "ECC", "Song": "SNG", "Isa": "ISA", "Jer": "JER", "Lam": "LAM",
    "Ezek": "EZK", "Dan": "DAN", "Hos": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Nah": "NAM", "Hab": "HAB",
    "Zeph": "ZEP", "Hag": "HAG", "Zech": "ZEC", "Mal": "MAL", "Matt": "MAT",
    "Mark": "MRK", "Luke": "LUK", "John": "JHN", "Acts": "ACT", "Rom": "ROM",
    "1Cor": "1CO", "2Cor": "2CO", "Gal": "GAL", "Eph": "EPH", "Phil": "PHP",
    "Col": "COL", "1Thess": "1TH", "2Thess": "2TH", "1Tim": "1TI",
    "2Tim": "2TI", "Titus": "TIT", "Phlm": "PHM", "Heb": "HEB", "Jas": "JAS",
    "1Pet": "1PE", "2Pet": "2PE", "1John": "1JN", "2John": "2JN",
    "3John": "3JN", "Jude": "JUD", "Rev": "REV",
}


def parse_point(text: str):
    book, chapter, verse = text.split(".")
    return OSIS[book], int(chapter), int(verse)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)

    source = Path(sys.argv[1])
    raw = source.read_bytes()
    lines = raw.decode("utf-8").splitlines()
    header = lines[0]

    v11n = Versification()
    stats = collections.Counter()
    by_book: dict[str, dict[str, list]] = collections.defaultdict(
        lambda: collections.defaultdict(list)
    )

    for line in lines[1:]:
        if not line.strip():
            continue
        frm, to, votes = line.split("\t")[:3]
        votes = int(votes)
        stats["rows"] += 1
        if votes < MIN_VOTES:
            stats["below_min_votes"] += 1
            continue

        b, c, v = parse_point(frm)
        start = v11n.english_to_german(b, c, v)
        parts = to.split("-")
        tb, tc, tv = parse_point(parts[0])
        tstart = v11n.english_to_german(tb, tc, tv)
        if len(parts) > 1:
            eb, ec, ev = parse_point(parts[1])
            tend = v11n.english_to_german(eb, ec, ev) if eb == tb else None
        else:
            tend = tstart

        if start is None or tstart is None or tend is None:
            stats["not_convertible"] += 1
            continue

        by_book[b][f"{start[0]}:{start[1]}"].append(
            (tb, tstart[0], tstart[1], tend[0], tend[1], votes)
        )

    out = ASSETS / "xrefs"
    written = []
    kept = 0
    for book, verses in sorted(by_book.items()):
        targets = sorted({t[0] for refs in verses.values() for t in refs})
        index = {t: i for i, t in enumerate(targets)}
        refs = {}
        for key, items in verses.items():
            items.sort(key=lambda t: (-t[5], t[0], t[1], t[2]))
            if len(items) > PER_VERSE:
                stats["dropped_per_verse_cap"] += len(items) - PER_VERSE
            items = items[:PER_VERSE]
            kept += len(items)
            refs[key] = [[index[t[0]], *t[1:]] for t in items]
        write_json(out / f"{book}.json", {"books": targets, "refs": refs})
        written.append(book)

    stats["kept"] = kept
    report = {
        "source": "OpenBible.info Cross References",
        "url": "https://www.openbible.info/labs/cross-references/",
        "license": "CC BY",
        "header": header,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "minVotes": MIN_VOTES,
        "perVerse": PER_VERSE,
        "versification": "KJV → deutsche Zählung (Perikopenliste); "
        "Psalmen über die Zahl der Überschriftsverse",
        "books": written,
        "stats": dict(stats),
    }
    write_json(Path(__file__).parent / "reports" / "crossrefs.json", report,
               pretty=True)
    print(report["stats"])


if __name__ == "__main__":
    main()
