# -*- coding: utf-8 -*-
"""Misst den Abgleich an den Abschnitten, die schon von Hand am Faksimile
geprüft in assets/confessions.json stehen (git HEAD): Wie viele Abweichungen
der Basis vom geprüften Text behebt der Abgleich, wie viele führt er neu ein?

Aufruf: python evaluate.py <de|la|en> [konfession,…]
"""
import collections
import difflib
import json
import subprocess
import sys

from check_render import render_all
from collate import WORD, collate
from common import REPO
from witnesses import witnesses_for


def words(t):
    return [m.group(0).replace('’', "'") for m in WORD.finditer(t)]


def diffs(a, b):
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return [(' '.join(a[i1:i2]), ' '.join(b[j1:j2])) for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag != 'equal']


def main():
    lang = sys.argv[1]
    blob = subprocess.run(['git', 'show', 'HEAD:assets/confessions.json'], cwd=REPO, capture_output=True).stdout
    verified = {c['id']: c for c in json.loads(blob.decode('utf-8'))}
    only = sys.argv[2].split(',') if len(sys.argv) > 2 else list(verified)
    rendered = render_all()
    wits, independent = witnesses_for(lang)
    lexicon = collections.Counter(w for secs in rendered.values() for v in secs.values() for w in words(v.get(lang, '')))
    tot = collections.Counter()
    for cid in only:
        for sec in verified[cid]['sections']:
            sid = sec['id']
            if lang not in sec['texts'] or sid not in rendered.get(cid, {}):
                continue
            v = words(sec['texts'][lang])
            base = rendered[cid][sid][lang]
            st = collections.Counter()
            fixed = collate(base, lang, wits, independent, st, lexicon=lexicon)
            d0 = diffs(words(base)[:len(v) + 30], v)
            d1 = diffs(words(fixed)[:len(v) + 30], v)
            new = [x for x in d1 if x not in d0]
            tot['woerter'] += len(v)
            tot['vorher'] += len(d0)
            tot['nachher'] += len(d1)
            tot['neu'] += len(new)
            if d1:
                print(cid, sid, 'Wörter', len(v), 'vorher', len(d0), 'nachher', len(d1), 'neu', len(new))
                for x in d1[:14]:
                    print('     ', 'NEU ' if x in new else 'rest', x)
    print(dict(tot))


if __name__ == '__main__':
    main()
