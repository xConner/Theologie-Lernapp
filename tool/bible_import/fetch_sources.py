# -*- coding: utf-8 -*-
"""Lädt die USFM-Archive der in ``sources.json`` genannten Ausgaben.

Quelle ist ausschließlich der offizielle Download von eBible.org (ein
Archiv je Ausgabe, kein Auslesen von Webseiten). Zusätzlich wird der
Katalog ``translations.csv`` geladen; ``build_bible.py`` vergleicht damit
die Verszahlen. ``--force`` lädt vorhandene Archive neu.
"""
import hashlib
import os
import subprocess
import sys
import zipfile

from common import UA, cache, config


def download(url, path, min_size):
    subprocess.run(['curl', '-sL', '-m', '600', '-A', UA, '-o', path, url], check=True)
    if not os.path.exists(path) or os.path.getsize(path) < min_size:
        raise SystemExit('Download fehlgeschlagen: ' + url)


def extract(archive, target):
    """Entpackt nur einfache Dateinamen – keine Pfade aus dem Archiv."""
    os.makedirs(target, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            name = info.filename
            if info.is_dir() or os.path.basename(name) != name:
                continue
            if not name.lower().endswith(('.usfm', '.htm')):
                continue
            with open(os.path.join(target, name), 'wb') as out:
                out.write(z.read(info))


def main():
    force = '--force' in sys.argv
    cfg = config()

    catalog = cache('translations.csv')
    if force or not os.path.exists(catalog):
        download('https://ebible.org/Scriptures/translations.csv', catalog, 100000)

    for t in cfg['translations']:
        archive = cache(t['id'], 'usfm.zip')
        if force or not os.path.exists(archive):
            download(cfg['downloadUrl'].format(ebibleId=t['ebibleId']), archive, 100000)
        extract(archive, os.path.join(os.path.dirname(archive), 'usfm'))
        with open(archive, 'rb') as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        print('%-10s %8d Bytes  sha256 %s' % (t['id'], os.path.getsize(archive), digest[:16]))


if __name__ == '__main__':
    main()
