// Öffentliche Form eines Katalogs für die App (Ausgabe von /api/catalog).
//
// Nur, was die App anzeigt oder zur Zuordnung braucht:
// * Personen nur mit Anzeigename (Titel, Vor-, Nachname – wie in UnivIS
//   öffentlich angezeigt) und einer gehashten Kennung: UnivIS-Personenschlüssel
//   enthalten Namensbestandteile und Einrichtungspfade und werden nicht
//   veröffentlicht.
// * Keine Freitexte, kein Roh-XML, keine internen Nummern (`internalId`),
//   keine Strukturwarnungen mit Quellkennungen.
// * Veranstaltungs- und Raumkennungen bleiben (für Zuordnung und Updates).

import type { CatalogSnapshot } from './model';
import { sha256 } from './source';

export const PUBLIC_CATALOG_VERSION = 1;

export interface PublicCatalog {
    version: number;
    synthetic: false;
    provenance: {
        sourceId: string;
        system: string;
        institution: string;
        url: string | null;
        fetchedAt: string;
        contentHash: string | null;
    };
    semester: CatalogSnapshot['semester'];
    courses: Array<Omit<CatalogSnapshot['courses'][number], 'lecturerIds'> & { lecturerIds: string[] }>;
    persons: Array<{ id: string; displayName: string | null }>;
    rooms: Array<{ id: string; shortName: string | null; name: string | null; online: boolean }>;
    occurrences: CatalogSnapshot['occurrences'];
    issues: Array<{ courseId: string; ruleId: string | null; code: string; severity: string; detail: string }>;
    counts: { courses: number; mergedDuplicates: number; occurrences: number };
}

/** Stabile, nicht sprechende Kennung einer Person im Katalog. */
export function publicPersonId(sourceId: string, personId: string): string {
    return `${sourceId}:p${sha256(personId).slice(0, 16)}`;
}

export function toPublicCatalog(snapshot: CatalogSnapshot): PublicCatalog {
    const sourceId = snapshot.provenance.sourceId;
    const personId = (id: string) => publicPersonId(sourceId, id);
    return {
        version: PUBLIC_CATALOG_VERSION,
        synthetic: false,
        provenance: {
            sourceId,
            system: snapshot.provenance.system,
            institution: snapshot.provenance.institution,
            url: snapshot.provenance.url,
            fetchedAt: snapshot.provenance.fetchedAt,
            contentHash: snapshot.provenance.contentHash,
        },
        semester: snapshot.semester,
        courses: snapshot.courses.map((c) => ({
            id: c.id,
            semesterId: c.semesterId,
            sources: c.sources,
            number: c.number,
            title: c.title,
            moduleCodes: c.moduleCodes,
            type: c.type,
            sws: c.sws,
            // Nur, was die Quelle angibt – nie geschätzt.
            ects: c.ects,
            organizations: c.organizations,
            organizationPath: c.organizationPath,
            classification: c.classification,
            lecturerIds: c.lecturerIds.map(personId),
            rules: c.rules,
            startDate: c.startDate,
            endDate: c.endDate,
            imported: c.imported,
            detailUrl: c.detailUrl,
        })),
        persons: snapshot.persons.map((p) => ({ id: personId(p.id), displayName: p.displayName })),
        rooms: snapshot.rooms.map((r) => ({ id: r.id, shortName: r.shortName, name: r.name, online: r.online })),
        occurrences: snapshot.occurrences,
        issues: snapshot.issues.map((i) => ({
            courseId: i.courseId,
            ruleId: i.ruleId,
            code: i.code,
            severity: i.severity,
            detail: i.detail,
        })),
        counts: {
            courses: snapshot.courses.length,
            mergedDuplicates: snapshot.mergedDuplicates.length,
            occurrences: snapshot.occurrences.length,
        },
    };
}
