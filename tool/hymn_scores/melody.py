"""Zieht aus einem mehrstimmigen MIDI-Satz die Melodie einer Strophe heraus.

Die Commons-Dateien enthalten einen vierstimmigen Satz, meist mehrere
Strophen hintereinander, mit leicht verkürzten Tönen und gelegentlichen
Atempausen. Hier wird daraus eine einstimmige, gerasterte Tonfolge:

1. Oberstimme: an jedem Einsatz der höchste klingende Ton, sofern er dort
   neu einsetzt – zuerst innerhalb der höchsten Spur, sonst im ganzen Satz.
2. Strophe: Die erste Strophe endet, wo die Melodie von vorn beginnt;
   die Silbenzahl der ersten Textstrophe grenzt die Suche ein.
3. Raster: Tonabstände und -längen werden auf Achtel (oder Sechzehntel)
   gerundet; was nicht aufgeht, wird als Warnung gezählt.
"""

import collections
from dataclasses import dataclass, field

# Notennamen auf der Quintenreihe (F = -1, C = 0, G = 1, …)
_FIFTHS_STEP = {-1: "f", 0: "c", 1: "g", 2: "d", 3: "a", 4: "e", 5: "b"}


@dataclass
class Tone:
    pitch: int  # MIDI-Tonhöhe, None = Pause
    units: int  # Länge in Rastereinheiten
    breath: bool = False  # in der Vorlage folgt hörbar Luft (Zeilenende)


@dataclass
class Melody:
    tones: list
    # Rastereinheiten je Viertel der Vorlage: 2 = Achtel, 4 = Sechzehntel,
    # 3 = Achteltriolen (geschrieben als Achtel im Dreierschlag)
    unit_per_quarter: int
    sharps: int
    meter: tuple = None  # (Zähler, Nenner) oder None
    pickup: int = 0  # Auftakt in Rastereinheiten
    uneven: int = 0  # Tonabstände, die im Raster nicht aufgehen
    warnings: list = field(default_factory=list)

    @property
    def note_count(self):
        return sum(1 for t in self.tones if t.pitch is not None)


def _skyline(notes):
    """Oberstimme als Liste (Einsatz, Ende, Tonhöhe)."""
    by_start = collections.defaultdict(list)
    for note in notes:
        by_start[note.start].append(note)
    line = []
    sounding = []
    for start in sorted(by_start):
        sounding = [n for n in sounding if n.end > start] + by_start[start]
        top = max(sounding, key=lambda n: (n.pitch, n.start))
        if top.start == start:
            line.append((top.start, top.end, top.pitch))
    return line


def _track_voices(notes):
    """Oberstimmen einzelner Spuren: zuerst die höchste, dann die erste.

    In den meisten Vorlagen ist das dieselbe Spur (Sopran); bei manchen
    sind die Spuren umgekehrt geordnet, bei Kanons führt die erste Stimme.
    """
    tracks = collections.defaultdict(list)
    for note in notes:
        tracks[(note.track, note.channel)].append(note)
    highest = max(tracks.values(), key=lambda t: sum(n.pitch for n in t) / len(t))
    first = min(tracks.values(), key=lambda t: (t[0].start, t[0].track))
    voices = [_skyline(highest)]
    if first is not highest:
        voices.append(_skyline(first))
    return voices


def _restarts(voice, voices, length):
    """Beginnt nach `length` Tönen die Melodie von vorn?

    Verglichen werden die ersten Intervalle; die Wiederholung darf in einer
    anderen Stimme oder Lage liegen als die erste Strophe.
    """
    opening = [b[2] - a[2] for a, b in zip(voice, voice[1:5])]
    start = voice[length][0]
    for other in voices:
        following = [p for onset, _, p in other if onset >= start][:5]
        if [b - a for a, b in zip(following, following[1:])] == opening:
            return True
    return False


