// Semesterdaten je Hochschule. Bewusst gepflegt statt aus UnivIS gelesen:
// UnivIS liefert keine Vorlesungszeit, und wiederkehrende Termine brauchen
// einen belegten Rahmen. Jede Angabe nennt ihre Quelle.

import type { Semester } from './model';

const CAU_DATES = 'https://www.uni-kiel.de/gf-praesidium/de/service-und-organisationshilfen/termine/zentrale-termine';
const CAU_DATES_EN = 'https://www.international.uni-kiel.de/en/incomings/application-admission/non-degree/erasmus-incomings/before-your-stay/academic-timetable-semester-dates';

/**
 * CAU Kiel (Quelle: zentrale Termine der CAU bzw. Semesterdaten des
 * International Center, Stand 14.10.2026). Gesetzliche Feiertage in
 * Schleswig-Holstein, die auf Vorlesungstage fallen, stehen als `breaks`.
 * Ein neues Semester wird hier erst eingetragen, wenn seine Daten offiziell
 * veröffentlicht sind – ohne Eintrag liefert der Katalog-Endpunkt es nicht.
 */
export const CAU_SEMESTERS: Record<string, Semester> = {
    '2026w': {
        id: '2026w',
        label: 'Wintersemester 2026/27',
        start: '2026-10-01',
        end: '2027-03-31',
        lectureStart: '2026-10-12',
        lectureEnd: '2027-02-12',
        breaks: [{ start: '2026-12-21', end: '2027-01-03', label: 'unterrichtsfrei (Jahreswechsel)' }],
        timeZone: 'Europe/Berlin',
        reference: CAU_DATES,
    },
    '2027s': {
        id: '2027s',
        label: 'Sommersemester 2027',
        start: '2027-04-01',
        end: '2027-09-30',
        lectureStart: '2027-04-05',
        lectureEnd: '2027-07-16',
        breaks: [
            { start: '2027-05-06', end: '2027-05-06', label: 'Feiertag (Christi Himmelfahrt)' },
            { start: '2027-05-17', end: '2027-05-17', label: 'Feiertag (Pfingstmontag)' },
        ],
        timeZone: 'Europe/Berlin',
        reference: CAU_DATES_EN,
    },
};

/**
 * Angebotene Semester zum Datum [today] (`YYYY-MM-DD`): das laufende und das
 * nächste konfigurierte, nach Beginn sortiert. Liegt [today] zwischen zwei
 * Semestern, sind es die nächsten beiden.
 */
export function offeredSemesters(semesters: Record<string, Semester>, today: string, count = 2): Semester[] {
    return Object.values(semesters)
        .filter((s) => s.end >= today)
        .sort((a, b) => (a.start < b.start ? -1 : 1))
        .slice(0, count);
}

/** UnivIS-Semesterkennung (`2026w`) → Semester der Konfiguration. */
export function semesterFor(semesters: Record<string, Semester>, id: string): Semester {
    const semester = semesters[id];
    if (!semester) throw new Error(`Semester ${id} ist nicht konfiguriert.`);
    return semester;
}
