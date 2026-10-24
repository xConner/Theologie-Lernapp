"""Prüft import_bkv.py an erfundenen BKV-Seiten (testdata/bkv).

    python3 tool/fathers/test_import_bkv.py
"""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import import_bkv  # noqa: E402
from bible_refs import RefReader  # noqa: E402


class ImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        (cls.tmp / "reports").mkdir()
        shutil.copy(HERE / "reports" / "crossrefs.json", cls.tmp / "reports")
        import_bkv.ASSETS = cls.tmp / "assets"
        import_bkv.REPORTS = cls.tmp / "reports"
        sys.argv = ["import_bkv.py", str(HERE / "testdata" / "bkv")]
        import_bkv.main()
        cls.library = cls.load("library.json")
        cls.links = cls.load("texts/bkv.tractatus-in-joh-bkv.links.json")["links"]

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)

    @classmethod
    def load(cls, name):
        return json.loads((cls.tmp / "assets" / name).read_text(encoding="utf-8"))

    def version(self, vid):
        return next(v for w in self.library["works"] for v in w["versions"] if v["id"] == vid)

    def test_rights(self):
        free = self.version("bkv.tractatus-in-joh-bkv")
        self.assertEqual(free["rights"], "publicDomain")
        self.assertIn("1918", free["rightsNote"])
        self.assertEqual(free["availability"], "full")
        unclear = self.version("bkv.conf-bkv")
        self.assertEqual(unclear["rights"], "unclear")
        self.assertEqual(unclear["availability"], "external")
        self.assertFalse((self.tmp / "assets" / "texts" / "bkv.conf-bkv.toc.json").exists())

    def test_text(self):
        sections = self.load("texts/bkv.tractatus-in-joh-bkv.0.json")["sections"]
        body = next(s for s in sections if s["n"] == 103)
        # Seitenmarken entfernt, „Forts.“-Absatz angehängt, Anmerkung ohne Nummer.
        self.assertEqual(len(body["p"]), 2)
        self.assertNotIn("S. 1", body["p"][0])
        self.assertIn("Fortsetzung des Absatzes", body["p"][0])
        self.assertEqual(body["notes"], ["Joh. 1, 3."])
        toc = self.load("texts/bkv.tractatus-in-joh-bkv.toc.json")["sections"]
        self.assertEqual(toc[1]["ref"], "S. 1–2")
        self.assertEqual(toc[1]["path"], ["Erster Vortrag"])

    def test_links(self):
        got = {(l["b"], tuple(l["r"]), l["k"], l["c"]) for l in self.links}
        self.assertEqual(got, {
            ("JHN", (1, 1, 1, 5), "sectionCommentary", "high"),
            ("JHN", (1, 3), "verseCommentary", "high"),
            ("ROM", (1, 20), "reference", "high"),
            ("PSA", (19, 2), "quotation", "medium"),
            ("JHN", (3, 16), "quotation", "high"),
            ("JHN", (3, 17), "quotation", "medium"),
        })
        self.assertEqual(len({l["id"] for l in self.links}), len(self.links))

    def test_catalog(self):
        ids = {a["id"] for a in self.library["authors"]}
        # Thomas von Aquin steht in der BKV und in der Kuratierung: eine Kennung.
        self.assertIn("thomas_aquin", ids)
        self.assertNotIn("thomas_von_aquin", ids)
        work = next(w for w in self.library["works"] if w["id"] == "bkv.cpl-278")
        self.assertEqual(work["title"], "Vorträge über das Evangelium des hl. Johannes")
        self.assertEqual(work["clavis"], "CPL 278")
        manifest = self.load("manifest.json")
        self.assertEqual(manifest["files"]["links"], ["JHN", "PSA", "ROM"])

    def test_stable_ids(self):
        before = sorted(l["id"] for l in self.links)
        import_bkv.main()
        after = sorted(l["id"] for l in self.load("texts/bkv.tractatus-in-joh-bkv.links.json")["links"])
        self.assertEqual(before, after)


class RefTest(unittest.TestCase):
    def read(self, text, kings=None):
        return [(r.book, r.compact(), r.confidence) for r in RefReader(kings).read(text)]

    def test_forms(self):
        self.assertEqual(self.read("Matth. 5, 3 ff."), [("MAT", [5, 3], "high")])
        self.assertEqual(self.read("Joh. 1, 14–2, 3"), [("JHN", [1, 14, 2, 3], "high")])
        self.assertEqual(self.read("1 Kor. 2, 14"), [("1CO", [2, 14], "high")])
        self.assertEqual(self.read("Ps. 50, 3 [51, 3]"), [("PSA", [51, 3], "high")])
        self.assertEqual(self.read("Ps. 9, 3"), [])  # Vulgata-Ps 9 = zwei Psalmen

    def test_kings(self):
        self.assertEqual(self.read("1 Kön. 3, 4", kings=True), [("1SA", [3, 4], "high")])
        self.assertEqual(self.read("1 Kön. 3, 4"), [("1KI", [3, 4], "low")])


if __name__ == "__main__":
    unittest.main()
