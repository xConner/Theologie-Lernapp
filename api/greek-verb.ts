import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as cheerio from 'cheerio';

const WIKTIONARY_BASE_URL =
    'https://en.wiktionary.org/wiki/';

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
        .replace(/\u00a0/g, '');

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
        .replace(/\u00a0/g, ' ')
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

    if (text.length === 0 || text === '\u00a0') {
        return null;
    }

    return text;
}

function findTenseTable(
    $: cheerio.CheerioAPI,
    tense: string,
): cheerio.Cheerio<any> | null {
    const tenseClass = getTenseClass(tense);

    if (tenseClass === null) {
        return null;
    }

    const candidates: {
        table: cheerio.Cheerio<any>;
        title: string;
    }[] = [];

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
                ?.find('.NavHead')
                .first()
                .text() ?? '',
        )
            .replace(/^show\s*▼\s*/i, '')
            .trim();

        candidates.push({
            table,
            title,
        });
    });

    if (candidates.length === 0) {
        return null;
    }

    // 1. Bevorzuge ausdrücklich die kontrahierte Tabelle.
    const contracted = candidates.find(({ title }) =>
        /\(Contracted\)$/i.test(title),
    );

    if (contracted) {
        return contracted.table;
    }

    // 2. Falls keine kontrahierte Tabelle existiert,
    //    bevorzuge die normale Tabelle ohne Dialektangabe.
    const normal = candidates.find(({ title }) =>
        !/\((?:Epic|Ionic|Attic|Koine)[^)]*\)/i.test(title),
    );

    if (normal) {
        return normal.table;
    }

    // 3. Letzter Fallback: erste passende Tabelle.
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

            // Nur Indicative
            if (
                secondHeader.toLowerCase() !== 'indicative'
            ) {
                return;
            }

            // Richtige Voice
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
    // ---------------------------------------------------------

    if (wantedVoice === 'active') {
        return findFormInRows(isActiveVoice);
    }

    // ---------------------------------------------------------
    // MEDIUM/PASSIV
    // ---------------------------------------------------------

    if (wantedVoice === 'middle/passive') {
        // Wiktionary verwendet häufig einfach "middle",
        // auch wenn die grammatische Kategorie Medium/Passiv ist.
        const middleForm = findFormInRows(isMiddleVoice);

        if (middleForm !== null) {
            return middleForm;
        }

        // Nur wenn keine Middle-Form existiert:
        // echte Passive-Form versuchen.
        return findFormInRows(isPassiveVoice);
    }

    // ---------------------------------------------------------
    // NUR MEDIUM
    // ---------------------------------------------------------

    if (wantedVoice === 'middle') {
        return findFormInRows(isMiddleVoice);
    }

    // ---------------------------------------------------------
    // NUR PASSIV
    // ---------------------------------------------------------

    if (wantedVoice === 'passive') {
        return findFormInRows(isPassiveVoice);
    }

    return null;
}

export default async function handler(
    req: VercelRequest,
    res: VercelResponse,
) {
    // CORS
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
        } = req.query;

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

        const url =
            WIKTIONARY_BASE_URL +
            encodeURIComponent(lemma);

        const response = await fetch(url, {
            headers: {
                'User-Agent':
                    'TheologieLernapp/1.0 (Ancient Greek grammar trainer)',
            },
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

        return res.status(200).json({
            lemma,
            tense,
            voice,
            number,
            person: personNumber,
            form,
        });
    } catch (error) {
        console.error(error);

        return res.status(500).json({
            error:
                'Interner Fehler beim Laden der Verbform.',
        });
    }
}