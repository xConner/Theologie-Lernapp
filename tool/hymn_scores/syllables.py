"""Zerlegt deutsche Liedzeilen in Sprechsilben für die Textunterlegung.

Regelbasiert, ohne Wörterbuch: Jede Silbe hat genau einen Vokalkern
(Vokal, Doppellaut oder Dehnung); von den Konsonanten zwischen zwei Kernen
geht der letzte bzw. die letzte sprechbare Verbindung zur folgenden Silbe.
Die Silbenzahl entscheidet über die Zuordnung zu den Noten; die genaue
Trennstelle ist nur Schreibweise.
"""

import re

_VOWELS = "aeiouyäöüáéèêëíïóôúû"
# Vokalfolgen, die als eine Silbe gesungen werden
_ONE_NUCLEUS = ("ei", "ai", "au", "eu", "äu", "ie", "ee", "aa", "oo", "ey", "ay")
# Konsonantenverbindungen, die ungetrennt eine Silbe eröffnen
_ONSETS = (
    "schw", "schl", "schm", "schn", "schr", "sch", "spr", "str", "pfl", "pfr",
    "ch", "ck", "ph", "th", "qu", "br", "bl", "dr", "fr", "fl", "gr", "gl",
    "kr", "kl", "kn", "pr", "pl", "tr", "zw", "sp", "st",
)
# Wörter, in denen eine Vokalfolge anders gesprochen wird, als die Regel
# annimmt: Trennstellen von Hand („|“).
_EXCEPTIONS = {
    "kyrie": "ky|ri|e",
    "marien": "ma|ri|en",
    "lilie": "li|li|e",
    "lilien": "li|li|en",
    "familie": "fa|mi|li|e",
    "familien": "fa|mi|li|en",
    "linie": "li|ni|e",
    "geehrt": "ge|ehrt",
    "geehret": "ge|eh|ret",
    "beehrt": "be|ehrt",
    "geendet": "ge|en|det",
    "beendet": "be|en|det",
    "geeint": "ge|eint",
    "vereint": "ver|eint",
    "vereinen": "ver|ei|nen",
    "vereinet": "ver|ei|net",
    "vereinigt": "ver|ei|nigt",
    "beieinander": "bei|ei|nan|der",
    "gloria": "glo|ri|a",
    "eleison": "e|le|i|son",
    "israel": "is|ra|el",
    "israels": "is|ra|els",
    "immanuel": "im|ma|nu|el",
    "emmanuel": "em|ma|nu|el",
    "halleluja": "hal|le|lu|ja",
    "hosianna": "ho|si|an|na",
    "zion": "zi|on",
    "zions": "zi|ons",
    "jesu": "je|su",
    "jesus": "je|sus",
    "knien": "kni|en",
    "knie": "knie",
    "seraphim": "se|ra|phim",
    "cherubim": "che|ru|bim",
    "erinnern": "er|in|nern",
    "erinnert": "er|in|nert",
}

# Nachsilben und Grundwörter, vor denen immer getrennt wird
_SUFFIXES = (
    "lein", "lich", "ling", "los", "nis", "heit", "keit", "schaft", "tum",
    "bar", "sam", "haft", "reich", "voll", "wärts",
)


def x_onset(suffix):
    """Zahl der Konsonanten, mit denen eine Nachsilbe beginnt."""
    return next(i for i, c in enumerate(suffix) if c in _VOWELS)


_WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)*", re.UNICODE)


def _nuclei(word):
    """Positionen (Anfang, Ende) der Vokalkerne eines kleingeschriebenen Wortes."""
    spans = []
    index = 0
    while index < len(word):
        if word[index] in _VOWELS:
            # „qu“: das u gehört zum Anlaut
            if word[index] == "u" and index > 0 and word[index - 1] == "q":
                index += 1
                continue
            pair = word[index : index + 2]
            length = 2 if pair in _ONE_NUCLEUS else 1
            # „ie“ vor weiterem Vokal nicht dehnen: „Marie-en“ bleibt Ausnahme
            spans.append((index, index + length))
            index += length
        else:
            index += 1
    return spans


