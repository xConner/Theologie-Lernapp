"""Setzt eine Melodie – mit unterlegtem Text – über MEI mit Verovio als SVG."""

import collections
import re
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

import verovio

from melody import spell

SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"

# Notenwerte in Sechzehnteln → (MEI-Dauer, Punktierung)
_VALUES = [
    (32, "breve", 0), (24, "1", 1), (16, "1", 0), (12, "2", 1), (8, "2", 0),
    (6, "4", 1), (4, "4", 0), (3, "8", 1), (2, "8", 0), (1, "16", 0),
]
_KEY_ORDER_SHARPS = "fcgdaeb"
_ACCIDENTAL = {-1: "f", 0: "n", 1: "s"}

# Seitenbreite in Verovio-Einheiten: schmal genug, dass das Notensystem auf
# einem Telefon in voller Breite gut lesbar bleibt.
PAGE_WIDTH = 950

# Schrift des Liedtextes. Verovio rechnet mit den Maßen der Liberation Serif;
# Tinos hat dieselben und liegt der App bei (assets/fonts).
TEXT_FONT = "Tinos"

# Ab so vielen Tönen passt eine Textzeile nicht mehr in ein Notensystem.
LONG_LINE = 10


def _split(sixteenths):
    """Zerlegt eine Länge in schreibbare, übergebundene Notenwerte."""
    parts = []
    for size, dur, dots in _VALUES:
        while sixteenths >= size:
            parts.append((size, dur, dots))
            sixteenths -= size
    return parts


def _key_alteration(step, sharps):
    if sharps > 0 and step in _KEY_ORDER_SHARPS[:sharps]:
        return 1
    if sharps < 0 and step in _KEY_ORDER_SHARPS[::-1][: -sharps]:
        return -1
    return 0


class _Event:
    """Ein Ton oder eine Pause mit allem, was der Satz dazu wissen muss."""

    def __init__(self, pitch, length):
        self.pitch = pitch
        self.length = length  # in Sechzehnteln
        self.syllable = None  # Silbe, die auf diesem Ton beginnt
        self.slur = ""  # "i" Anfang, "t" Ende eines Melismas
        self.line_end = False  # danach endet eine Textzeile


def _events(melody, syllables):
    """Töne mit Silben, Melismabögen und Zeilenenden."""
    factor = {2: 2, 3: 2, 4: 1}[melody.unit_per_quarter]
    events = [_Event(tone.pitch, tone.units * factor) for tone in melody.tones]
    notes = [e for e in events if e.pitch is not None]

    if syllables:
        position = 0
        for syllable in syllables:
            group = notes[position : position + syllable.notes]
            position += syllable.notes
            group[0].syllable = syllable
            if len(group) > 1:
                group[0].slur, group[-1].slur = "i", "t"
            group[-1].line_end = syllable.line_end
    else:
        # Ohne Text: Zeilen enden, wo in der Vorlage Luft ist.
        for event, tone in zip(events, melody.tones):
            event.line_end = tone.pitch is not None and tone.breath

    # Überlange Zeilen bekommen in der Mitte eine zweite Umbruchstelle –
    # mit Text an einer Wortgrenze –, damit das System nicht mitten in der
    # Zeile vollläuft und der Rest verwaist.
    start = 0
    for index, note in enumerate(notes):
        if note.line_end or index == len(notes) - 1:
            line = notes[start : index + 1]
            start = index + 1
            if len(line) <= LONG_LINE:
                continue
            ends = []  # mögliche Teilungen: Index des letzten Tons davor
            for position in range(2, len(line) - 3):
                following = line[position + 1].syllable
                if syllables is None or (
                    following is not None and following.kind in ("s", "i")
                ):
                    ends.append(position)
            if ends:
                middle = (len(line) - 1) / 2
                line[min(ends, key=lambda e: abs(e - middle))].line_end = True

    # Eine Pause nach dem Zeilenende gehört noch zur Zeile.
    for event, following in zip(events, events[1:]):
        if event.line_end and following.pitch is None:
            event.line_end, following.line_end = False, True
    events[-1].line_end = False
    return events


