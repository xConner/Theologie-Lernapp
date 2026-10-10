"""Ordnet die Silben der ersten Strophe den Tönen der Melodie zu.

Die Vorlagen enthalten keinen Text. Die Zuordnung wird deshalb aus dem
abgeleitet, was beide Seiten sicher hergeben, und nur übernommen, wenn sie
aufgeht:

* Jede Silbe bekommt einen Ton. Gibt es mehr Töne als Silben, werden kurze
  Töne zu Melismen gebunden – nach genau einer von zwei Regeln, die die
  Überzahl restlos erklären muss:
  „Paare“: zwei kurze Töne, die zusammen einen Grundschlag füllen;
  „Punktierung“: ein einzelner kurzer Ton hängt am längeren davor.
* Zuerst Zeile für Zeile: Textzeilen enden dort, wo in der Vorlage Luft ist
  (Pause, Atemholen). So darf jede Zeile ihre eigene Regel haben; eine Zeile
  mit Überzahl darf sich außerdem nach dem Silbenrhythmus einer gelösten
  Zeile gleicher Länge richten.
* Sonst die Strophe als Ganzes; dabei darf keine Luft in ein Wort fallen.
* Geht es nach keiner Regel auf oder gibt es mehrere Möglichkeiten, gilt
  die Zuordnung als nicht gesichert (None). Melismen aus gleich langen Tönen
  lassen sich aus den Vorlagen nicht erkennen.
"""

import collections
from dataclasses import dataclass


@dataclass
class Syllable:
    text: str
    kind: str  # s, i, m, t (einzeln, Wortanfang, -mitte, -ende)
    notes: int  # Zahl der Töne auf dieser Silbe (> 1 = Melisma)
    line_end: bool = False


def _pulse(notes):
    """Häufigster Notenwert – der Grundschlag, auf dem die Silben liegen."""
    return collections.Counter(n.units for n in notes).most_common(1)[0][0]


def _joins(notes, pulse):
    """Die beiden Melisma-Regeln als Mengen von Tönen, die am Vorgänger hängen."""
    pairs = set()
    index = 0
    while index + 1 < len(notes):
        first, second = notes[index], notes[index + 1]
        if (
            first.units < pulse
            and first.units + second.units <= pulse
            and not first.breath
        ):
            pairs.add(index + 1)
            index += 2
        else:
            index += 1
    # Punktierte Figur: ein einzelner kurzer Ton nach einem längeren. Folgen
    # mehrere kurze, bleibt offen, ob sie zum Ton davor oder danach gehören.
    dotted = {
        index
        for index in range(1, len(notes))
        if notes[index].units < pulse
        and notes[index - 1].units > notes[index].units
        and notes[index - 1].units >= pulse
        and not notes[index - 1].breath
        and (index + 1 == len(notes) or notes[index + 1].units >= pulse)
    }
    return pairs, dotted


def _fit(notes, count, pulse):
    """Töne je Silbe für eine Tonfolge oder None, wenn es nicht eindeutig aufgeht."""
    if len(notes) == count:
        return [1] * count
    if len(notes) < count:
        return None

    def grouped(joins):
        sizes = []
        for index in range(len(notes)):
            if index in joins:
                sizes[-1] += 1
            else:
                sizes.append(1)
        return sizes

    fits = [g for g in map(grouped, _joins(notes, pulse)) if len(g) == count]
    if len(fits) == 2 and fits[0] != fits[1]:
        return None
    return fits[0] if fits else None


