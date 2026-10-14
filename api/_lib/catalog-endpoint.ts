// Lesender Katalog-Endpunkt `/api/catalog` (Freigabe der UnivIS-Nutzung:
// docs/univis-integration-feasibility.md, Abschnitt 13).
//
//   GET /api/catalog                    → angebotene Semester
//   GET /api/catalog?semester=2026w     → Katalog der Theologischen Fakultät
//
// Sicherheit: Nur `GET`; Semester nur aus der Konfiguration (laufendes und
// nächstes), Einrichtung nur aus einer festen Liste – es gibt keinen Weg, eine
// beliebige Adresse abrufen zu lassen. Ausgabe nur in der öffentlichen Form
// (publish.ts). Protokolle enthalten nur Codes, nie Antwortinhalte.
//
// Cache (cache.ts): frisch → ohne UnivIS-Abruf; parallele Anfragen teilen
// einen Abruf; bei Ausfall letzter guter Stand als `stale`; sonst 503.
// Zusätzlich CDN-Cache über `Cache-Control: s-maxage`.

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { CatalogCache, CatalogUnavailableError, type PersistentCatalogStore } from './catalog/cache';
import { PUBLIC_CATALOG_VERSION, toPublicCatalog, type PublicCatalog } from './catalog/publish';
import { offeredSemesters } from './catalog/semesters';
import { buildSnapshot, sha256, type CatalogSource } from './catalog/source';
import { CAU_UNIVIS, UnivisSource } from './catalog/univis/source';

/** Einrichtungen, deren Katalog angeboten wird (UnivIS-OrgNr). */
export const ORGANIZATIONS: Record<string, string> = {
    '010000000': 'Theologische Fakultät',
};
export const DEFAULT_ORGANIZATION = '010000000';

const HOUR = 3_600_000;

export interface CatalogEndpointConfig {
    /** Gültigkeit eines Abrufs (Standard 24 h: etwa ein Abruf je Tag und Semester). */
    ttlMs: number;
    /** Wie lange ein alter Stand bei Ausfällen noch ausgeliefert wird. */
    maxStaleMs: number;
}

export function configFrom(env: NodeJS.ProcessEnv): CatalogEndpointConfig {
    const hours = (name: string, fallback: number, min: number, max: number) => {
        const value = Number(env[name]);
        return Number.isFinite(value) && value >= min && value <= max ? value : fallback;
    };
    return {
        ttlMs: hours('CATALOG_CACHE_TTL_HOURS', 24, 1, 168) * HOUR,
        maxStaleMs: hours('CATALOG_MAX_STALE_HOURS', 14 * 24, 24, 60 * 24) * HOUR,
    };
}

function berlinToday(now: number): string {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Berlin' }).format(new Date(now));
}

function single(value: string | string[] | undefined): string | undefined {
    return Array.isArray(value) ? undefined : value;
}

export interface CatalogEndpointDeps {
    source?: CatalogSource;
    persistent?: PersistentCatalogStore<PublicCatalog> | null;
    env?: NodeJS.ProcessEnv;
    now?: () => number;
    log?: (message: string) => void;
}

