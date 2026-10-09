# -*- coding: utf-8 -*-
"""Erzeugt die integrierten Bibellesepläne unter ``assets/reading_plans/``.

Die Pläne sind eigene Einteilungen von theologie.app: Die Kapitel werden in
ihrer Reihenfolge so auf die Tage verteilt, dass jeder Tag ungefähr gleich
viele Verse umfasst. Grundlage sind allein die Kapitel- und Verszahlen aus
``assets/bible/translations.json`` – es wird kein fremder Plan übernommen.

Joel und Maleachi zählen die Ausgaben unterschiedlich (3 bzw. 4 Kapitel).
Beide Bücher stehen deshalb immer als Ganzes an einem Tag („JOL“, „MAL“);
so lässt sich jede Stelle in jeder Ausgabe aufschlagen.

Format der Dateien: ``docs/reading-plans.md``.

    python build_plans.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
BIBLE = os.path.join(REPO, 'assets', 'bible', 'translations.json')
OUT = os.path.join(REPO, 'assets', 'reading_plans')

# Zählung, nach der verteilt wird (englische Zählung, 66 Bücher).
REFERENCE = 'deu1912'

# Bücher, deren Kapitelzahl je nach Ausgabe abweicht: nur als Ganzes.
WHOLE_BOOKS = {'JOL', 'MAL'}

NT_START = 'MAT'
GOSPELS = ['MAT', 'MRK', 'LUK', 'JHN']

SOURCE = {
    'name': 'theologie.app',
    'note': 'Eigene Einteilung nach Kapitel- und Verszahlen; kein '
            'fremder Leseplan übernommen.',
}


def load_books():
    with open(BIBLE, encoding='utf-8') as f:
        data = json.load(f)
    reference = next(t for t in data['translations'] if t['id'] == REFERENCE)
    return [(b['id'], b['chapters']) for b in reference['books']]


def atoms_of(books, segments):
    """Leseeinheiten (Buch, erstes Kapitel, letztes Kapitel, Verse).

    ``segments``: Buchkennung oder (Buch, von, bis) in Lesereihenfolge.
    Kapitel 0 steht für das ganze Buch.
    """
    counts = dict(books)
    result = []
    for segment in segments:
        book, first, last = (
            (segment, 1, len(counts[segment]))
            if isinstance(segment, str) else segment
        )
        if book in WHOLE_BOOKS:
            result.append((book, 0, 0, sum(counts[book])))
            continue
        for chapter in range(first, last + 1):
            result.append((book, chapter, chapter, counts[book][chapter - 1]))
    return result


def partition(atoms, days):
    """Teilt die Einheiten in ``days`` zusammenhängende, nach Versen
    möglichst gleich große Abschnitte."""
    assert len(atoms) >= days
    total = sum(a[3] for a in atoms)
    cumulative = []
    running = 0
    for atom in atoms:
        running += atom[3]
        cumulative.append(running)

    result = []
    start = 0
    for day in range(1, days + 1):
        if day == days:
            end = len(atoms)
        else:
            target = total * day / days
            # Mindestens eine Einheit je Tag, genug übrig für die restlichen.
            low = start + 1
            high = len(atoms) - (days - day)
            end = min(
                range(low, high + 1),
                key=lambda i: abs(cumulative[i - 1] - target),
            )
        result.append(atoms[start:end])
        start = end
    return result


def readings_of(day_atoms):
    """Fasst aufeinanderfolgende Kapitel eines Buchs zu einer Lesung."""
    readings = []
    for book, first, last, _ in day_atoms:
        if first == 0:
            readings.append([book, 0, 0])
        elif readings and readings[-1][0] == book \
                and readings[-1][2] == first - 1:
            readings[-1][2] = last
        else:
            readings.append([book, first, last])

    def text(reading):
        book, first, last = reading
        if first == 0:
            return book
        return f'{book} {first}' if first == last else f'{book} {first}-{last}'

    return [text(r) for r in readings]


def build(books, days, tracks):
    parts = [partition(atoms_of(books, track), days) for track in tracks]
    return [
        [reading for part in parts for reading in readings_of(part[day])]
        for day in range(days)
    ]


def plans(books):
    ids = [b[0] for b in books]
    old = ids[:ids.index(NT_START)]
    new = ids[ids.index(NT_START):]
    letters = [b for b in new if b not in GOSPELS and b != 'ACT']

    # Zwei Lesungen am Tag: Altes Testament fortlaufend, daneben Neues
    # Testament im Wechsel mit den fünf Psalmbüchern, am Ende die Sprüche.
    first_track = [b for b in old if b not in ('PSA', 'PRO')]
    second_track = [
        'MAT', ('PSA', 1, 41), 'MRK', ('PSA', 42, 72), 'LUK',
        ('PSA', 73, 89), 'JHN', ('PSA', 90, 106), 'ACT',
        ('PSA', 107, 150), *letters, 'PRO',
    ]

    return [
        {
            'id': 'bible-1-year',
            'name': 'Die ganze Bibel in einem Jahr',
            'description':
                'Täglich zwei Lesungen: das Alte Testament fortlaufend, '
                'daneben das Neue Testament im Wechsel mit den Psalmen und '
                'zum Schluss die Sprüche.',
            'category': 'whole-bible',
            'difficulty': 'moderate',
            'days': build(books, 365, [first_track, second_track]),
        },
        {
            'id': 'bible-6-months',
            'name': 'Die ganze Bibel in sechs Monaten',
            'description':
                'Derselbe Aufbau wie der Jahresplan in 180 Tagen – etwa der '
                'doppelte tägliche Umfang.',
            'category': 'whole-bible',
            'difficulty': 'demanding',
            'days': build(books, 180, [first_track, second_track]),
        },
        {
            'id': 'bible-90-days',
            'name': 'Die ganze Bibel in 90 Tagen',
            'description':
                'Die ganze Bibel fortlaufend von 1. Mose bis zur '
                'Offenbarung. Sehr intensiv: täglich rund 13 Kapitel.',
            'category': 'whole-bible',
            'difficulty': 'intensive',
            'days': build(books, 90, [ids]),
        },
        {
            'id': 'nt-90-days',
            'name': 'Das Neue Testament in 90 Tagen',
            'description':
                'Das Neue Testament fortlaufend von Matthäus bis zur '
                'Offenbarung – ein überschaubarer Einstieg mit etwa drei '
                'Kapiteln am Tag.',
            'category': 'new-testament',
            'difficulty': 'easy',
            'days': build(books, 90, [new]),
        },
        {
            'id': 'gospels-30-days',
            'name': 'Die Evangelien in 30 Tagen',
            'description':
                'Matthäus, Markus, Lukas und Johannes in einem Monat, etwa '
                'drei Kapitel am Tag.',
            'category': 'gospels',
            'difficulty': 'easy',
            'days': build(books, 30, [GOSPELS]),
        },
        {
            'id': 'bible-marathon-30-days',
            'name': 'Bibel-Marathon in 30 Tagen',
            'description':
                'Die ganze Bibel in einem Monat. Extrem: täglich rund 40 '
                'Kapitel, also mehrere Stunden Lesezeit. Nur für alle, die '
                'diesen Umfang ausdrücklich möchten.',
            'category': 'whole-bible',
            'difficulty': 'extreme',
            'days': build(books, 30, [ids]),
        },
    ]


def check_whole_bible(books, plan):
    """Jedes Kapitel der 66 Bücher genau einmal."""
    expected = []
    for book, chapters in books:
        if book in WHOLE_BOOKS:
            expected.append((book, 0))
        else:
            expected.extend((book, c) for c in range(1, len(chapters) + 1))

    found = []
    for day in plan['days']:
        for reading in day:
            book, _, chapters = reading.partition(' ')
            if not chapters:
                found.append((book, 0))
                continue
            first, _, last = chapters.partition('-')
            found.extend(
                (book, c) for c in range(int(first), int(last or first) + 1)
            )

    assert sorted(found) == sorted(expected), plan['id']
    assert len(found) == len(set(found)), plan['id']


def main():
    books = load_books()
    os.makedirs(OUT, exist_ok=True)
    index = []

    for plan in plans(books):
        assert all(plan['days']), plan['id']
        if plan['category'] == 'whole-bible':
            check_whole_bible(books, plan)

        document = {
            'format': 'theologie.app/reading-plan',
            'formatVersion': 1,
            'id': plan['id'],
            'name': plan['name'],
            'description': plan['description'],
            'language': 'de',
            'category': plan['category'],
            'difficulty': plan['difficulty'],
            'source': SOURCE,
            'days': plan['days'],
        }
        name = plan['id'] + '.json'
        with open(os.path.join(OUT, name), 'w', encoding='utf-8',
                  newline='\n') as f:
            json.dump(document, f, ensure_ascii=False, separators=(',', ':'))
            f.write('\n')
        index.append(name)
        print(f"{plan['id']}: {len(plan['days'])} Tage")

    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8',
              newline='\n') as f:
        json.dump({'plans': index}, f, ensure_ascii=False, indent=2)
        f.write('\n')


if __name__ == '__main__':
    main()
