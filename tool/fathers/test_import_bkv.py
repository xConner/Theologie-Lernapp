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
        epub = cls.tmp / "epub"
        epub.mkdir()
        make_epub(epub / "Exameron_BKV_deutsch_77.epub")
        sys.argv = ["import_bkv.py", str(HERE / "testdata" / "bkv"), "--epub", str(epub)]
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
        # Nicht nach GND gemeinfrei → Erlaubnis aus curation/rights.json
        # („default“), mit dem Grund aus der GND-Prüfung.
        other = self.version("bkv.conf-bkv")
        self.assertEqual(other["rights"], "permission")
        self.assertIn("Conner", other["rightsNote"])
        self.assertIn("kein eindeutiger GND-Eintrag", other["rightsNote"])
        # Ohne abgerufene Abschnitte bleibt es beim Link.
        self.assertEqual(other["availability"], "external")
        self.assertFalse((self.tmp / "assets" / "texts" / "bkv.conf-bkv.toc.json").exists())

    def test_text(self):
        sections = self.load("texts/bkv.tractatus-in-joh-bkv.0.json")["sections"]
        body = next(s for s in sections if s["n"] == 103)
        # Seitenmarken und „[Forts. v. S. n]“ entfernt, Anmerkung ohne Nummer.
        self.assertEqual(len(body["p"]), 3)
        self.assertNotIn("S. 1", body["p"][0])
        self.assertTrue(body["p"][1].startswith("Fortsetzung des Absatzes"))
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
        self.assertEqual(manifest["files"]["links"], ["GEN", "JHN", "PSA", "ROM"])

    def test_stable_ids(self):
        before = sorted(l["id"] for l in self.links)
        import_bkv.main()
        after = sorted(l["id"] for l in self.load("texts/bkv.tractatus-in-joh-bkv.links.json")["links"])
        self.assertEqual(before, after)


    def test_epub(self):
        version = self.version("bkv.v77")
        self.assertEqual(version["translator"], "Joh. Ev. Niederhuber")
        self.assertEqual(version["series"], "Bibliothek der Kirchenväter, 1. Reihe, Band 17")
        self.assertEqual(version["published"], "München 1914")
        self.assertEqual(version["availability"], "full")
        work = next(w for w in self.library["works"] if w["id"] == "bkv.cpl-123")
        self.assertEqual(work["author"], "ambrosius_von_mailand")
        self.assertEqual(work["genre"], "Kommentar")

        toc = self.load("texts/bkv.v77.toc.json")["sections"]
        self.assertEqual([s["t"] for s in toc], ["I. Kapitel. Kosmologien.", "IV. Kapitel. “Im Anfang” (Gen 1,1)"])
        self.assertEqual(toc[0]["path"], ["Der erste Tag (Gen 1,1-5)"])
        self.assertEqual(toc[0]["ref"], "S. 8–9")
        text = self.load("texts/bkv.v77.0.json")["sections"]
        # Absatznummern der Ausgabe vor den Absätzen, Seitenmarken entfernt.
        self.assertEqual(text[0]["p"], ["1. Erster Absatz.", "2. Zweiter Absatz[1] über Gott."])
        self.assertEqual(text[0]["notes"], ["Röm. 1, 20."])

        links = self.load("texts/bkv.v77.links.json")["links"]
        got = {(l["s"], l["b"], tuple(l["r"]), l["k"], l["m"]) for l in links}
        self.assertEqual(got, {
            (1, "GEN", (1, 1, 1, 5), "sectionCommentary", "editionHeading"),
            (2, "GEN", (1, 1), "sectionCommentary", "editionHeading"),
            (1, "ROM", (1, 20), "quotation", "editionCitation"),
            # Gen 1,2 liegt im ausgelegten Abschnitt Gen 1,1-5 der Überschrift darüber.
            (2, "GEN", (1, 2), "verseCommentary", "editionCitation"),
        })


def make_epub(path):
    """Kleiner EPUB-Export im Aufbau der BKV (pandoc)."""
    import zipfile
    meta = ('<p>Titel Werk: Exameron Autor: Ambrosius von Mailand Identifier: CPL 123 '
            'Tag: Bibelkommentar Time: 4. Jhd.</p><p>Titel Version: Exameron (BKV) Sprache: '
            'deutsch Bibliographie: Exameron In: Exameron. Aus dem Lateinischen übersetzt von '
            'Dr. Joh. Ev. Niederhuber. (Bibliothek der Kirchenväter, 1. Reihe, Band 17) '
            'München 1914. Unter der Mitarbeit von: Rudolf Heumann</p>')
    scan = '<a href="https://bkv.unifr.ch/works/64/versions/77/scans/b{0:04d}.jpg">S. {0}</a>'
    body = ('<section class="level1"><h1>Exameron</h1>'
            '<section class="level2"><h2>Der erste Tag (Gen 1,1-5)</h2>'
            '<section class="level3"><h3>I. Kapitel. Kosmologien.</h3>'
            '<section class="level4"><h4>1.</h4><p>' + scan.format(8) + ' Erster Absatz.</p></section>'
            '<section class="level4"><h4>2.</h4><p>[Forts. v. ' + scan.format(9) + ' ] Zweiter Absatz'
            '<a href="#fn1" class="footnote-ref">1</a> über Gott.</p></section></section>'
            '<section class="level3"><h3>IV. Kapitel. “Im Anfang” (Gen 1,1)</h3>'
            '<p>Die Erde war wüst (Gen 1,2).</p></section></section></section>'
            '<section class="footnotes"><ol><li id="fn1"><p>Röm. 1, 20.'
            '<a href="#fnref1" class="footnote-back">↩︎</a></p></li></ol></section>')
    page = '<html><body>{}</body></html>'
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("EPUB/text/ch001.xhtml", page.format(meta))
        z.writestr("EPUB/text/ch002.xhtml", page.format(body))


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
