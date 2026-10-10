"""Erzeugt das Noten-Inventar aus eg_lieder.json und dem Quellen-Schnappschuss.

Arbeitet ohne Netz. Schreibt docs/hymn-scores/eg_noten_inventar.{json,csv}
und docs/hymn-scores/auswertung.md. Keine produktiven Daten werden geändert.

Die Einstufung ist eine automatische Vorprüfung und keine Rechtsberatung;
die Regeln stehen in docs/hymn-scores/README.md.
"""

import collections
import csv
import json
import re
import urllib.parse

from common import (
    DOCS,
    EVALUATION_YEAR,
    INVENTORY_CSV,
    INVENTORY_JSON,
    LAST_FREE_DEATH_YEAR,
    OVERRIDES,
    SAFE_WORK_YEAR,
    SNAPSHOT,
    load_hymns,
    looks_like_person,
    norm,
    parse_credits,
)

FREE, PROTECTED, UNCLEAR = "gemeinfrei", "geschuetzt", "ungeklaert"

# Eine Wikidata-Person zählt nur als Treffer, wenn ihre Beschreibung zu
# einem Lieddichter oder Komponisten passt (sonst droht Namensgleichheit).
ROLE = re.compile(
    r"komponist|musik|kantor|organist|lied|dicht|poet|theolog|pfarrer|pastor|"
    r"geistlich|priester|prediger|reformator|schriftsteller|hymn|composer|"
    r"writer|mönch|bischof|missionar|sänger|kapellmeister|pädagog|lehrer|"
    r"jurist|humanist|philolog|lyriker|autor|mystiker|arzt",
    re.I,
)

FREE_FILE_LICENSES = {"CC0", "Public domain"}
ATTRIBUTION_LICENSES = {"CC BY 3.0", "CC BY 4.0", "CC BY-SA 3.0", "CC BY-SA 4.0"}


def umlaut_variants(text):
    plain = norm(text)
    spelled = norm(
        text.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue")
        .replace("Ä", "Ae").replace("Ö", "Oe").replace("Ü", "Ue")
    )
    return {plain, spelled}


class Rights:
    def __init__(self, persons, overrides):
        self.persons = persons
        self.aliases = {
            k: v for k, v in overrides["name_aliases"].items() if not k.startswith("_")
        }

    def person(self, name, year):
        """(Status, Begründung) für eine namentlich genannte Person."""
        lookup = self.aliases.get(name, name)
        candidates = [
            c
            for c in self.persons.get(lookup, {}).get("candidates", [])
            if (c["born"] or c["died"]) and ROLE.search(c["description"] or "")
        ]
        if year and year > 1900:
            # Bei neueren Werken muss das Werkjahr in die Lebenszeit fallen.
            candidates = [
                c for c in candidates if c["died"] is None or year <= c["died"] + 2
            ]
        verdicts = set()
        for c in candidates:
            if c["died"] is not None:
                verdicts.add(FREE if c["died"] <= LAST_FREE_DEATH_YEAR else PROTECTED)
            elif c["born"] and c["born"] >= EVALUATION_YEAR - 110:
                verdicts.add(PROTECTED)  # kein Sterbedatum: lebt vermutlich
            else:
                verdicts.add(UNCLEAR)
        if len(verdicts) == 1 and UNCLEAR not in verdicts:
            found = " oder ".join(
                f"{c['born'] or '?'}–{c['died'] or ''}, Wikidata {c['id']}" for c in candidates
            )
            return verdicts.pop(), f"{name} ({found})"
        if year and year <= SAFE_WORK_YEAR:
            return FREE, f"{name} (Werkjahr {year})"
        if year and year > LAST_FREE_DEATH_YEAR:
            # Wer nach 1955 noch schrieb, ist nach 1955 gestorben.
            return PROTECTED, f"{name} (Werkjahr {year})"
        return UNCLEAR, f"{name} (Sterbejahr nicht ermittelt)"

    def credit(self, credit):
        name, year = credit["name"], credit["year"]
        if looks_like_person(name) or name in self.aliases:
            status, reason = self.person(name, year)
            if status != UNCLEAR or self.persons.get(self.aliases.get(name, name), {}).get("candidates"):
                return status, reason
        if year and year <= SAFE_WORK_YEAR:
            return FREE, f"{name} (Werkjahr {year})"
        if year:
            return UNCLEAR, f"{name} ({year}, Urheber nicht ermittelt)"
        return UNCLEAR, f"{name} (ohne Jahr, Urheber nicht ermittelt)"

    def assess(self, value):
        """Gesamtstatus einer Angabe und ob eine spätere Bearbeitung hineinspielt."""
        credits = parse_credits(value)
        results = [self.credit(c) for c in credits]
        statuses = [s for s, _ in results]
        if not statuses:
            overall = UNCLEAR
        elif PROTECTED in statuses:
            overall = PROTECTED
        elif UNCLEAR in statuses:
            overall = UNCLEAR
        else:
            overall = FREE
        later_edit = (
            len(statuses) > 1 and statuses[0] == FREE and overall != FREE
        )
        return overall, "; ".join(r for _, r in results), later_edit


