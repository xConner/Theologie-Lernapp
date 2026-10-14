// Dauerhafter Zwischenspeicher des Katalogs in Firestore (nur Server,
// Admin SDK): `catalog_cache/{schlüssel}`. Der Katalog liegt gzip-komprimiert
// und Base64-kodiert in einem Feld (Theologie WS 2026/27: wenige zehn KB).
// Clients haben keinen Zugriff (firestore.rules: kein `match` → verboten).
//
// Aktiv nur, wenn FIREBASE_SERVICE_ACCOUNT gesetzt ist (wie bei den
// Push-Funktionen); sonst arbeitet der Endpunkt nur mit Arbeitsspeicher und
// CDN-Cache.

import { gunzipSync, gzipSync } from 'node:zlib';
import type { CachedCatalog, PersistentCatalogStore } from './cache';

export const CATALOG_CACHE_COLLECTION = 'catalog_cache';
/** Firestore-Dokumente dürfen höchstens 1 MiB groß sein. */
const MAX_ENCODED_BYTES = 900 * 1024;

interface DocLike {
    get(): Promise<{ exists: boolean; data(): Record<string, unknown> | undefined }>;
    set(data: Record<string, unknown>): Promise<unknown>;
}

export class FirestoreCatalogStore<T> implements PersistentCatalogStore<T> {
    constructor(
        private readonly doc: (key: string) => DocLike,
        private readonly version: number,
    ) {}

    async read(key: string): Promise<CachedCatalog<T> | null> {
        const snap = await this.doc(key).get();
        const data = snap.exists ? snap.data() : undefined;
        if (!data || data.version !== this.version) return null;
        if (typeof data.gz !== 'string' || typeof data.fetchedAt !== 'number' || typeof data.size !== 'number') {
            return null;
        }
        const value = JSON.parse(gunzipSync(Uint8Array.from(Buffer.from(data.gz, 'base64'))).toString('utf8')) as T;
        return { value, fetchedAt: data.fetchedAt, size: data.size };
    }

    async write(key: string, entry: CachedCatalog<T>): Promise<void> {
        const gz = gzipSync(JSON.stringify(entry.value)).toString('base64');
        if (gz.length > MAX_ENCODED_BYTES) throw new RangeError('Katalog zu groß für den dauerhaften Speicher');
        await this.doc(key).set({ version: this.version, fetchedAt: entry.fetchedAt, size: entry.size, gz });
    }
}
