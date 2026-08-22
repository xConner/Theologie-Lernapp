import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as cheerio from 'cheerio';

export default async function handler(
    req: VercelRequest,
    res: VercelResponse,
) {
    try {
        const lemma = req.query.lemma;

        if (typeof lemma !== 'string' || lemma.trim().length === 0) {
            return res.status(400).json({
                error: 'Lemma fehlt.',
            });
        }

        const url =
            `https://en.wiktionary.org/wiki/${encodeURIComponent(lemma)}`;

        const response = await fetch(url, {
            headers: {
                'User-Agent':
                    'TheologieLernapp/1.0 (Ancient Greek grammar trainer)',
            },
        });

        if (!response.ok) {
            return res.status(response.status).json({
                error: `Wiktionary HTTP ${response.status}`,
            });
        }

        const html = await response.text();

        const $ = cheerio.load(html);

        return res.status(200).json({
            html,
        });
    } catch (error) {
        console.error(error);

        return res.status(500).json({
            error: 'Fehler beim Abrufen von Wiktionary.',
        });
    }
}