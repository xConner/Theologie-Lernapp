# -*- coding: utf-8 -*-
"""Zeugen des Drucks (Concordia Triglotta, St. Louis 1921) je Sprache.

* Deutsch (Fraktur): eigene Texterkennung des Scans concordiatriglot00unse mit
  zwei Fraktur-Modellen (frak2021, Fraktur). Beide lesen dasselbe Bild, gelten
  also nicht als unabhängig.
* Lateinisch/Englisch (Antiqua): die bei archive.org liegenden Texterkennungen
  zweier verschiedener Scans (concordiatriglot00unse, ConcordiaTriglotta).
"""
from collate import Witness, file_stream, leaf_stream
from common import cache

TRIGLOTTA = ('concordiatriglot00unse', 285, 1447, 2)   # Blätter mit deutschem/lateinischem Text


def witnesses_for(lang):
    """(zeugen, anzahl unabhängiger Zeugen)"""
    if lang == 'de':
        item, lo, hi, step = TRIGLOTTA
        return [Witness(leaf_stream(item, 'frak2021', 'de', lo, hi, step)),
                Witness(leaf_stream(item, 'Fraktur', 'de', lo, hi, step))], 0
    return [Witness(file_stream(cache('ocrA.txt'), lang)), Witness(file_stream(cache('ocrB.txt'), lang))], 2
