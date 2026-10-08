# -*- coding: utf-8 -*-
"""Zerlegt und bereinigt alle Quellen und meldet Klammer-Auffälligkeiten."""
import collections
from textlib import slice_all, render
from spec import BOOKS

def render_all(log=None):
    r = slice_all()
    out = {}
    for b in BOOKS:
        for sec in b['sections']:
            if sec[0] is None:
                continue
            for lang, blocks in r[b['id']][sec[0]].items():
                tag = '%s/%s/%s' % (b['id'], sec[0], lang)
                out.setdefault(b['id'], {}).setdefault(sec[0], {})[lang] = render(
                    blocks, lang, log, tag, drop_headings=(b['id'] == 'konkordienbuch_vorrede' and lang == 'en'))
    return out

if __name__ == '__main__':
    log = []
    out = render_all(log)
    print({l: sum(len(v.get(l, '')) for s in out.values() for v in s.values()) for l in ('de', 'la', 'en')})
    print(collections.Counter(k for _, k, _ in log))
    for tag, k, ctx in log:
        if k not in ('LANG', 'RUNDE KLAMMER') and 'kleiner_katechismus/hauptstueck' not in tag:
            print(tag, k, '::', ctx[-260:].replace(chr(0), ' | '))
    print('Klammerreste:', [(c, s, l) for c in out for s in out[c] for l in out[c][s]
                            if ('[' in out[c][s][l] or ']' in out[c][s][l]) and not s.startswith('hauptstueck')])
