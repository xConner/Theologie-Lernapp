"""Gemeinsame Hilfen der Importe für „Kirchenväter & Schriften“.

Die Bibelstellen der App zählen wie die Perikopenliste (deutsche Zählung,
USFM-Kennungen). Die Umrechnung aus englischer Zählung liest die
Verschiebungen direkt aus lib/services/bible/versification_map.dart, damit
es nur eine Tabelle gibt.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "fathers"

_SHIFT = re.compile(
    r'_Shift\("(\w+)", (\d+), (\d+), (\d+), (\d+), (\d+)\)'
)


def load_shifts() -> list[tuple[str, int, int, int, int, int]]:
    """(Buch, Kapitel, von, bis) deutsch → (Kapitel, Vers) englisch."""
    source = (ROOT / "lib/services/bible/versification_map.dart").read_text(
        encoding="utf-8"
    )
    shifts = [
        (m[1], int(m[2]), int(m[3]), int(m[4]), int(m[5]), int(m[6]))
        for m in _SHIFT.finditer(source)
    ]
    if len(shifts) < 40:
        raise SystemExit("Verschiebungstabelle nicht gefunden")
    return shifts


def verse_counts(translation_id: str) -> dict[str, list[int]]:
    data = json.loads(
        (ROOT / "assets/bible/translations.json").read_text(encoding="utf-8")
    )
    for t in data["translations"]:
        if t["id"] == translation_id:
            return {b["id"]: b["chapters"] for b in t["books"]}
    raise SystemExit(f"Ausgabe {translation_id} fehlt")


class Versification:
    """Englische (KJV-)Zählung → deutsche Zählung der Perikopenliste."""

    def __init__(self) -> None:
        self.shifts = load_shifts()
        self.german = verse_counts("deutkw")
        self.english = verse_counts("engwebp")

    def english_to_german(self, book: str, chapter: int, verse: int):
        """Deutsche Stelle oder None, wenn sie sich nicht sicher bestimmen
        lässt."""
        if book == "PSA":
            return self._psalm(chapter, verse)

        for b, c, frm, to, ec, ev in self.shifts:
            if b != book or ec != chapter:
                continue
            german = frm + verse - ev
            if verse >= ev and german <= to:
                return c, german

        counts = self.german.get(book)
        if not counts or chapter > len(counts) or verse > counts[chapter - 1]:
            return None
        return chapter, verse

    def _psalm(self, chapter: int, verse: int):
        """Psalmen: Zählt die deutsche Ausgabe die Überschrift als eigene
        Verse, verschiebt sich die Zählung um deren Zahl. Das ergibt sich aus
        den Verszahlen (deutsch minus englisch); andere Abweichungen
        gelten als unsicher."""
        g = self.german.get("PSA")
        e = self.english.get("PSA")
        if not g or not e or chapter > len(g) or chapter > len(e):
            return None
        diff = g[chapter - 1] - e[chapter - 1]
        if diff < 0 or diff > 2 or verse > e[chapter - 1]:
            return None
        # Die englische Zählung zählt die Überschrift nicht mit.
        return chapter, verse + diff


def stable_id(*parts: object, length: int = 12) -> str:
    """Kennung, die bei gleichem Inhalt gleich bleibt."""
    text = "|".join(str(p) for p in parts)
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:length]


def write_json(path: Path, data, *, pretty: bool = False) -> bool:
    """Schreibt nur, wenn sich der Inhalt ändert. Gibt zurück, ob."""
    path.parent.mkdir(parents=True, exist_ok=True)
    text = (
        json.dumps(data, ensure_ascii=False, indent=1)
        if pretty
        else json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    ) + "\n"
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.write_text(text, encoding="utf-8")
    return True
