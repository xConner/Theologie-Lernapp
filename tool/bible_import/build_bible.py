# -*- coding: utf-8 -*-
"""Erzeugt die Bibeltexte des Readers aus den geladenen USFM-Archiven.

Schreibt je Ausgabe ``assets/bible/<id>/<BUCH>.json`` (ein Buch je Datei),
das Verzeichnis aller Ausgaben ``assets/bible/translations.json`` und legt
den Lizenzhinweis der Quelle unter ``docs/bible-sources/`` ab.

Jede Ausgabe wird geprüft: Die Verszahl muss mit dem Katalog von eBible.org
übereinstimmen, Kapitel müssen lückenlos gezählt sein und kein Vers darf
leer sein oder Reste von Formatmarken enthalten.
"""
import csv
import datetime
import glob
import hashlib
import html
import json
import os
import re
import shutil
import sys

from common import ASSETS, CACHE, NOTICES, REPO, cache, config
from usfm import parse_book

# Vorspann, Glossar und Anhänge der Quellen gehören nicht zum Bibeltext.
NOT_SCRIPTURE = {'FRT', 'INT', 'GLO', 'BAK', 'OTH', 'XXA', 'XXB', 'XXC'}

OLD_TESTAMENT = (
    'GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB '
    'PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP '
    'HAG ZEC MAL'
).split()
NEW_TESTAMENT = (
    'MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM '
    'HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV'
).split()
OTHER = (
    'TOB JDT ESG WIS SIR BAR LJE S3Y SUS BEL 1MA 2MA 3MA 4MA 1ES 2ES MAN PS2 '
    'DAG'
).split()
ORDER = {book: i for i, book in enumerate(OLD_TESTAMENT + OTHER + NEW_TESTAMENT)}


