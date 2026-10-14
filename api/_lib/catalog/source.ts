// Austauschbare Katalogquelle. UnivIS ist eine Implementierung
// (`univis/source.ts`); ein späterer HISinOne-Adapter implementiert dieselbe
// Schnittstelle, ohne dass Pipeline, Endpunkte oder App sich ändern.
//
// Ablauf: fetchRaw (Netz, einziger Seiteneffekt) → parse (Quellformat →
// SourceCourse) → dedupeCourses → resolveCourse je Veranstaltung.
// `buildSnapshot` ist rein und wird ohne Netzwerk getestet.

import { createHash } from 'node:crypto';
import { dedupeCourses } from './dedupe';
import type { CatalogSnapshot, ParsedCatalog, Provenance, Semester } from './model';
import { resolveCourse } from './schedule';
import { semesterFor } from './semesters';

export interface CatalogQuery {
    /** Systemneutrale Semesterkennung, z. B. `2026w`. */
    semesterId: string;
    /** Einrichtung in der Kennung der Quelle (UnivIS: neunstellige OrgNr). */
    organizationId: string;
}

export interface RawResponse {
    body: string;
    url: string;
    status: number;
    contentType: string | null;
}

export interface CatalogSource {
    readonly sourceId: string;
    readonly system: Provenance['system'];
    readonly institution: string;
    readonly semesters: Record<string, Semester>;
    /** Genau eine Anfrage an das Quellsystem. */
    fetchRaw(query: CatalogQuery, options?: { signal?: AbortSignal }): Promise<RawResponse>;
    /** Titel- bzw. Nummernsuche (genau eine Anfrage), falls die Quelle sie anbietet. */
    fetchSearchRaw?(query: import('./search').SearchQuery, options?: { signal?: AbortSignal }): Promise<RawResponse>;
    /** Quellformat → normalisierte Veranstaltungen (ohne Netzwerk). */
    parse(body: string, query: CatalogQuery): ParsedCatalog;
}

export function sha256(text: string): string {
    return createHash('sha256').update(text).digest('hex');
}

/** Rohantwort → vollständiger, aufgelöster Katalog (rein). */
export function buildSnapshot(
    source: CatalogSource,
    query: CatalogQuery,
    raw: RawResponse,
    fetchedAt: Date,
): CatalogSnapshot & { warnings: string[] } {
    const semester = semesterFor(source.semesters, query.semesterId);
    const parsed = source.parse(raw.body, query);
    const { courses, merged, possible } = dedupeCourses(parsed.courses);

    const occurrences: CatalogSnapshot['occurrences'] = [];
    const issues: CatalogSnapshot['issues'] = [];
    for (const course of courses) {
        const r = resolveCourse(course, semester);
        occurrences.push(...r.occurrences);
        issues.push(...r.issues);
    }

    return {
        provenance: {
            sourceId: source.sourceId,
            system: source.system,
            institution: source.institution,
            url: raw.url,
            fetchedAt: fetchedAt.toISOString(),
            contentHash: sha256(raw.body),
        },
        semester,
        courses,
        persons: parsed.persons,
        rooms: parsed.rooms,
        occurrences,
        issues,
        mergedDuplicates: merged,
        possibleDuplicates: possible,
        warnings: parsed.warnings,
    };
}

/** Abruf + Aufbau. Kein regelmäßiger Aufruf vorgesehen, solange die Nutzungsrechte offen sind. */
export async function loadCatalog(
    source: CatalogSource,
    query: CatalogQuery,
    options: { signal?: AbortSignal; now?: () => Date } = {},
) {
    const raw = await source.fetchRaw(query, { signal: options.signal });
    return buildSnapshot(source, query, raw, (options.now ?? (() => new Date()))());
}
