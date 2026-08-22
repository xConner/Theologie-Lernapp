import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as cheerio from 'cheerio';

const WIKTIONARY_BASE_URL =
    'https://en.wiktionary.org/wiki/';

function cleanText(text: string): string {
    return text
        .replace(/\u00a0/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function extractGreekForm(
    cell: cheerio.Cheerio<any>,
): string | null {
    // Bevorzugt den eigentlichen griechischen Text.
    const polyt = cell.find('.Polyt').first();

    if (polyt.length > 0) {
        const text = cleanText(polyt.text());

        if (text.length > 0) {
            return text;
        }
    }

    // Fallback: .form-of
    const formOf = cell.find('.form-of').first();

    if (formOf.length > 0) {
        const text = cleanText(formOf.text());

        if (text.length > 0) {
            return text;
        }
    }

    // Letzter Fallback: gesamter Zelltext
    const text = cleanText(cell.text());

    if (text.length === 0) {
        return null;
    }

    return text;
}

function normalizeCase(value: string): string {
    const normalized = value
        .toLowerCase()
        .replace(/\s+/g, '')
        .replace(/\u00a0/g, '');

    switch (normalized) {
        case 'nominativ':
        case 'nominative':
            return 'nominative';

        case 'genitiv':
        case 'genitive':
            return 'genitive';

        case 'dativ':
        case 'dative':
            return 'dative';

        case 'akkusativ':
        case 'accusative':
            return 'accusative';

        case 'vokativ':
        case 'vocative':
            return 'vocative';

        default:
            return normalized;
    }
}

function normalizeNumber(value: string): string {
    const normalized = value
        .toLowerCase()
        .replace(/\s+/g, '')
        .replace(/\u00a0/g, '');

    switch (normalized) {
        case 'sg':
        case 'singular':
        case 'singularis':
            return 'singular';

        case 'pl':
        case 'plural':
        case 'pluralis':
            return 'plural';

        case 'dual':
        case 'du':
            return 'dual';

        default:
            return normalized;
    }
}

function findNounTable(
    $: cheerio.CheerioAPI,
): cheerio.Cheerio<any> | null {
    const candidates: {
        table: cheerio.Cheerio<any>;
        title: string;
    }[] = [];

    $('table').each((_, element) => {
        const table = $(element);

        const classes = table.attr('class') ?? '';

        // Griechische Nominal-Flexionstabellen
        if (
            !classes.includes('inflection-table') ||
            !classes.includes('inflection-table-grc')
        ) {
            return;
        }

        const navFrame = table.closest('.NavFrame');

        const title = cleanText(
            navFrame
                ?.find('.NavHead')
                .first()
                .text() ?? '',
        );

        candidates.push({
            table,
            title,
        });
    });

    if (candidates.length === 0) {
        return null;
    }

    // Bevorzuge die erste Tabelle.
    // Bei normalen Wiktionary-Einträgen ist dies
    // normalerweise die attische Flexion.
    const attic = candidates.find(({ title }) =>
        /\(Attic\)/i.test(title),
    );

    if (attic) {
        return attic.table;
    }

    return candidates[0].table;
}

function getColumnIndex(
    number: string,
): number | null {
    const normalized = normalizeNumber(number);

    switch (normalized) {
        case 'singular':
            return 0;

        case 'dual':
            return 1;

        case 'plural':
            return 2;

        default:
            return null;
    }
}

function extractNounForm(
    $: cheerio.CheerioAPI,
    table: cheerio.Cheerio<any>,
    grammaticalCase: string,
    number: string,
): string | null {
    const wantedCase = normalizeCase(
        grammaticalCase,
    );

    const columnIndex = getColumnIndex(number);

    if (columnIndex === null) {
        return null;
    }

    let result: string | null = null;

    table.find('tr').each((_, element) => {
        if (result !== null) {
            return;
        }

        const row = $(element);
        const headers = row.find('th');

        if (headers.length === 0) {
            return;
        }

        const caseText = cleanText(
            $(headers[0]).text(),
        );

        if (
            normalizeCase(caseText) !== wantedCase
        ) {
            return;
        }

        const cells = row.find('td');

        if (cells.length <= columnIndex) {
            return;
        }

        result = extractGreekForm(
            $(cells[columnIndex]),
        );
    });

    return result;
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
            case: grammaticalCase,
            number,
        } = req.query;

        if (
            typeof lemma !== 'string' ||
            typeof grammaticalCase !== 'string' ||
            typeof number !== 'string'
        ) {
            return res.status(400).json({
                error:
                    'lemma, case und number sind erforderlich.',
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

        const table = findNounTable($);

        if (table === null) {
            return res.status(404).json({
                error:
                    'Keine griechische Flexionstabelle für dieses Nomen gefunden.',
            });
        }

        const form = extractNounForm(
            $,
            table,
            grammaticalCase,
            number,
        );

        if (form === null) {
            return res.status(404).json({
                error:
                    'Die gewünschte Nominalform wurde nicht gefunden.',
            });
        }

        return res.status(200).json({
            lemma,
            case: grammaticalCase,
            number,
            form,
        });
    } catch (error) {
        console.error(error);

        return res.status(500).json({
            error:
                'Interner Fehler beim Laden der Nominalform.',
        });
    }
}