"""Fassungen (Ausgaben, Übersetzungen) der Werke und woher ihr Text kommt.

Jede Fassung gehört zu genau einem Werk (curation/works_*.json). Rechte und
Herkunft stehen an der Fassung, nicht am Werk: ein antiker Text ist
gemeinfrei, eine moderne Übersetzung oder Edition muss es nicht sein.

`read(ctx)` liefert die Einheiten (readers.py); fehlt es, ist die Fassung nur
verzeichnet (Link). Sammlungen und Commits stehen in SOURCES; `build_
apocrypha.py --src <Ordner>` erwartet die Klone unter diesen Namen.
"""

from __future__ import annotations

from readers import (bible_asset, betamasaheft, coptic_scriptorium, cts, ebible_corpus, hcf,
                     openaf, scrollmapper)

SOURCES = {
    "scrollmapper": {
        "repo": "https://github.com/scrollmapper/bible_databases",
        "commit": "59b18c5af5845728c275d5b7178ad0d024172b1f",
        "name": "scrollmapper/bible_databases (Text der SWORD-Module von CrossWire)",
    },
    "ebible": {
        "repo": "https://github.com/BibleNLP/ebible",
        "commit": "c531ff2da02843ded6d09afbe29a197ab844981f",
        "name": "eBible-Korpus (BibleNLP/ebible), Texte von eBible.org",
    },
    "openaf": {
        "repo": "https://github.com/jtauber/apostolic-fathers",
        "commit": "a07f9207902d2a7a88aa3e7c8fb3671d7ef6f0ff",
        "name": "Open Apostolic Fathers (J. Tauber, S. Macdonald 2019)",
    },
    "first1k": {
        "repo": "https://github.com/OpenGreekAndLatin/First1KGreek",
        "commit": "ed91552c52530c8f5a3ddf2dd767e899372a804c",
        "name": "First Thousand Years of Greek (Open Greek and Latin, Leipzig/Harvard)",
    },
    "hcf": {
        "repo": "https://github.com/HistoricalChristianFaith/Writings-Database",
        "commit": "61632fa9f79d9da2d36589eb022b93a1ac3c77dc",
        "name": "HistoricalChristianFaith Writings-Database (Texte der Ante-Nicene Fathers)",
    },
    "coptic": {
        "repo": "https://github.com/CopticScriptorium/corpora",
        "commit": "6fb51458e7156dd5387c2b2dca207aac1692e4d0",
        "name": "Coptic SCRIPTORIUM",
    },
    "betamasaheft": {
        "repo": "https://github.com/BetaMasaheft/Works",
        "commit": "7db87c7a901508d4a0f508bc6a28dd71c9a17a1a",
        "name": "Beta maṣāḥǝft (Universität Hamburg)",
    },
}

# Verzeichnisnamen der Klone unter --src.
DIRS = {
    "scrollmapper": "scrollmapper_bible_databases",
    "ebible": "ebible",
    "openaf": "apostolic-fathers",
    "first1k": "OpenGreekAndLatin_First1KGreek",
    "hcf": "HistoricalChristianFaith_Writings-Database",
    "coptic": "CopticScriptorium_corpora",
    "betamasaheft": "BetaMasaheft_Works",
}

CC_BY_SA = "CC BY-SA 4.0"

# ----------------------------------------------------------- Vorlagen

MENGE = {
    "language": "de", "kind": "translation",
    "label": "Menge-Bibel (1939)",
    "translator": "Hermann Menge (1841–1939)",
    "edition": "Die Heilige Schrift, übersetzt von Hermann Menge; letzte von Menge bearbeitete Textfassung 1939, mit den Apokryphen",
    "year": "1939",
    "basis": "aus dem Griechischen (Septuaginta)",
    "source": "scrollmapper",
    "sourceNote": "SWORD-Modul GerMenge 1.1 (CrossWire, 2021), Textquelle github.com/renehamburger/Menge-Bibel",
    "rights": "publicDomain", "license": "gemeinfrei",
    "rightsNote": "Hermann Menge starb 1939; die Übersetzung ist seit 1. 1. 2010 gemeinfrei (so auch die Angabe der Deutschen Bibelgesellschaft im SWORD-Modul). Spätere Bearbeitungen der Menge-Bibel sind davon nicht erfasst.",
    "transcriptionNote": "Zwischenüberschriften und Anmerkungen der Druckausgabe sind im Digitalisat nicht enthalten.",
}

LXX = {
    "language": "grc", "kind": "original",
    "label": "Septuaginta (Brenton 1851)",
    "edition": "Griechischer Text der Septuaginta nach der Ausgabe von L. C. L. Brenton (London 1851)",
    "year": "1851",
    "source": "app",
    "sourceNote": "derselbe Text wie in der Bibel der App (Übersetzung „Septuaginta (Brenton 1851)“, eBible.org); hier nur angezeigt, nicht doppelt gespeichert",
    "rights": "publicDomain", "license": "gemeinfrei",
    "rightsNote": "Ausgabe von 1851; gemeinfrei (eBible.org: Public Domain).",
    "transcriptionNote": "Nicht der kritische Text von Rahlfs oder Göttingen.",
}

VULGATA = {
    "language": "la", "kind": "ancientVersion",
    "label": "Vulgata Clementina (1598)",
    "edition": "Biblia Sacra Vulgata, Clementinische Ausgabe 1592/1598",
    "year": "1598",
    "source": "app",
    "sourceNote": "derselbe Text wie in der Bibel der App (Übersetzung „Vulgata Clementina“, eBible.org); hier nur angezeigt, nicht doppelt gespeichert",
    "rights": "publicDomain", "license": "gemeinfrei",
    "rightsNote": "Ausgabe von 1598; gemeinfrei.",
}

