# -*- coding: utf-8 -*-
"""Lädt die Textquellen des Konkordienbuchs in den Zwischenspeicher.

* Deutsch/Lateinisch: elektronische Textfassung der Concordia Triglotta
  (Northwestern Publishing House 1996) als PDF von archive.org, daraus mit
  ``pdftotext -layout`` der Text.
* Englisch: Triglotta-Übersetzung von bookofconcord.org (eine Seite je Artikel).
* Texterkennungen zweier Scans des Drucks von 1921 (archive.org) als
  unabhängige Zeugen für den Abgleich.
"""
import json
import os
import re
import subprocess
import time
import urllib.parse
import urllib.request

from common import cache

UA = 'Mozilla/5.0 (theologie.app content import)'


def get(url, path, min_size=1000):
    if os.path.exists(path) and os.path.getsize(path) >= min_size:
        return
    for attempt in range(4):
        subprocess.run(['curl', '-sL', '-m', '400', '-A', UA, '-o', path, url])
        if os.path.exists(path) and os.path.getsize(path) >= min_size:
            return
        time.sleep(3 + attempt * 5)
    raise SystemExit('Download fehlgeschlagen: ' + url)


def archive_file(item, name, path, min_size=100000):
    """archive.org liefert über /download gelegentlich 500; dann direkt vom Datenserver."""
    if os.path.exists(path) and os.path.getsize(path) >= min_size:
        return
    quoted = urllib.parse.quote(name)
    try:
        get('https://archive.org/download/%s/%s' % (item, quoted), path, min_size)
        return
    except SystemExit:
        pass
    meta = json.load(urllib.request.urlopen('https://archive.org/metadata/' + item, timeout=60))
    for server in meta.get('workable_servers', []):
        try:
            get('https://%s%s/%s' % (server, meta['dir'], quoted), path, min_size)
            return
        except SystemExit:
            continue
    raise SystemExit('Download fehlgeschlagen: %s/%s' % (item, name))


def main():
    archive_file('ConcordiaTriglotta_German', 'CONCORDIA TRIGLOTTA-German.pdf', cache('de.pdf'), 1500000)
    archive_file('ConcordiaTriglotta_Latin', 'CONCORDIA TRIGLOTTA-Latin.pdf', cache('la.pdf'), 1500000)
    for lang in ('de', 'la'):
        subprocess.run(['pdftotext', '-enc', 'UTF-8', '-layout', cache(lang + '.pdf'), cache(lang + '_layout.txt')],
                       check=True)
    archive_file('concordiatriglot00unse', 'concordiatriglot00unse_djvu.txt', cache('ocrA.txt'), 7000000)
    archive_file('ConcordiaTriglotta', 'Concordia Triglotta (Google Books 2017)_djvu.txt', cache('ocrB.txt'), 7000000)

    home = cache('boc', '_home.html')
    get('https://bookofconcord.org/', home)
    html = open(home, encoding='utf-8').read()
    links = sorted(set(re.findall(r'href="(/[^"#]*)"', html)))
    keep = [l for l in links if re.match(
        r'^/(augsburg-confession|defense|smalcald-articles|power-and-primacy|small-catechism|large-catechism|'
        r'epitome|solid-declaration|preface)(/|$)', l)]
    for l in keep:
        get('https://bookofconcord.org' + l, cache('boc', l.strip('/').replace('/', '__') + '.html'), 5000)
        time.sleep(0.2)
    print('Quellen vollständig:', len(keep), 'Seiten von bookofconcord.org')


if __name__ == '__main__':
    main()