def _word_starts(events, index):
    """Beginnt mit dem Ton an `index` ein neues Wort (oder gibt es keinen Text)?"""
    if not any(e.syllable is not None for e in events):
        return True
    for event in events[index:]:
        if event.pitch is not None:
            return event.syllable is not None and event.syllable.kind in ("s", "i")
    return True


def _measures(melody, events):
    """Teilt in Takte bzw. bei freiem Rhythmus in kurze Abschnitte.

    Ergebnis: Liste von (Stücke, Zeilenende, Taktstrich sichtbar). Ein Stück
    ist (Ereignis, Sechzehntel, erstes Stück?, übergebunden zum nächsten?).
    An Zeilenenden darf das Notensystem umbrechen – im Takt auch mitten im
    Takt, wie im Gesangbuch bei Auftakten.
    """
    measures = []
    current = []

    def close(line_end, barline):
        nonlocal current
        if current:
            measures.append((current, line_end, barline))
            current = []

    if melody.meter:
        numerator, denominator = melody.meter
        bar = numerator * 16 // denominator
        room = melody.pickup * {2: 2, 4: 1}[melody.unit_per_quarter] or bar
        for event in events:
            length = event.length
            first = True
            while length > 0:
                piece = min(length, room)
                length -= piece
                room -= piece
                tied = event.pitch is not None and length > 0
                current.append((event, piece, first, tied))
                first = False
                done = length == 0
                if room == 0:
                    close(done and event.line_end, True)
                    room = bar
                elif done and event.line_end:
                    close(True, False)
    else:
        filled = 0
        for index, event in enumerate(events):
            current.append((event, event.length, True, False))
            filled += event.length
            if event.line_end:
                close(True, False)
                filled = 0
            elif filled >= 8 and _word_starts(events, index + 1):
                # etwa alle zwei Viertel eine unsichtbare Grenze, an der eine
                # überlange Zeile umbrechen kann – nie mitten im Wort
                close(False, False)
                filled = 0
    close(False, True)
    return measures


