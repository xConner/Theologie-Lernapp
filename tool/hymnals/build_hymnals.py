"""Erzeugt die Verzeichnisdaten der Regionalteile und des Ergänzungshefts.

Ohne Netz: Grundlage sind nur Daten, die schon im Repository liegen.

* Regionalteile: die Dateibeschreibungen der Commons-Kategorie
  „Melodies from Evangelisches Gesangbuch“ im Quellen-Schnappschuss
  (`docs/hymn-scores/quellen_snapshot.json`). Übernommen wird ein Lied nur,
  wenn die Beschreibung die Ausgabe und die Nummer wörtlich nennt (siehe
  `REGIONAL`); das Skript prüft das und bricht sonst ab.
* Ergänzungsheft (EG.E): die Liedangaben des liturgischen Kalenders der App
  („EG.E 10: Ich sage Ja zu dem, der mich erschuf“).

Liedtexte und Noten werden nicht erzeugt: Für keines dieser Lieder liegt im
Projekt ein Text oder eine Melodie vor, deren Fassung zur jeweiligen Ausgabe
gehört (siehe docs/hymnals.md).

    python tool/hymnals/build_hymnals.py
"""

import json
import re
import sys
import unicodedata
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "docs" / "hymn-scores" / "quellen_snapshot.json"
CALENDAR = ROOT / "assets" / "liturgical_calendar_2026.json"
STAMMTEIL = ROOT / "assets" / "eg_lieder.json"
OUT = ROOT / "assets" / "hymnals"

COMMONS_NOTE = (
    "Nummer und Titel laut Beschreibung der Datei auf Wikimedia Commons. "
    "Text und Noten dieser Ausgabe liegen der App nicht vor."
)

# Commons-Datei → (Sammlung, Nummer, Textstelle der Beschreibung, die beides
# belegt). Die Textstelle muss wörtlich in der Beschreibung stehen.
REGIONAL = [
    ("File:Es ist für uns eine Zeit angekommen.mid", "eg_niedersachsen_bremen", "543", "Niedersachsen/Bremen 543"),
    ("File:Wie mit grimmgem Unverstand.mid", "eg_niedersachsen_bremen", "592", "(Niedersachsen) 592"),
    ("File:Harre, meine Seele.mid", "eg_niedersachsen_bremen", "593", "(Niedersachsen) 593"),
    ("File:Du Gott der Liebe, Friedensheld.mid", "eg_niedersachsen_bremen", "614", "(Niedersachsen) 614"),
    ("File:We shall overcome.mid", "eg_niedersachsen_bremen", "616", "(Niedersachsen) 616"),
    ("File:Nun wollen wir singen das Abendlied.mid", "eg_niedersachsen_bremen", "637", "Niedersachsen-Bremen 637"),
    ("File:Brich herein, süßer Schein.mid", "eg_niedersachsen_bremen", "643", "Niedersachsen 643"),
    ("File:Bevor des Tages Licht vergeht.mid", "eg_niedersachsen_bremen", "786.5", "Niedersachsen 786.5"),
    ("File:Weil ich Jesu Schäflein bin (Gregor).mid", "eg_bayern_thueringen", "593", "Bayern/Thüringen 593"),
    ("File:Vergiss nicht zu danken dem ewigen Herrn.mid", "eg_bayern_thueringen", "602", "Bayern-Thüringen 602"),
    ("File:Ich bin durch die Welt gegangen.mid", "eg_bayern_thueringen", "621", "Bayern-Thüringen 621"),
    ("File:Herr, gib du uns Augen.mid", "eg_bayern_thueringen", "649", "Bayern-Thüringen 649"),
    ("File:Bevor des Tages Licht vergeht.mid", "eg_bayern_thueringen", "665", "Bayern/Thüringen 665"),
    ("File:Mit den Hirten will ich gehen.mid", "eg_rheinland_westfalen_lippe", "544", "Rheinland-Westfalen-Lippe 544"),
    ("File:Ich bete an die Macht der Liebe.mid", "eg_rheinland_westfalen_lippe", "661", "Lippe 661"),
    ("File:Die Sach ist dein, Herr Jesu Christ.mid", "eg_baden_pfalz", "606", "Baden/Pfalz 606"),
]

