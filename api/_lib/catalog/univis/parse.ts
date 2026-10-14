// UnivIS-XML (`/prg?search=lectures&show=xml`) → normalisierte Veranstaltungen.
// Elementnamen live gegen univis.uni-kiel.de geprüft (WS 2026/27,
// Theologische Fakultät; docs/univis-integration-feasibility.md, Abschnitt 3).
//
// Bewusst NICHT übernommen: Freitexte (`time_description`, `kontakt`,
// `organizational`, `summary`, `literature`, `comment`) – sie enthalten teils
// Kontaktdaten; die App verlinkt dafür auf UnivIS. Von Personen nur Titel und
// Name.

import * as cheerio from 'cheerio';
import type { Person, ParsedCatalog, RepeatKind, Room, SessionRule, SourceCourse } from '../model';
import { isIsoDate, normalizeTime } from '../time';
import { sha256 } from '../source';

export class UnivisFormatError extends Error {}

export interface UnivisParseContext {
    sourceId: string;
    semesterId: string;
    host: string;
}

type $ = cheerio.CheerioAPI;
type El = Parameters<$>[0];

function text($: $, el: El, name: string): string | null {
    const child = $(el).children(name).first();
    if (child.length === 0) return null;
    const value = child.text().replace(/\s+/g, ' ').trim();
    return value.length > 0 ? value : null;
}

function refs($: $, el: El, container: string): string[] {
    return $(el)
        .children(container)
        .find('UnivISRef')
        .map((_, r) => $(r).attr('key'))
        .get()
        .filter((k): k is string => typeof k === 'string' && k.length > 0);
}

function date(value: string | null): string | null {
    return isIsoDate(value) ? value : null;
}

function weekdays(list: string): number[] | null {
    const days = list.split(',').map((d) => Number(d.trim()));
    if (days.some((d) => !Number.isInteger(d) || d < 0 || d > 7)) return null;
    return [...new Set(days.map((d) => (d === 0 ? 7 : d)))].sort();
}

/** Wiederholungsmuster → Art, Intervall, Wochentage (1 = Mo … 7 = So). */
export function parseRepeat(raw: string | null): { kind: RepeatKind; intervalWeeks: number | null; weekdays: number[] } {
    const none = { kind: 'unknown' as const, intervalWeeks: null, weekdays: [] };
    if (raw == null) return none;
    const value = raw.trim();

    const weekly = /^w(\d+)\s+([\d,\s]+)$/.exec(value);
    if (weekly) {
        const days = weekdays(weekly[2]);
        const interval = Number(weekly[1]);
        return days && interval >= 1 ? { kind: 'weekly', intervalWeeks: interval, weekdays: days } : none;
    }
    if (value === 's1') return { kind: 'single', intervalWeeks: null, weekdays: [] };
    const block = /^bd\s+([\d,\s]+)$/.exec(value);
    if (block) {
        const days = weekdays(block[1]);
        return days ? { kind: 'block', intervalWeeks: null, weekdays: days } : none;
    }
    if (/^b\d*$/.test(value)) return { kind: 'block', intervalWeeks: null, weekdays: [] };
    return none;
}

/** Modulkürzel aus der Klammer am Titelende, z. B. „(DKA-Ein-ÜAT, DKA-AT1-Bib)“. */
export function moduleCodesFromTitle(title: string): string[] {
    const m = /\(([^()]+)\)\s*$/.exec(title);
    if (!m) return [];
    const parts = m[1].split(',').map((p) => p.trim()).filter(Boolean);
    // Nur wenn ALLE Teile wie Kürzel aussehen (kein Leerzeichen, mit Bindestrich);
    // „(Teil 1)“ oder „(mit Exkursion)“ sind keine Modulkürzel.
    const code = /^[\p{L}\d][\p{L}\d.]*(?:-[\p{L}\d.]+)+$/u;
    return parts.length > 0 && parts.every((p) => code.test(p)) ? parts : [];
}

function number(value: string | null): number | null {
    if (value == null) return null;
    const n = Number(value.replace(',', '.'));
    return Number.isFinite(n) ? n : null;
}