export function createCatalogHandler(deps: CatalogEndpointDeps = {}) {
    const env = deps.env ?? process.env;
    const now = deps.now ?? Date.now;
    const log = deps.log ?? ((m: string) => console.warn(`[catalog] ${m}`));
    const source = deps.source ?? new UnivisSource(CAU_UNIVIS);
    const config = configFrom(env);
    const cache = new CatalogCache<PublicCatalog>({
        ttlMs: config.ttlMs,
        maxStaleMs: config.maxStaleMs,
        sizeOf: (c) => c.courses.length,
        persistent: deps.persistent ?? null,
        now,
        log,
    });

    const handler = async (req: VercelRequest, res: VercelResponse) => {
        // Öffentliche, nur lesbare Daten ohne Anmeldung: Abruf von jeder
        // Herkunft erlaubt (z. B. lokale Web-Entwicklung).
        res.setHeader('Access-Control-Allow-Origin', '*');
        if (req.method !== 'GET' && req.method !== 'HEAD') {
            res.setHeader('Allow', 'GET, HEAD');
            return res.status(405).json({ error: 'Nur GET.' });
        }

        const offered = offeredSemesters(source.semesters, berlinToday(now()));
        const semesterParam = single(req.query.semester);
        const orgParam = single(req.query.organization) ?? DEFAULT_ORGANIZATION;

        if (semesterParam === undefined && req.query.semester === undefined) {
            res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=3600');
            return res.status(200).json({
                version: PUBLIC_CATALOG_VERSION,
                institution: source.institution,
                organizations: Object.entries(ORGANIZATIONS).map(([id, name]) => ({ id, name })),
                semesters: offered.map((s) => ({ id: s.id, label: s.label, start: s.start, end: s.end })),
            });
        }

        const semester = offered.find((s) => s.id === semesterParam);
        if (!semester) {
            return res.status(400).json({
                error: 'Unbekanntes oder nicht angebotenes Semester.',
                semesters: offered.map((s) => s.id),
            });
        }
        if (!(orgParam in ORGANIZATIONS)) {
            return res.status(400).json({ error: 'Unbekannte Einrichtung.' });
        }

        const query = { semesterId: semester.id, organizationId: orgParam };
        const key = `${source.sourceId}:${query.organizationId}:${query.semesterId}`;

        try {
            const result = await cache.get(key, async () => {
                const raw = await source.fetchRaw(query);
                return toPublicCatalog(buildSnapshot(source, query, raw, new Date(now())));
            });
            const body = JSON.stringify({
                ...result.value,
                cache: {
                    state: result.state,
                    fetchedAt: new Date(result.fetchedAt).toISOString(),
                    ...(result.reason ? { reason: result.reason } : {}),
                },
            });
            const etag = `"${sha256(`${result.value.provenance.contentHash}:${result.fetchedAt}`).slice(0, 32)}"`;
            const remaining = Math.max(60, Math.floor((config.ttlMs - (now() - result.fetchedAt)) / 1000));
            res.setHeader('ETag', etag);
            res.setHeader('X-Catalog-State', result.state);
            res.setHeader(
                'Cache-Control',
                result.state === 'stale'
                    // Alter Stand: nur kurz im CDN, damit eine Erholung der Quelle schnell sichtbar wird.
                    ? 'public, max-age=300, s-maxage=600'
                    : `public, max-age=3600, s-maxage=${remaining}, stale-while-revalidate=3600`,
            );
            if (req.headers['if-none-match'] === etag) return res.status(304).end();
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            return res.status(200).send(req.method === 'HEAD' ? '' : body);
        } catch (e) {
            if (e instanceof CatalogUnavailableError) {
                res.setHeader('Cache-Control', 'no-store');
                res.setHeader('Retry-After', '600');
                return res.status(503).json({
                    error: 'Der Veranstaltungskatalog ist derzeit nicht verfügbar. Bitte später erneut versuchen.',
                    code: 'source-unavailable',
                });
            }
            throw e;
        }
    };

    return Object.assign(handler, { cache });
}

/** Dauerhafter Speicher, falls das Firebase-Dienstkonto konfiguriert ist. */
function persistentFromEnv(): PersistentCatalogStore<PublicCatalog> | null {
    if (!process.env.FIREBASE_SERVICE_ACCOUNT?.trim()) return null;
    // Erst hier laden: ohne Konfiguration braucht der Endpunkt das Admin SDK nicht.
    const { firestore } = require('./push') as typeof import('./push');
    const { FirestoreCatalogStore, CATALOG_CACHE_COLLECTION } = require('./catalog/firestore-store') as typeof import('./catalog/firestore-store');
    // Je Umgebung getrennt: Ein Preview-Build darf den Produktions-Cache nie
    // überschreiben.
    const environment = (process.env.VERCEL_ENV ?? 'local').replace(/[^\w-]/g, '_');
    return new FirestoreCatalogStore<PublicCatalog>(
        (key) =>
            firestore()
                .collection(CATALOG_CACHE_COLLECTION)
                .doc(`${environment}__${key.replace(/[^\w.-]/g, '_')}`),
        PUBLIC_CATALOG_VERSION,
    );
}

export default createCatalogHandler({ persistent: persistentFromEnv() });
