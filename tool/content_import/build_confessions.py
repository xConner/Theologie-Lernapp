# -*- coding: utf-8 -*-
"""Baut ``assets/confessions.json``: das vollständige Konkordienbuch.

Ablauf: Quellen zerlegen (textlib) -> bereinigen -> Wort für Wort mit
Texterkennungen des Drucks abgleichen (collate) -> mit den schon vorhandenen,
von Hand am Faksimile geprüften Abschnitten zusammenführen.

Die geprüften Abschnitte (siehe VERIFIED) werden unverändert aus der
bestehenden Datei übernommen; ihre IDs und Texte bleiben stabil, damit
gespeicherte Lernstände gültig bleiben.

Aufruf: python build_confessions.py [--no-collate]
"""
import collections
import json
import sys

from check_render import render_all
from collate import WORD, collate
from common import cache, repo
from greek import restore_greek
from spec import BOOKS
from witnesses import witnesses_for

LANGS = ('de', 'la', 'en')

# Bereits am Faksimile geprüfte Abschnitte: Texte bleiben wortgleich.
VERIFIED = {
    'augsburger_konfession': ['art_%d' % i for i in range(1, 22)],
    'apologie': ['art_9'],
    'schmalkaldische_artikel': ['teil_2_art_1'],
    'kleiner_katechismus': ['hauptstueck_%d' % i for i in range(1, 7)],
    'konkordienformel_epitome': ['regel_und_richtschnur'],
}
# Großer Katechismus, erstes Gebot: geprüft sind §§ 1–4; der Rest wird angefügt.
GK_PREFIX_END = {
    'de': 'laß nur dein Herz an keinem andern hangen noch ruhen.',
    'la': 'nec ab eo pendeas, nec in eo conquiescas.',
    'en': 'only let not your heart cleave to or rest in any other.',
}