def dump(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')


def notice_text(page):
    """Lizenzhinweis aus ``copr.htm`` der Quelle als Text."""
    page = re.sub(r'(?s)<(script|style|head)\b.*?</\1>', '', page)
    page = re.sub(r'(?s)<ul class=.tnav.>.*?</ul>', '', page)
    page = re.sub(r'(?i)<(br|/p|/div|/h\d|/li)\b[^>]*>', '\n', page)
    lines = [re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', line))).strip()
             for line in page.split('\n')]
    lines = [line for line in lines if line and not line.startswith('HTML generated')]
    result = []
    for line in lines:
        if line not in result:
            result.append(line)
    return '\n'.join(result)


def expected_verses(catalog, ebible_id):
    for row in catalog:
        if row['translationId'] == ebible_id:
            return (int(row['OTverses']) + int(row['NTverses']) + int(row['DCverses']),
                    row['UpdateDate'])
    raise SystemExit('Nicht im Katalog von eBible.org: ' + ebible_id)


def build(entry, cfg, catalog):
    source_dir = os.path.join(CACHE, entry['id'], 'usfm')
    files = sorted(glob.glob(os.path.join(source_dir, '*.usfm')))
    if not files:
        raise SystemExit('Keine Quelldateien für %s – zuerst fetch_sources.py ausführen.' % entry['id'])

    target = os.path.join(ASSETS, entry['id'])
    shutil.rmtree(target, ignore_errors=True)

    books = []
    verses = 0
    notes = 0
    headings = 0

    for path in files:
        with open(path, encoding='utf-8-sig') as f:
            source = f.read()
        book = source[4:7]
        if book in NOT_SCRIPTURE:
            continue
        if book not in ORDER:
            raise SystemExit('Unbekanntes Buch %s in %s' % (book, path))

        head, chapters = parse_book(source, entry['footnotes'])

        numbers = sorted(chapters)
        if numbers != list(range(1, len(numbers) + 1)):
            raise SystemExit('%s %s: Kapitel nicht lückenlos: %s' % (entry['id'], book, numbers))

        counts = []
        for number in numbers:
            items = chapters[number]
            chapter_verses = [i for i in items if 'v' in i]
            if not chapter_verses:
                # Kommt in der Septuaginta vor (Spr 30 steht dort an anderer
                # Stelle); das Kapitel bleibt leer erhalten.
                print('  Hinweis: %s %s %d ist in der Quelle leer' % (entry['id'], book, number))
                counts.append(0)
                continue
            for item in chapter_verses:
                if '\\' in item['t'] or '|' in item['t']:
                    raise SystemExit('%s %s %d,%s: Formatrest im Text: %s'
                                     % (entry['id'], book, number, item['v'], item['t'][:80]))
                notes += len(item.get('f', ()))
            headings += sum(1 for i in items if 'h' in i)
            verses += sum(1 for i in chapter_verses if 'c' not in i)
            counts.append(max(i['v'] for i in chapter_verses))

        name = head.get('h') or head.get('toc2') or head.get('toc1')
        if not name:
            raise SystemExit('%s %s: kein Buchname in der Quelle' % (entry['id'], book))
        long_name = head.get('toc1') or name
        # Berichtigte Buchtitel (in sources.json unter „deviations“ genannt).
        override = entry.get('bookNames', {}).get(book)
        if override:
            name, long_name = override['name'], override['longName']

        dump(os.path.join(target, book + '.json'),
             {'id': book, 'chapters': [chapters[n] for n in numbers]})
        books.append({
            'id': book,
            'name': name,
            'longName': long_name,
            'chapters': counts,
        })

    books.sort(key=lambda b: ORDER[b['id']])

    expected, updated = expected_verses(catalog, entry['ebibleId'])
    if verses != expected:
        raise SystemExit('%s: %d Verse gelesen, Katalog nennt %d' % (entry['id'], verses, expected))

    with open(os.path.join(source_dir, 'copr.htm'), encoding='utf-8-sig') as f:
        page = f.read()
    os.makedirs(NOTICES, exist_ok=True)
    with open(os.path.join(NOTICES, entry['id'] + '-copr.htm'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)

    with open(cache(entry['id'], 'usfm.zip'), 'rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()

    size = sum(os.path.getsize(p) for p in glob.glob(os.path.join(target, '*.json')))
    print('%-10s %2d Bücher %5d Kapitel %6d Verse %5d Anmerkungen %5d Überschriften %5.1f MB'
          % (entry['id'], len(books), sum(len(b['chapters']) for b in books), verses, notes,
             headings, size / 1e6))

    return {
        'id': entry['id'],
        'name': entry['name'],
        'shortName': entry['shortName'],
        'language': entry['language'],
        'edition': entry['edition'],
        'source': {
            'name': 'eBible.org',
            'url': cfg['detailsUrl'].format(ebibleId=entry['ebibleId']),
            'file': cfg['downloadUrl'].format(ebibleId=entry['ebibleId']),
            'format': 'USFM',
            'updated': updated,
            'sha256': digest,
        },
        'license': {
            'type': entry['licenseType'],
            'url': entry['licenseUrl'],
            'notice': notice_text(page),
        },
        'copyright': entry['copyright'],
        'restrictions': entry['restrictions'],
        'deviations': entry['deviations'],
        'versification': entry['versification'],
        'features': {
            'search': True,
            'offline': True,
            'footnotes': notes > 0,
            'headings': headings > 0,
        },
        'verses': verses,
        'books': books,
    }


def main():
    cfg = config()
    with open(cache('translations.csv'), encoding='utf-8-sig') as f:
        catalog = list(csv.DictReader(f))

    only = set(sys.argv[1:])
    registry_path = os.path.join(ASSETS, 'translations.json')
    previous = {}
    if only and os.path.exists(registry_path):
        with open(registry_path, encoding='utf-8') as f:
            previous = {t['id']: t for t in json.load(f)['translations']}

    translations = []
    for entry in cfg['translations']:
        if only and entry['id'] not in only:
            if entry['id'] in previous:
                translations.append(previous[entry['id']])
            continue
        translations.append(build(entry, cfg, catalog))

    # Ausgaben, die nicht mehr in sources.json stehen, entfernen.
    known = {t['id'] for t in translations}
    for path in glob.glob(os.path.join(ASSETS, '*')):
        if os.path.isdir(path) and os.path.basename(path) not in known:
            shutil.rmtree(path)

    dump(registry_path, {
        'formatVersion': 1,
        'generated': datetime.date.today().isoformat(),
        'translations': translations,
    })

    print('\npubspec.yaml muss diese Einträge unter flutter/assets enthalten:')
    print('      - assets/bible/translations.json')
    for t in translations:
        print('      - assets/bible/%s/' % t['id'])
    print('\nGeschrieben nach', os.path.relpath(ASSETS, REPO))


if __name__ == '__main__':
    main()
