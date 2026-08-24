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

        // --- PRIORITÄTEN SYSTEM ---
        // 1. TABELLEN OHNE LABEL ("normal") haben niedrigste Priorität
        // 2. Contracted-Tabellen sind höher als normal für Imperfect
        // 3. Unter benannten Tabeln: Attic > Epic/Ionic/Koine

        let score = 0;

        // BASE SCORE für Contracted-Tabellen
        if (/Contracted/i.test(title)) {
            score += 150; // Contracted ist immer besser als "normal" ohne Label
        }
        // 1. TABELLEN OHNE SPEZIELLES LABEL ("normal")
        //    Diese haben die niedrigste Priorität (100 Points)
        //    Egal ob attic-class oder nicht - wenn kein Label im Titel,
        //    ist es die niedrigste Wahl
        if (!/Attic/i.test(title) && !/Contracted/i.test(title) &&
            !/(Epic|Ionic|Koine)/i.test(title)) {
            score += 100; // Niedrigste Priorität für "normale" Tabellen
        }
        // 2. ATTIC LABEL (unter den benannten Tabeln)
        else if (/Attic/i.test(title)) {
            score += 200; // Attic ist hoch

            // Bonus: Attic + Contracted kombiniert
            if (/Contracted/i.test(title)) {
                score += 50; // Attic+Contracted = 250 Points
            }
        }
        // 3. CONTRACTED LABEL (ohne Attic)
        else if (/Contracted/i.test(title)) {
            // Contracted hat Basis-Score 150, plus evtl. Bonus
            if (tense === 'Imperfekt') {
                score += 50; // Imperfect Contracted = 200 Points (über Attic! aber unter Attic+Contracted)
            }
        }
        // 4. NICHT-ATTIC BENANNETE TABELN (Epic, Ionic, Koine etc.)
        else if (/(Epic|Ionic|Koine)/i.test(title)) {
            score -= 100; // Bestrafung: -100 Points
        }
        // 5. Übrige spezielle Tabellen
        else {
            score += 0; // Neutral: 0 Points
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

    // Sortiere nach Score (höchste zuerst)
    candidates.sort((a, b) => b.score - a.score);

    // Debug-Logging (optional, kann bei Bedarf aktiviert werden)
    // if (lemma && candidates.length > 1) {
    //     console.log(`Verb: ${lemma}, Tempora-Kandidaten:`);
    //     candidates.forEach((c, i) => {
    //         console.log(`  ${i + 1}. Score ${c.score}: ${c.title}`);
    //     });
    // }

    // Nimm die beste Tabelle (höchster Score = beste Priorität)
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
        // 1. Middle
        const middleForm = findFormInRows(isMiddleVoice);

        if (middleForm !== null) {
            return middleForm;
        }

        // 2. Echte Middle/Passive-Zeile
        // (wird durch isMiddleVoice bereits mit abgedeckt,
        // bleibt aber logisch Teil des Fallbacks)

        // 3. Passive
        const passiveForm = findFormInRows(isPassiveVoice);

        if (passiveForm !== null) {
            return passiveForm;
        }

        // 4. Manche Deponentien haben in einzelnen Tempora
        // morphologisch aktive Formen, z. B. ἔρχομαι → ἦλθον.
        return findFormInRows(isActiveVoice);
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