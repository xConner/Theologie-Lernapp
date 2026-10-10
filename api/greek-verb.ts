import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as cheerio from 'cheerio';

const WIKTIONARY_BASE_URL =
    'https://en.wiktionary.org/wiki/';

// Obergrenzen gegen Missbrauch des öffentlichen Endpunkts. Die längste
// Grundform der Vokabelliste hat deutlich weniger als 64 Zeichen.
const MAX_LEMMA_LENGTH = 64;
const MAX_PARAM_LENGTH = 32;
const UPSTREAM_TIMEOUT_MS = 8000;

// Dialekttabellen, die nie dem Lernstoff (Attisch/Koine) entsprechen.
const FOREIGN_DIALECT =
    /(Epic|Ionic|Doric|Aeolic|Boeotian|Laconian|Arcadocypriot|Cretan)/i;

// Tabellen ohne Dialektangabe oder mit attischer Kontraktion.
function isForeignOrKoine(title: string): boolean {
    return FOREIGN_DIALECT.test(title) || /Koine/i.test(title);
}

// Ein Deponens steht im Präsens und Imperfekt nur in medialer Form; eine
// Tabelle der aktiven Nebenform (θεάω zu θεάομαι) gehört nicht zum Lemma.
function isActiveTableOfDeponent(
    title: string,
    tense: string,
    lemma?: string,
): boolean {
    if (!lemma || !lemma.endsWith('μαι')) {
        return false;
    }

    const ending =
        tense === 'Präsens' ? 'μαι' : tense === 'Imperfekt' ? 'μην' : null;

    if (ending === null) {
        return false;
    }

    const headline = comparableForm(
        (title.split(':')[1] ?? '').trim().split(/[\s,(]/)[0],
    );

    return headline.length > 0 && !headline.endsWith(ending);
}

// Attische ττ-Verben, deren Wiktionary-Seite keine Aorist-Tabelle enthält.
// Der Aorist steht nur auf der Seite der σσ-Form.
const AORIST_LEMMA_REPLACEMENTS = new Map([
    ['πράττω', 'πράσσω'],
    ['τάττω', 'τάσσω'],
    ['φυλάττω', 'φυλάσσω'],
]);

function isValidParam(value: string, maxLength: number): boolean {
    return (
        value.length > 0 &&
        value.length <= maxLength &&
        !/[\u0000-\u001f\u007f]/.test(value)
    );
}

function getTenseClass(tense: string): string | null {
    switch (tense) {
        case 'Präsens':
            return 'grc-conj-present';

        case 'Imperfekt':
            return 'grc-conj-imperfect';

        case 'Aorist':
            return 'grc-conj-aorist';

        default:
            return null;
    }
}

function normalizeVoice(value: string): string {
    const normalized = value
        .toLowerCase()
        .replace(/\s+/g, '')
        .replace(/ /g, '');

    if (
        normalized === 'aktiv' ||
        normalized === 'active'
    ) {
        return 'active';
    }

    if (
        normalized === 'passiv' ||
        normalized === 'passive'
    ) {
        return 'passive';
    }

    if (
        normalized === 'medium/passiv' ||
        normalized === 'medium/passive' ||
        normalized === 'middle/passive' ||
        normalized === 'middle/passiv' ||
        normalized === 'middleorpassive'
    ) {
        return 'middle/passive';
    }

    if (
        normalized === 'medium' ||
        normalized === 'middle'
    ) {
        return 'middle';
    }

    if (normalized === 'deponens') {
        return 'middle/passive';
    }

    return normalized;
}

function getCellIndex(
    number: string,
    person: number,
): number | null {
    if (person < 1 || person > 3) {
        return null;
    }

    switch (number) {
        case 'Sg':
            return person - 1;

        case 'Pl':
            return 4 + person;

        default:
            return null;
    }
}

function cleanText(text: string): string {
    return text
        .replace(/ /g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function extractGreekForm(
    cell: cheerio.Cheerio<any>,
): string | null {
    const polyt = cell.find('.Polyt').first();

    if (polyt.length > 0) {
        const text = cleanText(polyt.text());

        if (text.length > 0) {
            return text;
        }
    }

    const text = cleanText(cell.text());

    if (text.length === 0 || text === ' ') {
        return null;
    }

    return text;
}

function findTenseTable(
    $: cheerio.CheerioAPI,
    tense: string,
    lemma?: string,
): cheerio.Cheerio<any> | null {
    const tenseClass = getTenseClass(tense);

    if (tenseClass === null) {
        return null;
    }

    const candidates: {
        table: cheerio.Cheerio<any>;
        title: string;
        score: number;
    }[] = [];

    // Sonderfall-Definitionen
    const specialCases = {
        secondAoristTable: new Set(['εὑρίσκω', 'φέρω']),
        normalInsteadOfKoine: new Set(['λείπω']),
        atticInsteadOfKoine: new Set(['ἀγγέλλω'])
    };

    // SONDERFALL: Für εὑρίσκω / φέρω: explizit die ZWEITE normale Aorist-Tabelle
    if (lemma && tense === 'Aorist' && specialCases.secondAoristTable.has(lemma)) {
        const normalAoristTables: cheerio.Cheerio<any>[] = [];
        $('table').each((_, element) => {
            const table = $(element);
            const classes = table.attr('class') ?? '';
            if (!classes.includes('grc-conj') || !classes.includes(tenseClass)) return;
            const navFrame = table.closest('.NavFrame');
            const title = cleanText(navFrame.find('.NavHead').first().text() ?? '');
            if (!/Attic/i.test(title) && !/(?<!un)Contracted/i.test(title) && !isForeignOrKoine(title)) {
                normalAoristTables.push(table);
            }
        });
        if (normalAoristTables.length >= 2) {
            return normalAoristTables[1];
        }
    }

    $('table').each((_, element) => {
        const table = $(element);
        const classes = table.attr('class') ?? '';

        if (
            !classes.includes('grc-conj') ||
            !classes.includes(tenseClass)
        ) {
            return;
        }

        const navFrame = table.closest('.NavFrame');
        const title = cleanText(
            navFrame
                .find('.NavHead')
                .first()
                .text() ?? '',
        );

        let score = 0;

        if (/(?<!un)Contracted/i.test(title)) {
            score += 150;
        }
        if (!/Attic/i.test(title) && !/(?<!un)Contracted/i.test(title) &&
            !isForeignOrKoine(title)) {
            score += 100;
        }
        else if (FOREIGN_DIALECT.test(title)) {
            score -= 300;
        }
        else if (/Koine/i.test(title)) {
            score += 50;
        }
        else if (/Attic/i.test(title)) {
            score -= 50;
            if (/(?<!un)Contracted/i.test(title)) {
                score += 50;
            }
        }
        else {
            score += 0;
        }

        if (lemma && tense === 'Aorist') {
            if (specialCases.normalInsteadOfKoine.has(lemma) &&
                /Koine/i.test(title)) {
                score -= 150;
            }
            // Alle Tabellen tragen eine Dialektangabe; ohne Aufwertung
            // gewänne der seltene Koine-Aorist (ἤγγελον statt ἤγγειλα).
            if (specialCases.atticInsteadOfKoine.has(lemma) &&
                /Attic/i.test(title)) {
                score += 150;
            }
        }

        if (isActiveTableOfDeponent(title, tense, lemma)) {
            score -= 300;
        }

        candidates.push({
            table,
            title,
            score,
        });
    });

    if (candidates.length === 0) {
        return null;
    }

    candidates.sort((a, b) => b.score - a.score);
    return candidates[0].table;
}

function extractIndicativeForm(
    $: cheerio.CheerioAPI,
    table: cheerio.Cheerio<any>,
    voice: string,
    number: string,
    person: number,
): string | null {
    const wantedVoice = normalizeVoice(voice);

    const index = getCellIndex(number, person);

    if (index === null) {
        return null;
    }

    function isActiveVoice(header: string): boolean {
        return normalizeVoice(header) === 'active';
    }

    function isMiddleVoice(header: string): boolean {
        const normalized = normalizeVoice(header);

        return (
            normalized === 'middle' ||
            normalized === 'middle/passive'
        );
    }

    function isPassiveVoice(header: string): boolean {
        return normalizeVoice(header) === 'passive';
    }

    const findFormInRows = (
        voiceMatcher: (header: string) => boolean,
    ): string | null => {
        let result: string | null = null;

        table.find('tr').each((_, element) => {
            if (result !== null) {
                return;
            }

            const row = $(element);
            const headers = row.find('th');

            if (headers.length < 2) {
                return;
            }

            const firstHeader = cleanText(
                $(headers[0]).text(),
            );

            const secondHeader = cleanText(
                $(headers[1]).text(),
            );

            if (
                secondHeader.toLowerCase() !== 'indicative'
            ) {
                return;
            }

            if (!voiceMatcher(firstHeader)) {
                return;
            }

            const cells = row.find('td');

            if (cells.length <= index) {
                return;
            }

            const form = extractGreekForm(
                $(cells[index]),
            );

            if (form !== null && form.length > 0) {
                result = form;
            }
        });

        return result;
    };

    // ---------------------------------------------------------
    // AKTIV

    if (wantedVoice === 'active') {
        return findFormInRows(isActiveVoice);
    }

    // ---------------------------------------------------------
    // MEDIUM/PASSIV

    if (wantedVoice === 'middle/passive') {
        const middleForm = findFormInRows(isMiddleVoice);

        if (middleForm !== null) {
            return middleForm;
        }

        const passiveForm = findFormInRows(isPassiveVoice);

        if (passiveForm !== null) {
            return passiveForm;
        }

        return findFormInRows(isActiveVoice);
    }

    // ---------------------------------------------------------
    // NUR MEDIUM

    if (wantedVoice === 'middle') {
        return findFormInRows(isMiddleVoice);
    }

    // ---------------------------------------------------------
    // NUR PASSIV

    if (wantedVoice === 'passive') {
        return findFormInRows(isPassiveVoice);
    }

    return null;
}

function getQueryLemma(lemma: string, tense: string): string {
    return tense === 'Aorist'
        ? (AORIST_LEMMA_REPLACEMENTS.get(lemma) ?? lemma)
        : lemma;
}

// Vom Trainer abgefragte Bestimmungen, in der Schreibweise der Anfrage.
const TRAINER_TENSES = ['Präsens', 'Imperfekt', 'Aorist'];
const TRAINER_VOICES = ['Aktiv', 'Medium/Passiv'];
const TRAINER_NUMBERS = ['Sg', 'Pl'];

// Längenzeichen werden im Trainer nicht angezeigt und dürfen zwei Formen
// deshalb nicht unterscheiden.
function comparableForm(form: string): string {
    return form
        .normalize('NFD')
        .replace(/[̄̆]/g, '')
        .normalize('NFC');
}

type VerbAnalysis = {
    tense: string;
    voice: string;
    number: string;
    person: number;
};

// Alle Bestimmungen, für die der Trainer genau dieselbe Form ausliefern
// würde (z. B. 1. Sg. = 3. Pl. im Imperfekt Aktiv). Berücksichtigt werden nur
// Tempora, deren Tabelle auf der bereits geladenen Seite steht.
function findVerbAnalyses(
    $: cheerio.CheerioAPI,
    lemma: string,
    queryLemma: string,
    form: string,
): VerbAnalysis[] {
    const wanted = comparableForm(form);
    const analyses: VerbAnalysis[] = [];

    for (const tense of TRAINER_TENSES) {
        if (getQueryLemma(lemma, tense) !== queryLemma) {
            continue;
        }

        const table = findTenseTable($, tense, lemma);

        if (table === null) {
            continue;
        }

        for (const voice of TRAINER_VOICES) {
            for (const number of TRAINER_NUMBERS) {
                for (const person of [1, 2, 3]) {
                    const candidate = extractIndicativeForm(
                        $,
                        table,
                        voice,
                        number,
                        person,
                    );

                    if (
                        candidate !== null &&
                        comparableForm(candidate) === wanted
                    ) {
                        analyses.push({ tense, voice, number, person });
                    }
                }
            }
        }
    }

    return analyses;
}

// ---------------------------------------------------------------------------
// PARADIGMA (Indikativ, Imperativ, Partizipien)
// ---------------------------------------------------------------------------

// Spalten einer finiten Zeile in der Reihenfolge 1./2./3. Sg., 1./2./3. Pl.
// (dazwischen stehen die beiden Dualformen).
const FINITE_CELL_INDEXES = [0, 1, 2, 5, 6, 7];
const FINITE_CELL_COUNT = 8;

const KNOWN_VOICES = new Set([
    'active',
    'middle',
    'passive',
    'middle/passive',
]);

type FiniteForms = (string | null)[];
type ParticipleNominatives = Record<string, string | null>;

type TenseParadigm = {
    indicative: Record<string, FiniteForms>;
    imperative: Record<string, FiniteForms>;
    participles: Record<string, ParticipleNominatives>;
};

function cellForm(cell: cheerio.Cheerio<any>): string | null {
    const form = extractGreekForm(cell);

    return form === null ? null : comparableForm(form);
}

// Liest eine Tempustabelle vollständig aus. Die Genera Verbi stehen so, wie
// die Tabelle sie nennt ("active", "middle", "passive", "middle/passive");
// die Zuordnung zum Lernstoff trifft der Trainer.
function extractTenseParadigm(
    $: cheerio.CheerioAPI,
    table: cheerio.Cheerio<any>,
): TenseParadigm {
    const paradigm: TenseParadigm = {
        indicative: {},
        imperative: {},
        participles: {},
    };

    // Die Zeilen eines Genus Verbi teilen sich eine Kopfzelle (rowspan).
    let currentVoice: string | null = null;

    // Genera Verbi der Spalten im unteren Tabellenteil (Infinitiv, Partizip).
    let participleVoices: (string | null)[] = [];

    // Partizipien aus Spalten ohne Überschrift: In Tabellen ohne Aktiv
    // fehlt die Angabe des Genus Verbi über der medialen Spalte.
    const unlabelled = new Map<number, ParticipleNominatives>();

    table.find('tr').each((_, element) => {
        const row = $(element);
        const headers = row
            .children('th')
            .map((_, th) => cleanText($(th).text()).toLowerCase())
            .get();
        const cells = row.children('td');

        if (headers.length === 0) {
            return;
        }

        if (cells.length === 0) {
            const voices = headers.slice(1).map(normalizeVoice);

            // Die Kopfzeilen der finiten Formen (Numerus, Person) nennen
            // kein Genus Verbi und haben mehr Spalten.
            if (
                voices.length <= KNOWN_VOICES.size &&
                voices.every(
                    (voice) => voice === '' || KNOWN_VOICES.has(voice),
                )
            ) {
                participleVoices = voices.map((voice) =>
                    KNOWN_VOICES.has(voice) ? voice : null,
                );
            }

            return;
        }

        const label = headers[headers.length - 1];

        if (cells.length === FINITE_CELL_COUNT) {
            if (headers.length >= 2) {
                currentVoice = normalizeVoice(headers[0]);
            }

            if (
                currentVoice === null ||
                !KNOWN_VOICES.has(currentVoice) ||
                (label !== 'indicative' && label !== 'imperative')
            ) {
                return;
            }

            paradigm[label][currentVoice] = FINITE_CELL_INDEXES.map(
                (index) => cellForm($(cells[index])),
            );

            return;
        }

        if (
            (label === 'm' || label === 'f' || label === 'n') &&
            participleVoices.length > 0 &&
            cells.length === participleVoices.length
        ) {
            participleVoices.forEach((voice, index) => {
                const form = cellForm($(cells[index]));

                if (voice === null) {
                    if (!unlabelled.has(index)) {
                        unlabelled.set(index, { m: null, f: null, n: null });
                    }

                    unlabelled.get(index)![label] = form;

                    return;
                }

                paradigm.participles[voice] ??= { m: null, f: null, n: null };
                paradigm.participles[voice][label] = form;
            });
        }
    });

    // Ein Partizip auf -μενος ohne Spaltenüberschrift gehört zum medialen
    // Genus Verbi der finiten Formen.
    const middleVoice = ['middle/passive', 'middle'].find(
        (voice) => paradigm.indicative[voice] !== undefined,
    );

    for (const nominatives of unlabelled.values()) {
        if (
            middleVoice !== undefined &&
            paradigm.participles[middleVoice] === undefined &&
            nominatives.m?.endsWith('μενος')
        ) {
            paradigm.participles[middleVoice] = nominatives;
        }
    }

    return paradigm;
}

// Manche Aoristtabellen enthalten nur den augmentierten Indikativ (ηὗρον);
// Imperativ und Partizipien stehen dann in der Tabelle desselben Aorists
// ohne Dialektangabe (εὗρον). Gesucht wird in der Reihenfolge der Seite.
function findNonIndicativeForms(
    $: cheerio.CheerioAPI,
    tense: string,
): TenseParadigm | null {
    const tenseClass = getTenseClass(tense);
    let result: TenseParadigm | null = null;

    $('table').each((_, element) => {
        if (result !== null) {
            return;
        }

        const table = $(element);
        const classes = table.attr('class') ?? '';

        if (
            tenseClass === null ||
            !classes.includes('grc-conj') ||
            !classes.includes(tenseClass)
        ) {
            return;
        }

        const title = cleanText(
            table.closest('.NavFrame').find('.NavHead').first().text() ?? '',
        );

        if (/Attic/i.test(title) || isForeignOrKoine(title)) {
            return;
        }

        const paradigm = extractTenseParadigm($, table);

        if (
            Object.keys(paradigm.imperative).length > 0 &&
            Object.keys(paradigm.participles).length > 0
        ) {
            result = paradigm;
        }
    });

    return result;
}

async function loadWiktionaryPage(
    queryLemma: string,
): Promise<cheerio.CheerioAPI | number> {
    const response = await fetch(
        WIKTIONARY_BASE_URL + encodeURIComponent(queryLemma),
        {
            headers: {
                'User-Agent':
                    'TheologieLernapp/1.0 (Ancient Greek grammar trainer)',
            },
            signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
        },
    );

    if (!response.ok) {
        return response.status;
    }

    return cheerio.load(await response.text());
}

// Liefert alle Tempora des Trainers in einer Antwort. [aoristLemma] ist die
// Seite, auf der der Aorist steht, wenn er über ein anderes Lemma gebildet
// wird (λέγω → εἶπον).
async function handleParadigm(
    res: VercelResponse,
    lemma: string,
    aoristLemma: string | undefined,
) {
    const aoristQueryLemma = aoristLemma ?? getQueryLemma(lemma, 'Aorist');

    const [page, aoristPage] = await Promise.all([
        loadWiktionaryPage(lemma),
        aoristQueryLemma === lemma
            ? null
            : loadWiktionaryPage(aoristQueryLemma),
    ]);

    const failed = [page, aoristPage].find(
        (result) => typeof result === 'number',
    );

    if (failed !== undefined) {
        return res.status(502).json({
            error: `Wiktionary HTTP ${failed}`,
        });
    }

    const paradigm: Record<string, TenseParadigm> = {};

    for (const tense of TRAINER_TENSES) {
        const $ = (
            tense === 'Aorist' ? (aoristPage ?? page) : page
        ) as cheerio.CheerioAPI;

        const table = findTenseTable($, tense, lemma);

        if (table === null) {
            continue;
        }

        const forms = extractTenseParadigm($, table);

        if (
            tense === 'Aorist' &&
            Object.keys(forms.imperative).length === 0 &&
            Object.keys(forms.participles).length === 0
        ) {
            const other = findNonIndicativeForms($, tense);

            // Nur Genera Verbi übernehmen, die der Indikativ auch hat.
            for (const voice of Object.keys(forms.indicative)) {
                if (other?.imperative[voice]) {
                    forms.imperative[voice] = other.imperative[voice];
                }

                if (other?.participles[voice]) {
                    forms.participles[voice] = other.participles[voice];
                }
            }
        }

        paradigm[tense] = forms;
    }

    if (Object.keys(paradigm).length === 0) {
        return res.status(404).json({
            error: 'Keine Flexionstabelle gefunden.',
        });
    }

    res.setHeader(
        'Cache-Control',
        's-maxage=86400, stale-while-revalidate=604800',
    );

    return res.status(200).json({ lemma, paradigm });
}

export default async function handler(
    req: VercelRequest,
    res: VercelResponse,
) {
    res.setHeader(
        'Access-Control-Allow-Origin',
        '*',
    );

    res.setHeader(
        'Access-Control-Allow-Methods',
        'GET, OPTIONS',
    );

    res.setHeader(
        'Access-Control-Allow-Headers',
        'Content-Type',
    );

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'GET') {
        return res.status(405).json({
            error: 'Nur GET ist erlaubt.',
        });
    }

    try {
        const {
            lemma,
            tense,
            voice,
            number,
            person,
            paradigm,
            aoristLemma,
        } = req.query;

        if (paradigm !== undefined) {
            if (
                typeof lemma !== 'string' ||
                !isValidParam(lemma, MAX_LEMMA_LENGTH) ||
                (aoristLemma !== undefined &&
                    (typeof aoristLemma !== 'string' ||
                        !isValidParam(aoristLemma, MAX_LEMMA_LENGTH)))
            ) {
                return res.status(400).json({
                    error: 'Ungültige Parameter.',
                });
            }

            return await handleParadigm(res, lemma, aoristLemma);
        }

        if (
            typeof lemma !== 'string' ||
            typeof tense !== 'string' ||
            typeof voice !== 'string' ||
            typeof number !== 'string' ||
            typeof person !== 'string'
        ) {
            return res.status(400).json({
                error:
                    'lemma, tense, voice, number und person sind erforderlich.',
            });
        }

        if (
            !isValidParam(lemma, MAX_LEMMA_LENGTH) ||
            !isValidParam(tense, MAX_PARAM_LENGTH) ||
            !isValidParam(voice, MAX_PARAM_LENGTH) ||
            !isValidParam(number, MAX_PARAM_LENGTH)
        ) {
            return res.status(400).json({
                error: 'Ungültige Parameter.',
            });
        }

        const personNumber =
            Number.parseInt(person, 10);

        if (
            !Number.isInteger(personNumber) ||
            personNumber < 1 ||
            personNumber > 3
        ) {
            return res.status(400).json({
                error:
                    'person muss 1, 2 oder 3 sein.',
            });
        }

        // Nur der Aorist wird über die σσ-Seite geladen; Präsens und
        // Imperfekt stehen auf der Seite der attischen Form selbst.
        const queryLemma = getQueryLemma(lemma, tense);

        const url =
            WIKTIONARY_BASE_URL +
            encodeURIComponent(queryLemma);

        const response = await fetch(url, {
            headers: {
                'User-Agent':
                    'TheologieLernapp/1.0 (Ancient Greek grammar trainer)',
            },
            signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
        });

        if (!response.ok) {
            return res.status(502).json({
                error:
                    `Wiktionary HTTP ${response.status}`,
            });
        }

        const html = await response.text();
        const $ = cheerio.load(html);

        const table = findTenseTable(
            $,
            tense,
            lemma,
        );

        if (table === null) {
            return res.status(404).json({
                error:
                    `Keine Flexionstabelle für ${tense} gefunden.`,
            });
        }

        const form =
            extractIndicativeForm(
                $,
                table,
                voice,
                number,
                personNumber,
            );

        if (form === null) {
            return res.status(404).json({
                error:
                    'Die gewünschte Verbform wurde nicht gefunden.',
            });
        }

        // Gefundene Formen sind für dieselbe Anfrage stabil und dürfen
        // vom Vercel-CDN zwischengespeichert werden. Fehlerantworten
        // werden bewusst nicht gecacht.
        res.setHeader(
            'Cache-Control',
            's-maxage=86400, stale-while-revalidate=604800',
        );

        return res.status(200).json({
            lemma,
            tense,
            voice,
            number,
            person: personNumber,
            // Ohne Längenzeichen und in NFC ausliefern, sonst bleibt z. B.
            // bei ἐφῠ́λᾰξᾰ ein υ mit kombinierendem Akut statt ύ zurück.
            form: comparableForm(form),
            analyses: findVerbAnalyses($, lemma, queryLemma, form),
        });
    } catch (error) {
        console.error(error);

        return res.status(500).json({
            error:
                'Interner Fehler beim Laden der Verbform.',
        });
    }
}