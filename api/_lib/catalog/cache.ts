// Zwischenspeicher des Katalog-Endpunkts.
//
// * frisch (jünger als `ttlMs`): direkt ausliefern, kein UnivIS-Abruf;
// * abgelaufen: neu laden – parallele Anfragen zum selben Schlüssel teilen
//   sich EINEN Abruf;
// * Abruf gescheitert oder unplausibel (z. B. plötzlich viel weniger
//   Veranstaltungen): den letzten guten Stand als `stale` liefern, solange er
//   jünger als `maxStaleMs` ist; sonst Fehler – nie erfundene Daten.
//
// Ebenen: Arbeitsspeicher der Funktionsinstanz und optional ein dauerhafter
// Speicher (`PersistentCatalogStore`, z. B. Firestore), damit ein Kaltstart
// nicht sofort UnivIS abfragt und ein Ausfall auch nach Kaltstarts
// überbrückt wird.

export interface CachedCatalog<T> {
    value: T;
    /** Zeitpunkt des erfolgreichen Abrufs (ms seit 1970). */
    fetchedAt: number;
    /** Anzahl Veranstaltungen, für die Plausibilitätsprüfung. */
    size: number;
}

export interface PersistentCatalogStore<T> {
    read(key: string): Promise<CachedCatalog<T> | null>;
    write(key: string, entry: CachedCatalog<T>): Promise<void>;
}

export type CacheState = 'fresh' | 'refreshed' | 'stale';

export interface CacheResult<T> {
    value: T;
    fetchedAt: number;
    state: CacheState;
    /** Bei `stale`: warum nicht aktualisiert werden konnte (bereinigt). */
    reason?: string;
}

export class CatalogUnavailableError extends Error {
    constructor(message: string, readonly cause?: unknown) {
        super(message);
    }
}

export class ImplausibleCatalogError extends Error {}

export interface CatalogCacheOptions<T> {
    ttlMs: number;
    maxStaleMs: number;
    /** Neuer Stand mit weniger als diesem Anteil der bisherigen Größe gilt als unplausibel. */
    minSizeRatio?: number;
    sizeOf: (value: T) => number;
    persistent?: PersistentCatalogStore<T> | null;
    /** Höchstzahl der Einträge im Arbeitsspeicher (älteste zuerst verworfen). */
    maxEntries?: number;
    now?: () => number;
    /** Für Protokolle: nur Codes, keine Inhalte. */
    log?: (message: string) => void;
}

export class CatalogCache<T> {
    private readonly memory = new Map<string, CachedCatalog<T>>();
    private readonly inFlight = new Map<string, Promise<CacheResult<T>>>();
    private readonly now: () => number;

    constructor(private readonly options: CatalogCacheOptions<T>) {
        this.now = options.now ?? Date.now;
    }

    private async readPersistent(key: string): Promise<CachedCatalog<T> | null> {
        if (!this.options.persistent) return null;
        try {
            return await this.options.persistent.read(key);
        } catch (e) {
            this.options.log?.(`persistent-read-failed ${errorName(e)}`);
            return null;
        }
    }

    private remember(key: string, entry: CachedCatalog<T>) {
        this.memory.delete(key);
        this.memory.set(key, entry);
        const max = this.options.maxEntries;
        if (max !== undefined) {
            for (const oldest of this.memory.keys()) {
                if (this.memory.size <= max) break;
                this.memory.delete(oldest);
            }
        }
    }

    private async writePersistent(key: string, entry: CachedCatalog<T>): Promise<void> {
        if (!this.options.persistent) return;
        try {
            await this.options.persistent.write(key, entry);
        } catch (e) {
            this.options.log?.(`persistent-write-failed ${errorName(e)}`);
        }
    }

    /** Bester bekannter Stand (Arbeitsspeicher, sonst dauerhaft). */
    private async known(key: string): Promise<CachedCatalog<T> | null> {
        const inMemory = this.memory.get(key);
        if (inMemory) return inMemory;
        const stored = await this.readPersistent(key);
        if (stored) this.remember(key, stored);
        return stored;
    }

    async get(key: string, load: () => Promise<T>): Promise<CacheResult<T>> {
        const cached = this.memory.get(key);
        if (cached && this.now() - cached.fetchedAt < this.options.ttlMs) {
            if (this.options.maxEntries !== undefined) this.remember(key, cached);
            return { value: cached.value, fetchedAt: cached.fetchedAt, state: 'fresh' };
        }
        const running = this.inFlight.get(key);
        if (running) return running;

        const task = this.refresh(key, load).finally(() => this.inFlight.delete(key));
        this.inFlight.set(key, task);
        return task;
    }

    private async refresh(key: string, load: () => Promise<T>): Promise<CacheResult<T>> {
        const previous = await this.known(key);
        if (previous && this.now() - previous.fetchedAt < this.options.ttlMs) {
            return { value: previous.value, fetchedAt: previous.fetchedAt, state: 'fresh' };
        }

        try {
            const value = await load();
            const size = this.options.sizeOf(value);
            const ratio = this.options.minSizeRatio ?? 0.5;
            if (previous && previous.size > 0 && size < previous.size * ratio) {
                throw new ImplausibleCatalogError(`nur ${size} statt bisher ${previous.size} Veranstaltungen`);
            }
            const entry: CachedCatalog<T> = { value, fetchedAt: this.now(), size };
            this.remember(key, entry);
            await this.writePersistent(key, entry);
            return { value, fetchedAt: entry.fetchedAt, state: 'refreshed' };
        } catch (e) {
            this.options.log?.(`refresh-failed ${key} ${errorName(e)}`);
            if (previous && this.now() - previous.fetchedAt < this.options.maxStaleMs) {
                return {
                    value: previous.value,
                    fetchedAt: previous.fetchedAt,
                    state: 'stale',
                    reason: e instanceof ImplausibleCatalogError ? 'implausible' : 'source-unavailable',
                };
            }
            throw new CatalogUnavailableError('Der Veranstaltungskatalog ist derzeit nicht verfügbar.', e);
        }
    }

    /** Frischer Eintrag vorhanden (ohne Abruf)? */
    hasFresh(key: string): boolean {
        const cached = this.memory.get(key);
        return cached !== undefined && this.now() - cached.fetchedAt < this.options.ttlMs;
    }

    get size(): number {
        return this.memory.size;
    }

    /** Nur für Tests. */
    clear() {
        this.memory.clear();
        this.inFlight.clear();
    }
}

/** Fehlername ohne Meldungstext (der Text könnte Antwortinhalte enthalten). */
export function errorName(e: unknown): string {
    if (e instanceof Error) return e.name === 'Error' ? e.constructor.name : e.name;
    return typeof e;
}