def split_word(word):
    """Silben eines Wortes (mit Apostrophen), z. B. „Herrlichkeit“ → Herr-lich-keit."""
    lower = word.lower().replace("’", "'")
    plain = lower.replace("'", "")
    if plain in _EXCEPTIONS and "'" not in lower:
        parts = _EXCEPTIONS[plain].split("|")
        result, position = [], 0
        for part in parts:
            result.append(word[position : position + len(part)])
            position += len(part)
        return result

    spans = _nuclei(lower)
    if len(spans) <= 1:
        return [word]
    cuts = []
    for (_, end), (start, _) in zip(spans, spans[1:]):
        cluster = lower[end:start]
        letters = cluster.replace("'", "")
        suffix = next(
            (x for x in _SUFFIXES if lower.startswith(x, start - x_onset(x))), None
        )
        if not letters:
            cut = start  # zwei Kerne stoßen aneinander: „treu-en“
        elif suffix and start - x_onset(suffix) >= end:
            cut = start - x_onset(suffix)  # „Zweig-lein“, „Kö-nig-reich“
        else:
            onset = next((o for o in _ONSETS if letters.endswith(o)), letters[-1])
            if len(onset) == len(letters) and onset in ("st", "sp", "ck"):
                # „Chris-ten“, „Wes-pe“, „Zu-cker“ → vor dem letzten Laut
                onset = letters[-1] if onset != "ck" else onset
            # Der Anlaut steht am Ende der Lücke; Apostrophe bleiben davor.
            cut = start
            remaining = len(onset)
            while remaining:
                cut -= 1
                if lower[cut] != "'":
                    remaining -= 1
        cuts.append(cut)
    pieces = []
    previous = 0
    for cut in cuts:
        pieces.append(word[previous:cut])
        previous = cut
    pieces.append(word[previous:])
    return [p for p in pieces if p]


def split_line(line):
    """Silben einer Textzeile als Liste (Text, Wortposition).

    Wortposition: „s“ einzelne Silbe, „i“ Wortanfang, „m“ Wortmitte,
    „t“ Wortende. Satzzeichen bleiben an ihrer Silbe.
    """
    result = []
    matches = list(_WORD.finditer(line))
    # Zeichen vor dem ersten Wort
    pending = line[: matches[0].start()].strip() if matches else ""
    for index, match in enumerate(matches):
        word = match.group(0)
        if not any(c in _VOWELS for c in word.lower()):
            # Kein Vokal („'s“, „z.“): hängt an der vorigen Silbe.
            continue
        syllables = split_word(word)
        # Zeichen bis zum nächsten Wort: was direkt anschließt (Satzzeichen,
        # vokallose Reste), bleibt an diesem Wort; was nach einem Leerraum
        # kommt (öffnende Anführung, Klammer), gehört zum nächsten.
        lead = pending
        following = len(line)
        for later in matches[index + 1 :]:
            if any(c in _VOWELS for c in later.group(0).lower()):
                following = later.start()
                break
        gap = line[match.end() : following]
        if following < len(line) and gap.rstrip() == gap and " " in gap.strip():
            tail, pending = gap.strip().rsplit(" ", 1)
            tail = tail.strip()
        else:
            tail, pending = gap.strip(), ""
        syllables[0] = lead + syllables[0]
        syllables[-1] = syllables[-1] + tail
        for number, text in enumerate(syllables):
            if len(syllables) == 1:
                kind = "s"
            elif number == 0:
                kind = "i"
            elif number == len(syllables) - 1:
                kind = "t"
            else:
                kind = "m"
            result.append((text, kind))
    return result


def split_stanza(text):
    """Silben je Textzeile einer Strophe."""
    return [split_line(line) for line in text.split("\n") if line.strip()]
