"""Gleicht die Unterlegung aus Wikipedia-Notensätzen mit einem Lied der App ab.

Übernommen wird eine Unterlegung nur, wenn sie nachweislich dasselbe meint:

* gleiche Silbenzahl wie die erste Strophe in der App,
* für die Noten aus den Commons-Vorlagen: exakt dieselbe Tonfolge
  (Intervall für Intervall, Tonart egal),
* Text der Quelle auf Deutsch – derselbe wie in der App oder eine andere
  Strophe desselben deutschen Artikels. Englische Unterlegungen zählen nicht.

Passt die Tonfolge der Vorlage nicht, die Quelle unterlegt aber genau den
Text der App, kann der Notensatz der Quelle selbst verwendet werden.
"""

import difflib
import json
import re

from common import BUILD
from melody import Melody, Tone, _bar_pickup
from underlay import Syllable

SOURCES = BUILD / "wiki_underlay.json"


def load_sources():
    """EG-Nummer → ausgewertete Notensätze (siehe wiki_underlay.py)."""
    if not SOURCES.exists():
        return {}
    by_number = {}
    for source in json.loads(SOURCES.read_text(encoding="utf-8")):
        for number in source["numbers"]:
            by_number.setdefault(number, []).append(source)
    return by_number


def _letters(text):
    return re.sub(r"[^a-zäöüß]", "", text.lower())


def _covered(source):
    """Zahl der Silben(gruppen) im wiederholten Teil; None, wenn es nicht aufgeht."""
    covered = total = 0
    while total < source["repeat"] and covered < len(source["groups"]):
        total += source["groups"][covered]
        covered += 1
    return covered if total == source["repeat"] else None


def sung_syllables(source):
    """Silben der Quelle in gesungener Reihenfolge (Wiederholung ausgeschrieben)."""
    first = [text for text, _ in source["syllables"]]
    if not source["repeat"]:
        return first
    covered = _covered(source)
    if covered is None:
        return first
    return first[:covered] + [text for text, _ in source["second"]] + first[covered:]


def same_text(source, lines):
    """Unterlegt die Quelle den Text der App (bis auf Schreibweise)?"""
    theirs = _letters("".join(sung_syllables(source)))
    ours = _letters("".join(text for line in lines for text, _ in line))
    return difflib.SequenceMatcher(None, theirs, ours).ratio() >= 0.9


def split_like(source, stanza):
    """Zerlegt den Strophentext der App an den Silbengrenzen der Quelle.

    Nur wenn beide Buchstabe für Buchstabe denselben Text haben. So stammt
    auch die Silbentrennung aus der Vorlage und nicht aus der Regel.
    Ergebnis wie syllables.split_stanza oder None.
    """
    theirs = [len(_letters(text)) for text in sung_syllables(source)]
    if 0 in theirs or sum(theirs) != len(_letters(stanza)):
        return None
    if _letters("".join(sung_syllables(source))) != _letters(stanza):
        return None
    lines = []
    for line in stanza.split("\n"):
        result = []
        for word in line.split():
            letters = len(_letters(word))
            if not letters:
                # Gedankenstrich und Ähnliches hängt an der vorigen Silbe.
                if result:
                    result[-1] = (result[-1][0] + " " + word, result[-1][1])
                continue
            # Silben der Quelle, die genau dieses Wort ergeben
            lengths = []
            while sum(lengths) < letters:
                if not theirs:
                    return None
                lengths.append(theirs.pop(0))
            if sum(lengths) != letters:
                return None  # Silbe der Quelle reicht über die Wortgrenze
            pieces = []
            position = 0
            for index, length in enumerate(lengths):
                start = position
                seen = 0
                while seen < length:
                    seen += len(_letters(word[position]))
                    position += 1
                if index == len(lengths) - 1:
                    position = len(word)
                else:
                    # Zeichen im Wort (Apostroph) bleiben bei der Silbe davor.
                    while not _letters(word[position]):
                        position += 1
                pieces.append(word[start:position])
            for index, piece in enumerate(pieces):
                if len(pieces) == 1:
                    kind = "s"
                elif index == 0:
                    kind = "i"
                elif index == len(pieces) - 1:
                    kind = "t"
                else:
                    kind = "m"
                result.append((piece, kind))
        if result:
            lines.append(result)
    return lines if not theirs else None


