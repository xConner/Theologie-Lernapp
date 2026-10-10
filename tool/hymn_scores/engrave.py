"""Setzt eine Melodie mit Verovio als SVG (über MEI)."""

import re
import xml.etree.ElementTree as ET

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


def _events(melody):
    """Töne als (Tonhöhe, Sechzehntel); Rasterlängen werden umgerechnet."""
    factor = {2: 2, 3: 2, 4: 1}[melody.unit_per_quarter]
    return [(tone.pitch, tone.units * factor) for tone in melody.tones]


def _measures(melody):
    """Teilt die Töne in Takte bzw. bei freiem Rhythmus in kurze Abschnitte.

    Ergebnis: Liste von Takten, jeder eine Liste (Tonhöhe, Sechzehntel,
    Bindung zum nächsten Stück desselben Tons).
    """
    events = _events(melody)
    measures = [[]]
    if melody.meter:
        numerator, denominator = melody.meter
        bar = numerator * 16 // denominator
        room = melody.pickup * {2: 2, 4: 1}[melody.unit_per_quarter] or bar
        for pitch, length in events:
            while length > 0:
                piece = min(length, room)
                length -= piece
                room -= piece
                measures[-1].append((pitch, piece, pitch is not None and length > 0))
                if room == 0:
                    measures.append([])
                    room = bar
    else:
        # Freier Rhythmus: unsichtbare Abschnittsgrenzen etwa alle zwei
        # Viertel, damit die Zeile umbrechen kann.
        filled = 0
        for pitch, length in events:
            measures[-1].append((pitch, length, False))
            filled += length
            if filled >= 8:
                measures.append([])
                filled = 0
    return [m for m in measures if m]


def to_mei(melody):
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

    measures = _measures(melody)
    body = []
    carry = False  # Bindung aus dem vorigen Takt
    for number, measure in enumerate(measures, 1):
        state = {}
        position = 0
        items = []  # (Sechzehntel-Position, XML, bebalkbar)
        for pitch, length, tied_on in measure:
            parts = _split(length)
            for index, (size, dur, dots) in enumerate(parts):
                dot = f' dots="{dots}"' if dots else ""
                if pitch is None:
                    items.append((position, f'<rest dur="{dur}"{dot}/>', False))
                else:
                    step, octave, alter = spell(pitch, sharps)
                    current = state.get((step, octave), _key_alteration(step, sharps))
                    accid = ""
                    if alter != current:
                        accid = f' accid="{_ACCIDENTAL[alter]}"'
                        state[(step, octave)] = alter
                    elif alter:
                        accid = f' accid.ges="{_ACCIDENTAL[alter]}"'
                    last = index == len(parts) - 1
                    tie = ""
                    starts = not last or tied_on
                    ends = index > 0 or carry
                    if starts and ends:
                        tie = ' tie="m"'
                    elif starts:
                        tie = ' tie="i"'
                    elif ends:
                        tie = ' tie="t"'
                    carry = False
                    items.append(
                        (
                            position,
                            f'<note pname="{step}" oct="{octave}" dur="{dur}"{dot}{accid}{tie}/>',
                            size <= 3,
                        )
                    )
                position += size
            carry = tied_on
        # Kurze Noten innerhalb eines Schlags verbalken
        layer = []
        group = []

        def flush():
            if len(group) > 1:
                layer.append("<beam>" + "".join(group) + "</beam>")
            else:
                layer.extend(group)
            group.clear()

        group_beat = None
        for position, xml, beamable in items:
            if beamable and (group_beat is None or position // beat == group_beat):
                group_beat = position // beat
                group.append(xml)
            else:
                flush()
                group_beat = None
                if beamable:
                    group_beat = position // beat
                    group.append(xml)
                else:
                    layer.append(xml)
        flush()

        last_measure = number == len(measures)
        attributes = f' n="{number}"'
        if last_measure:
            attributes += ' right="end"'
        elif not melody.meter:
            attributes += ' right="invis"'
        if not melody.meter or (number == 1 and melody.pickup) or last_measure:
            attributes += ' metcon="false"'
        body.append(
            f'<measure{attributes}><staff n="1"><layer n="1">{"".join(layer)}</layer></staff></measure>'
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">'
        "<meiHead><fileDesc><titleStmt><title/></titleStmt><pubStmt/></fileDesc></meiHead>"
        f'<music><body><mdiv><score><scoreDef keysig="{keysig}"{meter}>'
        '<staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2"/></staffGrp>'
        f'</scoreDef><section>{"".join(body)}</section></score></mdiv></body></music></mei>'
    )


_toolkit = None


def render(mei):
    """MEI → schlankes, einfarbiges SVG (ein Bild, mehrere Zeilen)."""
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
                "breaks": "auto",
                "mnumInterval": 0,
                "spacingSystem": 6,
                "spacingLinear": 0.2,
                "spacingNonLinear": 0.55,
                "pageMarginLeft": 10,
                "pageMarginRight": 10,
                "pageMarginTop": 30,
                "pageMarginBottom": 30,
                "svgViewBox": True,
            }
        )
    if not _toolkit.loadData(mei):
        raise ValueError("Verovio konnte die Noten nicht lesen")
    if _toolkit.getPageCount() != 1:
        raise ValueError("Noten passen nicht auf eine Seite")
    return simplify(_toolkit.renderToSVG(1))


def simplify(svg):
    """Reduziert Verovios SVG auf das, was flutter_svg darstellen kann.

    Verovio färbt Linien über CSS und schachtelt ein zweites <svg>; beides
    kennt flutter_svg nicht. Übrig bleiben Glyphen, Pfade und Gruppen in
    Schwarz – die App färbt das Bild passend zum Theme ein.
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
            if name in ("text", "desc", "title", "style"):
                element.remove(child)
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
