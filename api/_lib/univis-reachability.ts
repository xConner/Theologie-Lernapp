// Erreichbarkeitstest: Kann eine Vercel-Funktion UnivIS abrufen und
// verarbeiten? NUR in Preview-Deployments aktiv (in Produktion 404), höchstens
// eine UnivIS-Anfrage pro Minute und Instanz. Antwort enthält nur Kennzahlen
// (catalogStats), keine Titel, Namen oder Freitexte.
//
// Kein regelmäßiger Abruf: Die Nutzungsrechte sind ungeklärt
// (docs/univis-integration-feasibility.md).

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { catalogStats } from './catalog/stats';
import { buildSnapshot } from './catalog/source';
import { CAU_UNIVIS, UnivisSource } from './catalog/univis/source';

const QUERY = { semesterId: '2026w', organizationId: '010000000' };
const MIN_INTERVAL_MS = 60_000;
let lastRun = 0;

export function createHandler(
    fetchImpl: typeof fetch = fetch,
    env: NodeJS.ProcessEnv = process.env,
    now: () => number = Date.now,
) {
    return async (req: VercelRequest, res: VercelResponse) => {
        if (env.VERCEL_ENV === 'production') return res.status(404).json({ error: 'Nicht gefunden.' });
        if (req.method !== 'GET') return res.status(405).json({ error: 'Nur GET.' });
        if (now() - lastRun < MIN_INTERVAL_MS) {
            return res.status(429).json({ error: 'Höchstens ein Abruf pro Minute.' });
        }
        lastRun = now();

        const source = new UnivisSource(CAU_UNIVIS, fetchImpl);
        const started = now();
        try {
            const raw = await source.fetchRaw(QUERY);
            const ms = now() - started;
            const parsed = source.parse(raw.body, QUERY);
            const snapshot = buildSnapshot(source, QUERY, raw, new Date(started));
            return res.status(200).json({
                reachable: true,
                region: env.VERCEL_REGION ?? null,
                url: raw.url,
                status: raw.status,
                contentType: raw.contentType,
                bytes: Buffer.byteLength(raw.body),
                ms,
                contentHash: snapshot.provenance.contentHash,
                stats: catalogStats(parsed, snapshot),
            });
        } catch (e) {
            const cause = (e as { cause?: { code?: string } })?.cause?.code;
            return res.status(502).json({
                reachable: false,
                region: env.VERCEL_REGION ?? null,
                error: e instanceof Error ? e.message.slice(0, 200) : 'unbekannt',
                cause: cause ?? null,
                ms: now() - started,
            });
        }
    };
}

/** Nur für Tests: Drosselung zurücksetzen. */
export function resetThrottle() {
    lastRun = 0;
}

export default createHandler();