TRIGLOTTA = 'Concordia Triglotta (St. Louis: Concordia Publishing House, 1921)'
METHOD = {
    'de': ('elektronische Textfassung der Triglotta (Northwestern Publishing House 1996; archive.org, '
           'ConcordiaTriglotta_German), maschinell Wort für Wort mit einer Fraktur-Texterkennung des Drucks '
           '(archive.org, concordiatriglot00unse) abgeglichen und danach berichtigt, aber nicht vollständig von '
           'Hand am Faksimile gegengelesen – einzelne Lesefehler, vor allem bei gleich aussehenden Wörtern und '
           'in der Zeichensetzung, sind möglich'),
    'la': ('elektronische Textfassung der Triglotta (Northwestern Publishing House 1996; archive.org, '
           'ConcordiaTriglotta_Latin), maschinell Wort für Wort mit den Texterkennungen zweier Scans des Drucks '
           '(archive.org, concordiatriglot00unse und ConcordiaTriglotta) abgeglichen und danach berichtigt, aber '
           'nicht vollständig von Hand am Faksimile gegengelesen – einzelne Lesefehler sind möglich'),
    'en': ('Wortlaut nach bookofconcord.org, maschinell Wort für Wort mit den Texterkennungen zweier Scans des '
           'Drucks (archive.org, concordiatriglot00unse und ConcordiaTriglotta) abgeglichen und danach '
           'berichtigt; Bibelstellen in der Schreibweise der Ausgabe'),
}
CONVENTIONS = {
    'de': 'Orthographie der Ausgabe, „HErr“/„JEsus“ als „Herr“/„Jesus“ wiedergegeben; Absatzzähler und '
          'Herausgeberzusätze in eckigen Klammern weggelassen',
    'la': 'Absatzzähler und Herausgeberzusätze in eckigen Klammern weggelassen',
    'en': 'Absatzzähler und Herausgeberzusätze in eckigen Klammern (u. a. die Ergänzungen aus dem deutschen '
          'Text) weggelassen',
}
# Was der jeweilige Text ist (Original/Übersetzung) und was fehlt.
WORKS = {
    'konkordienbuch_vorrede': dict(
        de='Deutscher Originaltext der Vorrede (1580) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        note=dict(en='Die Zwischenüberschriften der Website gehören nicht zum Text und sind weggelassen')),
    'augsburger_konfession': dict(
        de='Deutscher Text des Konkordienbuchs (1580) nach der %s' % TRIGLOTTA,
        la='Lateinischer Text (editio princeps 1531, Konkordienbuch 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung des lateinischen Textes in der %s' % TRIGLOTTA,
        verified='Art. I–XXI', new='Vorrede, Beschluss des ersten Teils, Art. XXII–XXVIII und Beschluss',
        note=dict(de='In Art. XXVI ist die mit [*…] gekennzeichnete Ergänzung aus dem Urtext (Pauluszitat '
                     '1 Tim. 4) beibehalten')),
    'apologie': dict(
        la='Originaltext Philipp Melanchthons (Editio princeps 1531) nach der %s' % TRIGLOTTA,
        de='Deutsche Übersetzung von Justus Jonas (1531), keine wörtliche Übertragung des lateinischen '
           'Originals; Text nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung des lateinischen Textes in der %s' % TRIGLOTTA,
        verified='Art. IX', new='alle übrigen Artikel und die Vorrede',
        note=dict(la='Griechische Wörter und Zitate sind nach der Ausgabe wiedergegeben; ihre Akzente und '
                     'Spiritus sind in der elektronischen Vorlage nicht eindeutig überliefert und ohne Abgleich '
                     'am Faksimile ergänzt',
                  en='Griechische Zitate, die bookofconcord.org auslässt, sind aus dem lateinischen Text '
                     'ergänzt')),
    'schmalkaldische_artikel': dict(
        de='Originaltext Martin Luthers (1537) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        verified='Teil II, Art. I', new='alle übrigen Teile und Artikel',
        note=dict(all='Die Unterschriftenliste am Schluss ist nicht aufgenommen')),
    'traktat': dict(
        la='Originaltext Philipp Melanchthons (1537) nach der %s' % TRIGLOTTA,
        de='Deutsche Übersetzung von Veit Dietrich (1541) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung des lateinischen Textes in der %s' % TRIGLOTTA,
        note=dict(all='Die Unterschriftenliste am Schluss ist nicht aufgenommen')),
    'kleiner_katechismus': dict(
        de='Deutscher Text Martin Luthers (1529) im Konkordienbuch (1580) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        verified='Die sechs Hauptstücke', new='Vorrede und Anhänge (Gebete, Haustafel)',
        note=dict(all='In den Hauptstücken sind die Zeilen „Antwort.“ und die Untertitel („wie sie ein '
                      'Hausvater …“) weggelassen',
                  en='In der Haustafel sind die beiden in der Ausgabe eingeklammerten Abschnitte („What the '
                     'Hearers Owe to Their Pastors“, „What Subjects Owe to the Magistrates“) weggelassen; die '
                     '„Christian Questions“ gehören nicht zum Konkordienbuch und fehlen',
                  la='Das griechische Distichon am Ende der Haustafel ist weggelassen')),
    'grosser_katechismus': dict(
        de='Deutscher Text Martin Luthers (1529) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        verified='Das erste Gebot, §§ 1–4', new='alles Übrige',
        note=dict(de='Im Vaterunser ist die mit [*…] gekennzeichnete Ergänzung aus Luthers Ausgaben (§§ 9–11, '
                     'im Konkordienbuch von 1580 ausgefallen) beibehalten',
                  all='Die „Kurze Vermahnung zu der Beichte“ steht nicht in der Triglotta und fehlt')),
    'konkordienformel_epitome': dict(
        de='Deutscher Originaltext (1577) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        verified='Der einleitende Abschnitt („Von dem summarischen Begriff …“)', new='Art. I–XII'),
    'konkordienformel_solida_declaratio': dict(
        de='Deutscher Originaltext (1577) nach der %s' % TRIGLOTTA,
        la='Lateinische Übersetzung (Konkordienbuch Leipzig 1584) nach der %s' % TRIGLOTTA,
        en='Englische Übersetzung der %s' % TRIGLOTTA,
        note=dict(all='Das „Verzeichnis der Zeugnisse“ (Catalogus Testimoniorum) und die Unterschriften sind '
                      'nicht aufgenommen')),
}
VERIFIED_HOW = {
    'de': 'am Faksimile des Drucks geprüft (archive.org, concordiatriglot00unse)',
    'la': 'am Faksimile des Drucks geprüft (archive.org, concordiatriglot00unse)',
    'en': 'Wortlaut nach bookofconcord.org, mit dem Druck verglichen und nach ihm berichtigt',
}


def source_note(cid, lang):
    w = WORKS[cid]
    parts = [w[lang]]
    if 'verified' in w:
        parts.append('%s: %s. %s: %s' % (w['verified'], VERIFIED_HOW[lang], w['new'][0].upper() + w['new'][1:],
                                           METHOD[lang]))
    else:
        parts.append(METHOD[lang][0].upper() + METHOD[lang][1:])
    parts.append(CONVENTIONS[lang])
    note = w.get('note', {})
    for key in (lang, 'all'):
        if key in note:
            parts.append(note[key])
    return '. '.join(p.rstrip('.') for p in parts)


def words(t):
    return [m.group(0) for m in WORD.finditer(t)]


def rest_after(end, new, what):
    """Teil von ``new`` nach der Wortfolge, mit der ``end`` schließt."""
    key = [w.casefold() for w in words(end)[-4:]]
    nw = [(m.end(), m.group(0).casefold()) for m in WORD.finditer(new)]
    for i in range(len(nw) - 3):
        if [x[1] for x in nw[i:i + 4]] == key:
            return new[nw[i + 3][0]:].lstrip(' .,;:\n“”"')
    raise SystemExit('Anschlussstelle nicht gefunden: %s' % what)


def merge_gk(old, new, lang):
    """Geprüfter Anfang (§§ 1–4) + Rest des neuen Textes."""
    end = GK_PREFIX_END[lang]
    prefix = old[:old.index(end) + len(end)]
    return prefix + '\n\n' + rest_after(end, new, 'Großer Katechismus ' + lang)


# Augsburgische Konfession: Der Beschluss des ersten Teils samt Überleitung zu
# den Missbräuchen fehlte bisher im deutschen und lateinischen Art. XXI und
# stand im englischen an dessen Ende. Er ist jetzt ein eigener Abschnitt.
CA_TRANSITION = ('beschluss_teil_1',
                 ('Beschluss des ersten Teils und Überleitung zu den Missbräuchen',
                  'Epilogus partis primae', 'Conclusion of the First Part'))
CA_EN_SPLIT = '\n\nThis is about the Sum of our Doctrine'


def split_ca_21(section, new_texts, previous_tail):
    """(Art. XXI ohne Überleitung, Texte des neuen Abschnitts)"""
    old = section['texts']
    en = old['en']
    if CA_EN_SPLIT in en:
        cut = en.index(CA_EN_SPLIT)
        tail = {'en': en[cut:].strip()}
        en = en[:cut]
    else:                                   # schon bei einem früheren Lauf abgetrennt
        tail = {'en': previous_tail['en']}
    art = dict(section, texts=dict(old, en=en))
    for lang in ('de', 'la'):
        tail[lang] = rest_after(old[lang], new_texts[lang], 'CA XXI ' + lang)
    return art, tail


def main():
    do_collate = '--no-collate' not in sys.argv
    path = repo('assets', 'confessions.json')
    old = {c['id']: c for c in json.load(open(path, encoding='utf-8'))}
    rendered = render_all()

    texts = {}   # (cid, sid, lang) -> text
    for lang in LANGS:
        wits, independent = witnesses_for(lang) if do_collate else (None, 0)
        lexicon = collections.Counter(
            w for secs in rendered.values() for v in secs.values() for w in words(v.get(lang, '')))
        stats = collections.Counter()
        log = []
        for b in BOOKS:
            cid = b['id']
            for sec in b['sections']:
                sid = sec[0]
                if sid is None or (sid in VERIFIED.get(cid, [])
                                   and (cid, sid) != ('augsburger_konfession', 'art_21')):
                    continue
                t = rendered[cid][sid][lang]
                if do_collate:
                    t = collate(t, lang, wits, independent, stats, log, '%s/%s' % (cid, sid), lexicon)
                texts[(cid, sid, lang)] = restore_greek(t, '%s/%s/%s' % (cid, sid, lang))
        if do_collate:
            with open(cache('collation_%s.tsv' % lang), 'w', encoding='utf-8') as f:
                for row in log:
                    f.write('\t'.join(row) + '\n')
            print(lang, dict(stats))

    out = [old[c] for c in ('apostolicum', 'nicenum', 'athanasianum')]
    for b in BOOKS:
        cid = b['id']
        prev = old.get(cid)
        prev_secs = {s['id']: s for s in prev['sections']} if prev else {}
        sections = []
        for sec in b['sections']:
            sid = sec[0]
            if sid is None:
                continue
            if sid in VERIFIED.get(cid, []):
                s = dict(prev_secs[sid])
                if sec[1] is not None:
                    s['title'] = dict(zip(LANGS, sec[1]))
                if (cid, sid) == ('augsburger_konfession', 'art_21'):
                    s, tail = split_ca_21(s, {l: texts[(cid, sid, l)] for l in ('de', 'la')},
                                          prev_secs.get(CA_TRANSITION[0], {}).get('texts'))
                    sections.append(s)
                    sections.append({'id': CA_TRANSITION[0], 'title': dict(zip(LANGS, CA_TRANSITION[1])),
                                     'texts': {l: tail[l] for l in LANGS}})
                    continue
                sections.append(s)
                continue
            body = {l: texts[(cid, sid, l)] for l in LANGS}
            if cid == 'grosser_katechismus' and sid == 'gebot_1':
                body = {l: merge_gk(prev_secs[sid]['texts'][l], body[l], l) for l in LANGS}
            # die elektronische Ausgabe lässt vereinzelt den Schlusspunkt aus
            body = {l: t + '.' if t[-1:].isalnum() else t for l, t in body.items()}
            sections.append({'id': sid, 'title': dict(zip(LANGS, sec[1])), 'texts': body})
        out.append({
            'id': cid,
            'category': 'lutherische_symbole',
            'title': b['title'] or prev['title'],
            'languages': list(LANGS),
            'sources': {l: source_note(cid, l) for l in LANGS},
            'sections': sections,
        })
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, indent=4)
    size = {l: sum(len(s['texts'].get(l, '')) for c in out for s in c['sections']) for l in LANGS + ('gr',)}
    print('geschrieben:', len(out), 'Bekenntnisse,', sum(len(c['sections']) for c in out), 'Abschnitte', size)


if __name__ == '__main__':
    main()
