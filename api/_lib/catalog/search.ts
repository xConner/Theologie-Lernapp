// Fakultätsübergreifende Veranstaltungssuche über die UnivIS-PRG-Titelsuche
// (`search=lectures&name=…` bzw. `number=…`, optional `department=<OrgNr>`).
// Live geprüft am 14.10.2026 (docs/univis-integration-feasibility.md,
// Abschnitt 14):
// * `name` sucht Teilzeichenfolgen im Titel, ohne Groß-/Kleinschreibung,
//   Wortgruppen zusammenhängend („Altes Testament“);
// * Umlaute nur als ISO-8859-1 kodiert (`Einf%FChrung`), UTF-8 findet nichts;
// * `department` schränkt auf eine Fakultät ein (UND-Verknüpfung).
//
// Ergebnisse werden wie der Fakultätskatalog verarbeitet (Dubletten,
// Terminauflösung, öffentliche Form) und auf die besten Treffer gekürzt.

import type { CatalogSnapshot } from './model';

/** Fakultäten der CAU (UnivIS-OrgNr, live aus `search=departments`). */
export const CAU_FACULTIES: Record<string, string> = {
    '010000000': 'Theologische Fakultät',
    '020000000': 'Rechtswissenschaftliche Fakultät',
    '030000000': 'Wirtschafts- und Sozialwissenschaftliche Fakultät',
    '040000000': 'Medizinische Fakultät',
    '050000000': 'Philosophische Fakultät',
    '060000000': 'Mathematisch-Naturwissenschaftliche Fakultät',
    '070000000': 'Agrar- und Ernährungswissenschaftliche Fakultät',
    '080000000': 'Technische Fakultät',
    '200000000': 'Gemeinsame Einrichtungen der Fakultäten',
};

export const SEARCH_MIN_LENGTH = 3;
export const SEARCH_MAX_LENGTH = 80;
/** Höchstzahl ausgelieferter Treffer (danach: „bitte genauer suchen“). */
export const SEARCH_MAX_RESULTS = 100;

export interface SearchQuery {
    semesterId: string;
    /** Titel bzw. Titelbestandteil (normalisiert, siehe [normalizeSearchText]). */
    text?: string;
    /** Sechsstellige Veranstaltungsnummer. */
    number?: string;
    /** Fakultät (Schlüssel aus [CAU_FACULTIES]). */
    facultyId?: string;
}

/**
 * Suchtext prüfen und vereinheitlichen: Leerraum zusammenfassen, Länge
 * begrenzen, nur Zeichen, die UnivIS (ISO-8859-1) überhaupt kennt und die in
 * Titeln vorkommen. Ungültig → null.
 */
