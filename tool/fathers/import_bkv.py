"""Bibliothek der Kirchenväter (bkv.unifr.ch) → assets/fathers/

Aufruf:
    python3 tool/fathers/import_bkv.py <Rohdaten-Ordner> [--check]
    python3 tool/fathers/import_bkv.py --ohne-bkv   (nur redaktionelle Autoren)

Der Rohdaten-Ordner ist der entpackte Abruf (siehe README.md, „Abruf“):
  - die Werkübersicht /de/works (eine HTML-Datei mit „accordion-card“),
  - je ausgewählter Fassung die Fassungsseite <werk>__<fassung>.html,
  - die Abschnittsseiten bkv-div/<werk>__<fassung>/<division_id>.html,
  - translators.json (GND-Abfrage zu den Übersetzern).

Erzeugt Katalog, Texte (je Fassung Inhaltsverzeichnis und Textdateien),
Zuordnungen zu Bibelstellen je Buch und das Manifest; dazu
tool/fathers/reports/bkv_import.json mit Fehlern, Dubletten und den
Änderungen gegenüber dem letzten Import. --check schreibt nichts und
endet mit Fehler, wenn sich Kennungen ändern würden.

Volltexte übernimmt der Import nur von Fassungen, deren Übersetzer
eindeutig in der GND stehen und vor 1956 gestorben sind (70 Jahre nach dem
Tod; Stand 2026), oder die in curation/rights.json mit Begründung
freigegeben sind. Alle anderen Fassungen erscheinen nur mit Angaben und
Link.
"""

from __future__ import annotations

import collections
import datetime
import json
import re
import sys
import unicodedata
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString, Tag

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bible_refs import RefReader, uses_vulgate_kings  # noqa: E402
from common import ASSETS, stable_id, write_json  # noqa: E402

HERE = Path(__file__).resolve().parent
REPORTS = HERE / "reports"
BKV = "https://bkv.unifr.ch"
PD_DEATH_YEAR = datetime.date.today().year - 71
CHUNK_BYTES = 150_000

report: dict = collections.defaultdict(list)


# ---------------------------------------------------------------- Hilfen