# Textangaben, die die Commons-Beschreibung ausdrücklich macht.
TEXT_CREDITS = {
    "File:Ich bete an die Macht der Liebe.mid": "Gerhard Tersteegen",
}

SUPPLEMENT = "eg_ergaenzungsheft"
SUPPLEMENT_NOTE = (
    "Nummer und Titel laut den Wochenliedern der Perikopenordnung im "
    "liturgischen Kalender der App. Text und Noten sind urheberrechtlich "
    "geschützt und stehen im gedruckten Ergänzungsheft."
)


def norm(text):
    text = re.sub(r"\([^)]*\)", " ", text).lower().replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def work_id(title):
    return norm(title).replace(" ", "_")


def title_of(file):
    name = file.removeprefix("File:").removesuffix(".mid")
    return re.sub(r"\s*\([^)]*\)\s*$", "", name).strip()


def melody_of(artist):
    """„Melodie: César Malan 1827 (…); Satz und Tondatei: …“ → „César Malan 1827 (…)“."""
    match = re.match(r"\s*(?:Melodie|Melody)\s*:\s*([^;]+);", artist)
    return match.group(1).strip() if match else ""


def commons_url(file):
    return "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(
        file.replace(" ", "_"), safe=":,()"
    )


def entry(number, title, **fields):
    return {
        "number": number,
        "title": title,
        "text": fields.get("text", ""),
        "melody": fields.get("melody", ""),
        "lyrics": [],
        "tags": [],
        "bibleReferences": [],
        "explanation": "",
        "workId": work_id(title),
        "lyricsNote": fields["note"],
        "source": fields["source"],
    }


def build_regional(files):
    collections = {}
    for file, collection, number, evidence in REGIONAL:
        info = files.get(file)
        if info is None:
            sys.exit(f"{file} fehlt im Quellen-Schnappschuss")
        description = info["description"]
        if evidence not in description or number not in evidence:
            sys.exit(f"{file}: „{evidence}“ steht nicht in „{description}“")
        title = title_of(file)
        collections.setdefault(collection, []).append(
            entry(
                number,
                title,
                text=TEXT_CREDITS.get(file, ""),
                melody=melody_of(info.get("artist", "")),
                note=COMMONS_NOTE,
                source={
                    "name": "Wikimedia Commons",
                    "file": file,
                    "url": commons_url(file),
                    "statement": description,
                    "license": info.get("license", ""),
                    "licenseUrl": info.get("license_url", ""),
                },
            )
        )
    return collections


def build_supplement(calendar_text):
    songs = {}
    for number, title in re.findall(r'"EG\.E (\d+):\s*([^"]+)"', calendar_text):
        title = title.strip()
        if songs.get(number, title) != title:
            sys.exit(f"EG.E {number}: abweichende Titel {songs[number]!r} / {title!r}")
        songs[number] = title
    return [
        entry(
            number,
            songs[number],
            note=SUPPLEMENT_NOTE,
            source={
                "name": "Liturgischer Kalender der App",
                "file": "assets/liturgical_calendar_2026.json",
                "statement": f"EG.E {number}: {songs[number]}",
            },
        )
        for number in sorted(songs, key=int)
    ]


def check_against_stammteil(collections):
    """Gleichlautende Titel im Stammteil wären ein Hinweis auf eine Dublette."""
    core = {norm(h["title"]): h["id"] for h in json.loads(STAMMTEIL.read_text("utf-8"))}
    for collection, songs in collections.items():
        for song in songs:
            if norm(song["title"]) in core:
                print(
                    f"Hinweis: {collection} {song['number']} „{song['title']}“ "
                    f"heißt wie EG {core[norm(song['title'])]}"
                )


def main():
    files = json.loads(SNAPSHOT.read_text("utf-8"))["commons"]["files"]
    collections = build_regional(files)
    collections[SUPPLEMENT] = build_supplement(CALENDAR.read_text("utf-8"))
    check_against_stammteil(collections)

    OUT.mkdir(parents=True, exist_ok=True)
    for collection, songs in collections.items():
        songs.sort(key=lambda s: float(s["number"]))
        path = OUT / f"{collection}.json"
        path.write_text(
            json.dumps(songs, ensure_ascii=False, indent=2) + "\n", "utf-8"
        )
        print(f"{path.relative_to(ROOT)}: {len(songs)} Lieder")


if __name__ == "__main__":
    main()
