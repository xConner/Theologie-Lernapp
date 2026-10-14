// Lesender Katalog-Endpunkt `/api/catalog` (Freigabe der UnivIS-Nutzung:
// docs/univis-integration-feasibility.md, Abschnitt 13).
//
//   GET /api/catalog                    → angebotene Semester und Fakultäten
//   GET /api/catalog?semester=2026w     → Katalog der Theologischen Fakultät
//   GET /api/catalog?semester=2026w&q=Ethik[&faculty=050000000]
//   GET /api/catalog?semester=2026w&number=010076
//                                       → fakultätsübergreifende Suche (search.ts)
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
import {
    CAU_FACULTIES,
    fallbackWord,
    keepCourses,
    matchesAllWords,
    normalizeLectureNumber,
    normalizeSearchText,
    SEARCH_MAX_RESULTS,
    trimSnapshot,
    type SearchQuery,
} from './catalog/search';
import { buildSnapshot, sha256, type CatalogSource } from './catalog/source';
import { CAU_UNIVIS, ResponseTooLargeError, UnivisSource } from './catalog/univis/source';

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
    /** Gültigkeit eines Suchergebnisses. */
    searchTtlMs: number;
    /** Höchstzahl der Suchanfragen an UnivIS je Minute und Funktionsinstanz. */
    searchPerMinute: number;
}

