// Normalisierung der XML-Ausgabe der UnivIS-PRG-Schnittstelle
// (`/prg?search=lectures&show=xml`) in ein app-taugliches JSON-Format.
//
// Prototyp der Machbarkeitsprüfung (docs/univis-integration-feasibility.md),
// nicht Teil der App. Die Elementnamen folgen dem UnivIS-Benutzerhandbuch
// (Kap. 19 „XML-Schnittstelle“) und veröffentlichten Clients; gegen eine
// echte Kieler Antwort sind sie noch NICHT geprüft. Deshalb ist der Parser
// tolerant: Unbekannte Elemente landen im Inventar (`inventory`), unbekannte
// Wiederholungsmuster bleiben als Rohwert erhalten statt geraten zu werden.

import * as cheerio from 'cheerio';

/** Text eines direkten Kindelements oder null. */
function childText($, el, name) {
    const child = $(el).children(name).first();
    if (child.length === 0) return null;
    const text = child.text().replace(/\s+/g, ' ').trim();
    return text.length > 0 ? text : null;
}

/** Schlüssel aller `UnivISRef` unterhalb von [el] (in Dokumentreihenfolge). */
function refKeys($, el) {
    return $(el)
        .find('UnivISRef')
        .map((_, ref) => $(ref).attr('key'))
        .get()
        .filter((key) => typeof key === 'string' && key.length > 0);
}

function addInventory(inventory, scope, $, el) {
    const names = (inventory[scope] ??= {});
    $(el)
        .children()
        .each((_, child) => {
            const name = child.tagName ?? child.name;
            names[name] = (names[name] ?? 0) + 1;
        });
}

const TIME = /^([01]?\d|2[0-3]):([0-5]\d)$/;

