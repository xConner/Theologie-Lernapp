// Reproduzierbarer Abruftest der UnivIS-PRG-Schnittstelle.
//
//   node tool/univis/univis_probe.mjs --sem 2026w --param name=Theologie
//   node tool/univis/univis_probe.mjs --sem 2026w --param department=<OrgNr>
//   node tool/univis/univis_probe.mjs --file antwort.xml        (offline)
//
// Optionen:
//   --host <host>        UnivIS-Installation (Standard: univis.uni-kiel.de)
//   --search <modul>     PRG-Suchmodul (Standard: lectures)
//   --sem <kennung>      Semester, z. B. 2026w oder 2026s
//   --param k=v          weiterer PRG-Parameter, mehrfach möglich
//   --file <pfad>        gespeicherte XML-Antwort statt Netzabruf
//   --save-raw <pfad>    Rohantwort speichern (NICHT ins Repository legen:
//                        enthält Namen von Lehrpersonen)
//   --sample <n>         n normalisierte Veranstaltungen ausgeben (Standard 3)
//
// Genau EINE Anfrage je Aufruf, mit Zeitlimit und erkennbarem User-Agent.
// Keine Anmeldung, keine Cookies, keine Zugangsdaten.

import { readFile, writeFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { parseUnivisLectures, validateLectures } from './univis_parser.mjs';

const USER_AGENT =
    'theologie.app-univis-probe/0.1 (+https://www.theologie.app; Machbarkeitstest)';
const TIMEOUT_MS = 20000;

const { values } = parseArgs({
    options: {
        host: { type: 'string', default: 'univis.uni-kiel.de' },
        search: { type: 'string', default: 'lectures' },
        sem: { type: 'string' },
        param: { type: 'string', multiple: true, default: [] },
        file: { type: 'string' },
        'save-raw': { type: 'string' },
        sample: { type: 'string', default: '3' },
    },
});

function buildUrl() {
    if (!/^[a-z0-9.-]+$/i.test(values.host)) {
        throw new Error(`Ungültiger Host: ${values.host}`);
    }
    const url = new URL(`https://${values.host}/prg`);
    url.searchParams.set('search', values.search);
    url.searchParams.set('show', 'xml');
    if (values.sem) url.searchParams.set('sem', values.sem);
    for (const entry of values.param) {
        const i = entry.indexOf('=');
        if (i <= 0) throw new Error(`--param erwartet k=v, nicht "${entry}"`);
        url.searchParams.set(entry.slice(0, i), entry.slice(i + 1));
    }
    return url;
}

async function load() {
    if (values.file) {
        return { xml: await readFile(values.file, 'utf8'), meta: { file: values.file } };
    }
    const url = buildUrl();
    const started = Date.now();
    const response = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/xml, text/xml' },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        redirect: 'follow',
    });
    const xml = await response.text();
    const meta = {
        url: url.toString(),
        status: response.status,
        contentType: response.headers.get('content-type'),
        lastModified: response.headers.get('last-modified'),
        etag: response.headers.get('etag'),
        cacheControl: response.headers.get('cache-control'),
        bytes: Buffer.byteLength(xml),
        ms: Date.now() - started,
    };
    if (values['save-raw']) await writeFile(values['save-raw'], xml);
    if (!response.ok) {
        console.log(JSON.stringify({ meta, bodyStart: xml.slice(0, 500) }, null, 2));
        process.exit(1);
    }
    return { xml, meta };
}

const { xml, meta } = await load();
const result = parseUnivisLectures(xml);
const sampleSize = Math.max(0, Number(values.sample) || 0);

console.log(
    JSON.stringify(
        {
            meta,
            validation: validateLectures(result),
            inventory: result.inventory,
            sample: result.lectures.slice(0, sampleSize),
        },
        null,
        2,
    ),
);
