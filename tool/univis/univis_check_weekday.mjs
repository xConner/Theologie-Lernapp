// Prüft die Deutung der Wochentagscodes (`w1 4` …) gegen die Klartextansicht
// derselben Veranstaltung (`show=llong`):
//
//   node tool/univis/univis_check_weekday.mjs --sem 2026w --number 010076
//
// Genau EINE Anfrage. Ausgegeben werden nur Treffer der Form
// „<Wochentag> <Uhrzeit>“ – keine Namen oder sonstigen Texte der Seite.

import { parseArgs } from 'node:util';
import { fetchUnivis, htmlText } from './univis_http.mjs';

const { values } = parseArgs({
    options: {
        host: { type: 'string', default: 'univis.uni-kiel.de' },
        sem: { type: 'string', default: '2026w' },
        number: { type: 'string' },
    },
});

if (!/^\d{6}$/.test(values.number ?? '')) {
    throw new Error('--number erwartet eine sechsstellige Veranstaltungsnummer');
}

const url = new URL(`https://${values.host}/prg`);
url.searchParams.set('search', 'lectures');
url.searchParams.set('number', values.number);
url.searchParams.set('sem', values.sem);
url.searchParams.set('show', 'llong');

const { body, meta } = await fetchUnivis(url);
const text = htmlText(body.length > 0 ? body : '');
const full = body
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ');
const pattern =
    /\b(Mo|Di|Mi|Do|Fr|Sa|So|Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag)\b[,.]?\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/g;
const matches = [...new Set([...full.matchAll(pattern)].map((m) => `${m[1]} ${m[2]}-${m[3]}`))];

console.log(
    JSON.stringify(
        { meta, matches, hasContent: text.length > 0 },
        null,
        2,
    ),
);