def _first_strophe(voice, voices, syllables):
    """Zahl der Töne der ersten Strophe oder None, wenn sie nicht abgrenzbar ist.

    Die Strophe endet etwa nach so vielen Tönen, wie die erste Textstrophe
    Silben hat (oder später, bei Melismen), und dort, wo die Melodie hörbar
    neu ansetzt:
    Danach beginnt sie von vorn, und davor liegt der größte Abstand zwischen
    zwei Einsätzen. Ohne solchen Neuansatz gilt die Datei nur dann als eine
    Strophe, wenn ihre Länge zum Text passt.
    """
    count = len(voice)
    if not syllables:
        # Ohne Text: der größte Einschnitt, nach dem die Melodie neu ansetzt.
        gaps = {
            length: voice[length][0] - voice[length - 1][0]
            for length in range(8, count - 4)
            if _restarts(voice, voices, length)
        }
        if not gaps:
            return None
        widest = max(gaps.values())
        return min(length for length, gap in gaps.items() if gap >= widest * 0.95)
    lowest = max(6, int(syllables * 0.9))
    highest = min(int(syllables * 2.2), count - 1)
    gaps = {
        length: voice[length][0] - voice[length - 1][0]
        for length in range(lowest, highest + 1)
        if _restarts(voice, voices, length)
    }
    if gaps:
        widest = max(gaps.values())
        length = min(length for length, gap in gaps.items() if gap >= widest * 0.95)
        return _single_strophe(voice, length, lowest, syllables)
    if lowest <= count <= syllables * 1.45:
        return count
    return None


def _single_strophe(voice, length, lowest, syllables):
    """Kürzt auf eine Strophe, wenn `length` in Wahrheit zwei umfasst.

    Ist die zweite Strophe anders gesetzt, setzt die Melodie erst nach der
    dritten erkennbar neu an. Das zeigt sich an der Überlänge und daran, dass
    der größte Einschnitt in Textlänge die Dauer genau halbiert.
    """
    if length <= syllables * 1.45:
        return length
    inner = {
        cut: voice[cut][0] - voice[cut - 1][0]
        for cut in range(lowest, int(syllables * 1.45) + 1)
    }
    if not inner:
        return length
    cut = max(inner, key=lambda c: (inner[c], -c))
    whole = voice[length][0] - voice[0][0]
    half = voice[cut][0] - voice[0][0]
    return cut if abs(whole / half - 2) <= 0.08 else length


def _singable(line):
    """Eine Liedmelodie springt nicht über eine Oktave und bleibt im Umfang."""
    pitches = [p for _, _, p in line]
    leaps = max(abs(b - a) for a, b in zip(pitches, pitches[1:]))
    return leaps <= 12 and max(pitches) - min(pitches) <= 17


def _strophe_line(midi, syllables):
    """Tonfolge der ersten Strophe: zuerst aus einer einzelnen Spur, sonst
    aus der Oberstimme des ganzen Satzes."""
    voices = (*_track_voices(midi.notes), _skyline(midi.notes))
    for voice in voices:
        length = _first_strophe(voice, voices, syllables)
        if length and _singable(voice[:length]):
            return voice[:length]
    return None


def _quantize(line, quarter, per_quarter):
    """Rastert die Tonfolge; liefert (Töne, Zahl nicht aufgehender Abstände)."""
    unit = quarter / per_quarter
    eighth = per_quarter / 2
    tones = []
    uneven = 0
    for index, (start, end, pitch) in enumerate(line):
        sounding = max(1, round((end - start) / unit))
        rest = 0
        if index + 1 < len(line):
            gap = (line[index + 1][0] - start) / unit
            span = max(1, round(gap))
            if abs(gap - span) > 0.4:
                uneven += 1
            sounding = min(sounding, span)
            rest = span - sounding
            # Bis zu einer Achtel Luft nach einem längeren Ton ist ein
            # Atemholen des Spielers, keine notierte Pause.
            if 0 < rest <= eighth and sounding >= 2 * eighth:
                sounding, rest = span, 0
            elif rest and rest < eighth:
                sounding, rest = span, 0
        # Luft nach dem Ton: mehr als die übliche Artikulation (ein Sechstel
        # Viertel) oder eine eingeschobene Verlängerung.
        breath = False
        if index + 1 < len(line):
            silence = (line[index + 1][0] - end) / quarter
            breath = silence >= 0.17 or gap - span > 0.1
        tones.append(Tone(pitch, sounding, breath or bool(rest)))
        if rest:
            tones.append(Tone(None, rest))
    return tones, uneven