def to_mei(melody, syllables=None):
    """MEI der Melodie; `syllables` (aus underlay.align) unterlegt den Text."""
    sharps = melody.sharps
    keysig = "0" if sharps == 0 else f"{abs(sharps)}{'s' if sharps > 0 else 'f'}"
    meter = ""
    beat = 6 if melody.unit_per_quarter == 3 else 4
    if melody.meter:
        meter = f' meter.count="{melody.meter[0]}" meter.unit="{melody.meter[1]}"'
        if melody.meter[1] == 8 and melody.meter[0] % 3 == 0:
            beat = 6
        elif melody.meter[1] == 2:
            beat = 8

    measures = _measures(melody, _events(melody, syllables))
    body = []
    counter = 0
    slur_start = None
    carry = False  # Bindung aus dem vorigen Takt
    full_bar = melody.meter[0] * 16 // melody.meter[1] if melody.meter else None

    for number, (pieces, line_end, barline) in enumerate(measures, 1):
        state = {}
        position = 0
        items = []  # (Sechzehntel-Position, XML, bebalkbar)
        slurs = []
        for event, length, first, tied_on in pieces:
            parts = _split(length)
            for index, (size, dur, dots) in enumerate(parts):
                dot = f' dots="{dots}"' if dots else ""
                if event.pitch is None:
                    items.append((position, f'<rest dur="{dur}"{dot}/>', False))
                else:
                    counter += 1
                    note_id = f"n{counter}"
                    step, octave, alter = spell(event.pitch, sharps)
                    current = state.get((step, octave), _key_alteration(step, sharps))
                    accid = ""
                    if alter != current:
                        accid = f' accid="{_ACCIDENTAL[alter]}"'
                        state[(step, octave)] = alter
                    elif alter:
                        accid = f' accid.ges="{_ACCIDENTAL[alter]}"'
                    last = index == len(parts) - 1
                    starts = not last or tied_on
                    ends = index > 0 or carry
                    if starts and ends:
                        tie = ' tie="m"'
                    elif starts:
                        tie = ' tie="i"'
                    elif ends:
                        tie = ' tie="t"'
                    else:
                        tie = ""
                    carry = False

                    verse = ""
                    if first and index == 0:
                        syllable = event.syllable
                        if syllable is not None:
                            attributes = ""
                            if syllable.kind in ("i", "m"):
                                attributes = f' wordpos="{syllable.kind}" con="d"'
                            elif syllable.kind == "t":
                                attributes = ' wordpos="t"'
                            if syllable.notes > 1 and syllable.kind in ("s", "t"):
                                attributes += ' con="u"'
                            verse = (
                                f'<verse n="1"><syl{attributes}>'
                                f"{escape(syllable.text)}</syl></verse>"
                            )
                        if event.slur == "i":
                            slur_start = note_id
                    if event.slur == "t" and last and not tied_on and slur_start:
                        slurs.append(
                            f'<slur startid="#{slur_start}" endid="#{note_id}" '
                            'curvedir="above"/>'
                        )
                        slur_start = None
                    items.append(
                        (
                            position,
                            f'<note xml:id="{note_id}" pname="{step}" oct="{octave}" '
                            f'dur="{dur}"{dot}{accid}{tie}>{verse}</note>',
                            size <= 3,
                        )
                    )
                position += size
            carry = tied_on

        # Kurze Noten innerhalb eines Schlags verbalken
        layer = []
        group = []
        group_beat = None

        def flush():
            if len(group) > 1:
                layer.append("<beam>" + "".join(group) + "</beam>")
            else:
                layer.extend(group)
            group.clear()

        for start, xml, beamable in items:
            if beamable and (group_beat is None or start // beat == group_beat):
                group_beat = start // beat
                group.append(xml)
            else:
                flush()
                group_beat = None
                if beamable:
                    group_beat = start // beat
                    group.append(xml)
                else:
                    layer.append(xml)
        flush()

        last_measure = number == len(measures)
        attributes = f' n="{number}"'
        if last_measure:
            attributes += ' right="end"'
        elif not barline:
            attributes += ' right="invis"'
        if position != full_bar:
            attributes += ' metcon="false"'
        body.append(
            f'<measure{attributes}><staff n="1"><layer n="1">{"".join(layer)}'
            f'</layer></staff>{"".join(slurs)}</measure>'
        )
        if line_end and not last_measure:
            body.append("<sb/>")

    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">'
        "<meiHead><fileDesc><titleStmt><title/></titleStmt><pubStmt/></fileDesc></meiHead>"
        f'<music><body><mdiv><score><scoreDef keysig="{keysig}"{meter}>'
        '<staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2"/></staffGrp>'
        f'</scoreDef><section>{"".join(body)}</section></score></mdiv></body></music></mei>'
    )


_toolkit = None


def systems_start_words(svg, syllables):
    """Beginnt jedes Notensystem des Bildes mit einem Wortanfang?"""
    rows = collections.defaultdict(int)
    for y in re.findall(r'<text x="[\d.]+" y="([\d.]+)"', svg):
        rows[round(float(y))] += 1
    index = 0
    for y in sorted(rows):
        if syllables[index].kind not in ("s", "i"):
            return False
        index += rows[y]
    return index == len(syllables)


