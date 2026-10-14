// Dubletten: Dieselbe Veranstaltung erscheint in UnivIS mehrfach, wenn andere
// Einrichtungen sie importieren (Kiel, WS 2026/27: 70 von 150 importiert).
//
// Zusammengeführt wird nur, was eindeutig dieselbe Veranstaltung ist:
// 1. Import-Verknüpfung (`importParentId` zeigt auf die `internalId` der
//    anderen) UND gleiche Termine, oder
// 2. gleiche Veranstaltungsnummer UND gleicher Titel UND gleiche, nicht
//    leere Termine (gleiche Regeln samt Raum).
// Ähnliche Titel allein führen nie zusammen. Gleiche Nummer mit abweichendem
// Titel oder abweichenden Terminen (z. B. Parallelgruppen) bleibt getrennt und
// wird als `possibleDuplicates` gemeldet. Alle Quellkennungen bleiben erhalten.

import type { Course, SessionRule, SourceCourse } from './model';

export interface DedupeResult {
    courses: Course[];
    merged: { courseId: string; mergedKeys: string[]; reason: string }[];
    possible: { courseIds: string[]; reason: string }[];
}

/** Titelvergleich: Groß-/Kleinschreibung, Leerraum und Satzzeichen egal. */
export function normalizeTitle(title: string): string {
    return title
        .normalize('NFC')
        .toLowerCase()
        .replace(/[\s ]+/g, ' ')
        .replace(/[.,;:!?„“"'()[\]–-]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function ruleSignature(rule: SessionRule): string {
    return [
        rule.kind,
        rule.intervalWeeks ?? '',
        rule.weekdays.join(','),
        rule.startTime ?? '',
        rule.endTime ?? '',
        rule.startDate ?? '',
        rule.endDate ?? '',
        rule.roomId ?? '',
    ].join('|');
}

/** Termine einer Veranstaltung als vergleichbare Signatur (Reihenfolge egal). */
export function scheduleSignature(course: Course): string {
    return course.rules.map(ruleSignature).sort().join('\n');
}

function union<T>(...lists: T[][]): T[] {
    return [...new Set(lists.flat())];
}

/** Hauptfassung: nicht importiert vor importiert, sonst kleinste Kennung. */
function pickPrimary(group: SourceCourse[]): SourceCourse {
    return [...group].sort((a, b) =>
        a.imported !== b.imported ? (a.imported ? 1 : -1) : a.id < b.id ? -1 : 1,
    )[0];
}

function mergeGroup(group: SourceCourse[]): Course {
    const primary = pickPrimary(group);
    const others = group.filter((c) => c !== primary);
    return {
        ...stripSource(primary),
        sources: union(primary.sources, ...others.map((c) => c.sources)),
        organizations: union(primary.organizations, ...others.map((c) => c.organizations)),
        organizationPath: [primary, ...others].find((c) => (c.organizationPath?.length ?? 0) > 0)?.organizationPath ?? [],
        classification: union(primary.classification, ...others.map((c) => c.classification)),
        lecturerIds: union(primary.lecturerIds, ...others.map((c) => c.lecturerIds)),
        moduleCodes: union(primary.moduleCodes, ...others.map((c) => c.moduleCodes)),
    };
}

function stripSource(course: SourceCourse): Course {
    const { internalId: _i, importParentId: _p, ...rest } = course;
    return rest;
}

/** Einfache Union-Find-Struktur über Indizes. */
function groups(n: number, pairs: [number, number][]): number[][] {
    const parent = Array.from({ length: n }, (_, i) => i);
    const find = (i: number): number => (parent[i] === i ? i : (parent[i] = find(parent[i])));
    for (const [a, b] of pairs) parent[find(a)] = find(b);
    const byRoot = new Map<number, number[]>();
    for (let i = 0; i < n; i++) {
        const root = find(i);
        byRoot.set(root, [...(byRoot.get(root) ?? []), i]);
    }
    return [...byRoot.values()];
}

export function dedupeCourses(input: SourceCourse[]): DedupeResult {
    const pairs: [number, number][] = [];
    const reasons = new Map<string, string>();
    const possible: DedupeResult['possible'] = [];
    const signatures = input.map(scheduleSignature);
    const titles = input.map((c) => normalizeTitle(c.title));

    const byInternalId = new Map<string, number>();
    input.forEach((c, i) => c.internalId && byInternalId.set(c.internalId, i));

    // 1. Import-Verknüpfung.
    input.forEach((c, i) => {
        if (!c.importParentId) return;
        const j = byInternalId.get(c.importParentId);
        if (j === undefined || j === i) return;
        if (signatures[i] === signatures[j]) {
            pairs.push([i, j]);
            reasons.set(`${Math.min(i, j)}-${Math.max(i, j)}`, 'import');
        } else {
            possible.push({ courseIds: [input[j].id, c.id], reason: 'import-link-schedule-differs' });
        }
    });

    // 2. Gleiche Nummer, gleicher Titel, gleiche Termine.
    const byNumber = new Map<string, number[]>();
    input.forEach((c, i) => c.number && byNumber.set(c.number, [...(byNumber.get(c.number) ?? []), i]));
    for (const indices of byNumber.values()) {
        for (let x = 0; x < indices.length; x++) {
            for (let y = x + 1; y < indices.length; y++) {
                const [i, j] = [indices[x], indices[y]];
                const key = `${Math.min(i, j)}-${Math.max(i, j)}`;
                if (reasons.has(key)) continue;
                const sameTitle = titles[i] === titles[j];
                const sameSchedule = signatures[i] === signatures[j] && signatures[i] !== '';
                if (sameTitle && sameSchedule) {
                    pairs.push([i, j]);
                    reasons.set(key, 'number-title-schedule');
                } else {
                    possible.push({
                        courseIds: [input[i].id, input[j].id],
                        reason: sameTitle ? 'same-number-schedule-differs' : 'same-number-title-differs',
                    });
                }
            }
        }
    }

    const courses: Course[] = [];
    const merged: DedupeResult['merged'] = [];
    const mergedInto = new Map<string, string>();
    for (const group of groups(input.length, pairs)) {
        const members = group.map((i) => input[i]);
        const course = mergeGroup(members);
        courses.push(course);
        if (members.length > 1) {
            const why = new Set<string>();
            for (let x = 0; x < group.length; x++) {
                for (let y = x + 1; y < group.length; y++) {
                    const r = reasons.get(`${Math.min(group[x], group[y])}-${Math.max(group[x], group[y])}`);
                    if (r) why.add(r);
                }
            }
            merged.push({
                courseId: course.id,
                mergedKeys: members.filter((m) => m.id !== course.id).map((m) => m.sources[0].key),
                reason: [...why].sort().join('+'),
            });
            for (const m of members) mergedInto.set(m.id, course.id);
        }
    }

    // Hinweise auf mögliche Dubletten auf die zusammengeführten Kennungen
    // umschreiben und solche innerhalb einer Gruppe verwerfen.
    const seen = new Set<string>();
    const possibleOut = possible
        .map((p) => ({ ...p, courseIds: [...new Set(p.courseIds.map((id) => mergedInto.get(id) ?? id))].sort() }))
        .filter((p) => p.courseIds.length > 1)
        .filter((p) => {
            const key = `${p.courseIds.join(',')}|${p.reason}`;
            return seen.has(key) ? false : (seen.add(key), true);
        });

    courses.sort((a, b) => (a.id < b.id ? -1 : 1));
    return { courses, merged, possible: possibleOut };
}
