// Auflösung von Terminregeln in konkrete Termine eines Semesters.
//
// Deutung, gegen die Klartextansicht von UnivIS Kiel geprüft
// (docs/univis-integration-feasibility.md, Abschnitt 4):
// * wöchentlich (`w1 <Tage>`): jeder passende Wochentag im Zeitraum – das ist
//   der Zeitraum der Regel, sonst der der Veranstaltung („vom 18.10.2026 bis
//   7.2.2027“), jeweils begrenzt auf die Vorlesungszeit –, stets ohne
//   unterrichtsfreie Zeiten (in Kiel zusätzlich als `exclude` = `vac`
//   gekennzeichnet). Ausfalldaten (`exclude` mit Datum) bleiben als
//   `cancelled` sichtbar.
// * 14-täglich (`w2`): nur mit Startdatum der Regel; sonst ist die Startwoche
//   unbekannt (die Klartextansicht nennt sie nicht) und es entstehen KEINE
//   Termine (`biweekly-phase-unknown`).
// * Einzeltermin (`s1`): genau das angegebene Datum.
// * Block mit Tagen (`bd <Tage>`): die genannten Wochentage im Zeitraum der
//   Regel („Blockveranstaltung 12.10.2026 - 16.10.2026“ ↔ `bd 1,2,3,4,5`).
// * Block ohne Tage (`b1`): EIN durchgehender Zeitraum vom Start- bis zum
//   Endzeitpunkt („Blockveranstaltung 5.2.2027 9:15 - 8.2.2027 19:45“);
//   mehrtägig mit Hinweis `block-continuous`.
// * fehlende/ungültige Uhrzeiten oder Daten, unbekannte Muster: keine Termine.
//
// Semestergrenzen: Termine außerhalb des Semesters werden verworfen
// (`outside-semester`).

import type { Course, IsoDate, Occurrence, ScheduleIssue, Semester, SessionRule } from './model';
import { addDays, eachDay, epochMs, isoWeekday, minutesOf, zonedDateTime } from './time';

export interface Resolution {
    occurrences: Occurrence[];
    issues: ScheduleIssue[];
}

interface Slot {
    date: IsoDate;
    /** Enddatum bei durchgehenden Blöcken, sonst gleich `date`. */
    endDate: IsoDate;
}

/**
 * Bekannte Ausschluss-Kennzeichen. `vac` (Kiel, 24 Regeln im WS 2026/27):
 * vorlesungsfreie Zeit ausgenommen – das tut die Auflösung für wöchentliche
 * Regeln ohnehin (`Semester.breaks`), daher ohne Wirkung.
 */
const KNOWN_EXCLUDE_CODES = new Set(['vac']);

function inBreak(semester: Semester, date: IsoDate): boolean {
    return semester.breaks.some((b) => date >= b.start && date <= b.end);
}

function later(a: IsoDate, b: IsoDate | null): IsoDate {
    return b && b > a ? b : a;
}

function earlier(a: IsoDate, b: IsoDate | null): IsoDate {
    return b && b < a ? b : a;
}

function issue(
    course: Course,
    rule: SessionRule | null,
    code: ScheduleIssue['code'],
    severity: ScheduleIssue['severity'],
    detail: string,
): ScheduleIssue {
    return { courseId: course.id, ruleId: rule?.id ?? null, code, severity, detail };
}

/** Kandidaten einer Regel oder null (dann ist ein Hinweis erfasst). */
function slotsFor(course: Course, rule: SessionRule, semester: Semester, issues: ScheduleIssue[]): Slot[] | null {
    const warn = (code: ScheduleIssue['code'], detail: string) => {
        issues.push(issue(course, rule, code, 'warning', detail));
        return null;
    };
    const days = (dates: IsoDate[]) => dates.map((date) => ({ date, endDate: date }));

    switch (rule.kind) {
        case 'single': {
            const date = rule.startDate ?? rule.endDate;
            if (!date) return warn('missing-date', 'Einzeltermin ohne Datum');
            if (rule.startDate && rule.endDate && rule.startDate !== rule.endDate) {
                return warn('unknown-pattern', `Einzeltermin mit Zeitraum ${rule.startDate}–${rule.endDate}`);
            }
            return days([date]);
        }

        case 'weekly': {
            if (rule.weekdays.length === 0) return warn('unknown-pattern', `wöchentlich ohne Wochentag (${rule.raw})`);
            const hasOwnRange = rule.startDate != null || rule.endDate != null;
            const from = hasOwnRange
                ? rule.startDate ?? semester.lectureStart
                : later(semester.lectureStart, course.startDate);
            const to = hasOwnRange
                ? rule.endDate ?? semester.lectureEnd
                : earlier(semester.lectureEnd, course.endDate);
            if (from > to) return warn('missing-date', `Zeitraum ${from}–${to} ist leer`);
            const interval = rule.intervalWeeks ?? 1;

            if (interval === 1) {
                return days([...eachDay(from, to)]
                    .filter((d) => rule.weekdays.includes(isoWeekday(d)))
                    .filter((d) => !inBreak(semester, d)));
            }
            if (!rule.startDate) {
                return warn('biweekly-phase-unknown',
                    `alle ${interval} Wochen (${rule.raw}) ohne Startdatum der Regel – Startwoche unbekannt`);
            }
            const dates: IsoDate[] = [];
            for (const weekday of rule.weekdays) {
                let d = rule.startDate;
                while (isoWeekday(d) !== weekday) d = addDays(d, 1);
                for (; d <= to; d = addDays(d, 7 * interval)) dates.push(d);
            }
            return days(dates.filter((d) => !inBreak(semester, d)).sort());
        }

        case 'block': {
            if (!rule.startDate || !rule.endDate) return warn('missing-date', `Block ohne Zeitraum (${rule.raw})`);
            if (rule.startDate > rule.endDate) return warn('missing-date', `Zeitraum ${rule.startDate}–${rule.endDate} ist leer`);
            if (rule.weekdays.length > 0) {
                return days([...eachDay(rule.startDate, rule.endDate)].filter((d) => rule.weekdays.includes(isoWeekday(d))));
            }
            if (rule.startDate !== rule.endDate) {
                issues.push(issue(course, rule, 'block-continuous', 'info',
                    `durchgehender Block ${rule.startDate} ${rule.startTime ?? ''} bis ${rule.endDate} ${rule.endTime ?? ''}`.replace(/\s+/g, ' ')));
            }
            return [{ date: rule.startDate, endDate: rule.endDate }];
        }

        default:
            return warn('unknown-pattern', `unbekanntes Muster ${JSON.stringify(rule.raw)}`);
    }
}

