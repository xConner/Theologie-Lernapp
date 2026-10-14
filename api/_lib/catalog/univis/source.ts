// UnivIS als Katalogquelle. Pro Abruf genau eine Anfrage
// `search=lectures&show=xml&sem=<sem>&department=<OrgNr>` – live bestätigt
// für die CAU (Theologische Fakultät: 010000000).

import type { Semester } from '../model';
import { CAU_SEMESTERS } from '../semesters';
import { CAU_FACULTIES, latin1Component, type SearchQuery } from '../search';
import type { CatalogQuery, CatalogSource, RawResponse } from '../source';
import { parseUnivisXml } from './parse';

export interface UnivisConfig {
    sourceId: string;
    host: string;
    institution: string;
    semesters: Record<string, Semester>;
}

export const CAU_UNIVIS: UnivisConfig = {
    sourceId: 'cau-univis',
    host: 'univis.uni-kiel.de',
    institution: 'Christian-Albrechts-Universität zu Kiel',
    semesters: CAU_SEMESTERS,
};

const USER_AGENT = 'theologie.app/1.0 (+https://www.theologie.app)';
const TIMEOUT_MS = 20_000;
/** Theologie WS 2026/27: ~0,4 MB. Deutlich mehr deutet auf eine Fehlanfrage. */
const MAX_BYTES = 8 * 1024 * 1024;

/** Antwort größer als erlaubt (z. B. zu allgemeiner Suchbegriff). */
export class ResponseTooLargeError extends Error {
    constructor(readonly bytes: number) {
        super(`Antwort zu groß (${bytes} Bytes).`);
        this.name = 'ResponseTooLargeError';
    }
}

export class UnivisSource implements CatalogSource {
    readonly system = 'univis' as const;
    readonly sourceId: string;
    readonly institution: string;
    readonly semesters: Record<string, Semester>;
    private readonly host: string;

    constructor(config: UnivisConfig, private readonly fetchImpl: typeof fetch = fetch) {
        if (!/^[a-z0-9.-]+$/i.test(config.host)) throw new Error(`Ungültiger Host ${config.host}`);
        this.sourceId = config.sourceId;
        this.institution = config.institution;
        this.semesters = config.semesters;
        this.host = config.host;
    }

    url(query: CatalogQuery): URL {
        if (!/^\d{9}$/.test(query.organizationId)) {
            throw new Error('Organisationsnummer muss neunstellig sein (UnivIS <orgnr>).');
        }
        if (!/^\d{4}[ws]$/.test(query.semesterId) || !this.semesters[query.semesterId]) {
            throw new Error(`Semester ${query.semesterId} ist nicht konfiguriert.`);
        }
        const url = new URL(`https://${this.host}/prg`);
        url.searchParams.set('search', 'lectures');
        url.searchParams.set('show', 'xml');
        url.searchParams.set('sem', query.semesterId);
        url.searchParams.set('department', query.organizationId);
        return url;
    }

    /**
     * Titel- bzw. Nummernsuche über alle Einrichtungen oder eine Fakultät.
     * Der Suchtext muss aus `normalizeSearchText` stammen (nur Latin-1).
     */
    searchUrl(query: SearchQuery): URL {
        if (!/^\d{4}[ws]$/.test(query.semesterId) || !this.semesters[query.semesterId]) {
            throw new Error(`Semester ${query.semesterId} ist nicht konfiguriert.`);
        }
        if (query.facultyId !== undefined && !(query.facultyId in CAU_FACULTIES)) {
            throw new Error('Unbekannte Fakultät.');
        }
        const parts = ['search=lectures', 'show=xml', `sem=${query.semesterId}`];
        if (query.number !== undefined) {
            if (!/^\d{6}$/.test(query.number)) throw new Error('Veranstaltungsnummer muss sechsstellig sein.');
            parts.push(`number=${query.number}`);
        } else if (query.text !== undefined) {
            // UnivIS findet Umlaute nur in ISO-8859-1-Kodierung (live geprüft).
            parts.push(`name=${latin1Component(query.text)}`);
        } else {
            throw new Error('Suchtext oder Veranstaltungsnummer fehlt.');
        }
        if (query.facultyId !== undefined) parts.push(`department=${query.facultyId}`);
        return new URL(`https://${this.host}/prg?${parts.join('&')}`);
    }

    async fetchRaw(query: CatalogQuery, options: { signal?: AbortSignal } = {}): Promise<RawResponse> {
        return this.get(this.url(query), options);
    }

    async fetchSearchRaw(query: SearchQuery, options: { signal?: AbortSignal } = {}): Promise<RawResponse> {
        return this.get(this.searchUrl(query), options);
    }

    private async get(url: URL, options: { signal?: AbortSignal }): Promise<RawResponse> {
        const signal = options.signal
            ? AbortSignal.any([options.signal, AbortSignal.timeout(TIMEOUT_MS)])
            : AbortSignal.timeout(TIMEOUT_MS);
        const response = await this.fetchImpl(url, {
            headers: { 'User-Agent': USER_AGENT, Accept: 'application/xml, text/xml' },
            signal,
        });
        const bytes = new Uint8Array(await response.arrayBuffer());
        if (bytes.length > MAX_BYTES) throw new ResponseTooLargeError(bytes.length);
        const contentType = response.headers.get('content-type');
        if (!response.ok) throw new Error(`UnivIS antwortete mit HTTP ${response.status}.`);
        return { body: decode(bytes, contentType), url: url.toString(), status: response.status, contentType };
    }

    parse(body: string, query: CatalogQuery) {
        return parseUnivisXml(body, { sourceId: this.sourceId, semesterId: query.semesterId, host: this.host });
    }
}

/** Zeichensatz aus Content-Type bzw. XML-Deklaration (UnivIS: teils ISO-8859-1). */
export function decode(bytes: Uint8Array, contentType: string | null): string {
    const head = Buffer.from(bytes.slice(0, 200)).toString('latin1');
    const label = (/charset=([\w-]+)/i.exec(contentType ?? '')?.[1]
        ?? /encoding=["']([\w-]+)["']/i.exec(head)?.[1]
        ?? 'utf-8').toLowerCase().replace(/^iso8859/, 'iso-8859');
    try {
        return new TextDecoder(label).decode(bytes);
    } catch {
        return new TextDecoder('utf-8').decode(bytes);
    }
}