export function configFrom(env: NodeJS.ProcessEnv): CatalogEndpointConfig {
    const hours = (name: string, fallback: number, min: number, max: number) => {
        const value = Number(env[name]);
        return Number.isFinite(value) && value >= min && value <= max ? value : fallback;
    };
    return {
        ttlMs: hours('CATALOG_CACHE_TTL_HOURS', 24, 1, 168) * HOUR,
        maxStaleMs: hours('CATALOG_MAX_STALE_HOURS', 14 * 24, 24, 60 * 24) * HOUR,
        searchTtlMs: hours('CATALOG_SEARCH_TTL_HOURS', 12, 1, 168) * HOUR,
        searchPerMinute: hours('CATALOG_SEARCH_PER_MINUTE', 20, 1, 120),
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

    // Suchergebnisse: eigener Zwischenspeicher, begrenzte Größe, kein
    // dauerhafter Speicher; weniger Treffer als zuvor sind hier normal.
    const searchCache = new CatalogCache<PublicSearchResult>({
        ttlMs: config.searchTtlMs,
        maxStaleMs: 7 * 24 * HOUR,
        minSizeRatio: 0,
        maxEntries: 300,
        sizeOf: (c) => c.courses.length,
        now,
        log,
    });
    const recentSearchFetches: number[] = [];
    const takeSearchBudget = () => {
        const t = now();
        while (recentSearchFetches.length > 0 && t - recentSearchFetches[0] >= 60_000) recentSearchFetches.shift();
        if (recentSearchFetches.length >= config.searchPerMinute) return false;
        recentSearchFetches.push(t);
        return true;
    };

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

        if (semesterParam === undefined && req.query.semester === undefined && req.query.q === undefined && req.query.number === undefined) {
            res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=3600');
            return res.status(200).json({
                version: PUBLIC_CATALOG_VERSION,
                institution: source.institution,
                organizations: Object.entries(ORGANIZATIONS).map(([id, name]) => ({ id, name })),
                faculties: Object.entries(CAU_FACULTIES).map(([id, name]) => ({ id, name })),
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
        if (req.query.q !== undefined || req.query.number !== undefined) {
            return search(req, res, semester.id);
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

    async function search(req: VercelRequest, res: VercelResponse, semesterId: string) {
        const number = req.query.number === undefined ? undefined : normalizeLectureNumber(single(req.query.number));
        const text = req.query.q === undefined ? undefined : normalizeSearchText(single(req.query.q));
        const facultyParam = single(req.query.faculty);
        if (number === null || text === null || (number !== undefined && text !== undefined)) {
            return res.status(400).json({
                error: 'Bitte einen Suchbegriff (3 bis 80 Zeichen) oder eine sechsstellige Veranstaltungsnummer angeben.',
                code: 'invalid-query',
            });
        }
        if (req.query.faculty !== undefined && (facultyParam === undefined || !(facultyParam in CAU_FACULTIES))) {
            return res.status(400).json({ error: 'Unbekannte Fakultät.', code: 'invalid-faculty' });
        }
        if (!source.fetchSearchRaw) {
            return res.status(501).json({ error: 'Die Quelle bietet keine Suche an.', code: 'not-supported' });
        }
        const query: SearchQuery = {
            semesterId,
            ...(number !== undefined ? { number } : { text: text! }),
            ...(facultyParam !== undefined ? { facultyId: facultyParam } : {}),
        };
        const key = `${source.sourceId}:search:${semesterId}:${query.facultyId ?? 'all'}:${
            query.number ?? `q=${query.text!.toLowerCase()}`
        }`;
        if (!searchCache.hasFresh(key) && !takeSearchBudget()) {
            res.setHeader('Retry-After', '30');
            res.setHeader('Cache-Control', 'no-store');
            return res.status(429).json({
                error: 'Gerade laufen sehr viele Suchanfragen. Bitte in einer halben Minute erneut versuchen.',
                code: 'rate-limited',
            });
        }
        try {
            const result = await searchCache.get(key, async () => {
                const build = (raw: Awaited<ReturnType<NonNullable<CatalogSource['fetchSearchRaw']>>>) =>
                    buildSnapshot(source, { semesterId, organizationId: query.facultyId ?? 'all' }, raw, new Date(now()));
                let full = build(await source.fetchSearchRaw!(query));
                let match: 'phrase' | 'words' = 'phrase';
                // UnivIS sucht Wortgruppen zusammenhängend. Findet die Gruppe
                // nichts, einmal mit dem längsten Wort suchen und nur Titel
                // mit allen Wörtern behalten (z. B. „Ethik Einführung“).
                const word = query.text ? fallbackWord(query.text) : null;
                if (full.courses.length === 0 && word && takeSearchBudget()) {
                    const wide = build(await source.fetchSearchRaw!({ ...query, text: word }));
                    full = keepCourses(wide, wide.courses.filter((c) => matchesAllWords(c.title, query.text!)));
                    match = 'words';
                }
                const snapshot = trimSnapshot(full, query);
                return {
                    ...toPublicCatalog(snapshot),
                    search: {
                        text: query.text ?? null,
                        number: query.number ?? null,
                        faculty: query.facultyId ?? null,
                        total: snapshot.total,
                        returned: snapshot.courses.length,
                        truncated: snapshot.total > snapshot.courses.length,
                        limit: SEARCH_MAX_RESULTS,
                        match,
                    },
                };
            });
            res.setHeader('X-Catalog-State', result.state);
            res.setHeader(
                'Cache-Control',
                result.state === 'stale' ? 'public, max-age=300, s-maxage=600' : 'public, max-age=600, s-maxage=3600',
            );
            res.setHeader('Content-Type', 'application/json; charset=utf-8');
            return res.status(200).send(
                req.method === 'HEAD'
                    ? ''
                    : JSON.stringify({
                          ...result.value,
                          cache: {
                              state: result.state,
                              fetchedAt: new Date(result.fetchedAt).toISOString(),
                              ...(result.reason ? { reason: result.reason } : {}),
                          },
                      }),
            );
        } catch (e) {
            if (e instanceof CatalogUnavailableError) {
                res.setHeader('Cache-Control', 'no-store');
                if (e.cause instanceof ResponseTooLargeError) {
                    return res.status(422).json({
                        error: 'Zu viele Treffer – bitte den Suchbegriff genauer fassen oder eine Fakultät wählen.',
                        code: 'too-many-results',
                    });
                }
                res.setHeader('Retry-After', '600');
                return res.status(503).json({
                    error: 'Die Suche in UnivIS ist derzeit nicht verfügbar. Bitte später erneut versuchen.',
                    code: 'source-unavailable',
                });
            }
            throw e;
        }
    }

    return Object.assign(handler, { cache, searchCache });
}

export type PublicSearchResult = PublicCatalog & {
    search: {
        text: string | null;
        number: string | null;
        faculty: string | null;
        total: number;
        returned: number;
        truncated: boolean;
        limit: number;
        /** `phrase`: Wortgruppe wie eingegeben; `words`: alle Wörter einzeln. */
        match: 'phrase' | 'words';
    };
};

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