def commons_url(title):
    return "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_"))


def main():
    hymns = load_hymns()
    snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    melody_aliases = {
        norm(k): v for k, v in overrides["melody_aliases"].items() if not k.startswith("_")
    }
    rights = Rights(snapshot["persons"], overrides)
    by_title = {}
    for hymn in hymns:
        by_title.setdefault(norm(hymn["title"]), hymn)
    by_id = {hymn["id"]: hymn for hymn in hymns}
    dewiki = snapshot["dewiki"]["entries"]
    commons = snapshot["commons"]["files"]

    # --- Commons: Datei → EG-Nummern (direkt genannt oder über den Titel) ---
    commons_by_number = collections.defaultdict(dict)
    commons_by_title = collections.defaultdict(list)
    for title, info in commons.items():
        for number in info["eg_numbers"]:
            commons_by_number[number][title] = "EG-Nummer in Dateibeschreibung"
        commons_by_title[norm(title[len("File:"):-len(".mid")])].append(title)

    # --- Open Hymnal: Melodienamen aus den Dateinamen ---
    open_hymnal = collections.defaultdict(list)
    for path in snapshot["open_hymnal"]["abc_files"]:
        stem = path.rsplit("/", 1)[-1][: -len(".abc")]
        for segment in stem.split("-")[1:]:
            segment = re.sub(r"_(\d{4}|Isorhythmic|Rhythmic)$", "", segment)
            open_hymnal[norm(segment.replace("_", " "))].append(path)

    def melody_source(hymn):
        """Löst einen Melodieverweis auf: (Melodieangabe, EG-Nummer, Beleg)."""
        key = norm(hymn["melody"])
        other = by_title.get(key)
        if other is not None and other["id"] != hymn["id"] and not re.search(r"\d{4}", hymn["melody"]):
            return other["melody"], other["id"], "Verweis auf EG %d" % other["id"]
        if key in melody_aliases:
            return melody_aliases[key], None, "manuell (manual_overrides.json)"
        return hymn["melody"], None, "Angabe in eg_lieder.json"

    rows = []
    for hymn in hymns:
        number = hymn["id"]
        melody_value, melody_from, melody_basis = melody_source(hymn)
        melody_status, melody_reason, later_edit = rights.assess(melody_value)
        text_status, text_reason, _ = rights.assess(hymn["text"])

        if later_edit:
            category = 4
        elif text_status == FREE and melody_status == FREE:
            category = 1
        elif text_status == FREE:
            category = 2
        elif melody_status == FREE:
            category = 3
        elif text_status == PROTECTED and melody_status == PROTECTED:
            category = 6
        else:
            category = 5

        # Commons-Dateien: direkt, über Titel, über Wikipedia, über die Melodie
        files = dict(commons_by_number.get(number, {}))
        article = dewiki.get(str(number), {}).get("article")
        names = {norm(hymn["title"])}
        if str(number) in dewiki:
            names.add(norm(dewiki[str(number)]["link"]))
        for name in names:
            for title in commons_by_title.get(name, []):
                files.setdefault(title, "Titelgleichheit")
        if article:
            for name in article["midi_files"]:
                if "File:" + name in commons:
                    files.setdefault("File:" + name, "im Wikipedia-Artikel eingebunden")
        if melody_from is not None:
            for title in commons_by_number.get(melody_from, {}):
                files.setdefault(title, f"Melodie von EG {melody_from}")

        licenses = sorted({commons[t]["license"] for t in files})
        oh_names = umlaut_variants(hymn["title"])
        if melody_from is not None:
            oh_names |= umlaut_variants(by_id[melody_from]["title"])
        oh_exact = sorted({p for name in oh_names for p in open_hymnal.get(name, [])})

        # Beste Quelle und Nutzbarkeit
        has_score = bool(article and article["score_blocks"])
        if files:
            best = "Wikimedia Commons (MIDI, Peter Gerloff)"
            location = " | ".join(commons_url(t) for t in sorted(files))
            fmt = "MIDI"
            scope = "mehrstimmiger Satz; Melodie in der Oberstimme"
            license_text = ", ".join(licenses)
        elif has_score:
            best = "Wikipedia (LilyPond im Artikeltext)"
            location = "https://de.wikipedia.org/w/index.php?oldid=%d" % article["revid"]
            fmt = "LilyPond (<score>)"
            scope = "je Artikel verschieden (Melodie oder Satz)"
            license_text = "CC BY-SA 4.0"
        elif oh_exact:
            best = "Open Hymnal Project"
            location = " | ".join(
                f"{snapshot['open_hymnal']['repository']}/blob/{snapshot['open_hymnal']['commit']}/{p}"
                for p in oh_exact
            )
            fmt = "ABC"
            scope = "vierstimmiger Satz mit englischem Text"
            license_text = "laut Projekt gemeinfrei (je Datei prüfen)"
        else:
            best = location = fmt = scope = license_text = ""

        if melody_status == PROTECTED:
            usability = "nicht ohne Lizenz (Melodie geschützt)"
            advice = "Keine Noten übernehmen; Rechteinhaber/Verlag anfragen oder verzichten."
        elif melody_status == UNCLEAR:
            usability = "ungeklärt"
            advice = "Urheber und Sterbejahr der Melodie klären, erst dann Quelle prüfen."
        elif not best:
            usability = "Melodie gemeinfrei, Notenquelle fehlt"
            advice = "Melodie aus gemeinfreiem Gesangbuchdruck (z. B. Zahn) selbst setzen."
        elif files and set(licenses) <= FREE_FILE_LICENSES:
            usability = "frei integrierbar"
            advice = "Melodie aus der MIDI-Oberstimme als ABC setzen, an EG-Fassung gegenlesen."
        elif files and set(licenses) <= FREE_FILE_LICENSES | ATTRIBUTION_LICENSES or has_score and not files:
            usability = "unter Bedingungen nutzbar (Namensnennung, ggf. Weitergabe unter gleichen Bedingungen)"
            advice = "Als Vorlage für eigenen Notensatz nutzen; bei Übernahme der Datei Lizenzhinweis führen."
        else:
            usability = "ungeklärt"
            advice = "Lizenz der konkreten Datei prüfen."

        if files and any("EG-Nummer" in how for how in files.values()):
            fit = "laut Dateibeschreibung zum EG-Lied; Fassung am Gesangbuch gegenlesen"
        elif files and all("Melodie von" in how for how in files.values()):
            fit = "gleiche Melodie laut Melodieverweis; Textverteilung prüfen"
        elif best:
            fit = "nicht geprüft"
        else:
            fit = ""

        rows.append(
            {
                "eg_nummer": number,
                "titel": hymn["title"],
                "text_angabe": hymn["text"],
                "melodie_angabe": hymn["melody"],
                "melodie_aufgeloest": melody_value,
                "melodie_beleg": melody_basis,
                "text_in_app": bool(hymn["lyrics"]),
                "text_status": text_status,
                "text_begruendung": text_reason,
                "melodie_status": melody_status,
                "melodie_begruendung": melody_reason,
                "kategorie": category,
                "commons_dateien": [
                    {
                        "datei": t,
                        "zuordnung": how,
                        "lizenz": commons[t]["license"],
                        "sha1": commons[t]["sha1"],
                    }
                    for t, how in sorted(files.items())
                ],
                "wikipedia_artikel": article["title"] if article else "",
                "wikipedia_revid": article["revid"] if article else None,
                "wikipedia_score_bloecke": article["score_blocks"] if article else 0,
                "open_hymnal": oh_exact,
                "beste_notenquelle": best,
                "fundstelle": location,
                "format": fmt,
                "umfang": scope,
                "lizenz": license_text,
                "nutzbarkeit": usability,
                "uebereinstimmung": fit,
                "empfehlung": advice,
            }
        )

    DOCS.mkdir(parents=True, exist_ok=True)
    INVENTORY_JSON.write_text(
        json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    with INVENTORY_CSV.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle, delimiter=";")
        columns = [c for c in rows[0] if c not in ("commons_dateien", "open_hymnal")]
        writer.writerow(columns)
        for row in rows:
            writer.writerow(
                ["ja" if row[c] is True else "nein" if row[c] is False else row[c] for c in columns]
            )
    write_summary(rows, snapshot)
    print(f"{len(rows)} Lieder → {INVENTORY_JSON.name}, {INVENTORY_CSV.name}, auswertung.md")