def _bar_pickup(tones, bar):
    """Auftakt, bei dem kein Ton über einen Taktstrich reicht; sonst None."""
    total = sum(t.units for t in tones)
    for pickup in range(bar):
        position = (bar - pickup) % bar
        fits = True
        for tone in tones:
            if position + tone.units > bar and tone.units <= bar:
                fits = False
                break
            position = (position + tone.units) % bar
        # Auftakt und Schlusstakt ergänzen sich zu einem vollen Takt.
        if fits and (total - pickup) % bar in (0, (bar - pickup) % bar):
            return pickup
    return None


def extract(midi, syllables=0):
    """Melodie der ersten Strophe oder None, wenn sie nicht sicher abgrenzbar ist."""
    line = _strophe_line(midi, syllables)
    if line is None:
        return None
    warnings = []

    # Raster: Achtel, Achteltriolen (Dreiertakt aus punktierten Schlägen)
    # oder Sechzehntel – das gröbste, in dem die Abstände am besten aufgehen.
    tones, uneven, per_quarter = min(
        (
            (*_quantize(line, midi.division, per_quarter), per_quarter)
            for per_quarter in (2, 3, 4)
        ),
        key=lambda result: result[1],
    )

    # Der Schlusston ist in den Vorlagen oft ausgehalten; geschrieben wird
    # der nächstkleinere einfache Notenwert.
    eighth = 1 if per_quarter == 3 else per_quarter // 2
    simple = [n * eighth for n in (16, 12, 8, 6, 4, 3, 2, 1)]
    tones[-1].units = next((n for n in simple if n <= tones[-1].units), tones[-1].units)

    if uneven:
        warnings.append(f"{uneven} Tonabstände gehen im Raster nicht auf")

    pitches = sorted(t.pitch for t in tones if t.pitch is not None)
    median = pitches[len(pitches) // 2]
    shift = -12 if median > 74 else 12 if median < 57 else 0
    if shift:
        for tone in tones:
            if tone.pitch is not None:
                tone.pitch += shift
        warnings.append("um eine Oktave versetzt")

    sharps = midi.key_signatures[0][1] if midi.key_signatures else 0
    melody = Melody(tones, per_quarter, sharps, uneven=uneven, warnings=warnings)

    if midi.time_signatures and per_quarter != 3:
        _, numerator, denominator = midi.time_signatures[0]
        if numerator in (2, 3, 4, 6, 9, 12) and denominator in (2, 4, 8):
            bar = numerator * per_quarter * 4 // denominator
            pickup = _bar_pickup(tones, bar)
            if pickup is not None:
                melody.meter = (numerator, denominator)
                melody.pickup = pickup
    return melody


def spell(pitch, sharps):
    """(Notenname, Oktave, Versetzung) passend zur Vorzeichnung.

    Töne außerhalb der Tonleiter werden so benannt, wie sie in der Tonart
    üblich sind: erhöhte 4., 1. und 5. Stufe als Kreuz, erniedrigte 7., 3.
    und 6. Stufe als b.
    """
    best = None
    for fifths in range(sharps - 3, sharps + 9):
        if (fifths * 7) % 12 == pitch % 12:
            best = fifths
            break
    alter = (best + 1) // 7
    step = _FIFTHS_STEP[best - 7 * alter]
    natural = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}[step]
    octave = (pitch - natural - alter) // 12 - 1
    return step, octave, alter