def _like_sibling(notes, count, solved):
    """Töne je Silbe nach dem Rhythmus einer schon gelösten Zeile gleicher Länge.

    Zeilen gleichen Versmaßes haben in einer Melodie meist denselben
    Silbenrhythmus. Wo die Schwesterzeile einen langen Ton hat und hier zwei
    kürzere dieselbe Dauer füllen, liegt das Melisma. Der Zeilenschluss wird
    nicht verglichen (Schlusstöne sind verschieden lang).
    """
    found = set()
    for sibling_notes, sibling_sizes in solved:
        if len(sibling_sizes) != count:
            continue
        durations = []
        position = 0
        for size in sibling_sizes:
            durations.append(sum(n.units for n in sibling_notes[position : position + size]))
            position += size
        sizes = []
        position = 0
        for duration in durations[:-1]:
            filled = size = 0
            while position + size < len(notes) and filled < duration:
                filled += notes[position + size].units
                size += 1
            if filled != duration:
                break
            sizes.append(size)
            position += size
        else:
            if position < len(notes):
                sizes.append(len(notes) - position)
                # Am Zeilenschluss höchstens ein kurzer Durchgang, kein Rest
                if sizes[-1] <= 2:
                    found.add(tuple(sizes))
    return list(found.pop()) if len(found) == 1 else None


def _by_lines(notes, lines, pulse):
    """Zeile für Zeile: Jede Zeile endet, wo in der Vorlage Luft ist."""
    ends = [i + 1 for i, note in enumerate(notes) if note.breath or i == len(notes) - 1]

    if len(ends) == len(lines):
        # Genau so viele Einschnitte wie Zeilen: Die Zeilen liegen fest.
        segments = [notes[a:b] for a, b in zip([0] + ends, ends)]
        fits = [_fit(seg, len(line), pulse) for seg, line in zip(segments, lines)]
        solved = [(seg, fit) for seg, fit in zip(segments, fits) if fit is not None]
        progress = True
        while progress and any(fit is None for fit in fits):
            progress = False
            for index, (segment, line) in enumerate(zip(segments, lines)):
                if fits[index] is None and len(segment) > len(line):
                    fits[index] = _like_sibling(segment, len(line), solved)
                    if fits[index] is not None:
                        solved.append((segment, fits[index]))
                        progress = True
        if all(fit is not None for fit in fits):
            return [size for fit in fits for size in fit]
        return None

    solutions = []

    def search(line, start, chosen):
        if len(solutions) > 1:
            return
        if line == len(lines):
            if start == len(notes):
                solutions.append([size for sizes in chosen for size in sizes])
            return
        need = len(lines[line])
        for end in ends:
            if end - start < need:
                continue
            if end - start > need * 2:
                break
            fit = _fit(notes[start:end], need, pulse)
            if fit is not None:
                chosen.append(fit)
                search(line + 1, end, chosen)
                chosen.pop()

    search(0, 0, [])
    return solutions[0] if len(solutions) == 1 else None


def _as_whole(notes, lines, pulse):
    """Ganze Strophe auf einmal – gültig nur, wenn kein Wort durch Luft reißt."""
    words = [kind for line in lines for _, kind in line]
    sizes = _fit(notes, len(words), pulse)
    if sizes is None:
        return None
    position = 0
    for kind, size in zip(words, sizes):
        group = notes[position : position + size]
        position += size
        # Luft mitten im Melisma oder vor der nächsten Silbe desselben Wortes
        if any(note.breath for note in group[:-1]):
            return None
        if group[-1].breath and kind in ("i", "m"):
            return None
    return sizes


def align(melody, lines):
    """Silben in Reihenfolge der Töne oder None, wenn nicht gesichert.

    `lines` sind die Zeilen der Strophe als Listen (Text, Wortposition).
    """
    notes = [t for t in melody.tones if t.pitch is not None]
    lines = [line for line in lines if line]
    if not notes or not lines:
        return None
    pulse = _pulse(notes)
    sizes = _by_lines(notes, lines, pulse) or _as_whole(notes, lines, pulse)
    if sizes is None:
        return None

    result = []
    position = 0
    for line in lines:
        for index, (text, kind) in enumerate(line):
            result.append(Syllable(text, kind, sizes[position], index == len(line) - 1))
            position += 1
    return result