BRENTON_EN = {
    "language": "en", "kind": "translation",
    "label": "Brenton, englische Septuaginta (aktualisiert)",
    "translator": "Lancelot C. L. Brenton (1807–1862); sprachlich aktualisierte Fassung von eBible.org",
    "edition": "The Septuagint Version of the Old Testament, London 1844/1851; „Updated Brenton English Septuagint“ (eBible.org)",
    "year": "1851",
    "basis": "aus dem Griechischen",
    "source": "ebible",
    "rights": "publicDomain", "license": "gemeinfrei",
    "rightsNote": "Brenton starb 1862; die aktualisierte Fassung ist von eBible.org als Public Domain veröffentlicht.",
    "transcriptionNote": "Die Aktualisierung betrifft vor allem veraltete Formen (thee/thou); Versgrenzen nach der Zählung des eBible-Korpus.",
}


def menge(work, book, **kw):
    return {**MENGE, "id": f"{work}.menge1939", "work": work,
            "read": lambda c: scrollmapper(c.path("scrollmapper", "formats/json/GerMenge.json"), book, **kw)}


def lxx(work, book, **kw):
    return {**LXX, "id": f"{work}.lxx_brenton", "work": work,
            "read": lambda c: bible_asset(c.app, "grcbrent", book, **kw)}


def vulgata(work, book, **kw):
    return {**VULGATA, "id": f"{work}.vulgata", "work": work,
            "read": lambda c: bible_asset(c.app, "latVUC", book, **kw)}


def brenton_en(work, book, **kw):
    return {**BRENTON_EN, "id": f"{work}.brenton_en", "work": work,
            "read": lambda c: ebible_corpus(c.path("ebible", "corpus/eng-englxxup.txt"),
                                            c.path("ebible", "metadata/vref.txt"), book, **kw)}


def merged(*readers):
    def read(c):
        out = []
        for r in readers:
            out.extend(r(c))
        return out
    return read


OPENAF = {
    "language": "grc", "kind": "original",
    "label": "Griechisch (Lake 1912/13, Open Apostolic Fathers)",
    "editor": "Kirsopp Lake (1872–1946)",
    "edition": "The Apostolic Fathers, hg. von K. Lake, Loeb Classical Library, 2 Bde., London/New York 1912–1913; digital korrigiert von J. Tauber und S. Macdonald (Open Apostolic Fathers 1.0, 2019)",
    "year": "1912–1913",
    "source": "openaf",
    "rights": "openLicense", "license": CC_BY_SA,
    "rightsNote": "Text der Ausgabe Lake (gemeinfrei); Digitalisat Tauber/Macdonald unter CC BY-SA 4.0.",
    "attribution": "Tauber, James & Macdonald, Seumas (2019): Open Apostolic Fathers (Version 1.0), doi:10.5281/zenodo.2555673, CC BY-SA 4.0",
}

ANF = {
    "language": "en", "kind": "translation",
    "label": "Ante-Nicene Fathers (engl., 1885–1886)",
    "translator": "Übersetzer der Ante-Nicene Christian Library (Edinburgh 1867–1872)",
    "edition": "The Ante-Nicene Fathers, hg. von A. Roberts, J. Donaldson, A. C. Coxe, Buffalo 1885–1886",
    "year": "1885–1886",
    "basis": "aus dem Griechischen bzw. Lateinischen",
    "source": "hcf",
    "rights": "publicDomain", "license": "gemeinfrei",
    "rightsNote": "Erschienen 1867–1886; die Übersetzer sind seit über 70 Jahren tot (gemeinfrei). Übernommen nur Dateien der Sammlung ohne maschinelle Übertragung.",
    "transcriptionNote": "Anmerkungen der Ausgabe übernommen; Zwischenüberschriften der Ausgabe als Kapiteltitel.",
}

JAMES = {
    "language": "en", "kind": "translation",
    "label": "M. R. James (1924)",
    "translator": "Montague Rhodes James (1862–1936)",
    "edition": "The Apocryphal New Testament, Oxford: Clarendon Press 1924",
    "year": "1924",
    "basis": "aus dem Griechischen (teils in Auszügen und Zusammenfassungen)",
    "source": "first1k",
    "rights": "openLicense", "license": CC_BY_SA,
    "rightsNote": "M. R. James starb 1936 (Text gemeinfrei); Digitalisat Open Greek and Latin unter CC BY-SA 4.0.",
    "attribution": "Open Greek and Latin, First Thousand Years of Greek, CC BY-SA 4.0",
    "transcriptionNote": "James übersetzt nicht immer vollständig, sondern fasst manche Abschnitte zusammen.",
}


def f1k(path):
    return lambda c: c.path("first1k", path)


def f1k_greek(work, vid, path, *, label, editor, edition, year, **reader):
    return {
        "id": vid, "work": work, "language": "grc", "kind": "original",
        "label": label, "editor": editor, "edition": edition, "year": year,
        "source": "first1k",
        "rights": "openLicense", "license": CC_BY_SA,
        "rightsNote": "Text der Ausgabe gemeinfrei; Digitalisat (Open Greek and Latin / Perseus, Harvard College Library) unter CC BY-SA 4.0.",
        "attribution": "Open Greek and Latin, First Thousand Years of Greek, CC BY-SA 4.0",
        "transcriptionNote": "Textkritischer Apparat und Seitenangaben der Ausgabe entfallen.",
        "read": lambda c: cts(f1k(path)(c), **reader),
    }