def render(mei, breaks="smart"):
    """MEI → schlankes, einfarbiges SVG (ein Bild, mehrere Zeilen).

    `breaks="encoded"` bricht nur an den Zeilenenden des Textes um.
    """
    global _toolkit
    if _toolkit is None:
        verovio.enableLog(verovio.LOG_OFF)
        _toolkit = verovio.toolkit()
        _toolkit.setOptions(
            {
                "pageWidth": PAGE_WIDTH,
                "pageHeight": 60000,
                "adjustPageHeight": True,
                "scale": 40,
                "header": "none",
                "footer": "none",
                # Umbruch bevorzugt an Zeilenenden des Textes (<sb/>), sobald
                # das System gut zur Hälfte gefüllt ist; sonst wo es voll ist.
                "breaks": "smart",
                "breaksSmartSb": 0.45,
                "mnumInterval": 0,
                "spacingSystem": 6,
                "spacingLinear": 0.2,
                "spacingNonLinear": 0.55,
                "fontTextLiberation": True,
                "lyricSize": 4.2,
                "lyricTopMinMargin": 2.5,
                "pageMarginLeft": 10,
                "pageMarginRight": 10,
                "pageMarginTop": 30,
                "pageMarginBottom": 30,
                "svgViewBox": True,
            }
        )
    _toolkit.setOptions({"breaks": breaks})
    if not _toolkit.loadData(mei):
        raise ValueError("Verovio konnte die Noten nicht lesen")
    if _toolkit.getPageCount() != 1:
        raise ValueError("Noten passen nicht auf eine Seite")
    return simplify(_toolkit.renderToSVG(1))


def simplify(svg):
    """Reduziert Verovios SVG auf das, was flutter_svg darstellen kann.

    Verovio färbt Linien über CSS, schachtelt ein zweites <svg> und setzt
    Text in verschachtelte <tspan>; all das kennt flutter_svg nicht. Übrig
    bleiben Glyphen, Pfade, Gruppen und einfache <text>-Elemente in Schwarz –
    die App färbt das Bild passend zum Theme ein.
    """
    ET.register_namespace("", SVG)
    ET.register_namespace("xlink", XLINK)
    root = ET.fromstring(svg)
    suffix = "-" + root.get("id")
    inner = next(e for e in root if e.tag == f"{{{SVG}}}svg")
    defs = next(e for e in root if e.tag == f"{{{SVG}}}defs")

    out = ET.Element(f"{{{SVG}}}svg", {"viewBox": inner.get("viewBox")})
    for glyph in defs:
        glyph.set("id", glyph.get("id").removesuffix(suffix))
    out.append(defs)

    def clean(element):
        for child in list(element):
            name = child.tag.split("}")[1]
            if name in ("desc", "title", "style"):
                element.remove(child)
                continue
            if name == "text":
                # <text x y><tspan><tspan font-size="405px">Silbe</tspan>…
                content = "".join(child.itertext()).strip()
                size = next(
                    (
                        span.get("font-size")
                        for span in child.iter()
                        if span is not child and span.get("font-size")
                    ),
                    None,
                )
                position = {"x": child.get("x"), "y": child.get("y")}
                # Ohne Ort ist es eine Taktzahl am Zeilenanfang – weglassen.
                if not content or size is None or None in position.values():
                    element.remove(child)
                    continue
                for span in list(child):
                    child.remove(span)
                child.attrib.clear()
                child.attrib.update(
                    {
                        **position,
                        "font-family": TEXT_FONT,
                        "font-size": size.removesuffix("px"),
                    }
                )
                child.text = content
                continue
            clean(child)
            for attribute in ("id", "class", "data-id", "data-class"):
                child.attrib.pop(attribute, None)
            if name == "use":
                target = child.attrib.pop("href", None) or child.attrib.pop(f"{{{XLINK}}}href")
                child.set(f"{{{XLINK}}}href", target.removesuffix(suffix))
            elif "stroke-width" in child.attrib:
                child.set("stroke", "#000")
            if name == "g" and len(child) == 0:
                element.remove(child)
            elif name == "g" and not child.attrib:
                # Gruppe ohne eigene Eigenschaften: Inhalt hochziehen
                index = list(element).index(child)
                element.remove(child)
                for offset, grandchild in enumerate(child):
                    element.insert(index + offset, grandchild)

    clean(inner)
    out.extend(list(inner))
    text = ET.tostring(out, encoding="unicode")
    text = re.sub(r">\s+<", "><", text)
    return text + "\n"
