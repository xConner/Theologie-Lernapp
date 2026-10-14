// Auflösung von Terminregeln in konkrete Termine eines Semesters.
//
// Regeln (Belege: docs/univis-integration-feasibility.md, Abschnitt 3):
// * wöchentlich (`w1 <Tage>`): jeder passende Wochentag in der
//   Vorlesungszeit – oder im Zeitraum der Regel, wenn sie einen angibt –,
//   stets ohne unterrichtsfreie Zeiten; Ausfalldaten (`exclude`) werden als
//   `cancelled` geführt, nicht verschwiegen.
// * 14-täglich (`w2`): nur mit Startdatum der Regel; sonst ist die Startwoche
//   unbekannt und es entstehen KEINE Termine (Hinweis `biweekly-phase-unknown`).
// * Einzeltermin (`s1`): genau das angegebene Datum.
// * Block mit Tagen (`bd <Tage>`): passende Wochentage im Zeitraum der Regel;
//   Deutung nicht gegen den Klartext geprüft → Hinweis `block-unverified`.
// * Block ohne Tage (`b1`): nur bei eintägigem Zeitraum eindeutig; sonst
//   keine Termine (unklar, ob Wochenenden dazugehören).
// * fehlende/ungültige Uhrzeiten oder Daten, unbekannte Muster: keine Termine.
//
// Semestergrenzen: Termine außerhalb des Semesters werden nicht erzeugt
// (Hinweis `outside-semester`). Der Zeitraum der Veranstaltung selbst
// (`Course.startDate/endDate`) schränkt NICHT ein – seine Bedeutung in UnivIS
// ist unklar (in Kiel teils Sonntage); Abweichungen werden nur gemeldet.

import type { Course, IsoDate, Occurrence, ScheduleIssue, Semester, SessionRule } from './model';
import { addDays, eachDay, isoWeekday, minutesOf, zonedDateTime } from './time';

export interface Resolution {
    occurrences: Occurrence[];
    issues: ScheduleIssue[];
}

function inBreak(semester: Semester, date: IsoDate): boolean {
    return semester.breaks.some((b) => date >= b.start && date <= b.end);
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

/** Kandidatendaten einer Regel oder null mit Begründung. */
function candidateDates(
    course: Course,
    rule: SessionRule,
    semester: Semester,
    issues: ScheduleIssue[],
): IsoDate[] | null {
    const warn = (code: ScheduleIssue['code'], detail: string) => {
        issues.push(issue(course, rule, code, 'warning', detail));
        return null;
    };

    switch (rule.kind) {
        case 'single': {
            const date = rule.startDate ?? rule.endDate;
            if (!date) return warn('missing-date', 'Einzeltermin ohne Datum');
            if (rule.startDate && rule.endDate && rule.startDate !== rule.endDate) {
                return warn('unknown-pattern', `Einzeltermin mit Zeitraum ${rule.startDate}–${rule.endDate}`);
            }
            return [date];
        }

        case 'weekly': {
            if (rule.weekdays.length === 0) return warn('unknown-pattern', `wöchentlich ohne Wochentag (${rule.raw})`);
            const interval = rule.intervalWeeks ?? 1;
            const from = rule.startDate ?? semester.lectureStart;
            const to = rule.endDate ?? semester.lectureEnd;
            if (from > to) return warn('missing-date', `Zeitraum ${from}–${to} ist leer`);

            if (interval === 1) {
                return [...eachDay(from, to)]
                    .filter((d) => rule.weekdays.includes(isoWeekday(d)))
                    .filter((d) => !inBreak(semester, d));
            }

            if (!rule.startDate) {
                return warn(
                    'biweekly-phase-unknown',
                    `alle ${interval} Wochen (${rule.raw}), aber ohne Startdatum – Startwoche unbekannt`,
                );
            }
            // Erster Termin: der erste passende Wochentag ab dem Startdatum.
            const dates: IsoDate[] = [];
            for (const weekday of rule.weekdays) {
                let d = rule.startDate;
                while (isoWeekday(d) !== weekday) d = addDays(d, 1);
                for (; d <= to; d = addDays(d, 7 * interval)) dates.push(d);
            }
            return dates.filter((d) => !inBreak(semester, d)).sort();
        }

        case 'block': {
            if (!rule.startDate || !rule.endDate) return warn('missing-date', `Block ohne Zeitraum (${rule.raw})`);
            if (rule.startDate > rule.endDate) return warn('missing-date', `Zeitraum ${rule.startDate}–${rule.endDate} ist leer`);
            if (rule.weekdays.length > 0) {
                issues.push(issue(course, rule, 'block-unverified', 'info', `Block ${rule.raw}: Wochentage im Zeitraum angenommen`));
                return [...eachDay(rule.startDate, rule.endDate)].filter((d) => rule.weekdays.includes(isoWeekday(d)));
            }
            if (rule.startDate === rule.endDate) return [rule.startDate];
            return warn(
                'block-pattern-unclear',
                `Block ${rule.raw} über ${rule.startDate}–${rule.endDate} ohne Tagesangabe – unklar, welche Tage`,
            );
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
        if (minutesOf(rule.endTime) <= minutesOf(rule.startTime)) {
            issues.push(issue(course, rule, 'invalid-time', 'warning', `Ende ${rule.endTime} nicht nach Beginn ${rule.startTime}`));
            continue;
        }

        const dates = candidateDates(course, rule, semester, issues);
        if (!dates) continue;

        const inSemester = dates.filter((d) => d >= semester.start && d <= semester.end);
        if (inSemester.length < dates.length) {
            issues.push(issue(course, rule, 'outside-semester', 'warning',
                `${dates.length - inSemester.length} Termin(e) außerhalb ${semester.start}–${semester.end} verworfen`));
        }

        const excluded = new Set(rule.excludedDates);
        const unmatched = rule.excludedDates.filter((d) => !inSemester.includes(d));
        if (unmatched.length > 0) {
            issues.push(issue(course, rule, 'exclude-not-matching', 'info',
                `Ausfalldatum ohne passenden Termin: ${unmatched.join(', ')}`));
        }

        for (const date of inSemester) {
            const start = zonedDateTime(date, rule.startTime, semester.timeZone);
            const end = zonedDateTime(date, rule.endTime, semester.timeZone);
            if (!start || !end) {
                issues.push(issue(course, rule, 'nonexistent-local-time', 'warning',
                    `${date} ${rule.startTime}–${rule.endTime} existiert wegen der Zeitumstellung nicht`));
                continue;
            }
            occurrences.push({
                id: `${rule.id}@${date}`,
                courseId: course.id,
                ruleId: rule.id,
                date,
                start,
                end,
                roomId: rule.roomId,
                status: excluded.has(date) ? 'cancelled' : 'scheduled',
            });
        }
    }

    // Abweichender Zeitraum der Veranstaltung: nur melden.
    if (course.startDate || course.endDate) {
        const from = course.startDate ?? '0000-01-01';
        const to = course.endDate ?? '9999-12-31';
        const outside = occurrences.filter((o) => o.date < from || o.date > to).length;
        if (outside > 0) {
            issues.push(issue(course, null, 'course-range-differs', 'info',
                `${outside} Termin(e) außerhalb des Veranstaltungszeitraums ${course.startDate ?? '…'}–${course.endDate ?? '…'}`));
        }
    }

    occurrences.sort((a, b) => (a.start < b.start ? -1 : a.start > b.start ? 1 : a.id < b.id ? -1 : 1));
    return { occurrences, issues };
}
