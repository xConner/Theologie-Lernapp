"""Kleiner Leser für Standard-MIDI-Dateien (nur was die Notenerzeugung braucht)."""

import struct
from dataclasses import dataclass, field


@dataclass
class Note:
    start: int
    end: int
    pitch: int
    track: int
    channel: int


@dataclass
class MidiFile:
    division: int
    notes: list = field(default_factory=list)
    # (Tick, Zähler, Nenner) bzw. (Tick, Vorzeichenzahl, Moll?)
    time_signatures: list = field(default_factory=list)
    key_signatures: list = field(default_factory=list)


def _varlen(data, pos):
    value = 0
    while True:
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if byte < 0x80:
            return value, pos


def read_midi(path):
    data = path.read_bytes()
    if data[:4] != b"MThd":
        raise ValueError("keine MIDI-Datei")
    _, track_count, division = struct.unpack(">HHH", data[8:14])
    if division & 0x8000:
        raise ValueError("SMPTE-Zeitbasis wird nicht unterstützt")
    midi = MidiFile(division)
    pos = 14
    for track in range(track_count):
        if data[pos : pos + 4] != b"MTrk":
            raise ValueError("Spurkopf fehlt")
        length = struct.unpack(">I", data[pos + 4 : pos + 8])[0]
        pos += 8
        end = pos + length
        tick = 0
        status = 0
        sounding = {}
        while pos < end:
            delta, pos = _varlen(data, pos)
            tick += delta
            byte = data[pos]
            if byte == 0xFF:
                kind = data[pos + 1]
                size, pos = _varlen(data, pos + 2)
                payload = data[pos : pos + size]
                pos += size
                if kind == 0x58 and size >= 2:
                    midi.time_signatures.append((tick, payload[0], 2 ** payload[1]))
                elif kind == 0x59 and size >= 2:
                    sharps = struct.unpack("b", payload[:1])[0]
                    midi.key_signatures.append((tick, sharps, bool(payload[1])))
            elif byte in (0xF0, 0xF7):
                size, pos = _varlen(data, pos + 1)
                pos += size
            else:
                if byte & 0x80:
                    status = byte
                    pos += 1
                kind = status & 0xF0
                channel = status & 0x0F
                size = 1 if kind in (0xC0, 0xD0) else 2
                args = data[pos : pos + size]
                pos += size
                is_on = kind == 0x90 and args[1] > 0
                is_off = kind == 0x80 or (kind == 0x90 and args[1] == 0)
                key = (channel, args[0])
                if (is_on or is_off) and key in sounding:
                    start = sounding.pop(key)
                    if tick > start:
                        midi.notes.append(Note(start, tick, args[0], track, channel))
                if is_on:
                    sounding[key] = tick
        pos = end
    midi.notes.sort(key=lambda n: (n.start, -n.pitch))
    return midi
