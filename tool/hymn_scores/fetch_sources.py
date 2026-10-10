"""Lädt die Metadaten der Notenquellen und schreibt den Quellen-Schnappschuss.

Es werden nur Metadaten geladen (Titel, Lizenzangaben, Versionskennungen,
Lebensdaten), keine Notendateien. Rohantworten liegen im nicht versionierten
build/hymn_scores; der Schnappschuss docs/hymn-scores/quellen_snapshot.json
wird versioniert, damit spätere Änderungen an den Quellen sichtbar werden.

    python fetch_sources.py            # alles
    python fetch_sources.py persons    # nur einen Teil neu laden
"""

import datetime
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor

from common import (
    BUILD,
    DOCS,
    OVERRIDES,
    SNAPSHOT,
    api,
    get_json,
    load_hymns,
    looks_like_person,
    norm,
    parse_credits,
)

EG_LIST = "Liste der Kirchenlieder im Evangelischen Gesangbuch"
COMMONS_CATEGORY = 'Category:Melodies from "Evangelisches Gesangbuch"'
OPEN_HYMNAL_REPO = "mzealey/openhymnal"

# Nennung einer EG-Nummer in einer Commons-Dateibeschreibung, etwa
# „Evang. Gesangbuch 66“, „Ev. Gsb. 516“ oder „(EG 362)“. Regionalteile
# („Evang. Gesangbuch Niedersachsen 643“) werden bewusst nicht erfasst.
EG_NUMBER = re.compile(
    r"(?:Evang(?:el(?:isches)?)?\.?|Ev\.)\s*(?:Gesangbuch|Gsb\.?)\s*(\d{1,3})\b"
    r"|\bEG\s*(\d{1,3})\b"
)


def strip_html(value):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", value or "")).strip()


def fetch_dewiki():
    """EG-Nummer → Wikipedia-Artikel, mit Versionskennung und Notenhinweisen."""
    raw = api(
        "de.wikipedia.org",
        action="query",
        formatversion=2,
        titles=EG_LIST,
        prop="revisions",
        rvprop="content|ids|timestamp",
        rvslots="main",
    )["query"]["pages"][0]["revisions"][0]
    core = raw["slots"]["main"]["content"].split("== Regionalteile ==")[0]

    entries = {}
    for match in re.finditer(r"^::(\d+)\s+(.*)$", core, re.M):
        link = re.search(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]", match.group(2))
        if link:
            entries[int(match.group(1))] = link.group(1).strip()

    titles = sorted(set(entries.values()))
    pages = {}
    for start in range(0, len(titles), 40):
        chunk = titles[start : start + 40]
        query = api(
            "de.wikipedia.org",
            action="query",
            formatversion=2,
            titles="|".join(chunk),
            prop="revisions|pageprops",
            rvprop="content|ids|timestamp",
            rvslots="main",
            redirects=1,
        )["query"]
        renamed = {x["from"]: x["to"] for x in query.get("normalized", [])}
        redirected = {x["from"]: x["to"] for x in query.get("redirects", [])}
        by_title = {p["title"]: p for p in query["pages"]}
        for title in chunk:
            target = renamed.get(title, title)
            target = redirected.get(target, target).split("#")[0]
            page = by_title.get(target)
            if page is None or page.get("missing"):
                continue
            revision = page["revisions"][0]
            text = revision["slots"]["main"]["content"]
            pages[title] = {
                "title": page["title"],
                "revid": revision["revid"],
                "timestamp": revision["timestamp"],
                "wikidata": page.get("pageprops", {}).get("wikibase_item"),
                "score_blocks": len(re.findall(r"<score\b", text)),
                "midi_files": sorted(
                    {
                        m.strip().replace("_", " ")
                        for m in re.findall(
                            r"(?:Datei|File):([^|\]\n]+?\.mid)\b", text
                        )
                    }
                ),
            }

    return {
        "list_title": EG_LIST,
        "list_revid": raw["revid"],
        "list_timestamp": raw["timestamp"],
        "entries": {
            str(number): {"link": title, **({"article": pages[title]} if title in pages else {})}
            for number, title in sorted(entries.items())
        },
    }


def fetch_commons():
    """Alle MIDI-Dateien der Commons-Kategorie mit Lizenz und Prüfsumme."""
    files = {}
    cont = {}
    while True:
        query = api(
            "commons.wikimedia.org",
            action="query",
            formatversion=2,
            generator="categorymembers",
            gcmtitle=COMMONS_CATEGORY,
            gcmtype="file",
            gcmlimit=50,
            prop="imageinfo",
            iiprop="extmetadata|user|timestamp|mime|sha1|size",
            **cont,
        )
        for page in query["query"]["pages"]:
            info = page["imageinfo"][0]
            if info["mime"] != "audio/midi":
                continue
            meta = info["extmetadata"]
            description = strip_html(meta.get("ImageDescription", {}).get("value"))
            numbers = sorted(
                {
                    int(a or b)
                    for a, b in EG_NUMBER.findall(description + " " + page["title"])
                    if 1 <= int(a or b) <= 535
                }
            )
            files[page["title"]] = {
                "sha1": info["sha1"],
                "timestamp": info["timestamp"],
                "size": info["size"],
                "uploader": info["user"],
                "license": meta.get("LicenseShortName", {}).get("value"),
                "license_url": meta.get("LicenseUrl", {}).get("value"),
                "artist": strip_html(meta.get("Artist", {}).get("value")),
                "description": description,
                "eg_numbers": numbers,
            }
        if "continue" not in query:
            break
        cont = query["continue"]
    return {"category": COMMONS_CATEGORY, "files": dict(sorted(files.items()))}