def hermas_units(n):
    if n <= 5:
        return f"vis{n}", f"Vision {n}", ["Visionen"]
    if n <= 17:
        return f"mand{n - 5}", f"Gebot {n - 5}", ["Gebote"]
    return f"sim{n - 17}", f"Gleichnis {n - 17}", ["Gleichnisse"]


HCF = "hcf"


def hcf_files(c, *names):
    return [c.path(HCF, n) for n in names]


def hermas_anf(c):
    files, ids, labels = [], [], []
    for k, (folder, word, de, count) in enumerate([
        ("First Book - Visions", "Vision", "Vision", 5),
        ("Second Book - Commandments", "Commandment", "Gebot", 12),
        ("Third Book - Similitudes", "Similitude", "Gleichnis", 10),
    ]):
        for i in range(1, count + 1):
            files.append(c.path(HCF, f"Shepherd of Hermas/Translation-ANF/{folder}/{word} {i}.html"))
            ids.append(f"{['vis', 'mand', 'sim'][k]}{i}")
            labels.append(f"{de} {i}")
    units = hcf(files, mode="file", ids=ids, labels=labels)
    for u in units:
        u["path"] = [{"vis": "Visionen", "man": "Gebote", "sim": "Gleichnisse"}[u["id"][:3]]]
    return units


TESTAMENTS = ["Reuben", "Simeon", "Levi", "Judah", "Issachar", "Zebulun", "Dan", "Naphtali",
              "Gad", "Asher", "Joseph", "Benjamin"]
TESTAMENTS_DE = ["Ruben", "Simeon", "Levi", "Juda", "Issachar", "Sebulon", "Dan", "Naftali",
                 "Gad", "Ascher", "Josef", "Benjamin"]


def testaments_anf(c):
    files = hcf_files(c, *[f"Testaments of the Twelve Patriarchs/The Testament of {n}.html"
                           for n in TESTAMENTS])
    return hcf(files, mode="file", ids=[n.lower() for n in TESTAMENTS_DE],
               labels=[f"Testament {n}s" if not n.endswith("s") else f"Testament {n}'" for n in TESTAMENTS_DE])


def clementine(c, folder, count, word, de):
    files = [c.path(HCF, f"Clement of Rome/Pseudo-Clement/{folder}/{word} {i}.html")
             for i in range(1, count + 1)]
    return hcf(files, mode="file", ids=[str(i) for i in range(1, count + 1)],
               labels=[f"{de} {i}" for i in range(1, count + 1)])


def constitutions(c):
    files = [c.path(HCF, f"Apostolic Constitutions/Constitutions of the Holy Apostles Book {i}.html")
             for i in range(1, 9)]
    files.append(c.path(HCF, "Apostolic Constitutions/The Ecclesiastical Canons of the Same Holy Apostles.html"))
    return hcf(files, mode="file", ids=[str(i) for i in range(1, 9)] + ["kanones"],
               labels=[f"Buch {i}" for i in range(1, 9)] + ["Apostolische Kanones"])


IGNATIUS_LETTERS = [
    ("003-ignatius-ephesians", "eph", "An die Epheser"),
    ("004-ignatius-magnesians", "magn", "An die Magnesier"),
    ("005-ignatius-trallians", "trall", "An die Trallianer"),
    ("006-ignatius-romans", "rom", "An die Römer"),
    ("007-ignatius-philadelphians", "phld", "An die Philadelphier"),
    ("008-ignatius-smyrnaeans", "smyrn", "An die Smyrnäer"),
    ("009-ignatius-polycarp", "pol", "An Polykarp"),
]


def ignatius_greek(c):
    out = []
    for name, uid, label in IGNATIUS_LETTERS:
        units = openaf(c.path("openaf", f"texts/{name}.txt"))
        blocks = []
        for u in units:
            for num, text in u["blocks"]:
                blocks.append([f"{u['id']},{num}" if u["id"] != "0" else f"Zuschrift {num}", text])
        out.append({"id": uid, "label": label, "path": [], "title": None, "blocks": blocks, "notes": []})
    return out


def acta_greek(work, vid, path, label, edition):
    return f1k_greek(work, vid, path, label=label, editor="Maximilian Bonnet (1841–1917)",
                     edition=edition, year="1898–1903")