export function normalizeSearchText(raw: unknown): string | null {
    if (typeof raw !== 'string') return null;
    const text = raw.replace(/[–—]/g, '-').replace(/[‘’]/g, "'").replace(/\s+/g, ' ').trim();
    if (text.length < SEARCH_MIN_LENGTH || text.length > SEARCH_MAX_LENGTH) return null;
    // Buchstaben aus Latin-1, Ziffern und wenige Satzzeichen.
    if (!/^[A-Za-z0-9À-ÖØ-öø-ÿ .,'&()/:-]+$/.test(text)) return null;
    // Mindestens drei Buchstaben oder Ziffern (kein reines Satzzeichen-Muster).
    if ((text.match(/[A-Za-z0-9À-ÿ]/g) ?? []).length < SEARCH_MIN_LENGTH) return null;
    return text;
}

export function normalizeLectureNumber(raw: unknown): string | null {
    return typeof raw === 'string' && /^\d{6}$/.test(raw.trim()) ? raw.trim() : null;
}

/**
 * Prozentkodierung in ISO-8859-1 (UnivIS erwartet Latin-1; `encodeURIComponent`
 * kodiert UTF-8). Nur für Text aus [normalizeSearchText].
 */
export function latin1Component(text: string): string {
    let out = '';
    for (const ch of text) {
        const code = ch.codePointAt(0)!;
        if (code > 0xff) throw new Error('Zeichen außerhalb von ISO-8859-1');
        out += /[A-Za-z0-9\-_.~]/.test(ch) ? ch : `%${code.toString(16).toUpperCase().padStart(2, '0')}`;
    }
    return out;
}

/** Vergleichsform: klein, Umlaute aufgelöst, nur Buchstaben/Ziffern/Leerzeichen. */
export function foldForRanking(text: string): string {
    return text
        .toLowerCase()
        .replace(/ä/g, 'a').replace(/ö/g, 'o').replace(/ü/g, 'u').replace(/ß/g, 'ss')
        .normalize('NFD').replace(/[̀-ͯ]/g, '')
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
}

/** Rangfolge: exakter Titel, Titelanfang, Wortanfang, sonst enthalten. */
export function rankOf(title: string, text: string): number {
    const t = foldForRanking(title.replace(/\s*\([^()]*\)\s*$/, ''));
    const q = foldForRanking(text);
    if (!q) return 3;
    if (t === q) return 0;
    if (t.startsWith(q)) return 1;
    if (` ${t}`.includes(` ${q}`)) return 2;
    return 3;
}

/** Füllwörter, die bei der Wortsuche nicht zählen. */
const STOPWORDS = new Set(['der', 'die', 'das', 'und', 'oder', 'in', 'im', 'ins', 'zu', 'zur', 'zum', 'von', 'vom', 'mit', 'fur', 'fuer', 'an', 'am', 'auf', 'aus', 'bei', 'den', 'dem', 'des', 'ein', 'eine', 'einer', 'eines', 'the', 'of', 'and']);

/** Bedeutungstragende Wörter eines Suchtexts (Vergleichsform). */
export function significantWords(text: string): string[] {
    return foldForRanking(text).split(' ').filter((w) => w.length >= 2 && !STOPWORDS.has(w));
}

/**
 * Für die Rückfallsuche: das längste bedeutungstragende Wort in der
 * Originalschreibweise (Latin-1, für UnivIS). Nur bei mehreren Wörtern.
 */
export function fallbackWord(text: string): string | null {
    const words = text.split(/[^A-Za-z0-9\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF]+/).filter(Boolean);
    if (words.length < 2) return null;
    const candidates = words.filter((w) => w.length >= 3 && !STOPWORDS.has(foldForRanking(w)));
    if (candidates.length === 0) return null;
    return candidates.reduce((a, b) => (b.length > a.length ? b : a));
}

/** Nur Veranstaltungen, deren Titel alle Wörter des Suchtexts enthält. */
export function matchesAllWords(title: string, text: string): boolean {
    const haystack = foldForRanking(title);
    return significantWords(text).every((w) => haystack.includes(w));
}

/** Teilmenge der Veranstaltungen samt zugehöriger Personen, Räume, Termine. */
export function keepCourses<T extends CatalogSnapshot>(snapshot: T, courses: CatalogSnapshot['courses']): T {
    const ids = new Set(courses.map((c) => c.id));
    const persons = new Set(courses.flatMap((c) => c.lecturerIds));
    const rooms = new Set(courses.flatMap((c) => c.rules.map((r) => r.roomId)).filter((r): r is string => r != null));
    return {
        ...snapshot,
        courses,
        persons: snapshot.persons.filter((p) => persons.has(p.id)),
        rooms: snapshot.rooms.filter((r) => rooms.has(r.id)),
        occurrences: snapshot.occurrences.filter((o) => ids.has(o.courseId)),
        issues: snapshot.issues.filter((i) => ids.has(i.courseId)),
        mergedDuplicates: snapshot.mergedDuplicates.filter((m) => ids.has(m.courseId)),
        possibleDuplicates: snapshot.possibleDuplicates.filter((p) => p.courseIds.some((id) => ids.has(id))),
    };
}

/**
 * Beste Treffer behalten (höchstens [limit]) und alles, was nur zu
 * entfallenen Veranstaltungen gehört, entfernen.
 */
export function trimSnapshot<T extends CatalogSnapshot>(snapshot: T, query: SearchQuery, limit = SEARCH_MAX_RESULTS): T & { total: number } {
    const ranked = [...snapshot.courses].sort((a, b) => {
        const r = query.text ? rankOf(a.title, query.text) - rankOf(b.title, query.text) : 0;
        return r !== 0 ? r : foldForRanking(a.title).localeCompare(foldForRanking(b.title));
    });
    return { ...keepCourses(snapshot, ranked.slice(0, limit)), total: snapshot.courses.length };
}