def fetch_open_hymnal():
    """ABC-Dateien des Open Hymnal Project (GitHub-Spiegel) mit Commit."""
    branch = get_json(f"https://api.github.com/repos/{OPEN_HYMNAL_REPO}/branches/master")
    commit = branch["commit"]["sha"]
    tree = get_json(
        f"https://api.github.com/repos/{OPEN_HYMNAL_REPO}/git/trees/{commit}?recursive=1"
    )
    return {
        "repository": f"https://github.com/{OPEN_HYMNAL_REPO}",
        "commit": commit,
        "commit_date": branch["commit"]["commit"]["committer"]["date"],
        "abc_files": sorted(
            item["path"] for item in tree["tree"] if item["path"].endswith(".abc")
        ),
    }


def year_of(claims, prop):
    years = []
    for claim in claims.get(prop, []):
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if value and "time" in value:
            years.append(int(value["time"][1:5]) * (-1 if value["time"][0] == "-" else 1))
    return max(years) if years else None


def lookup_person(name, years):
    """Sucht eine Person in Wikidata; das Werkjahr muss zur Lebenszeit passen."""
    try:
        hits = api(
            "www.wikidata.org",
            action="wbsearchentities",
            search=name,
            language="de",
            uselang="de",
            type="item",
            limit=8,
        )["search"]
    except Exception as error:  # Netzfehler: beim nächsten Lauf erneut
        return {"error": str(error)}
    if not hits:
        return {"candidates": []}
    try:
        entities = api(
            "www.wikidata.org",
            action="wbgetentities",
            ids="|".join(hit["id"] for hit in hits),
            props="claims|labels|aliases|descriptions",
            languages="de|en",
        )["entities"]
    except Exception as error:
        return {"error": str(error)}

    wanted = norm(name)
    candidates = []
    for hit in hits:
        entity = entities.get(hit["id"], {})
        claims = entity.get("claims", {})
        is_human = any(
            c.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") == "Q5"
            for c in claims.get("P31", [])
        )
        if not is_human:
            continue
        names = [v["value"] for v in entity.get("labels", {}).values()]
        names += [a["value"] for group in entity.get("aliases", {}).values() for a in group]
        if wanted not in {norm(n) for n in names}:
            continue
        born, died = year_of(claims, "P569"), year_of(claims, "P570")
        # Ein Werk entsteht zu Lebzeiten; Drucke erscheinen teils erst später.
        fits = all(
            (born is None or year >= born + 8) and (died is None or year <= died + 80)
            for year in years
        )
        if not fits:
            continue
        descriptions = entity.get("descriptions", {})
        candidates.append(
            {
                "id": hit["id"],
                "born": born,
                "died": died,
                "description": (descriptions.get("de") or descriptions.get("en") or {}).get("value"),
            }
        )
    return {"candidates": candidates}


def fetch_persons():
    hymns = load_hymns()
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    aliases = overrides["name_aliases"]
    titles = {norm(h["title"]) for h in hymns}
    values = [
        h[field]
        for h in hymns
        for field in ("text", "melody")
        if not (field == "melody" and norm(h[field]) in titles)
    ]
    values += [v for k, v in overrides["melody_aliases"].items() if not k.startswith("_")]
    wanted = {}
    for value in values:
        for credit in parse_credits(value):
            name = aliases.get(credit["name"], credit["name"])
            if looks_like_person(name):
                years = wanted.setdefault(name, set())
                if credit["year"]:
                    years.add(credit["year"])

    cache_file = BUILD / "persons.json"
    cache = json.loads(cache_file.read_text(encoding="utf-8")) if cache_file.exists() else {}
    todo = [n for n in sorted(wanted) if n not in cache or "error" in cache[n]]

    def work(name):
        time.sleep(0.3)
        return name, lookup_person(name, sorted(wanted[name]))

    with ThreadPoolExecutor(max_workers=1) as pool:
        for index, (name, result) in enumerate(pool.map(work, todo), 1):
            cache[name] = result
            if index % 50 == 0:
                print(f"  Personen: {index}/{len(todo)}")
                cache_file.write_text(json.dumps(cache, ensure_ascii=False, indent=1), encoding="utf-8")
    cache_file.write_text(json.dumps(cache, ensure_ascii=False, indent=1), encoding="utf-8")
    return {name: cache[name] for name in sorted(wanted)}


PARTS = {
    "dewiki": fetch_dewiki,
    "commons": fetch_commons,
    "open_hymnal": fetch_open_hymnal,
    "persons": fetch_persons,
}


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)
    snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8")) if SNAPSHOT.exists() else {}
    for part in sys.argv[1:] or list(PARTS):
        print(f"Lade {part} …")
        snapshot[part] = PARTS[part]()
        snapshot.setdefault("fetched", {})[part] = datetime.date.today().isoformat()
    SNAPSHOT.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Geschrieben: {SNAPSHOT}")


if __name__ == "__main__":
    main()
