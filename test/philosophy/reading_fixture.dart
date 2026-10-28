import 'dart:convert';

/// Kleine private Ausgabe im Format von
/// `tool/philosophy/import_heinemann_physics.py`. Der griechische Text ist
/// der freie Ross-Text (First1KGreek, CC BY-SA 4.0); Übersetzung,
/// Anmerkungen, Einleitung und Glossar sind Platzhalter für Tests, kein
/// Text einer geschützten Ausgabe.
Map<String, dynamic> privateEditionFixture() => {
  "format": "theologie.app/philosophy-edition",
  "version": 1,
  "work": "aristotle.physics",
  "edition": "heinemann-2021",
  "title": "Testausgabe",
  "preface": {
    "pages": "VII",
    "paragraphs": ["Vorwort (Platzhalter)."],
  },
  "intro": [
    {
      "id": "1",
      "title": "Erster Abschnitt",
      "page": "IX",
      "blocks": [
        {"text": "Einleitungstext über Prinzipien [1].", "page": "IX"},
      ],
      "footnotes": [
        {"n": 1, "text": "Fußnote der Einleitung (Platzhalter)."},
      ],
    },
    {
      "id": "1.1",
      "title": "Unterabschnitt",
      "page": "X",
      "blocks": [
        {"text": "Weiterer Text.", "page": "X", "n": "1.1.1"},
      ],
    },
  ],
  "introCitations": [
    {"section": "1", "book": 1, "from": "184a14", "to": "184a16", "page": "IX"},
  ],
  "glossary": [
    {
      "id": "g1",
      "term": "archê",
      "gram": "f.",
      "de": ["Prinzip", "Anfang"],
      "text": "Testeintrag zum Prinzip.",
      "tt": true,
      "intro": ["1.1"],
      "notes": ["184a10"],
    },
    {
      "id": "g2",
      "term": "physis",
      "gram": "f.",
      "de": ["Natur"],
      "text": "Testeintrag zur Natur.",
      "tt": false,
    },
  ],
  "sigla": ["E = Parisinus gr. 1853 (Platzhalter)"],
  "bibliography": ["Literatur (Platzhalter)."],
  "books": [
    {
      "n": 1,
      "title": "Buch I",
      "chapters": [
        {
          "n": 1,
          "title": "Kapitel eins",
          "from": "184a10",
          "to": "184b14",
          "units": [
            {
              "id": "184a10",
              "g": [
                {
                  "id": "184a10",
                  "r": "184a10",
                  "to": "184a16",
                  "t": "Ἐπειδὴ τὸ εἰδέναι καὶ τὸ ἐπίστασθαι συμβαίνει περὶ "
                      "πάσας τὰς μεθόδους, ὧν εἰσὶν ἀρχαὶ ἢ αἴτια ἢ στοιχεῖα.",
                },
              ],
              "d": [
                {"r": "184a10", "t": "Übersetzung A (Platzhalter)."},
                {"r": "184a12", "t": "Übersetzung B (Platzhalter)."},
              ],
              "fit": "exact",
              "pg": 2,
              "pd": 3,
            },
            {
              "id": "184a16",
              "g": [
                {
                  "id": "184a16",
                  "r": "184a16",
                  "to": "184a18",
                  "t": "πέφυκε δὲ ἐκ τῶν γνωριμωτέρων ἡμῖν ἡ ὁδός.",
                },
                {
                  "id": "184a18",
                  "r": "184a18",
                  "to": "184a21",
                  "t": "οὐ γὰρ ταὐτὰ ἡμῖν τε γνώριμα καὶ ἁπλῶς.",
                },
              ],
              "d": [
                {"r": "184a16", "t": "Übersetzung C (Platzhalter)."},
              ],
              "fit": "approx",
              "pg": 2,
              "pd": 3,
            },
          ],
        },
      ],
      "textcrit": [
        {
          "id": "tc1.1",
          "from": "184a17",
          "to": "184a17",
          "text": "Textkritischer Platzhalter, vgl. Anm. zu 184a10.",
          "page": 2,
          "fit": "exact",
        },
      ],
      "notes": [
        {
          "id": "n1.1",
          "ref": "184a10–16",
          "from": "184a10",
          "to": "184a16",
          "text": "Anmerkung zum Anfang (Platzhalter), s. Einl. 1.1.",
          "page": 400,
          "intro": ["1.1"],
          "notes": [],
        },
      ],
      "translatorNotes": [
        {
          "id": "t1.1",
          "page": 3,
          "unit": "184a16",
          "text": "Fußnote zur Übersetzung (Platzhalter), vgl. Einleitung 1.1.",
        },
      ],
    },
  ],
};

String privateEditionFixtureJson() => jsonEncode(privateEditionFixture());

