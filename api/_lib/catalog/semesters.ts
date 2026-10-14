// Semesterdaten je Hochschule. Bewusst gepflegt statt aus UnivIS gelesen:
// UnivIS liefert keine Vorlesungszeit, und wiederkehrende Termine brauchen
// einen belegten Rahmen. Jede Angabe nennt ihre Quelle.

import type { Semester } from './model';

const CAU_DATES = 'https://www.uni-kiel.de/gf-praesidium/de/service-und-organisationshilfen/termine/zentrale-termine';

/** CAU Kiel (Quelle: zentrale Termine der CAU, Stand 14.10.2026). */
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
};

/** UnivIS-Semesterkennung (`2026w`) → Semester der Konfiguration. */
export function semesterFor(semesters: Record<string, Semester>, id: string): Semester {
    const semester = semesters[id];
    if (!semester) throw new Error(`Semester ${id} ist nicht konfiguriert.`);
    return semester;
}