export function parseUnivisXml(xml: string, ctx: UnivisParseContext): ParsedCatalog {
    const $ = cheerio.load(xml, { xml: true });
    const root = $('UnivIS').first();
    if (root.length === 0) {
        throw new UnivisFormatError('Antwort ist kein UnivIS-XML (fehlendes <UnivIS>-Element).');
    }

    const warnings: string[] = [];
    const id = (key: string) => `${ctx.sourceId}:${key}`;

    const persons = new Map<string, Person>();
    root.children('Person').each((_, el) => {
        const key = $(el).attr('key');
        if (!key) return;
        const name = [text($, el, 'title'), text($, el, 'firstname'), text($, el, 'lastname')].filter(Boolean).join(' ');
        persons.set(key, { id: id(key), source: { sourceId: ctx.sourceId, key }, displayName: name || null });
    });

    const rooms = new Map<string, Room>();
    root.children('Room').each((_, el) => {
        const key = $(el).attr('key');
        if (!key) return;
        const shortName = text($, el, 'short');
        const name = text($, el, 'name');
        rooms.set(key, {
            id: id(key),
            source: { sourceId: ctx.sourceId, key },
            shortName,
            name,
            online: /online/i.test(`${shortName ?? ''} ${name ?? ''}`),
        });
    });

    const titles = new Map<string, string>();
    root.children('Title').each((_, el) => {
        const key = $(el).attr('key');
        const value = text($, el, 'title') ?? text($, el, 'name');
        if (key && value) titles.set(key, value);
    });

    const usedPersons = new Set<string>();
    const usedRooms = new Set<string>();
    const courses: SourceCourse[] = [];

    root.children('Lecture').each((_, el) => {
        const key = $(el).attr('key');
        const title = text($, el, 'name');
        if (!key || !title) {
            warnings.push(`Veranstaltung ohne ${key ? 'Titel' : 'Kennung'} übersprungen${key ? ` (${key})` : ''}`);
            return;
        }
        const courseId = `${ctx.sourceId}:${ctx.semesterId}:${key}`;

        const lecturerIds = refs($, el, 'dozs').flatMap((k) => {
            if (!persons.has(k)) {
                warnings.push(`unbekannte Lehrperson ${k} in ${key}`);
                return [];
            }
            usedPersons.add(k);
            return [id(k)];
        });

        const seenRuleIds = new Map<string, number>();
        const rules: SessionRule[] = $(el)
            .children('terms')
            .children('term')
            .map((_, term): SessionRule => {
                const raw = text($, term, 'repeat');
                const repeat = parseRepeat(raw);
                const roomKey = refs($, term, 'room')[0] ?? null;
                if (roomKey && !rooms.has(roomKey)) warnings.push(`unbekannter Raum ${roomKey} in ${key}`);
                if (roomKey && rooms.has(roomKey)) usedRooms.add(roomKey);
                const rule = {
                    kind: repeat.kind,
                    intervalWeeks: repeat.intervalWeeks,
                    weekdays: repeat.weekdays,
                    startTime: normalizeTime(text($, term, 'starttime')),
                    endTime: normalizeTime(text($, term, 'endtime')),
                    startDate: date(text($, term, 'startdate')),
                    endDate: date(text($, term, 'enddate')),
                    excludedDates: $(term)
                        .children('exclude')
                        .map((_, ex) => $(ex).text().trim())
                        .get()
                        .filter(isIsoDate)
                        .sort(),
                    roomId: roomKey && rooms.has(roomKey) ? id(roomKey) : null,
                    raw,
                };
                // Kennung aus dem Inhalt (ohne Ausfälle, damit ein neuer
                // Ausfall die Zuordnung nicht ändert); gleiche Regeln
                // innerhalb einer Veranstaltung werden durchnummeriert.
                const base = `${courseId}#${sha256(JSON.stringify([rule.raw, rule.startTime, rule.endTime, rule.startDate, rule.endDate, roomKey])).slice(0, 10)}`;
                const n = seenRuleIds.get(base) ?? 0;
                seenRuleIds.set(base, n + 1);
                return { id: n === 0 ? base : `${base}-${n + 1}`, ...rule };
            })
            .get();

        const lectureNumber = text($, el, 'number');
        courses.push({
            id: courseId,
            semesterId: ctx.semesterId,
            sources: [{ sourceId: ctx.sourceId, key }],
            number: lectureNumber,
            title,
            moduleCodes: moduleCodesFromTitle(title),
            type: text($, el, 'type'),
            sws: number(text($, el, 'sws')),
            ects: number(text($, el, 'ects_cred')),
            organizations: [text($, el, 'orgname')].filter((o): o is string => o != null),
            classification: refs($, el, 'classification').map((k) => titles.get(k)).filter((t): t is string => t != null),
            lecturerIds,
            rules,
            startDate: date(text($, el, 'startdate')),
            endDate: date(text($, el, 'enddate')),
            imported: text($, el, 'import_parent_id') != null,
            detailUrl: lectureNumber
                ? `https://${ctx.host}/prg?search=lectures&number=${encodeURIComponent(lectureNumber)}&sem=${encodeURIComponent(ctx.semesterId)}&show=llong`
                : null,
            internalId: text($, el, 'id'),
            importParentId: text($, el, 'import_parent_id'),
        });
    });

    return {
        courses,
        // Nur Personen und Räume, auf die eine Veranstaltung verweist.
        persons: [...persons.entries()].filter(([k]) => usedPersons.has(k)).map(([, p]) => p),
        rooms: [...rooms.entries()].filter(([k]) => usedRooms.has(k)).map(([, r]) => r),
        warnings,
    };
}
