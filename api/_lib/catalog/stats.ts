// Kennzahlen eines Katalogs ohne Inhalte: keine Titel, Namen, Räume oder
// Freitexte – nur Zählungen und Veranstaltungsnummern. Für öffentliche
// Protokolle (Erreichbarkeitstest, GitHub Actions) gedacht.

import type { CatalogSnapshot, ParsedCatalog } from './model';

export function catalogStats(parsed: ParsedCatalog, snapshot: CatalogSnapshot) {
    const count = <T>(items: T[], key: (t: T) => string) =>
        items.reduce<Record<string, number>>((acc, item) => {
            const k = key(item);
            acc[k] = (acc[k] ?? 0) + 1;
            return acc;
        }, {});

    const internalIds = new Set(parsed.courses.map((c) => c.internalId).filter(Boolean));
    const imported = parsed.courses.filter((c) => c.importParentId);
    const rules = snapshot.courses.flatMap((c) => c.rules.map((r) => ({ c, r })));
    // Nummern (nicht personenbezogen) je unsicherem Muster, für gezielte Gegenproben.
    const numbersFor = (pred: (r: (typeof rules)[number]['r']) => boolean) =>
        [...new Set(rules.filter(({ r }) => pred(r)).map(({ c }) => c.number ?? '?'))].sort().slice(0, 5);

    return {
        coursesParsed: parsed.courses.length,
        courses: snapshot.courses.length,
        importedCourses: imported.length,
        importParentsResolved: imported.filter((c) => internalIds.has(c.importParentId)).length,
        merged: count(snapshot.mergedDuplicates, (m) => m.reason),
        possibleDuplicates: count(snapshot.possibleDuplicates, (p) => p.reason),
        rules: rules.length,
        repeatKinds: count(rules, ({ r }) => (r.kind === 'weekly' ? `weekly/${r.intervalWeeks}` : r.kind)),
        occurrences: snapshot.occurrences.length,
        cancelled: snapshot.occurrences.filter((o) => o.status === 'cancelled').length,
        issues: count(snapshot.issues, (i) => `${i.severity}:${i.code}`),
        warnings: parsed.warnings.length,
        // Meldungen ohne Kennungen gruppiert (Kennungen sind sprechend, aber
        // für die Auswertung unnötig).
        warningKinds: count(parsed.warnings, (w) => w.replace(/ in \S+$/, '').replace(/ \(.*\)$/, '')),
        coursesWithoutOccurrences: snapshot.courses.filter((c) => !snapshot.occurrences.some((o) => o.courseId === c.id)).length,
        coursesWithModuleCodes: snapshot.courses.filter((c) => c.moduleCodes.length > 0).length,
        samples: {
            biweekly: numbersFor((r) => r.kind === 'weekly' && r.intervalWeeks !== 1),
            blockWithDays: numbersFor((r) => r.kind === 'block' && r.weekdays.length > 0),
            blockWithoutDays: numbersFor((r) => r.kind === 'block' && r.weekdays.length === 0),
        },
    };
}