function normalizeTime(value) {
    if (value == null) return null;
    const match = TIME.exec(value);
    return match ? `${match[1].padStart(2, '0')}:${match[2]}` : null;
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;

function normalizeDate(value) {
    return value != null && DATE.test(value) ? value : null;
}

/**
 * Deutet das UnivIS-Wiederholungsmuster eines Termins.
 *
 * Belegt ist nur, DASS das Handbuch eine Kodierung beschreibt (Abschnitt 19.4).
 * Die hier erkannten Formen (`w<n> <Tage>`, `s1`, `d<n>`, `b…`, `m…`) sind
 * Annahmen und werden beim ersten echten Abruf mit `univis_probe.mjs`
 * überprüft; alles andere ergibt `kind: 'unknown'` mit Rohwert.
 * Wochentage: Annahme 1 = Montag … 6 = Samstag, 0 oder 7 = Sonntag.
 */
export function parseRepeat(raw) {
    if (raw == null) return { kind: 'unknown', raw: null };
    const value = raw.trim();

    const weekly = /^w(\d+)\s+([0-7](?:\s*,\s*[0-7])*)$/.exec(value);
    if (weekly) {
        const weekdays = weekly[2]
            .split(',')
            .map((d) => Number(d.trim()))
            .map((d) => (d === 0 ? 7 : d));
        return {
            kind: 'weekly',
            intervalWeeks: Number(weekly[1]),
            weekdays: [...new Set(weekdays)].sort(),
            raw: value,
        };
    }
    if (/^s1$/.test(value)) return { kind: 'single', raw: value };
    if (/^d\d+/.test(value)) return { kind: 'daily', raw: value };
    if (/^b/.test(value)) return { kind: 'block', raw: value };
    if (/^m/.test(value)) return { kind: 'monthly', raw: value };
    return { kind: 'unknown', raw: value };
}

function personName($, el) {
    const parts = [
        childText($, el, 'title'),
        childText($, el, 'firstname'),
        childText($, el, 'lastname'),
    ].filter(Boolean);
    return parts.length > 0 ? parts.join(' ') : null;
}

/**
 * Wandelt ein UnivIS-XML-Dokument in normalisierte Veranstaltungen um.
 *
 * Personen werden bewusst nur mit Schlüssel und Anzeigename übernommen
 * (keine Telefonnummern, E-Mail-Adressen, Sprechzeiten).
 */
export function parseUnivisLectures(xml) {
    const $ = cheerio.load(xml, { xml: true });
    const root = $('UnivIS').first();
    if (root.length === 0) {
        throw new Error('Kein <UnivIS>-Wurzelelement – keine UnivIS-XML-Antwort.');
    }

    const inventory = {};
    addInventory(inventory, 'UnivIS', $, root);

    const persons = new Map();
    root.children('Person').each((_, el) => {
        persons.set($(el).attr('key'), personName($, el));
    });

    const rooms = new Map();
    root.children('Room').each((_, el) => {
        rooms.set($(el).attr('key'), {
            short: childText($, el, 'short'),
            name: childText($, el, 'name'),
        });
    });

    const unresolved = new Set();
    const lectures = [];

    root.children('Lecture').each((_, el) => {
        addInventory(inventory, 'Lecture', $, el);

        const lecturers = $(el)
            .children('dozs')
            .children('doz')
            .map((_, doz) => refKeys($, doz))
            .get()
            .map((key) => {
                if (!persons.has(key)) unresolved.add(key);
                return { key, displayName: persons.get(key) ?? null };
            });

        const sessions = $(el)
            .children('terms')
            .children('term')
            .map((_, term) => {
                addInventory(inventory, 'term', $, term);
                const roomKey = refKeys($, $(term).children('room'))[0] ?? null;
                if (roomKey && !rooms.has(roomKey)) unresolved.add(roomKey);
                return {
                    repeat: parseRepeat(childText($, term, 'repeat')),
                    startTime: normalizeTime(childText($, term, 'starttime')),
                    endTime: normalizeTime(childText($, term, 'endtime')),
                    startDate: normalizeDate(childText($, term, 'startdate')),
                    endDate: normalizeDate(childText($, term, 'enddate')),
                    excludedDates: $(term)
                        .children('exclude')
                        .map((_, ex) => normalizeDate($(ex).text().trim()))
                        .get()
                        .filter(Boolean),
                    room: roomKey
                        ? { key: roomKey, ...(rooms.get(roomKey) ?? {}) }
                        : null,
                };
            })
            .get();

        lectures.push({
            sourceKey: $(el).attr('key') ?? null,
            id: childText($, el, 'id'),
            name: childText($, el, 'name'),
            shortName: childText($, el, 'short'),
            type: childText($, el, 'type'),
            sws: childText($, el, 'sws'),
            ects: childText($, el, 'ects_cred'),
            orgName: childText($, el, 'orgname'),
            hasSummary: childText($, el, 'summary') != null,
            lecturers,
            sessions,
        });
    });

    return { lectures, unresolvedRefs: [...unresolved].sort(), inventory };
}

/**
 * Prüft die Qualität der normalisierten Daten und liefert Kennzahlen,
 * damit ein echter Abruf ohne Sichtprüfung jedes Datensatzes bewertet
 * werden kann.
 */
export function validateLectures(result) {
    const { lectures, unresolvedRefs } = result;
    const sessions = lectures.flatMap((l) => l.sessions);
    const count = (pred) => sessions.filter(pred).length;
    const keys = lectures.map((l) => l.sourceKey);

    return {
        lectures: lectures.length,
        lecturesWithoutName: lectures.filter((l) => !l.name).length,
        lecturesWithoutKey: keys.filter((k) => !k).length,
        duplicateKeys: keys.length - new Set(keys).size,
        lecturesWithoutSessions: lectures.filter((l) => l.sessions.length === 0)
            .length,
        lecturesWithoutLecturer: lectures.filter((l) => l.lecturers.length === 0)
            .length,
        sessions: sessions.length,
        sessionsWithTimes: count((s) => s.startTime && s.endTime),
        sessionsWithRoom: count((s) => s.room),
        sessionsWithResolvedRoom: count((s) => s.room?.short || s.room?.name),
        repeatKinds: sessions.reduce((acc, s) => {
            acc[s.repeat.kind] = (acc[s.repeat.kind] ?? 0) + 1;
            return acc;
        }, {}),
        unknownRepeatValues: [
            ...new Set(
                sessions
                    .filter((s) => s.repeat.kind === 'unknown' && s.repeat.raw)
                    .map((s) => s.repeat.raw),
            ),
        ],
        unresolvedRefs: unresolvedRefs.length,
    };
}
