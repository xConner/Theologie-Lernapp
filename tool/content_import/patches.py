# -*- coding: utf-8 -*-
"""Einzelkorrekturen offenkundiger Fehler der Quellen (vor der Klammerbereinigung).

Schlüssel: "<konfession>/<abschnitt>/<sprache>" -> [(alt, neu), …]. Jede
Ersetzung muss genau einmal greifen, sonst bricht der Import ab – so fällt
auf, wenn sich eine Quelle ändert.
"""

PATCHES = {
    # verirrte Klammer mitten im Satz
    'konkordienbuch_vorrede/full/la': [('pugnantes cum]iis', 'pugnantes cum iis')],
    # Klammer nicht geschlossen: "[vertrauend hingeben]" erläutert "erwägen"
    'schmalkaldische_artikel/teil_2_art_4/de': [('[vertraünd hingeben der', '[vertraünd hingeben] der')],
    # schließende Klammer ohne öffnende
    'konkordienformel_solida_declaratio/art_2/la': [('corde suo sentiat.]Et per', 'corde suo sentiat. Et per')],
    # überzählige öffnende Klammern
    'traktat/papst/en': [('ordination and [confirmation, who', 'ordination and confirmation, who')],
    'grosser_katechismus/gebot_7/de': [('vorzuhalten [[vorzünthalten]),', 'vorzuhalten [vorzünthalten]),')],
    'apologie/art_24/en': [('a little afterward: [((greek)),', 'a little afterward: ((greek)),')],
    # versehentlich verdoppelte Wortfolge der elektronischen Ausgabe
    'grosser_katechismus/gebot_9_10/de': [
        ('Gescheidigkeit [solches nicht Schalkheit, sondern Gescheidigkeit [Gescheitheit]',
         'Gescheidigkeit [Gescheitheit]')],
    # Griechisch in einer Symbolschrift-Umschrift
    'konkordienformel_solida_declaratio/art_8/en': [
        ('koinwniva and e{nwsi",', 'κοινωνία and ἕνωσις,'),
        ('duvo fuvsei" ajkoinwnhvtou" prov" eJauta;" pantavpasin,',
         'δύο φύσεις ἀκοινωνήτους πρὸς ἑαυτὰς παντάπασιν,')],
    # "(local) [or circumscribed]"
    'konkordienformel_epitome/art_7/en': [('localis (local) for circumscribed]', 'localis (local) [or circumscribed]')],
    # Die beiden Abschnitte stehen in der Triglotta als spätere Zusätze in
    # eckigen Klammern; auf bookofconcord.org fehlt die öffnende Klammer.
    'kleiner_katechismus/haustafel/en': [
        ('What the Hearers Owe to Their Pastors.', '[What the Hearers Owe to Their Pastors.'),
        ('What Subjects Owe to the Magistrates.', '[What Subjects Owe to the Magistrates.'),
    ],
}

# Absätze, die ganz entfallen (in der elektronischen Ausgabe unlesbar kodiert).
DROP = {
    'apologie/art_28/en': ['THE END.'],
    # griechisches Distichon am Ende der Haustafel (nur im lateinischen Text)
    'kleiner_katechismus/haustafel/la': ['Πα̃ς'],
}


# Titelzeilen am Abschnittsanfang, die zum (ohnehin angezeigten) Titel gehören:
# Zahl der führenden Überschriftblöcke, die entfallen.
LEADING = {
    'konkordienbuch_vorrede/full/de': 2,      # "zu dem / Christlichen Konkordienbuch"
    'konkordienbuch_vorrede/full/la': 3,
    'traktat/papst/de': 2,                    # "durch die Gelehrten …" / Jahr
    'traktat/papst/la': 2,
    'schmalkaldische_artikel/vorrede/en': 1,  # "Preface"
    'konkordienformel_epitome/art_10/de': 1, 'konkordienformel_epitome/art_10/la': 1,
    'konkordienformel_epitome/art_10/en': 1,
    'konkordienformel_epitome/art_12/de': 1, 'konkordienformel_epitome/art_12/la': 1,
    'konkordienformel_solida_declaratio/regel_und_richtschnur/la': 3,
    'konkordienformel_solida_declaratio/art_10/de': 1, 'konkordienformel_solida_declaratio/art_10/la': 1,
    'konkordienformel_solida_declaratio/art_12/de': 1, 'konkordienformel_solida_declaratio/art_12/la': 1,
    'konkordienformel_solida_declaratio/art_12/en': 1,
}


def apply_patches(blocks, lang, tag):
    todo = list(PATCHES.get(tag, []))
    drop = DROP.get(tag, [])
    lead = LEADING.get(tag, 0)
    out = []
    for kind, text in blocks:
        if lead and kind == 'H' and not out:
            lead -= 1
            continue
        if any(d in text for d in drop):
            continue
        for old, new in list(todo):
            if old in text:
                text = text.replace(old, new, 1)
                todo.remove((old, new))
        out.append((kind, text))
    if todo:
        raise SystemExit('Korrektur greift nicht (%s): %r' % (tag, todo))
    return out