/** Löst alle Regeln einer Veranstaltung für [semester] auf. */
export function resolveCourse(course: Course, semester: Semester): Resolution {
    const issues: ScheduleIssue[] = [];
    const occurrences: Occurrence[] = [];

    if (course.rules.length === 0) {
        issues.push(issue(course, null, 'no-rules', 'info', 'keine Terminangabe (z. B. nach Vereinbarung)'));
    }

    for (const rule of course.rules) {
        if (!rule.startTime || !rule.endTime) {
            issues.push(issue(course, rule, 'missing-time', 'warning', `Uhrzeit fehlt (${rule.raw ?? 'ohne Muster'})`));
            continue;
        }
        const continuous = rule.kind === 'block' && rule.weekdays.length === 0 && rule.startDate !== rule.endDate;
        if (!continuous && minutesOf(rule.endTime) <= minutesOf(rule.startTime)) {
            issues.push(issue(course, rule, 'invalid-time', 'warning', `Ende ${rule.endTime} nicht nach Beginn ${rule.startTime}`));
            continue;
        }
        const unknownCodes = rule.excludeCodes.filter((c) => !KNOWN_EXCLUDE_CODES.has(c));
        if (unknownCodes.length > 0) {
            issues.push(issue(course, rule, 'exclude-code-unknown', 'info',
                `Ausschluss-Kennzeichen ${unknownCodes.join(', ')} (Bedeutung ungeklärt, nicht angewendet)`));
        }

        const slots = slotsFor(course, rule, semester, issues);
        if (!slots) continue;

        const inSemester = slots.filter((s) => s.date >= semester.start && s.endDate <= semester.end);
        if (inSemester.length < slots.length) {
            issues.push(issue(course, rule, 'outside-semester', 'warning',
                `${slots.length - inSemester.length} Termin(e) außerhalb ${semester.start}–${semester.end} verworfen`));
        }

        const dates = new Set(inSemester.map((s) => s.date));
        const unmatched = rule.excludedDates.filter((d) => !dates.has(d));
        if (unmatched.length > 0) {
            issues.push(issue(course, rule, 'exclude-not-matching', 'info', `Ausfalldatum ohne passenden Termin: ${unmatched.join(', ')}`));
        }

        for (const slot of inSemester) {
            const start = zonedDateTime(slot.date, rule.startTime, semester.timeZone);
            const end = zonedDateTime(slot.endDate, rule.endTime, semester.timeZone);
            if (!start || !end) {
                issues.push(issue(course, rule, 'nonexistent-local-time', 'warning',
                    `${slot.date} ${rule.startTime}–${rule.endTime} existiert wegen der Zeitumstellung nicht`));
                continue;
            }
            if (epochMs(end) <= epochMs(start)) {
                issues.push(issue(course, rule, 'invalid-time', 'warning', `Ende ${slot.endDate} ${rule.endTime} nicht nach Beginn`));
                continue;
            }
            occurrences.push({
                id: `${rule.id}@${slot.date}`,
                courseId: course.id,
                ruleId: rule.id,
                date: slot.date,
                start,
                end,
                roomId: rule.roomId,
                status: rule.excludedDates.includes(slot.date) ? 'cancelled' : 'scheduled',
            });
        }
    }

    occurrences.sort((a, b) => epochMs(a.start) - epochMs(b.start) || (a.id < b.id ? -1 : 1));
    return { occurrences, issues };
}
