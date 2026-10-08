# -*- coding: utf-8 -*-
"""Zeigt die Texterkennung einzelner Seiten (zum Nachlesen und Abschreiben).

Aufruf: python show_ocr.py <archive-id> <modell> <von> [bis] [--heads]
"""
import os
import re
import sys

from common import cache


def page(item, model, n):
    f = cache('ocr', item, 'n%d.%s.txt' % (n, model))
    if not os.path.exists(f):
        return None
    t = open(f, encoding='utf-8').read().replace('ſ', 's')
    t = re.sub(r'[⸗=-]\n(?=[a-zäöüß])', '', t)
    return re.sub(r'\n{2,}', '\n', t)


if __name__ == '__main__':
    item, model, lo = sys.argv[1], sys.argv[2], int(sys.argv[3])
    hi = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else lo
    for n in range(lo, hi + 1):
        t = page(item, model, n)
        if t is None:
            continue
        if '--heads' in sys.argv:
            lines = [l.strip() for l in t.split('\n') if l.strip()]
            print('n%d | %s' % (n, ' / '.join(lines[:3])[:130]))
        else:
            print('=== n%d' % n)
            print(t)
