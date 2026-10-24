"""Stellenangaben der BKV-Ausgaben lesen.

Die Übersetzungen (1831–1938) kürzen die Bücher nach katholischem Brauch
ihrer Zeit ab („Matth.“, „Is.“, „3 Kön.“, „Eccli.“) und zählen die Psalmen
meist nach der Vulgata. Welche Abkürzung welches Buch meint, steht in
book_aliases.json; ein Test (test/fathers/fathers_data_test.dart) prüft die
Zielbücher gegen BibleBooks der App.

Ergebnis ist immer eine Stelle in USFM-Kennung mit Kapitel und Vers (bzw.
Versbereich) und einer Sicherheit:
  high   – Buch, Kapitel und Vers eindeutig
  medium – Psalm nach Vulgata-Zählung, wo die Ausgabe keine hebräische
           Zählung in [ ] nennt; „Ebd.“-Angaben
  low    – mehrdeutige Bücher (1/2 Kön. ohne erkennbare Zählweise)
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

ALIASES: dict[str, str] = json.loads(
    (Path(__file__).parent / "book_aliases.json").read_text(encoding="utf-8")
)["aliases"]

# Vulgata/Septuaginta-Psalm → hebräische (deutsche) Zählung, nur das
# Kapitel. Ps 9 und 113 (Vulg.) umfassen je zwei hebräische Psalmen,
# 114/115 und 146/147 (Vulg.) je einen halben; dort ist das Kapitel ohne
# Vers nicht sicher.
def vulgate_psalm(chapter: int):
    if chapter <= 8 or chapter >= 148:
        return chapter, True
    if 10 <= chapter <= 112:
        return chapter + 1, True
    if 116 <= chapter <= 145:
        return chapter + 1, True
    return None, False


DASH = "-–―—‐‑−"

_book_names = sorted(ALIASES, key=len, reverse=True)
_book_pattern = "|".join(re.escape(b).replace(r"\ ", r"\s*") for b in _book_names)

# Buch, Kapitel, Vers(e); z. B. „Joh. 1, 1―5“, „1 Kor. 2, 14“, „Ps. 72, 3“,
# „Matth. 5, 3 ff.“, „Röm. 1, 17“, „Joh. 1, 14–2, 3“, „Joh. 1, 1. 3“.
REF = re.compile(
    rf"(?<![\wÄÖÜäöü])(?P<book>{_book_pattern})\.?\s*"
    rf"(?P<chapter>\d{{1,3}})\s*,\s*(?P<verse>\d{{1,3}})"
    rf"(?:\s*(?P<ff>ff?)\.?)?"
    rf"(?:\s*[{DASH}]\s*(?:(?P<endchapter>\d{{1,3}})\s*,\s*)?(?P<endverse>\d{{1,3}}))?"
    rf"(?:\s*\[(?P<alt>[^\]]{{1,30}})\])?",
    re.UNICODE,
)

EBD = re.compile(
    rf"(?<!\w)(?:Ebd|Ebenda|Ebendas)\.?\s*(?:(?P<chapter>\d{{1,3}})\s*,\s*)?(?P<verse>\d{{1,3}})"
    rf"(?:\s*[{DASH}]\s*(?P<endverse>\d{{1,3}}))?",
    re.UNICODE,
)

CONFER = re.compile(r"(?:^|[\s;(])(?:vgl|Vgl|cf|Cf|s\.)\.?\s*$")


@dataclass
class Ref:
    book: str
    chapter: int
    verse: int
    end_chapter: int
    end_verse: int
    confidence: str
    cited: str
    note: str | None = None
    confer: bool = False

    def compact(self) -> list[int]:
        if self.end_chapter == self.chapter and self.end_verse == self.verse:
            return [self.chapter, self.verse]
        return [self.chapter, self.verse, self.end_chapter, self.end_verse]

    def contains(self, other: "Ref") -> bool:
        if other.book != self.book:
            return False
        start = (self.chapter, self.verse)
        end = (self.end_chapter, self.end_verse)
        return start <= (other.chapter, other.verse) and (
            other.end_chapter, other.end_verse
        ) <= end


def normalize_book(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip().rstrip(".")).strip()


def _alias(book: str) -> str | None:
    key = normalize_book(book)
    if key in ALIASES:
        return ALIASES[key]
    compact = key.replace(" ", "")
    for name, target in ALIASES.items():
        if name.replace(" ", "") == compact:
            return target
    return None


# „I. Kor.“ → „1 Kor.“; „Das. [Gen.] 1, 22“ (daselbst, Buch ergänzt) → „Gen. 1, 22“.
_ROMAN = re.compile(r"(?<![\w.])(III|II|I)\.?\s+(?=[A-ZÄÖÜ][a-zäöü]+\.?\s*\d)")
_DAS = re.compile(r"(?<!\w)Das(?:elbst)?\.\s*\[([^\]]{2,15})\]\s*")


def normalize(text: str) -> str:
    text = _DAS.sub(lambda m: m[1].strip() + " ", text)
    return _ROMAN.sub(lambda m: f"{len(m[1])} ", text)


class RefReader:
    """Liest alle Stellen aus einem Text (Anmerkung, Überschrift, Absatz).

    [kings_vulgate] sagt, ob die Fassung die Königsbücher nach der Vulgata
    zählt (1–4 Kön.); das zeigt sich daran, ob „3 Kön.“ oder „4 Kön.“
    irgendwo in ihr vorkommt.
    """

    def __init__(self, kings_vulgate: bool | None) -> None:
        self.kings_vulgate = kings_vulgate
        self.last: Ref | None = None

    def read(self, text: str) -> list[Ref]:
        text = normalize(text)
        refs: list[Ref] = []
        spans: list[tuple[int, int]] = []

        for m in REF.finditer(text):
            ref = self._from_match(m, text)
            spans.append(m.span())
            if ref is not None:
                refs.append(ref)
                self.last = ref

        for m in EBD.finditer(text):
            if any(a <= m.start() < b for a, b in spans) or self.last is None:
                continue
            last = self.last
            chapter = int(m["chapter"]) if m["chapter"] else last.chapter
            verse = int(m["verse"])
            end = int(m["endverse"]) if m["endverse"] else verse
            if end < verse:
                continue
            refs.append(
                Ref(last.book, chapter, verse, chapter, end, "medium",
                    m.group(0).strip(), "„Ebd.“ – Buch aus der vorigen Angabe")
            )

        return refs

    def _from_match(self, m: re.Match, text: str) -> Ref | None:
        book = _alias(m["book"])
        if book is None:
            return None

        confidence = "high"
        note = None
        chapter = int(m["chapter"])
        verse = int(m["verse"])
        end_chapter = int(m["endchapter"]) if m["endchapter"] else chapter
        end_verse = int(m["endverse"]) if m["endverse"] else verse
        if end_chapter - chapter > 2:
            # „2, 17—13, 3“: eher zwei Angaben als ein Bereich über elf Kapitel.
            end_chapter, end_verse = chapter, verse
            note = "Bereich unklar – nur die erste Angabe"
        if m["ff"]:
            # „ff.“: offenes Ende – nur der Anfangsvers ist belegt.
            end_chapter, end_verse = chapter, verse
            note = "„ff.“ – nur der Anfangsvers"

        if book.startswith("?KINGS"):
            # 1/2 Kön.: Vulgata (= 1/2 Sam) oder Luther (= 1/2 Kön)?
            number = book[-1]
            if self.kings_vulgate is None:
                book = f"{number}KI"
                confidence = "low"
                note = "1/2 Kön.: Zählweise der Ausgabe unklar"
            elif self.kings_vulgate:
                book = f"{number}SA"
                note = f"{number} Kön. (Vulgata) = {number} Sam"
            else:
                book = f"{number}KI"

        if book == "PSA":
            alt = m["alt"]
            alt_ref = None
            if alt:
                am = re.match(rf"\s*(?:Hebr\.?\s*)?(?:Ps\.?)?\s*(\d{{1,3}})\s*,\s*(\d{{1,3}})(?:\s*[{DASH}]\s*(\d{{1,3}}))?", alt)
                if am:
                    alt_ref = (int(am[1]), int(am[2]), int(am[3] or am[2]))
            if alt_ref:
                chapter, verse, end_verse = alt_ref
                end_chapter = chapter
                note = "Psalm in hebräischer Zählung nach der Angabe der Ausgabe in [ ]"
            else:
                hebrew, sure = vulgate_psalm(chapter)
                if hebrew is None:
                    return None
                if end_chapter != int(m["chapter"]):
                    return None
                chapter = end_chapter = hebrew
                confidence = "medium"
                note = ("Psalm nach Vulgata-Zählung umgerechnet; Verszählung "
                        "kann abweichen")

        if (end_chapter, end_verse) < (chapter, verse):
            return None

        before = text[max(0, m.start() - 6):m.start()]
        return Ref(book, chapter, verse, end_chapter, end_verse, confidence,
                   m.group(0).strip(), note, bool(CONFER.search(before)))


def uses_vulgate_kings(texts) -> bool | None:
    """Ob eine Fassung „3 Kön.“/„4 Kön.“ verwendet (Vulgata-Zählung)."""
    pattern = re.compile(r"(?<!\d)[34]\s*Kön\.", re.UNICODE)
    for t in texts:
        if pattern.search(t):
            return True
    return None