def _unfolded(source):
    """Töne und Gruppen der Quelle, Wiederholung ausgeschrieben."""
    pitches = [p for p, _ in source["tones"] if p is not None]
    groups = source["groups"]
    variants = [(pitches, groups)]
    repeat = source["repeat"]
    if repeat:
        covered = 0
        total = 0
        while total < repeat and covered < len(groups):
            total += groups[covered]
            covered += 1
        if total == repeat:
            variants.insert(0, (pitches[:repeat] + pitches, groups[:covered] + groups))
    return variants


def _intervals(pitches):
    return [b - a for a, b in zip(pitches, pitches[1:])]


def sizes_for(melody, stanza, lines, sources):
    """Unterlegung für die Melodie der App nach einer passenden Quelle.

    Ergebnis: (Zeilen, Größen, Quelle, gleicher Text?) oder None. Die Zeilen
    sind nach der Quelle getrennt, wenn sie denselben Text unterlegt, sonst
    die übergebenen.
    """
    ours = _intervals([t.pitch for t in melody.tones if t.pitch is not None])
    for source in sources:
        split = split_like(source, stanza)
        identical = split is not None or same_text(source, lines)
        if source["wiki"] != "de.wikipedia.org" and not identical:
            continue
        used = split or lines
        count = sum(len(line) for line in used)
        for pitches, groups in _unfolded(source):
            if len(groups) == count and _intervals(pitches) == ours:
                return used, list(groups), source, identical
    return None


def to_syllables(lines, sizes):
    result = []
    position = 0
    for line in lines:
        for index, (text, kind) in enumerate(line):
            result.append(Syllable(text, kind, sizes[position], index == len(line) - 1))
            position += 1
    return result


def _sharps_for(pitches):
    """Vorzeichnung mit den wenigsten Versetzungszeichen."""
    def outside(sharps):
        scale = {(7 * (sharps + step)) % 12 for step in range(-1, 6)}
        return sum(1 for p in pitches if p % 12 not in scale)

    return min(range(-6, 7), key=lambda s: (outside(s), abs(s)))


def melody_from(source, stanza, lines):
    """Notensatz der Quelle als Melodie mit Unterlegung – nur bei gleichem Text.

    Ergebnis: (Melodie, Silben) oder None.
    """
    split = split_like(source, stanza)
    if split is None and not same_text(source, lines):
        return None
    lines = split or lines
    count = sum(len(line) for line in lines)
    tones = source["tones"]
    groups = source["groups"]
    if source["repeat"]:
        # Wiederholung ausschreiben: Töne bis zum Ende des wiederholten Teils.
        covered = total = 0
        while total < source["repeat"] and covered < len(groups):
            total += groups[covered]
            covered += 1
        if total != source["repeat"]:
            return None
        seen = 0
        cut = len(tones)
        for index, (pitch, _) in enumerate(tones):
            if pitch is not None:
                seen += 1
                if seen == source["repeat"]:
                    cut = index + 1
                    break
        # Pausen direkt nach dem wiederholten Teil gehören noch dazu.
        while cut < len(tones) and tones[cut][0] is None:
            cut += 1
        tones = tones[:cut] + tones
        groups = groups[:covered] + groups
    if len(groups) != count:
        return None

    result = []
    for pitch, length in tones:
        units = length * 16
        if abs(units - round(units)) > 1e-6 or round(units) < 1:
            return None  # Triolen und Vorschläge: nicht im Raster
        result.append(Tone(pitch, round(units)))
    # Luft nach jeder Pause, damit Zeilen auch ohne Text umbrechen könnten.
    for tone, following in zip(result, result[1:]):
        tone.breath = tone.pitch is not None and following.pitch is None
    pitches = [t.pitch for t in result if t.pitch is not None]
    if max(pitches) - min(pitches) > 19:
        return None
    sharps = source["key"] if source["key"] is not None else _sharps_for(pitches)
    melody = Melody(result, 4, max(-7, min(7, sharps)))
    # Taktstriche nur, wenn die Töne restlos in die genannte Taktart passen.
    if source.get("time"):
        numerator, denominator = source["time"]
        if numerator in (2, 3, 4, 6, 9, 12) and denominator in (2, 4, 8):
            pickup = _bar_pickup(result, numerator * 16 // denominator)
            if pickup is not None:
                melody.meter = (numerator, denominator)
                melody.pickup = pickup
    return melody, to_syllables(lines, groups)
