"""Gemeinsame Helfer der Noten-Recherche (siehe README.md)."""

import json
import re
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HYMNS = ROOT / "assets" / "eg_lieder.json"
BUILD = ROOT / "build" / "hymn_scores"
DOCS = ROOT / "docs" / "hymn-scores"
SNAPSHOT = DOCS / "quellen_snapshot.json"
INVENTORY_JSON = DOCS / "eg_noten_inventar.json"
INVENTORY_CSV = DOCS / "eg_noten_inventar.csv"
OVERRIDES = Path(__file__).resolve().parent / "manual_overrides.json"

USER_AGENT = "theologie.app-hymn-scores/0.1 (https://theologie.app)"

# Stichjahr der Auswertung: Wer bis Ende 1955 gestorben ist, ist seit dem
# 1.1.2026 gemeinfrei (§ 64, § 69 UrhG: 70 Jahre nach dem Todesjahr).
EVALUATION_YEAR = 2026
LAST_FREE_DEATH_YEAR = EVALUATION_YEAR - 71
# Eine Angabe mit Jahr bis 1850 kann von niemandem stammen, der 1956 noch
# lebte; solche Angaben gelten ohne Personenabgleich als gemeinfrei.
SAFE_WORK_YEAR = 1850


def load_hymns():
    return json.loads(HYMNS.read_text(encoding="utf-8"))


def norm(text):
    """Vergleichsform eines Titels: ohne Klammerzusatz, Satzzeichen, Umlaute."""
    text = re.sub(r"\([^)]*\)", " ", text)
    text = text.lower().replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def _open(request):
    """Lädt JSON; bei Drosselung (HTTP 429) wird gewartet und wiederholt."""
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            time.sleep(int(error.headers.get("Retry-After") or 5 * (attempt + 1)))


def api(host, **params):
    params.setdefault("format", "json")
    return _open(
        urllib.request.Request(
            f"https://{host}/w/api.php",
            data=urllib.parse.urlencode(params).encode(),
            headers={"User-Agent": USER_AGENT},
        )
    )


def get_json(url):
    return _open(urllib.request.Request(url, headers={"User-Agent": USER_AGENT}))


def parse_credits(value):
    """Zerlegt eine Text- oder Melodieangabe in Einträge mit Name und Jahr.

    Die Angaben in eg_lieder.json haben die Form
    „Name (Jahr) , Name (Jahr)“; das Jahr kann fehlen.
    """
    credits = []
    for part in re.split(r"\s+,\s+", value.strip()):
        part = part.strip()
        if not part:
            continue
        match = re.match(r"^(.*?)\s*\((\d{3,4})\)\s*$", part)
        if match:
            credits.append({"name": match.group(1).strip(), "year": int(match.group(2))})
        else:
            credits.append({"name": part, "year": None})
    return credits


def looks_like_person(name):
    """Nur mehrteilige Namen werden als Person nachgeschlagen (nicht „Halle“)."""
    return len(name.split()) >= 2
