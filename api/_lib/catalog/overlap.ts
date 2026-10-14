// Zeitliche Überschneidungen konkreter Termine. Intervalle sind halboffen
// [start, end): Endet ein Termin um 10:00 und beginnt der nächste um 10:00,
// ist das KEINE Überschneidung. Ausgefallene Termine zählen nicht.

import type { Occurrence } from './model';
import { epochMs } from './time';

export interface Overlap {
    a: Occurrence;
    b: Occurrence;
    minutes: number;
    /** Beide Termine gehören zur selben Veranstaltung (z. B. doppelte Regel). */
    sameCourse: boolean;
}

/**
 * Alle Paare sich überschneidender Termine (sortiert nach Beginn). Für einen
 * Stundenplan: nur die Termine der gewählten Veranstaltungen übergeben.
 */
export function findOverlaps(occurrences: Occurrence[]): Overlap[] {
    const items = occurrences
        .filter((o) => o.status !== 'cancelled')
        .map((o) => ({ o, start: epochMs(o.start), end: epochMs(o.end) }))
        .filter((x) => x.end > x.start)
        .sort((x, y) => x.start - y.start || x.end - y.end);

    const result: Overlap[] = [];
    const active: typeof items = [];
    for (const item of items) {
        // Abgelaufene entfernen (Ende <= Beginn: berührt nur).
        for (let k = active.length - 1; k >= 0; k--) {
            if (active[k].end <= item.start) active.splice(k, 1);
        }
        for (const other of active) {
            result.push({
                a: other.o,
                b: item.o,
                minutes: Math.round((Math.min(other.end, item.end) - item.start) / 60_000),
                sameCourse: other.o.courseId === item.o.courseId,
            });
        }
        active.push(item);
    }
    return result;
}

/** Überschneidungen zwischen den gewählten Veranstaltungen [courseIds]. */
export function overlapsBetween(occurrences: Occurrence[], courseIds: Iterable<string>): Overlap[] {
    const selected = new Set(courseIds);
    return findOverlaps(occurrences.filter((o) => selected.has(o.courseId)));
}
