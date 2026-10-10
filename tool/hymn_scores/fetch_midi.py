"""Lädt die MIDI-Vorlagen von Wikimedia Commons.

Geladen wird jede Datei, die das Inventar einem Lied zuordnet. Der
Projektinhaber hat die Verwendung der recherchierten Vorlagen freigegeben;
die Einstufung der Recherche bleibt im Inventar und in der Übersicht
(docs/hymn-scores/integration.md) sichtbar. Die Dateien landen unversioniert
in build/hymn_scores/midi/<sha1>.mid; die Prüfsumme muss zum
Quellen-Schnappschuss passen, sonst wird die Datei verworfen.
"""

import hashlib
import json
import time
import urllib.parse
import urllib.request

from common import BUILD, INVENTORY_JSON, USER_AGENT

MIDI_DIR = BUILD / "midi"


def usable(row):
    """Lied mit mindestens einer zugeordneten Vorlage."""
    return bool(row["commons_dateien"])


def wanted_files():
    rows = json.loads(INVENTORY_JSON.read_text(encoding="utf-8"))
    files = {}
    for row in rows:
        if usable(row):
            for file in row["commons_dateien"]:
                files[file["datei"]] = file["sha1"]
    return files


def main():
    MIDI_DIR.mkdir(parents=True, exist_ok=True)
    files = wanted_files()
    failed = []
    for index, (title, sha1) in enumerate(sorted(files.items()), 1):
        target = MIDI_DIR / f"{sha1}.mid"
        if target.exists():
            continue
        name = urllib.parse.quote(title[len("File:"):].replace(" ", "_"))
        url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{name}"
        data = None
        for attempt in range(5):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = response.read()
                break
            except Exception as error:  # Drosselung oder Netzfehler
                print(f"  {title}: {error}")
                time.sleep(5 * (attempt + 1))
        if data is None or hashlib.sha1(data).hexdigest() != sha1:
            failed.append(title)
            continue
        target.write_bytes(data)
        time.sleep(0.3)
        if index % 25 == 0:
            print(f"  {index}/{len(files)}")
    print(f"{len(files) - len(failed)} von {len(files)} Dateien vorhanden")
    for title in failed:
        print(f"  FEHLT oder geändert: {title}")


if __name__ == "__main__":
    main()
