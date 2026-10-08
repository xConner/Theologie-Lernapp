# -*- coding: utf-8 -*-
"""Texterkennung einzelner Seiten eines archive.org-Digitalisats (Fraktur).

Aufruf:  python ocr_pages.py <archive-id> <von> <bis> <schritt> <modell[,modell]> [prozesse]

Braucht ``tesserocr`` und die Modelle in ``build/content_import/tessdata``
(frak2021 der UB Mannheim, Fraktur aus tessdata_best). Ergebnis je Seite:
``build/content_import/ocr/<archive-id>/n<blatt>.<modell>.txt``.
"""
import os
import subprocess
import sys
import time
from multiprocessing import Pool

from common import cache

ITEM = sys.argv[1] if len(sys.argv) > 1 else ''
MODELS = sys.argv[5].split(',') if len(sys.argv) > 5 else []


def work(n):
    import tesserocr
    from PIL import Image

    img = cache('img', ITEM, 'n%d.jpg' % n)
    todo = [m for m in MODELS if not os.path.exists(cache('ocr', ITEM, 'n%d.%s.txt' % (n, m)))]
    if not todo:
        return n
    for attempt in range(5):
        if os.path.exists(img) and os.path.getsize(img) > 50000:
            break
        subprocess.run(['curl', '-sL', '-m', '120', '-o', img,
                        'https://archive.org/download/%s/page/n%d.jpg' % (ITEM, n)])
        time.sleep(1 + attempt * 3)
    try:
        im = Image.open(img)
        im.load()
    except Exception as e:  # noqa: BLE001 - Seite wird beim nächsten Lauf nachgeholt
        return 'ERR %d %s' % (n, e)
    for m in todo:
        with tesserocr.PyTessBaseAPI(path=cache('tessdata', ''), lang=m, psm=tesserocr.PSM.AUTO) as api:
            api.SetImage(im)
            txt = api.GetUTF8Text()
        with open(cache('ocr', ITEM, 'n%d.%s.txt' % (n, m)), 'w', encoding='utf-8') as f:
            f.write(txt)
    return n


if __name__ == '__main__':
    lo, hi, step = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    procs = int(sys.argv[6]) if len(sys.argv) > 6 else 8
    with Pool(procs) as p:
        for i, r in enumerate(p.imap_unordered(work, range(lo, hi, step))):
            if isinstance(r, str) or i % 25 == 0:
                print(i, r, flush=True)
    print('DONE', flush=True)
