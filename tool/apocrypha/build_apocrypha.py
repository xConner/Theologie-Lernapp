#!/usr/bin/env python3
"""Erzeugt assets/apocrypha/ (Bereich „Apokryphen & außerkanonische Schriften“).

    python3 -I tool/apocrypha/build_apocrypha.py --src <Ordner mit den Klonen>

Werke: curation/works_*.json (redaktionell). Fassungen und Quellen:
curation/sources.py. Ausgabe:

    assets/apocrypha/catalog.json            Werke, Fassungen, Quellen (ohne Text)
    assets/apocrypha/texts/<fassung>.toc.json Einheiten (Kapitel …) mit Datei
    assets/apocrypha/texts/<fassung>.<n>.json Text, je Datei etwa 150 KB
    tool/apocrypha/reports/import.json       Zählungen und Prüfungen

Fassungen, deren Text schon unter assets/bible/ liegt (Septuaginta,
Vulgata), bekommen nur ein Inhaltsverzeichnis mit Fundstellen; die App liest
den Text dort.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "curation"))

from sources import DIRS, SOURCES, versions  # noqa: E402

APP = HERE.parent.parent
OUT = APP / "assets" / "apocrypha"
CHUNK_CHARS = 150_000

CATEGORIES = [
    ["deuterokanonisch", "Apokryphen / Deuterokanonen (AT)"],
    ["pseudepigraphen", "Jüdische Pseudepigraphen"],
    ["evangelien", "Evangelien & Jesusüberlieferung"],
    ["apostolische_vaeter", "Apostolische Väter"],
    ["kirchenordnungen", "Kirchenordnungen & Unterweisung"],
    ["apokalypsen", "Apokalypsen & Visionen"],
    ["apostelakten", "Apostelakten & Legenden"],
    ["nag_hammadi", "Nag Hammadi & gnostische Schriften"],
    ["poesie", "Psalmen, Oden & Gebete"],
    ["fruehchristlich", "Weitere frühchristliche Schriften"],
]
TRADITIONS = {"juedisch", "christlich", "juedisch_christlich"}
PRESERVATION = {"complete", "partial", "fragmentary", "lost"}
COVERAGE = {"full", "partial", "fragments", "excerpt", "external"}
RIGHTS = {"publicDomain", "openLicense", "permission", "protected", "unclear"}
KINDS = {"original", "ancientVersion", "translation"}
CANON_TRADITIONS = {"judentum", "lutherisch", "reformiert", "anglikanisch", "katholisch",
                    "orthodox", "aethiopisch"}
CANON_STATUS = {"kanonisch", "deuterokanonisch", "apokryph", "anagignoskomena", "anhang",
                "nichtkanonisch"}
ASSESSMENT = {"secure", "likely", "disputed"}
ATTRIBUTION = {"pseudepigraph", "traditionell", "umstritten", "anonym"}
ID = re.compile(r"^[a-z0-9_]+$")


class Ctx:
    def __init__(self, src: Path):
        self.src = src
        self.app = APP

    def path(self, source: str, rel: str) -> Path:
        p = self.src / DIRS[source] / rel
        if not p.exists():
            raise FileNotFoundError(p)
        return p


def load_works():
    works = []
    for f in sorted((HERE / "curation").glob("works_*.json")):
        works.extend(json.loads(f.read_text(encoding="utf-8")))
    return works


def check_work(w, errors):
    wid = w.get("id", "?")
    if not ID.match(wid):
        errors.append(f"{wid}: ungültige Kennung")
    for key in ("title", "categories", "tradition", "genre", "dating", "preservation", "summary"):
        if not w.get(key):
            errors.append(f"{wid}: {key} fehlt")
    cats = {c for c, _ in CATEGORIES}
    for c in w.get("categories", []):
        if c not in cats:
            errors.append(f"{wid}: Kategorie {c} unbekannt")
    if w.get("tradition") not in TRADITIONS:
        errors.append(f"{wid}: Tradition {w.get('tradition')}")
    if w.get("preservation") not in PRESERVATION:
        errors.append(f"{wid}: Überlieferung {w.get('preservation')}")
    d = w.get("dating", {})
    if not d.get("label") or not isinstance(d.get("from"), int) or not isinstance(d.get("to"), int) \
            or d["from"] > d["to"]:
        errors.append(f"{wid}: Datierung unvollständig")
    for t, s, _ in w.get("canon", []):
        if t not in CANON_TRADITIONS or s not in CANON_STATUS:
            errors.append(f"{wid}: Kanonangabe {t}/{s}")
    for level, _ in w.get("assessments", []):
        if level not in ASSESSMENT:
            errors.append(f"{wid}: Einschätzung {level}")
    a = w.get("attribution")
    if a and a.get("assessment") not in ATTRIBUTION:
        errors.append(f"{wid}: Zuschreibung {a.get('assessment')}")


VERSION_FIELDS = ["id", "work", "language", "kind", "label", "translator", "editor", "edition", "year",
                  "basis", "source", "sourceNote", "rights", "license", "rightsNote", "attribution",
                  "coverage", "coverageNote", "transcriptionNote", "url"]

NOTE_MARK = re.compile(r"\[(\d+)\]")


def check_units(vid, units, errors):
    seen = set()
    for u in units:
        if u["id"] in seen:
            errors.append(f"{vid}: Einheit {u['id']} doppelt")
        seen.add(u["id"])
        if "src" in u:
            continue
        if not u["blocks"]:
            errors.append(f"{vid}: Einheit {u['id']} ohne Text")
        for _, text in u["blocks"]:
            for m in NOTE_MARK.finditer(text):
                if int(m.group(1)) > len(u["notes"]):
                    errors.append(f"{vid}: Einheit {u['id']}: Anmerkungszeichen [{m.group(1)}] ohne Anmerkung")
                    break
            if re.search(r"ChatGPT|GPT-4", text):
                errors.append(f"{vid}: maschinelle Übertragung")


def write_json(path: Path, data) -> bool:
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.write_text(text, encoding="utf-8")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--check", action="store_true", help="nichts schreiben")
    args = ap.parse_args()
    ctx = Ctx(args.src)
    errors: list[str] = []

    works = load_works()
    by_id = {}
    for w in works:
        check_work(w, errors)
        if w["id"] in by_id:
            errors.append(f"{w['id']}: Werk doppelt")
        by_id[w["id"]] = w
        w["versions"] = []

    texts = {}
    report = {"generated": date.today().isoformat(), "versions": {}}
    seen_versions = set()
    for v in versions():
        vid = v["id"]
        if vid in seen_versions:
            errors.append(f"{vid}: Fassung doppelt")
        seen_versions.add(vid)
        if v["work"] not in by_id:
            errors.append(f"{vid}: Werk {v['work']} fehlt")
            continue
        for key, allowed in (("kind", KINDS), ("rights", RIGHTS)):
            if v.get(key) not in allowed:
                errors.append(f"{vid}: {key} = {v.get(key)}")
        read = v.get("read")
        meta = {k: v[k] for k in VERSION_FIELDS if v.get(k) is not None}
        if read is None:
            meta.setdefault("coverage", "external")
        else:
            if v.get("rights") not in ("publicDomain", "openLicense", "permission"):
                errors.append(f"{vid}: Text ohne geklärte Rechte")
            meta.setdefault("coverage", "full")
            units = read(ctx)
            check_units(vid, units, errors)
            texts[vid] = units
            meta["units"] = len(units)
            meta["fromBible"] = all("src" in u for u in units)
            chars = sum(len(t) for u in units for _, t in u["blocks"])
            meta["chars"] = chars
            report["versions"][vid] = {"units": len(units), "chars": chars,
                                       "verses": sum(len(u["blocks"]) or u.get("count", 0) for u in units)}
        if meta["coverage"] not in COVERAGE:
            errors.append(f"{vid}: coverage {meta['coverage']}")
        if meta["coverage"] == "external" and not meta.get("url"):
            errors.append(f"{vid}: Verweis ohne Link")
        if meta.get("source") and meta["source"] not in SOURCES and meta["source"] != "app":
            errors.append(f"{vid}: Quelle {meta['source']} unbekannt")
        by_id[v["work"]]["versions"].append(meta)

    # Einheiten derselben Fassung sind eindeutig; Fassungen mit Text je Werk zählen.
    for w in works:
        lang_order = {"de": 0, "grc": 1, "la": 2, "cop": 3, "gez": 4, "en": 5}
        w["versions"].sort(key=lambda m: (m["coverage"] == "external", lang_order.get(m["language"], 9)))

    if errors:
        for e in errors:
            print("FEHLER:", e, file=sys.stderr)
        sys.exit(1)

    with_text = [w for w in works if any(m["coverage"] != "external" for m in w["versions"])]
    report["works"] = len(works)
    report["worksWithText"] = len(with_text)
    report["versionsWithText"] = len(texts)
    report["versionsTotal"] = sum(len(w["versions"]) for w in works)
    print(f"{len(works)} Werke, {len(with_text)} mit Text, {len(texts)} Fassungen mit Text, "
          f"{report['versionsTotal']} Fassungen insgesamt")
    if args.check:
        return

    (OUT / "texts").mkdir(parents=True, exist_ok=True)
    wanted = set()
    for vid, units in texts.items():
        toc, chunks, current, size = [], [], [], 0
        for u in units:
            entry = {"id": u["id"], "label": u["label"]}
            if u.get("path"):
                entry["path"] = u["path"]
            if u.get("title"):
                entry["title"] = u["title"]
            if "src" in u:
                entry["src"] = u["src"]
                entry["count"] = u["count"]
                toc.append(entry)
                continue
            body = {"id": u["id"], "b": u["blocks"]}
            if u["notes"]:
                body["notes"] = u["notes"]
            length = sum(len(t) for _, t in u["blocks"])
            if current and size + length > CHUNK_CHARS:
                chunks.append(current)
                current, size = [], 0
            entry["c"] = len(chunks)
            entry["n"] = len(u["blocks"])
            current.append(body)
            size += length
            toc.append(entry)
        if current:
            chunks.append(current)
        name = f"{vid}.toc.json"
        wanted.add(name)
        write_json(OUT / "texts" / name, {"version": vid, "units": toc})
        for i, chunk in enumerate(chunks):
            name = f"{vid}.{i}.json"
            wanted.add(name)
            write_json(OUT / "texts" / name, {"version": vid, "units": chunk})
    for old in (OUT / "texts").glob("*.json"):
        if old.name not in wanted:
            old.unlink()

    catalog = {
        "formatVersion": 1,
        "generated": report["generated"],
        "categories": CATEGORIES,
        "sources": SOURCES,
        "works": works,
    }
    write_json(OUT / "catalog.json", catalog)
    (HERE / "reports").mkdir(exist_ok=True)
    (HERE / "reports" / "import.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