def versions():
    v = []
    # ------------------------------------------------ A. Deuterokanonen
    simple = [
        ("tobit", "Tobit", "TOB", "TOB"), ("judit", "Judith", "JDT", "JDT"),
        ("weisheit", "Wisdom", "WIS", "WIS"), ("sirach", "Sirach", "SIR", "SIR"),
        ("makk1", "I Maccabees", "1MA", "1MA"), ("makk2", "II Maccabees", "2MA", "2MA"),
    ]
    for work, mbook, gbook, ebook in simple:
        v.append(menge(work, mbook))
        v.append(lxx(work, gbook))
        v.append(vulgata(work, gbook))
        v.append(brenton_en(work, ebook))

    v.append(menge("baruch", "Baruch", chapters=[1, 2, 3, 4, 5]))
    v.append(lxx("baruch", "BAR"))
    v.append(vulgata("baruch", "BAR", chapters=[1, 2, 3, 4, 5]))
    v.append(brenton_en("baruch", "BAR"))

    v.append({**menge("brief_jeremia", "Baruch", chapters=[6], ids={6: "1", ("label", 6): "Brief des Jeremia (Baruch 6)"}),
              "coverageNote": "bei Menge als Baruch 6"})
    v.append(lxx("brief_jeremia", "LJE", label="Brief des Jeremia"))
    v.append({**vulgata("brief_jeremia", "BAR", chapters=[6], uid="1", label="Brief des Jeremia (Baruch 6)"),
              "coverageNote": "in der Vulgata als Baruch 6"})
    v.append(brenton_en("brief_jeremia", "LJE"))

    v.append({**menge("ester_zusaetze", "Additions to Esther",
                      ids={**{n: f"st{n}" for n in range(1, 8)}, **{("label", n): f"Stück {n}" for n in range(1, 8)}}),
              "coverageNote": "Luthers Anordnung als „Stücke zu Esther“ (7 Kapitel)"})
    v.append({**lxx("ester_zusaetze", "ESG"), "coverageNote": "vollständiges griechisches Esterbuch mit den eingefügten Zusätzen"})
    v.append({**vulgata("ester_zusaetze", "EST", chapters=[10, 11, 12, 13, 14, 15, 16]),
              "coverageNote": "Vulgata-Anhang Est 10,4–16,24 (Kap. 10 enthält auch die letzten kanonischen Verse 10,1–3)"})
    v.append({**brenton_en("ester_zusaetze", "ESG"), "coverageNote": "vollständiges griechisches Esterbuch in englischer Übersetzung"})

    v.append(menge("daniel_zusaetze", "Additions to Daniel",
                   ids={1: "susanna", 2: "bel", 3: "asarja", ("label", 1): "Susanna",
                        ("label", 2): "Bel und der Drache", ("label", 3): "Gebet Asarjas und Gesang der drei Männer"}))
    v.append({**LXX, "id": "daniel_zusaetze.lxx_brenton", "work": "daniel_zusaetze",
              "read": merged(lambda c: bible_asset(c.app, "grcbrent", "DAG", chapters=[3], verses=(24, 90),
                                                   uid="asarja", label="Gebet Asarjas und Gesang der drei Männer"),
                             lambda c: bible_asset(c.app, "grcbrent", "SUS", uid="susanna", label="Susanna"),
                             lambda c: bible_asset(c.app, "grcbrent", "BEL", uid="bel", label="Bel und der Drache")),
              "coverageNote": "Theodotion-Fassung nach Brenton (Dan 3,24–90; Susanna; Bel)"})
    v.append({**VULGATA, "id": "daniel_zusaetze.vulgata", "work": "daniel_zusaetze",
              "read": merged(lambda c: bible_asset(c.app, "latVUC", "DAN", chapters=[3], verses=(24, 90),
                                                   uid="asarja", label="Gebet Asarjas und Gesang der drei Männer (Dan 3,24–90)"),
                             lambda c: bible_asset(c.app, "latVUC", "DAN", chapters=[13], uid="susanna", label="Susanna (Dan 13)"),
                             lambda c: bible_asset(c.app, "latVUC", "DAN", chapters=[14], uid="bel", label="Bel und der Drache (Dan 14)")),
              "coverageNote": "in der Vulgata als Dan 3,24–90; 13; 14"})
    v.append({**BRENTON_EN, "id": "daniel_zusaetze.brenton_en", "work": "daniel_zusaetze",
              "read": merged(lambda c: [dict(u, id="susanna", label="Susanna") for u in ebible_corpus(
                  c.path("ebible", "corpus/eng-englxxup.txt"), c.path("ebible", "metadata/vref.txt"), "SUS")],
                  lambda c: [dict(u, id="bel", label="Bel und der Drache") for u in ebible_corpus(
                      c.path("ebible", "corpus/eng-englxxup.txt"), c.path("ebible", "metadata/vref.txt"), "BEL")]),
              "coverage": "partial",
              "coverageNote": "nur Susanna und Bel; das Gebet Asarjas fehlt im verwendeten Korpus"})

    v.append(lxx("makk3", "3MA"))
    v.append(brenton_en("makk3", "3MA"))
    v.append(lxx("makk4", "4MA"))
    v.append(brenton_en("makk4", "4MA"))
    v.append(lxx("esra3", "1ES"))
    v.append(brenton_en("esra3", "1ES"))
    v.append({
        "id": "esra4.kjv", "work": "esra4", "language": "en", "kind": "translation",
        "label": "King James Version (1611/1769)",
        "translator": "Übersetzer der King James Version (1611), Text nach der Revision von 1769",
        "edition": "The Holy Bible (Authorized Version), Apokryphen: 2 Esdras",
        "year": "1611/1769",
        "basis": "aus dem Lateinischen",
        "source": "scrollmapper",
        "sourceNote": "SWORD-Modul KJVA (CrossWire)",
        "rights": "publicDomain", "license": "gemeinfrei",
        "rightsNote": "Außerhalb des Vereinigten Königreichs gemeinfrei (dort Krone-Privileg).",
        "coverage": "partial",
        "coverageNote": "ohne den erst 1875 veröffentlichten Abschnitt 7,36–105",
        "read": lambda c: scrollmapper(c.path("scrollmapper", "formats/json/KJVA.json"), "II Esdras"),
    })
    v.append(menge("gebet_manasse", "Prayer of Manasses", ids={1: "1", ("label", 1): "Gebet Manasses"}))
    v.append(lxx("gebet_manasse", "MAN", label="Gebet Manasses"))
    v.append(brenton_en("gebet_manasse", "MAN"))
    v.append({**lxx("psalm151", "PSA", chapters=[151], uid="151", label="Psalm 151")})
    v.append({**f1k_greek("psalmen_salomos", "psalmen_salomos.swete", "data/tlg0527/tlg035/tlg0527.tlg035.1st1K-grc1.xml",
                          label="Griechisch (Swete 1905)", editor="Henry Barclay Swete (1835–1917)",
                          edition="The Old Testament in Greek according to the Septuagint, Bd. 3, Cambridge 1905",
                          year="1905"),
              "transcriptionNote": "Texterkennung der Digitalausgabe; vereinzelt stehen lateinische statt griechischer Großbuchstaben (z. B. am Psalmanfang).",
              "read": lambda c: cts(c.path("first1k", "data/tlg0527/tlg035/tlg0527.tlg035.1st1K-grc1.xml"), label="Psalm")})

    # ------------------------------------------------ B. Evangelien
    v.append({
        "id": "thomasevangelium.koptisch", "work": "thomasevangelium", "language": "cop", "kind": "ancientVersion",
        "label": "Koptisch (NHC II,2; Coptic SCRIPTORIUM)",
        "editor": "Paul Dilley, Lydia Bremer-McCollum, Caroline T. Schroeder, Amir Zeldes (Annotation)",
        "edition": "Coptic SCRIPTORIUM, Gospel of Thomas (Nag-Hammadi-Codex II, S. 32–51), Fassung 6.2.0 (2025)",
        "year": "2025",
        "basis": "Nag-Hammadi-Codex II (Koptisches Museum Kairo), sahidisch mit lykopolitanischen Zügen",
        "source": "coptic",
        "rights": "openLicense", "license": "CC BY 4.0",
        "rightsNote": "Coptic SCRIPTORIUM, Lizenz CC BY 4.0.",
        "attribution": "Coptic SCRIPTORIUM (Dilley, Bremer-McCollum, Schroeder, Zeldes), CC BY 4.0",
        "transcriptionNote": "Wortgrenzen nach den gebundenen Gruppen der Ausgabe; Lücken und Ergänzungen sind in der Datei nicht eigens gekennzeichnet.",
        "read": lambda c: coptic_scriptorium(c.path("coptic", "thomas-gospel/thomas.gospel_TEI/thomas_gospel.xml")),
    })
    v.append({**ANF, "id": "protevangelium.anf", "work": "protevangelium",
              "edition": "Ante-Nicene Fathers, Bd. 8, Buffalo 1886 (zuerst Ante-Nicene Christian Library 16, 1870)",
              "year": "1870/1886",
              "read": lambda c: hcf(hcf_files(c, "Protoevangelium of James/The Protevangelium of James.html"), mode="numbered")})

    # ------------------------------------------------ C. Apostolische Väter
    for work, name in [("didache", "011-didache"), ("clemens1", "001-i_clement"), ("clemens2", "002-ii_clement"),
                       ("polykarp_phil", "010-polycarp-philippians"), ("martyrium_polykarp", "014-martyrdom"),
                       ("barnabas", "012-barnabas"), ("diognet", "015-diognetus")]:
        extra = {}
        if work == "didache":
            extra = {"zero_label": "Titel"}
        ver = {**OPENAF, "id": f"{work}.lake", "work": work,
               "read": (lambda name, extra: lambda c: openaf(c.path("openaf", f"texts/{name}.txt"), **extra))(name, extra)}
        if work == "polykarp_phil":
            ver["coverageNote"] = "Kap. 10–12 und 14 lateinisch (griechisch nicht erhalten), Kap. 13 griechisch aus Eusebius"
        v.append(ver)
    v.append({**OPENAF, "id": "ignatius.lake", "work": "ignatius", "read": ignatius_greek,
              "coverageNote": "mittlere Rezension, sieben Briefe; Abschnittsnummern „Kapitel,Vers“"})
    v.append({**OPENAF, "id": "hermas.lake", "work": "hermas",
              "read": lambda c: openaf(c.path("openaf", "texts/013-shepherd.txt"), mapping=hermas_units),
              "coverageNote": "griechisch bis Gleichnis 9,30,3; danach druckt Lake den lateinischen Text"})

    v.append({**ANF, "id": "didache.anf", "work": "didache", "edition": "Ante-Nicene Fathers, Bd. 7, Buffalo 1886", "year": "1886",
              "read": lambda c: hcf(hcf_files(c, "Didache/Didache.html"))})
    v.append({**ANF, "id": "clemens1.anf", "work": "clemens1", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "read": lambda c: hcf(hcf_files(c, "Clement of Rome/First Epistle to the Corinthians.html"),
                                    skip_heads=[r"Historical Introductions"])})
    v.append({**ANF, "id": "polykarp_phil.anf", "work": "polykarp_phil", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "read": lambda c: hcf(hcf_files(c, "Polycarp of Smyrna/Epistle to the Philippians.html"))})
    v.append({**ANF, "id": "martyrium_polykarp.anf", "work": "martyrium_polykarp", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "read": lambda c: hcf(hcf_files(c, "Polycarp of Smyrna/Martyrdom of Polycarp.html"))})
    v.append({**ANF, "id": "barnabas.anf", "work": "barnabas", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "read": lambda c: hcf(hcf_files(c, "Epistle of Barnabas/The Epistle of Barnabas.html"))})
    v.append({**ANF, "id": "diognet.anf", "work": "diognet", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "read": lambda c: hcf(hcf_files(c, "Epistle to Diognetus/The Epistle to Diognetus.html"))})
    v.append({**ANF, "id": "hermas.anf", "work": "hermas", "edition": "Ante-Nicene Fathers, Bd. 2, Buffalo 1885", "year": "1867/1885",
              "read": hermas_anf})
    v.append({**ANF, "id": "papias.anf", "work": "papias", "edition": "Ante-Nicene Fathers, Bd. 1, Buffalo 1885", "year": "1867/1885",
              "coverage": "fragments",
              "read": lambda c: hcf(hcf_files(c, "Papias of Hierapolis/Fragments of Papias - ANF.html"), mode="roman", label="Fragment")})
    v.append({**ANF, "id": "apostolische_konstitutionen.anf", "work": "apostolische_konstitutionen",
              "edition": "Ante-Nicene Fathers, Bd. 7, Buffalo 1886", "year": "1886", "read": constitutions})

    # Deutsche BKV-Fassungen (Zeller 1918): mit Erlaubnis nutzbar, Text liegt
    # nicht vor (EPUB-Export nur von Hand) – nur Verweis.
    for work in ["didache", "clemens1", "clemens2", "ignatius", "polykarp_phil", "martyrium_polykarp",
                 "barnabas", "hermas", "diognet", "papias"]:
        v.append({
            "id": f"{work}.bkv_zeller", "work": work, "language": "de", "kind": "translation",
            "label": "Bibliothek der Kirchenväter (Zeller 1918)",
            "translator": "Franz Zeller",
            "edition": "Die Apostolischen Väter, übersetzt von Franz Zeller, Bibliothek der Kirchenväter, 1. Reihe, Bd. 35, Kempten/München 1918",
            "year": "1918",
            "rights": "permission", "license": "Nutzungserlaubnis (BKV)",
            "rightsNote": "Für BKV-Texte liegt eine Nutzungserlaubnis vor (Conner, 24.10.2026). Der Text ist noch nicht importiert, weil die BKV den automatischen Abruf sperrt; er kann als EPUB nachgereicht werden.",
            "coverage": "external",
            "url": "https://bkv.unifr.ch/de/works",
        })

    # ------------------------------------------------ D. Apokalypsen
    v.append({
        "id": "henoch1.flemming_de", "work": "henoch1", "language": "de", "kind": "translation",
        "label": "Deutsch (Flemming 1901)",
        "translator": "Johannes Flemming (1859–1914)",
        "edition": "Das Buch Henoch, hg. von J. Flemming und L. Radermacher, GCS 5, Leipzig: Hinrichs 1901",
        "year": "1901",
        "basis": "aus dem Äthiopischen",
        "source": "first1k",
        "rights": "openLicense", "license": CC_BY_SA,
        "rightsNote": "Flemming starb 1914 (Text gemeinfrei); Digitalisat Open Greek and Latin unter CC BY-SA 4.0.",
        "attribution": "Open Greek and Latin, First Thousand Years of Greek, CC BY-SA 4.0",
        "coverage": "partial",
        "coverageNote": "Kap. 33–108; für Kap. 1–32 enthält die Digitalausgabe nur den griechischen Text (eigene Fassung)",
        "transcriptionNote": "Rechtschreibung von 1901 („Thore“); textkritische Fußnoten entfallen.",
        "read": lambda c: cts(c.path("first1k", "data/tlg1463/tlg001/tlg1463.tlg001.opp-ger1.xml")),
    })
    v.append({**f1k_greek("henoch1", "henoch1.radermacher_grc", "data/tlg1463/tlg001/tlg1463.tlg001.1st1K-grc2.xml",
                          label="Griechische Fragmente (Radermacher 1901)", editor="Ludwig Radermacher (1867–1952)",
                          edition="Das Buch Henoch, hg. von J. Flemming und L. Radermacher, GCS 5, Leipzig 1901", year="1901"),
              "kind": "ancientVersion", "coverage": "fragments",
              "coverageNote": "griechischer Text Kap. 1–32 (Codex Panopolitanus)"})
    v.append({
        "id": "henoch1.geez", "work": "henoch1", "language": "gez", "kind": "ancientVersion",
        "label": "Äthiopisch (Ge'ez, gedruckte Bibel der EOTC)",
        "edition": "Text der gedruckten Bibel der Äthiopisch-Orthodoxen Täwahədo-Kirche, digitalisiert von Beta maṣāḥǝft (LIT1340EnochE, Edition „EOTCed“)",
        "editor": "Digitalisierung: Michal Jerabek (Beta maṣāḥǝft)",
        "source": "betamasaheft",
        "rights": "openLicense", "license": CC_BY_SA,
        "rightsNote": "Antiker Text; Digitalisat von Beta maṣāḥǝft (Universität Hamburg) unter CC BY-SA 4.0.",
        "attribution": "Beta maṣāḥǝft: Manuscripts of Ethiopia and Eritrea (Universität Hamburg), CC BY-SA 4.0",
        "read": lambda c: betamasaheft(c.path("betamasaheft", "1001-2000/LIT1340EnochE.xml"), "EOTCed"),
    })
    v.append({
        "id": "jubilaeen.geez", "work": "jubilaeen", "language": "gez", "kind": "ancientVersion",
        "label": "Äthiopisch (Ge'ez, gedruckte Bibel der EOTC)",
        "edition": "Text der gedruckten Bibel der Äthiopisch-Orthodoxen Täwahədo-Kirche, digitalisiert von Beta maṣāḥǝft (LIT1697Jubilees, Edition „EOTCed“)",
        "source": "betamasaheft",
        "rights": "openLicense", "license": CC_BY_SA,
        "rightsNote": "Antiker Text; Digitalisat von Beta maṣāḥǝft (Universität Hamburg) unter CC BY-SA 4.0.",
        "attribution": "Beta maṣāḥǝft: Manuscripts of Ethiopia and Eritrea (Universität Hamburg), CC BY-SA 4.0",
        "read": lambda c: betamasaheft(c.path("betamasaheft", "1001-2000/LIT1697Jubilees.xml"), "EOTCed"),
    })
    v.append({
        "id": "himmelfahrt_jesaja.geez", "work": "himmelfahrt_jesaja", "language": "gez", "kind": "ancientVersion",
        "label": "Äthiopisch (Ge'ez, Charles 1900)",
        "editor": "Robert Henry Charles (1855–1931)",
        "edition": "The Ascension of Isaiah, hg. von R. H. Charles, London 1900; digitalisiert von Beta maṣāḥǝft (LIT1671Isaiah)",
        "year": "1900",
        "source": "betamasaheft",
        "rights": "openLicense", "license": CC_BY_SA,
        "rightsNote": "Ausgabe von 1900 (gemeinfrei); Digitalisat von Beta maṣāḥǝft unter CC BY-SA 4.0.",
        "attribution": "Beta maṣāḥǝft: Manuscripts of Ethiopia and Eritrea (Universität Hamburg), CC BY-SA 4.0",
        "read": lambda c: betamasaheft(c.path("betamasaheft", "1001-2000/LIT1671Isaiah.xml"), "*"),
        "coverage": "partial",
        "coverageNote": "Das Digitalisat enthält nur Kap. 1–5 (Martyrium Jesajas); Kap. 6–11 (Vision) fehlen.",
    })
    v.append({**f1k_greek("sibyllinen", "sibyllinen.geffcken", "data/tlg1551/tlg001/tlg1551.tlg001.1st1K-grc1.xml",
                          label="Griechisch (Geffcken 1902)", editor="Johannes Geffcken (1861–1935)",
                          edition="Die Oracula Sibyllina, GCS 8, Leipzig 1902", year="1902"),
              "read": lambda c: cts(c.path("first1k", "data/tlg1551/tlg001/tlg1551.tlg001.1st1K-grc1.xml"), label="Buch")})

    # ------------------------------------------------ E. Weitere
    v.append({**ANF, "id": "testamente_xii.anf", "work": "testamente_xii",
              "translator": "Robert Sinker (1838–1913)",
              "edition": "Ante-Nicene Fathers, Bd. 8, Buffalo 1886 (zuerst Ante-Nicene Christian Library 22, 1871)",
              "year": "1871/1886", "read": testaments_anf})
    v.append({**f1k_greek("vitae_prophetarum", "vitae_prophetarum.anonyma", "data/tlg1750/tlg002/tlg1750.tlg002.1st1K-grc1.xml",
                          label="Griechisch, anonyme Rezension (Schermann 1907)", editor="Theodor Schermann (1878–1922)",
                          edition="Prophetarum vitae fabulosae, Leipzig: Teubner 1907", year="1907"),
              "read": lambda c: cts(c.path("first1k", "data/tlg1750/tlg002/tlg1750.tlg002.1st1K-grc1.xml"), label="Abschnitt")})
    v.append({**f1k_greek("vitae_prophetarum", "vitae_prophetarum.dorotheus", "data/tlg1750/tlg001/tlg1750.tlg001.1st1K-grc1.xml",
                          label="Griechisch, Rezension des Dorotheus (Schermann 1907)", editor="Theodor Schermann (1878–1922)",
                          edition="Prophetarum vitae fabulosae, Leipzig: Teubner 1907", year="1907"),
              "read": lambda c: cts(c.path("first1k", "data/tlg1750/tlg001/tlg1750.tlg001.1st1K-grc1.xml"), label="Abschnitt")})

    v.append(acta_greek("johannesakten", "johannesakten.bonnet", "data/tlg0317/tlg001/tlg0317.tlg001.1st1K-grc1.xml",
                        "Griechisch (Bonnet 1898)", "Acta Apostolorum Apocrypha II,1, hg. von M. Bonnet, Leipzig 1898"))
    v.append({**JAMES, "id": "johannesakten.james", "work": "johannesakten",
              "read": lambda c: cts(c.path("first1k", "data/tlg0317/tlg001/tlg0317.tlg001.1st1K-eng1.xml"))})
    v.append(acta_greek("thomasakten", "thomasakten.bonnet", "data/tlg2038/tlg001/tlg2038.tlg001.1st1K-grc1.xml",
                        "Griechisch (Bonnet 1903)", "Acta Apostolorum Apocrypha II,2, hg. von M. Bonnet, Leipzig 1903"))
    v.append({**JAMES, "id": "thomasakten.james", "work": "thomasakten",
              "read": lambda c: cts(c.path("first1k", "data/tlg2038/tlg001/tlg2038.tlg001.1st1K-eng1.xml"), label="Abschnitt")})
    v.append(acta_greek("philippusakten", "philippusakten.bonnet", "data/tlg2948/tlg001/tlg2948.tlg001.1st1K-grc1.xml",
                        "Griechisch (Bonnet 1903)", "Acta Apostolorum Apocrypha II,2, hg. von M. Bonnet, Leipzig 1903"))
    v.append({**JAMES, "id": "philippusakten.james", "work": "philippusakten",
              "read": lambda c: cts(c.path("first1k", "data/tlg2948/tlg001/tlg2948.tlg001.1st1K-eng1.xml"))})
    v.append(acta_greek("barnabasakten", "barnabasakten.bonnet", "data/tlg2949/tlg001/tlg2949.tlg001.1st1K-grc1.xml",
                        "Griechisch (Bonnet 1903)", "Acta Apostolorum Apocrypha II,2, hg. von M. Bonnet, Leipzig 1903"))
    v.append({**ANF, "id": "petrus_paulus_akten.anf", "work": "petrus_paulus_akten",
              "edition": "Ante-Nicene Fathers, Bd. 8, Buffalo 1886", "year": "1886",
              "transcriptionNote": "Die Ausgabe hat keine Kapitelzählung; die App teilt den Text in Teile zu je zwölf Absätzen.",
              "read": lambda c: hcf(hcf_files(c, "Acts of Peter and Paul/Acts of Peter and Paul.html"), mode="groups", group=12, label="Teil")})
    v.append({**f1k_greek("pseudoklementinen_homilien", "pseudoklementinen_homilien.schwegler",
                          "data/tlg1271/tlg006/tlg1271.tlg006.1st1K-grc1.xml",
                          label="Griechisch (Schwegler 1847)", editor="Albert Schwegler (1819–1857)",
                          edition="Clementis Romani quae feruntur homiliae, Stuttgart 1847", year="1847"),
              "coverage": "partial", "coverageNote": "Homilien 1–19; die 20. Homilie fehlt in dieser Ausgabe",
              "read": lambda c: cts(c.path("first1k", "data/tlg1271/tlg006/tlg1271.tlg006.1st1K-grc1.xml"), label="Homilie")})
    v.append({**ANF, "id": "pseudoklementinen_homilien.anf", "work": "pseudoklementinen_homilien",
              "edition": "Ante-Nicene Fathers, Bd. 8, Buffalo 1886", "year": "1870/1886",
              "read": lambda c: clementine(c, "Clementine Homilies", 20, "Homily", "Homilie")})
    v.append({**ANF, "id": "pseudoklementinen_rekognitionen.anf", "work": "pseudoklementinen_rekognitionen",
              "edition": "Ante-Nicene Fathers, Bd. 8, Buffalo 1886", "year": "1867/1886",
              "basis": "aus dem Lateinischen (Rufinus)",
              "read": lambda c: clementine(c, "Clementine Recognitions", 10, "Book", "Buch")})
    for rec, letter, n in (("A", "a", "001"), ("B", "b", "002")):
        path = f"data/tlg1701/tlg{n}/tlg1701.tlg{n}.1st1K-grc1.xml"
        v.append({**f1k_greek("testament_abraham", f"testament_abraham.james_{letter}", path,
                              label=f"Griechisch, Rezension {rec} (James 1892)",
                              editor="Montague Rhodes James (1862–1936)",
                              edition="The Testament of Abraham, hg. von M. R. James, Texts and Studies II,2, Cambridge 1892",
                              year="1892"),
                  "transcriptionNote": "Textkritischer Apparat und Seitenangaben der Ausgabe entfallen. Die Kapitel der "
                                       "langen (A) und kurzen (B) Rezension entsprechen einander nicht; der Vergleich "
                                       "stellt nur gleich nummerierte Kapitel nebeneinander.",
                  "read": (lambda p: lambda c: cts(c.path("first1k", p)))(path)})

    # ------------------------------------------------ Verweise ohne Text
    # Werke ohne freien Text: Eintrag mit Link auf eine Übersichtsseite, die
    # Ausgaben, Übersetzungen und Literatur nennt (Links per Suche geprüft).
    ECW = "https://www.earlychristianwritings.com/"
    EJW = "https://www.earlyjewishwritings.com/"
    refs = {
        "petrusevangelium": ECW + "gospelpeter.html",
        "judasevangelium": ECW + "gospeljudas.html",
        "philippusevangelium": ECW + "gospelphilip.html",
        "mariaevangelium": ECW + "gospelmary.html",
        "kindheitsevangelium_thomas": ECW + "infancythomas.html",
        "nikodemusevangelium": ECW + "actspilate.html",
        "hebraeerevangelium": ECW + "gospelhebrews.html",
        "muratorisches_fragment": ECW + "text/muratorian-latin.html",
        "laodizenerbrief": ECW + "apocrypha.html",
        "epistula_apostolorum": ECW + "text/apostolorum.html",
        "petrusapokalypse": ECW + "info/apocalypsepeter.html",
        "paulusapokalypse": ECW + "apocrypha.html",
        "paulus_thekla": ECW + "actspaul.html",
        "petrusakten": ECW + "actspeter.html",
        "apokryphon_johannes": ECW + "apocryphonjohn.html",
        "evangelium_wahrheit": ECW + "gospeltruth.html",
        "oden_salomos": ECW + "odes.html",
        "pistis_sophia": "https://github.com/CopticScriptorium/corpora",
        "henoch2": EJW + "2enoch.html",
        "henoch3": EJW + "3enoch.html",
        "baruch2": EJW + "2baruch.html",
        "baruch3": EJW + "3baruch.html",
        "apokalypse_abraham": EJW + "apocabraham.html",
        "joseph_aseneth": EJW + "aseneth.html",
        "leben_adam_eva": EJW + "lifeadameve.html",
        "aristeasbrief": EJW + "letteraristeas.html",
    }
    for work, url in refs.items():
        if url.startswith(ECW):
            site = "Early Christian Writings (P. Kirby)"
        elif url.startswith(EJW):
            site = "Early Jewish Writings (P. Kirby)"
        else:
            site = "Coptic SCRIPTORIUM (koptischer Text, CC BY 4.0)"
        v.append({
            "id": f"{work}.verweis", "work": work, "language": "en", "kind": "translation",
            "label": f"Verweis: {site}",
            "edition": f"{site}: Übersicht mit Übersetzungen, Ausgaben und Literatur",
            "rights": "unclear", "license": "nicht in der App",
            "rightsNote": "Nur Link. Die dort verlinkten Übersetzungen haben unterschiedliche Rechte und sind nicht übernommen.",
            "coverage": "external",
            "url": url,
        })

    return v