CATEGORIES = {
    1: "Text und Melodie gemeinfrei",
    2: "Text gemeinfrei, Melodie geschützt oder ungeklärt",
    3: "Melodie gemeinfrei, Text geschützt oder ungeklärt",
    4: "Melodie alt, aber spätere Bearbeitung geschützt oder ungeklärt",
    5: "Rechte nicht ausreichend geklärt",
    6: "Text und Melodie geschützt",
}


def write_summary(rows, snapshot):
    def numbers(selection):
        return ", ".join(str(r["eg_nummer"]) for r in selection) or "–"

    count = collections.Counter
    with_source = [r for r in rows if r["beste_notenquelle"]]
    free_melody = [r for r in rows if r["melodie_status"] == FREE]
    lines = [
        "# Auswertung des Noten-Inventars",
        "",
        "Automatisch erzeugt von `tool/hymn_scores/build_inventory.py` – nicht von Hand ändern.",
        "Automatische Vorprüfung, **keine rechtliche Bewertung**; Regeln und Grenzen stehen in `README.md`.",
        "",
        f"Stand der Quellen: {json.dumps(snapshot['fetched'], ensure_ascii=False)}; "
        f"Stichjahr der Schutzfristen: {EVALUATION_YEAR} (gemeinfrei bei Tod bis {LAST_FREE_DEATH_YEAR}).",
        "",
        "## Zahlen",
        "",
        f"- Lieder im Bestand (EG-Stammteil): **{len(rows)}**, davon {sum(r['text_in_app'] for r in rows)} mit angezeigtem Text",
        f"- Melodie gemeinfrei (belegt): **{len(free_melody)}**, geschützt: "
        f"{sum(r['melodie_status'] == PROTECTED for r in rows)}, ungeklärt: {sum(r['melodie_status'] == UNCLEAR for r in rows)}",
        f"- davon Melodiezuordnung von Hand (`manual_overrides.json`): "
        f"{sum(r['melodie_beleg'].startswith('manuell') for r in rows)}",
        f"- Lieder mit mindestens einer gefundenen Notenquelle: **{len(with_source)}**",
        f"- davon mit gemeinfreier Melodie: **{sum(r['melodie_status'] == FREE for r in with_source)}**",
        f"- „frei integrierbar“ (Melodie gemeinfrei, Datei CC0/gemeinfrei): "
        f"**{sum(r['nutzbarkeit'] == 'frei integrierbar' for r in rows)}**",
        "",
        "### Kategorien",
        "",
        "| Kategorie | Bedeutung | Lieder |",
        "|---|---|---|",
    ]
    by_category = count(r["kategorie"] for r in rows)
    lines += [f"| {k} | {v} | {by_category[k]} |" for k, v in CATEGORIES.items()]
    lines += ["", "### Nutzbarkeit", "", "| Nutzbarkeit | Lieder |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in count(r["nutzbarkeit"] for r in rows).most_common()]
    lines += ["", "### Beste Notenquelle", "", "| Quelle | Lieder |", "|---|---|"]
    lines += [
        f"| {k or '(keine gefunden)'} | {v} |"
        for k, v in count(r["beste_notenquelle"] for r in rows).most_common()
    ]
    lines += [
        "",
        "### Abdeckung je Quelle (unabhängig vom Rechtsstatus)",
        "",
        f"- Wikimedia Commons, MIDI: {sum(bool(r['commons_dateien']) for r in rows)} Lieder "
        f"({len(snapshot['commons']['files'])} Dateien in der Kategorie)",
        f"- Wikipedia-Artikel vorhanden: {sum(bool(r['wikipedia_artikel']) for r in rows)} Lieder, "
        f"mit LilyPond-Noten im Artikel: {sum(r['wikipedia_score_bloecke'] > 0 for r in rows)}",
        f"- Open Hymnal (Melodiename gleich Liedtitel): {sum(bool(r['open_hymnal']) for r in rows)} Lieder "
        f"({len(snapshot['open_hymnal']['abc_files'])} ABC-Dateien im Projekt)",
        "",
        "## Lieder ohne geeignete Noten (EG-Nummern)",
        "",
        "**Melodie gemeinfrei, aber keine Notenquelle gefunden:** "
        + numbers([r for r in rows if r["nutzbarkeit"].startswith("Melodie gemeinfrei")]),
        "",
        "**Melodie mit ungeklärtem Rechtsstatus:** "
        + numbers([r for r in rows if r["melodie_status"] == UNCLEAR]),
        "",
        "**Melodie geschützt:** " + numbers([r for r in rows if r["melodie_status"] == PROTECTED]),
        "",
        "**Spätere Bearbeitung geschützt oder ungeklärt (Kategorie 4):** "
        + numbers([r for r in rows if r["kategorie"] == 4]),
        "",
        "**Melodie nur von Hand zugeordnet (zu prüfen):** "
        + numbers([r for r in rows if r["melodie_beleg"].startswith("manuell")]),
        "",
        "## Ungeklärte Melodien im Einzelnen",
        "",
        "| EG | Titel | Melodieangabe | Grund |",
        "|---|---|---|---|",
    ]
    lines += [
        f"| {r['eg_nummer']} | {r['titel']} | {r['melodie_aufgeloest']} | {r['melodie_begruendung']} |"
        for r in rows
        if r["melodie_status"] == UNCLEAR
    ]
    (DOCS / "auswertung.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