def slug(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("ß", "ss")
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def clean(text: str) -> str:
    text = text.replace("\xa0", " ")
    return re.sub(r"\s+", " ", text).strip()


def soup(path: Path) -> BeautifulSoup:
    return BeautifulSoup(path.read_text(encoding="utf-8", errors="replace"), "lxml")


def life_dates(label: str):
    """„Augustinus von Hippo (354-430)“ → („Augustinus von Hippo“, „354–430“, 430)."""
    m = re.match(r"^(.*?)\s*\(([^()]*\d[^()]*)\)\s*$", clean(label))
    if not m:
        return clean(label), None, None
    years = [int(y) for y in re.findall(r"\d{2,4}", m[2])]
    return m[1], m[2].replace("-", "–"), years[-1] if years else None


GENRES = [
    (r"Homilie", "Homilien"),
    (r"Predigt|Sermo|Rede", "Predigten"),
    (r"Katechese", "Katechesen"),
    (r"Kommentar|Erklärung|Auslegung|Vorträge über|Exegese", "Kommentar"),
    (r"Brief", "Briefe"),
    (r"Apologie|Verteidigung", "Apologie"),
    (r"^Gegen |^Wider |Widerlegung|Streitschrift", "Streitschrift"),
    (r"Bekenntnis", "Bekenntnisse"),
    (r"Gebet|Vaterunser", "Gebet"),
    (r"Leben |Vita|Martyrium|Akten", "Hagiographie"),
    (r"Regel", "Regel"),
    (r"Geschichte", "Geschichte"),
]


def genre_of(title: str) -> str:
    for pattern, genre in GENRES:
        if re.search(pattern, title):
            return genre
    return "Schrift"


def language_of(work_slug: str):
    if work_slug.startswith("cpl"):
        return "la"
    if work_slug.startswith("cpg"):
        return "grc"
    return None


def clavis_of(work_slug: str):
    m = re.match(r"^(cpl|cpg)-(\w+)$", work_slug)
    return f"{m[1].upper()} {m[2]}" if m else None


# --------------------------------------------------------------- Katalog


def find_index(raw: Path) -> Path:
    for path in sorted(raw.rglob("*.html")):
        head = path.read_text(encoding="utf-8", errors="replace")
        if "accordion-card" in head and "search-result-divisions-link" in head:
            return path
    raise SystemExit("Werkübersicht (/de/works) nicht gefunden")


def read_index(path: Path):
    """Autoren, Werke und Fassungen aus der Werkübersicht."""
    authors: dict[str, dict] = {}
    works: list[dict] = []

    for card in soup(path).find_all("accordion-card"):
        name = clean(card.get("header", ""))
        if not name:
            continue
        author_id = slug(name)
        authors.setdefault(author_id, {"id": author_id, "name": name})

        for h3 in card.find_all("h3"):
            info = h3.find("a", href=re.compile(r"/works/[^/]+$"))
            if info is None:
                continue
            work_slug = info["href"].rstrip("/").split("/")[-1]
            info.extract()
            title = clean(h3.get_text(" "))
            ul = h3.find_next_sibling("ul")
            versions = []
            for a in ul.find_all("a", class_="search-result-divisions-link") if ul else []:
                m = re.search(r"/works/([^/]+)/versions/([^/]+)", a["href"])
                if not m:
                    continue
                small = clean(a.small.get_text()) if a.small else ""
                kind = re.match(r"^(\w+)\s*\(([^)]*)\)", small)
                text = clean(a.get_text(" "))
                vtitle = clean(text[len(small):]).lstrip(": ") if small else text
                versions.append({
                    "slug": m[2],
                    "type": kind[1] if kind else None,
                    "language": kind[2] if kind else None,
                    "title": vtitle,
                })
            works.append({"slug": work_slug, "author": author_id,
                          "title": title, "versions": versions})

    return authors, works


def read_version_page(path: Path) -> dict:
    """Inhaltsverzeichnis, Bibliographie und Autorenangabe einer Fassung."""
    page = soup(path)
    tree = page.find("collapsible-tree")
    toc = json.loads(tree[":data"]) if tree else []

    text = clean(page.get_text(" "))
    biblio = None
    m = re.search(r"Bibliographische Angabe\s*(.+?)(?:\s+Datum\b|\s+Mitarbeiter\b|$)", text)
    if m:
        biblio = re.sub(r"\s*\((?:Translation|Übersetzung), Deutsch\)\s*$", "", m[1]).strip()

    author_label = None
    header = page.find(class_="author-info-header")
    if header:
        author_label = clean(header.get_text(" "))

    return {"toc": toc, "biblio": biblio, "author": author_label}


def translators_from(biblio: str | None) -> list[str]:
    if not biblio:
        return []
    m = re.search(r"übers(?:etzt|\.)?[^/()]*?\bvon\s+([^/(;]+?)(?:\.\s*\(|\.\s*$|\s*\(|;|$)", biblio)
    if not m:
        return []
    names = re.split(r"\s*(?:,| und | u\. )\s*", m[1])
    return [clean(n).rstrip(".") for n in names if len(clean(n)) > 3]


def series_from(biblio: str | None):
    if not biblio:
        return None, None
    series = None
    m = re.search(r"(Bibliothek der Kirchenväter,\s*\d\.\s*Reihe,\s*Band[^)]*)", biblio)
    if m:
        series = clean(m[1])
    elif "Kempten" in biblio:
        series = "Bibliothek der Kirchenväter (Kempten)"
    published = None
    m = re.search(r"\)\s*([A-ZÄÖÜ][^.()]*?\d{4}(?:\s*[-–]\s*\d{4})?)\.", biblio)
    if m:
        published = clean(m[1])
    return series, published


def load_translators(raw: Path) -> dict[str, list[dict]]:
    """Name → Kandidaten (mit Todesjahr) aus translators.json."""
    found: dict[str, list[dict]] = {}
    for path in raw.rglob("translators.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        entries = data if isinstance(data, list) else data.get("translators", data)
        if isinstance(entries, dict):
            entries = [{"name": k, **(v if isinstance(v, dict) else {"candidates": v})}
                       for k, v in entries.items()]
        for e in entries:
            name = clean(e.get("name", ""))
            found[name] = e.get("candidates") or e.get("matches") or []
    return found


def death_year(candidate: dict):
    value = candidate.get("dateOfDeath") or candidate.get("death") or ""
    if isinstance(value, list):
        value = value[0] if value else ""
    m = re.search(r"(\d{4})", str(value))
    return int(m[1]) if m else None


def rights_of(version_id: str, translators: list[str], gnd: dict, overrides: dict):
    if version_id in overrides:
        o = overrides[version_id]
        return o["rights"], o["note"]
    if not translators:
        return "unclear", "Kein Übersetzer genannt – Rechte nicht prüfbar"
    notes = []
    for name in translators:
        candidates = gnd.get(name)
        if candidates is None:
            for key, value in gnd.items():
                if key.split()[-1] == name.split()[-1] and key[0] == name[0]:
                    candidates = value
        if not candidates:
            return "unclear", f"{name}: keine Lebensdaten gefunden"
        years = {death_year(c) for c in candidates}
        if len(candidates) != 1 or None in years:
            return "unclear", f"{name}: kein eindeutiger GND-Eintrag"
        year = years.pop()
        gid = candidates[0].get("gndIdentifier") or candidates[0].get("gnd") or candidates[0].get("id")
        if year > PD_DEATH_YEAR:
            return "protected", f"{name} † {year} (GND {gid}) – geschützt bis Ende {year + 70}"
        notes.append(f"{name} † {year} (GND {gid})")
    return "publicDomain", "Übersetzer " + "; ".join(notes) + " – gemeinfrei (70 Jahre nach dem Tod)"


# ------------------------------------------------------------ Abschnitte


def division_text(path: Path, title: str):
    """Absätze, Anmerkungen und Seitenzahlen einer Abschnittsseite.

    Absätze: Text mit „[n]“ an den Anmerkungszeichen; ohne Seitenmarken.
    Rückgabe: (Absätze, Anmerkungen, {Absatz: [Anmerkungsnummern]}, Seiten)
    """
    page = soup(path)

    notes: dict[str, str] = {}
    for box in page.find_all("div", class_="footnotes"):
        for li in box.find_all("li", id=re.compile(r"^fn:")):
            for back in li.find_all("a", class_="footnote-backref"):
                back.decompose()
            notes[li["id"]] = clean(li.get_text(" "))
        box.decompose()

    container = None
    for h3 in page.find_all("h3"):
        if clean(h3.get_text(" ")) == clean(title):
            container = h3.parent
            break
    if container is None:
        report["missing_container"].append(str(path))
        return [], [], {}, []

    paragraphs: list[str] = []
    marks: dict[int, list[int]] = {}
    shown_notes: list[str] = []
    pages: list[str] = []

    for p in container.find_all("p"):
        if p.find_parent(class_="footnotes"):
            continue
        refs_here: list[int] = []
        for a in p.find_all("a"):
            href = a.get("href", "")
            if "/scans/" in href:
                pages.append(clean(a.get_text()))
                a.replace_with(NavigableString(""))
        for sup in p.find_all("sup"):
            a = sup.find("a", href=re.compile(r"^#fn:"))
            if a is None:
                continue
            key = a["href"][1:]
            if key in notes:
                shown_notes.append(notes[key])
                refs_here.append(len(shown_notes) - 1)
            sup.replace_with(NavigableString(f"[{len(shown_notes)}]"))
        text = clean(p.get_text(""))
        continued = re.match(r"^\[Forts\. v\.\s*(?:S\.\s*\d+)?\s*\]\s*", text)
        if continued and paragraphs:
            text = text[continued.end():]
            paragraphs[-1] = f"{paragraphs[-1]} {text}".strip()
            marks.setdefault(len(paragraphs) - 1, []).extend(refs_here)
            continue
        if not text:
            continue
        paragraphs.append(text)
        if refs_here:
            marks[len(paragraphs) - 1] = refs_here

    return paragraphs, shown_notes, marks, pages


INTRO = re.compile(r"^(?:Über|Zu|Auslegung) (?:die|den|der) (?:Stelle|Worte|Vers|Text)")


def passage_of(paragraphs: list[str], reader: RefReader):
    """Ausgelegter Abschnitt, wie ihn die Ausgabe am Anfang nennt."""
    for text in paragraphs[:3]:
        if INTRO.search(text) or "bis dahin" in text:
            refs = reader.read(text)
            if refs:
                return refs[-1], text
    return None, None


# ------------------------------------------------------------------ Import


def import_version(raw: Path, work: dict, version: dict, page: dict, author_id: str):
    vid = f"bkv.{version['slug']}"
    folder = raw / "bkv-div" / f"{work['slug']}__{version['slug']}"
    if not folder.exists():
        matches = list(raw.rglob(f"{work['slug']}__{version['slug']}"))
        folder = matches[0] if matches else folder

    nodes = {n["id"]: n for n in page["toc"]}

    def ancestors(node):
        path = []
        parent = node.get("parent")
        while parent in nodes:
            parent_node = nodes[parent]
            if parent_node.get("depth", 0) > 0:
                path.append(clean(parent_node["title"]))
            parent = parent_node.get("parent")
        return list(reversed(path))

    content = [n for n in page["toc"] if n.get("has_valid_content")]
    sections = []
    missing = 0
    for node in content:
        path = folder / f"{node['division_id']}.html"
        if not path.exists():
            missing += 1
            continue
        paragraphs, notes, marks, pages = division_text(path, node["title"])
        if not paragraphs:
            continue
        unit = None
        parent = node.get("parent")
        while parent in nodes and nodes[parent].get("depth", 0) > 1:
            parent = nodes[parent].get("parent")
        if parent in nodes and nodes[parent].get("depth", 0) == 1:
            unit = parent
        sections.append({
            "n": node["division_id"], "t": clean(node["title"]),
            "path": ancestors(node), "unit": unit, "p": paragraphs,
            "notes": notes, "marks": marks,
            "ref": (f"S. {pages[0].replace('S. ', '')}–{pages[-1].replace('S. ', '')}"
                    if len(pages) > 1 else (pages[0] if pages else None)),
            "url": f"{BKV}/works/{work['slug']}/versions/{version['slug']}/divisions/{node['division_id']}",
        })

    if missing:
        report["missing_divisions"].append({"version": vid, "missing": missing,
                                            "of": len(content)})

    all_text = [p for s in sections for p in s["p"] + s["notes"]]
    reader = RefReader(uses_vulgate_kings(all_text))

    links = []
    seen = set()
    unit_passage: dict = {}

    def add(section, first, last, ref, kind, method, cited, extra_note=None):
        key = (section["n"], first, ref.book, tuple(ref.compact()), kind)
        if key in seen:
            report["duplicate_links"].append(f"{vid}:{key}")
            return
        seen.add(key)
        link = {
            "id": stable_id(vid, *key),
            "b": ref.book, "v": vid, "w": f"bkv.{work['slug']}", "a": author_id,
            "s": section["n"], "p": [first, last], "r": ref.compact(),
            "k": kind, "m": method, "c": ref.confidence, "cited": cited,
        }
        note = "; ".join(n for n in [ref.note, extra_note] if n)
        if note:
            link["note"] = note
        links.append(link)

    # Ausgelegter Abschnitt je Einheit (z. B. „1. Vortrag“).
    for s in sections:
        if s["unit"] is None or s["unit"] in unit_passage:
            continue
        ref, text = passage_of(s["p"], reader)
        if ref is not None:
            unit_passage[s["unit"]] = (ref, s)

    for unit, (ref, intro) in unit_passage.items():
        body = [s for s in sections if s["unit"] == unit and s is not intro]
        target = body[0] if body else intro
        add(target, 0, min(2, len(target["p"]) - 1), ref, "sectionCommentary",
            "editionHeading", ref.cited,
            f"Abschnittsangabe der Ausgabe zu „{clean(nodes[unit]['title'])}“")

    # Stellenangaben in den Anmerkungen und in Klammern im Text.
    for s in sections:
        passage = unit_passage.get(s["unit"], (None, None))[0]
        for i, paragraph in enumerate(s["p"]):
            cited = [(s["notes"][k], True) for k in s["marks"].get(i, [])]
            cited += [(m.group(1), False) for m in re.finditer(r"\(([^()]{4,60})\)", paragraph)]
            for text, is_note in cited:
                for ref in reader.read(text):
                    if passage is not None and ref.book == passage.book and ref.compact() == passage.compact():
                        continue  # schon als Auslegung des Abschnitts verzeichnet
                    if passage is not None and passage.contains(ref):
                        kind = "verseCommentary"
                    elif ref.confer:
                        kind = "reference"
                    else:
                        kind = "quotation"
                    add(s, i, i, ref, kind, "editionCitation",
                        text if is_note else ref.cited)

    for s in sections:
        for note in s["notes"]:
            if re.search(r"\d+\s*,\s*\d+", note) and not reader.read(note):
                report["unparsed_references"].append({"version": vid, "note": note})

    return vid, sections, links


def write_texts(vid: str, sections: list[dict]):
    """Inhaltsverzeichnis und Textdateien von je etwa CHUNK_BYTES."""
    toc, chunks, current, size = [], [], [], 0
    for s in sections:
        body = {"n": s["n"], "p": s["p"]}
        if s["notes"]:
            body["notes"] = s["notes"]
        length = len(json.dumps(body, ensure_ascii=False).encode("utf-8"))
        if current and size + length > CHUNK_BYTES:
            chunks.append(current)
            current, size = [], 0
        current.append(body)
        size += length
        entry = {"n": s["n"], "t": s["t"], "c": len(chunks)}
        if s["path"]:
            entry["path"] = s["path"]
        if s["ref"]:
            entry["ref"] = s["ref"]
        entry["url"] = s["url"]
        toc.append(entry)
    if current:
        chunks.append(current)

    texts = ASSETS / "texts"
    write_json(texts / f"{vid}.toc.json", {"sections": toc})
    for i, chunk in enumerate(chunks):
        write_json(texts / f"{vid}.{i}.json", {"sections": chunk})
    for old in texts.glob(f"{vid}.*.json"):
        m = re.match(rf"^{re.escape(vid)}\.(\d+)\.json$", old.name)
        if m and int(m[1]) >= len(chunks):
            old.unlink()
    return len(chunks)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    if len(args) > 1 or (not args and "--ohne-bkv" not in sys.argv):
        raise SystemExit(__doc__)
    raw = Path(args[0]) if args else None

    curation = json.loads((HERE / "curation" / "bkv_authors.json").read_text(encoding="utf-8"))
    overrides = json.loads((HERE / "curation" / "rights.json").read_text(encoding="utf-8"))["versions"]
    later = json.loads((HERE / "curation" / "later_authors.json").read_text(encoding="utf-8"))

    authors, index_works, gnd, pages = {}, [], {}, {}
    if raw is not None:
        authors, index_works = read_index(find_index(raw))
        gnd = load_translators(raw)

    # BKV-Autoren, die auch redaktionell gepflegt sind, behalten deren Kennung.
    later_ids = {a["name"]: a["id"] for a in later["authors"]}
    for work in index_works:
        name = authors[work["author"]]["name"]
        if name in later_ids:
            work["author"] = later_ids[name]

    for path in raw.rglob("*__*.html") if raw is not None else []:
        if path.parent.name.startswith("bkv-div") or path.name.endswith("__divisions.html"):
            continue
        pages[path.stem] = path

    works_out, links_out = [], []
    imported = []

    for work in index_works:
        author_id = work["author"]
        versions_out = []
        for version in work["versions"]:
            if version["language"] not in (None, "Deutsch"):
                continue
            key = f"{work['slug']}__{version['slug']}"
            vid = f"bkv.{version['slug']}"
            entry = {
                "id": vid, "title": version["title"], "language": "de",
                "kind": "historicalTranslation",
                "sourceName": "Bibliothek der Kirchenväter (Universität Freiburg/Schweiz)",
                "sourceUrl": f"{BKV}/works/{work['slug']}/versions/{version['slug']}/divisions",
                "rights": "unclear",
                "rightsNote": "Nur verzeichnet; Übersetzer und Rechte noch nicht geprüft",
                "availability": "external",
            }

            page_path = pages.get(key)
            if page_path is not None:
                page = read_version_page(page_path)
                if page["author"]:
                    name, dates, died = life_dates(page["author"])
                    a = authors.get(author_id)
                    if a is not None and dates:
                        a.setdefault("lifeDates", dates)
                        a.setdefault("deathYear", died)
                translators = translators_from(page["biblio"])
                series, published = series_from(page["biblio"])
                rights, note = rights_of(vid, translators, gnd, overrides)
                entry.update({
                    "translator": ", ".join(translators) or None,
                    "series": series, "published": published,
                    "biblio": page["biblio"], "rights": rights, "rightsNote": note,
                })
                if rights == "publicDomain":
                    _, sections, links = import_version(raw, work, version, page, author_id)
                    if sections:
                        write_texts(vid, sections)
                        tree = [n for n in page["toc"] if n.get("has_valid_content")]
                        entry["availability"] = "full" if len(sections) >= len(tree) else "partial"
                        entry["sections"] = len(sections)
                        entry["links"] = len(links)
                        entry["books"] = sorted({l["b"] for l in links})
                        write_json(ASSETS / "texts" / f"{vid}.links.json", {"links": links})
                        links_out.extend(links)
                        imported.append({"version": vid, "sections": len(sections),
                                         "of": len(tree), "links": len(links)})
                else:
                    report["not_imported"].append({"version": vid, "rights": rights, "note": note})
            versions_out.append({k: v for k, v in entry.items() if v is not None})

        if not versions_out:
            continue
        works_out.append({
            "id": f"bkv.{work['slug']}", "author": author_id, "title": work["title"],
            "clavis": clavis_of(work["slug"]), "genre": genre_of(work["title"]),
            "originalLanguage": language_of(work["slug"]), "versions": versions_out,
        })
        works_out[-1] = {k: v for k, v in works_out[-1].items() if v is not None}

    # Autoren: Einordnung aus der Kuratierung, sonst Alte Kirche (BKV).
    authors_out = []
    for a in authors.values():
        if a["name"] in later_ids:
            continue
        if not any(w["author"] == a["id"] for w in works_out):
            continue
        extra = curation["authors"].get(a["name"], {})
        out = {"id": a["id"], "name": a["name"], "category": "churchFather", **extra}
        for k in ("lifeDates", "deathYear"):
            if a.get(k) is not None:
                out.setdefault(k, a[k])
        if "category" not in extra and (out.get("deathYear") or 0) > 800:
            report["uncategorized_authors"].append(a["name"])
        authors_out.append(out)

    for a in later["authors"]:
        authors_out.append(a)
    for w in later["works"]:
        version = {
            "id": f"{w['id']}.verzeichnet", "title": w["title"],
            "kind": "original", "rights": "unclear",
            "rightsNote": "Noch keine geprüfte Ausgabe in der Bibliothek",
            "availability": "external",
        }
        if "appLink" in w:
            version = {"id": f"{w['id']}.app", "title": w["title"],
                       "kind": "original", "appLink": w["appLink"],
                       "rightsNote": "Text im Bereich Bekenntnisse der App"}
        works_out.append({k: v for k, v in w.items() if k != "appLink"} | {"versions": [version]})

    # Kennungen: Dubletten und Änderungen gegenüber dem letzten Import.
    ids = [w["id"] for w in works_out] + [v["id"] for w in works_out for v in w["versions"]]
    dupes = [i for i, c in collections.Counter(ids).items() if c > 1]
    if dupes:
        raise SystemExit(f"Doppelte Kennungen: {dupes}")
    link_ids = [l["id"] for l in links_out]
    if len(link_ids) != len(set(link_ids)):
        raise SystemExit("Doppelte Kennungen von Zuordnungen")

    old_report = REPORTS / "bkv_import.json"
    old_ids = set()
    if old_report.exists():
        old_ids = set(json.loads(old_report.read_text(encoding="utf-8")).get("ids", []))
    new_ids = set(ids) | set(link_ids)
    changes = {"added": len(new_ids - old_ids), "removed": sorted(old_ids - new_ids)[:200],
               "removedCount": len(old_ids - new_ids)}
    if check:
        print(json.dumps(changes, ensure_ascii=False, indent=1))
        raise SystemExit(1 if changes["removedCount"] else 0)

    library = {"authors": sorted(authors_out, key=lambda a: a["id"]),
               "works": works_out}
    write_json(ASSETS / "library.json", library)

    by_book = collections.defaultdict(list)
    for l in links_out:
        by_book[l["b"]].append({k: v for k, v in l.items() if k != "b"})
    for old in (ASSETS / "links").glob("*.json"):
        if old.stem not in by_book:
            old.unlink()
    for book, items in by_book.items():
        write_json(ASSETS / "links" / f"{book}.json", {"links": items})

    xrefs = json.loads((REPORTS / "crossrefs.json").read_text(encoding="utf-8"))
    kinds = collections.Counter(l["k"] for l in links_out)
    readable = [v for w in works_out for v in w["versions"] if v.get("availability") in ("full", "partial") and v.get("rights") == "publicDomain"]
    manifest = {
        "generated": datetime.date.today().isoformat(),
        "dataVersion": stable_id(*sorted(new_ids), length=10),
        "files": {"links": sorted(by_book), "xrefs": xrefs["books"]},
        "counts": {
            "authors": len(authors_out), "works": len(works_out),
            "versions": sum(len(w["versions"]) for w in works_out),
            "versionsWithText": len(readable),
            "sections": sum(v.get("sections", 0) for v in readable),
            "links": len(links_out), "linksByKind": dict(kinds),
            "bibleBooksWithLinks": len(by_book),
            "crossReferences": xrefs["stats"]["kept"],
        },
        "sources": [
            {"id": "bkv", "name": "Bibliothek der Kirchenväter (BKV)", "url": BKV,
             "license": "Laut Anbieter nach seinem Wissen urheberrechtsfrei; Volltexte "
                        "in der App nur bei gemeinfreien Übersetzungen (Übersetzer vor "
                        f"{PD_DEATH_YEAR + 1} gestorben)",
             "coverage": f"{len(works_out)} Werke im Katalog, {len(readable)} Fassungen mit Text"},
            {"id": "openbible", "name": xrefs["source"], "url": xrefs["url"],
             "license": xrefs["license"], "header": xrefs["header"]},
            {"id": "pericopes", "name": "Perikopen-Datensatz theologie.app",
             "license": "eigene Daten", "coverage": "synoptische Parallelen"},
        ],
    }
    write_json(ASSETS / "manifest.json", manifest, pretty=True)

    out = dict(report)
    out.update({"imported": imported, "changes": changes, "ids": sorted(new_ids),
                "counts": manifest["counts"]})
    write_json(old_report, out, pretty=True)
    print(json.dumps(manifest["counts"], ensure_ascii=False, indent=1))
    print(json.dumps(changes, ensure_ascii=False))


if __name__ == "__main__":
    main()
