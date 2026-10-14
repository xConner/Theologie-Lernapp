// Prüft die Deutung von Terminangaben (Wochentagscodes, Blöcke, 14-täglich,
// Veranstaltungszeitraum) gegen die Klartextansicht (`show=llong`):
//
//   node tool/univis/univis_check_schedule.mjs --sem 2026w --number 010076 --number 010032
//   node tool/univis/univis_check_schedule.mjs --html-file seite.html   (offline)
//
// Eine Anfrage je Nummer, 5 s Pause dazwischen. Ausgegeben werden nur Folgen
// aus einer festen Liste unverfänglicher Wörter (Wochentage, Daten,
// Uhrzeiten, „Block“, „ab“, „bis“ …) – Namen oder Freitexte der Seite können
// so nicht ins (öffentliche) Protokoll gelangen.

import { parseArgs } from 'node:util';
import { setTimeout as sleep } from 'node:timers/promises';
import { fetchUnivis } from './univis_http.mjs';

const { values } = parseArgs({
    options: {
        host: { type: 'string', default: 'univis.uni-kiel.de' },
        sem: { type: 'string', default: '2026w' },
        number: { type: 'string', multiple: true, default: [] },
        'html-file': { type: 'string' },
    },
});

const WORDS = new Set([
    'mo', 'di', 'mi', 'do', 'fr', 'sa', 'so',
    'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag',
    'block', 'blockveranstaltung', 'einzeltermin', 'einzeltermine', 'termin', 'termine',
    'wöchentlich', 'woche', 'wochen', 'jede', 'jeden', 'zweiwöchentlich', '14-täglich', 'täglich',
    'gerade', 'ungerade', 'kw', 'ab', 'bis', 'am', 'vom', 'von', 'und', 'beginn', 'ende', 'zeit', 'ort',
    'uhr', 'c.t.', 's.t.', 'ausfall', 'entfällt', 'fällt', 'aus', 'nicht', '-', '–', ',', ':',
]);
const DATE = /^\d{1,2}\.\d{1,2}\.(\d{2}|\d{4})?$/;
const TIME = /^\d{1,2}:\d{2}$/;

function tokens(html) {
    return html
        .replace(/<(script|style)[\s\S]*?<\/\1>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
        .replace(/(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})/g, '$1 - $2')
        .replace(/(\d{1,2}\.\d{1,2}\.(?:\d{4}|\d{2})?)\s*[-–]\s*(\d{1,2}\.\d{1,2}\.)/g, '$1 - $2')
        .replace(/([,;])/g, ' $1 ')
        .split(/\s+/)
        .filter(Boolean);
}

function allowed(token) {
    const t = token.toLowerCase().replace(/[.;]$/, (m) => (DATE.test(token) ? m : ''));
    return WORDS.has(t) || DATE.test(token) || TIME.test(token);
}

/** Folgen erlaubter Wörter mit mindestens einem Datum oder einer Uhrzeit. */
function phrases(html) {
    const result = [];
    let run = [];
    const flush = () => {
        if (run.some((t) => DATE.test(t) || TIME.test(t))) result.push(run.join(' '));
        run = [];
    };
    for (const t of tokens(html)) {
        if (allowed(t)) run.push(t);
        else flush();
    }
    flush();
    return [...new Set(result)];
}

if (values['html-file']) {
    const { readFileSync } = await import('node:fs');
    console.log(JSON.stringify(phrases(readFileSync(values['html-file'], 'utf8')), null, 2));
    process.exit(0);
}

const report = [];
for (const [i, number] of values.number.entries()) {
    if (!/^\d{6}$/.test(number)) throw new Error(`--number erwartet sechs Ziffern, nicht "${number}"`);
    if (i > 0) await sleep(5000);
    const url = new URL(`https://${values.host}/prg`);
    url.searchParams.set('search', 'lectures');
    url.searchParams.set('number', number);
    url.searchParams.set('sem', values.sem);
    url.searchParams.set('show', 'llong');
    const { body, meta } = await fetchUnivis(url);
    report.push({ number, status: meta.status, bytes: meta.bytes, phrases: phrases(body) });
}

console.log(JSON.stringify(report, null, 2));
