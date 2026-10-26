"""Prüft open_texts.py an kleinen erfundenen Dateien (testdata/open).

    python3 tool/fathers/test_open_texts.py
"""

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import open_texts  # noqa: E402
from common import Versification  # noqa: E402

DATA = HERE / "testdata" / "open"


class OpenTextsTest(unittest.TestCase):
    def test_beta_code(self):
        self.assertEqual(open_texts.beta_to_greek("Kai\\ ga/r e0ra=te"), "Καὶ γάρ ἐρᾶτε")
        # Englische Wörter bleiben, wie sie sind.
        self.assertEqual(open_texts.beta_to_greek("one's and/or A1"), "one's and/or A1")

    def test_english_refs(self):
        refs = open_texts.EnglishRefReader().read(
            "Matt. xii. 25; 1 Cor. ii. 9-10 (Psalms chapter 51, verse 3) Philemon chapter 4, verse 6")
        found = [(r.book, r.compact()) for r in refs]
        self.assertIn(("MAT", [12, 25]), found)
        self.assertIn(("1CO", [2, 9, 2, 10]), found)
        # Englische Psalmzählung → deutsche (Überschrift als Vers gezählt).
        self.assertIn(("PSA", [51, 5]), found)
        # Unmögliche Stelle (Phlm hat ein Kapitel) entfällt.
        self.assertNotIn("PHM", [b for b, _ in found])

    def test_latin_refs(self):
        refs = open_texts.LatinRefReader().read("Gen. 1, 1; II Cor. 12, 3-6; Ps. 32, 6")
        self.assertEqual([(r.book, r.compact()) for r in refs],
                         [("GEN", [1, 1]), ("2CO", [12, 3, 12, 6]), ("PSA", [33, 6])])

    def test_hcf(self):
        sections = open_texts.read_hcf([DATA / "homily.html"])
        self.assertEqual(len(sections), 1)
        s = sections[0]
        self.assertEqual(s["t"], "Homily 2")
        self.assertEqual(s["notes"], ["[ ἐρᾶτε .]", "Luke xi. 28."])
        self.assertEqual(s["p"][1], "1. It is a great thing[1] to hear (Rom. v. 20.) and to keep it.[2]")
        self.assertEqual(s["marks"], {1: [0, 1]})
        # Abschnittszahl ohne Punkt ist kein Anmerkungszeichen.
        self.assertTrue(s["p"][2].startswith("[7.] And besides, the word [ Καὶ γάρ ]"))
        ref = open_texts.passage_from_start(s["p"][0], "MAT", Versification())
        self.assertEqual((ref.book, ref.compact()), ("MAT", [1, 1]))

    def test_machine_translation_refused(self):
        with self.assertRaises(ValueError):
            open_texts.read_hcf([DATA / "machine.html"])

    def test_tei(self):
        sections = open_texts.read_tei(DATA / "csel.xml", keep_footnotes=True)
        self.assertEqual([s["t"] for s in sections], ["Buch 1", "Buch 2"])
        first = sections[0]
        # Randangabe und Apparat entfallen, Trennung wird zusammengezogen.
        self.assertEqual(first["p"][0], "1. In principio fecit deus uidelicet caelum. [1]")
        self.assertEqual(first["notes"], ["Gen. 1, 1; Ps. 32, 6"])
        self.assertEqual(first["p"][1], "2. Et terra erat inanis.")
        header = open_texts.tei_header(DATA / "csel.xml")
        self.assertEqual(header["editor"], "Karl Schenkl")
        self.assertIn("Creative Commons", header["licence"])


if __name__ == "__main__":
    unittest.main()
