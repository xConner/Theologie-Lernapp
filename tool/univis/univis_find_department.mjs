// Ermittelt die Organisationsnummer einer Einrichtung direkt aus UnivIS,
// statt sie zu raten:
//
//   node tool/univis/univis_find_department.mjs --name "Theologische Fakultät"
//   node tool/univis/univis_find_department.mjs --file antwort.xml   (offline)
//
// Genau EINE Anfrage (`search=departments&show=xml&noimports=1`). Ausgegeben
// werden nur Datensätze von Einrichtungen; Personen-Datensätze werden nur
// gezählt, Kontaktfelder ausgelassen – die Ausgabe darf in öffentlichen
// Protokollen (GitHub Actions) stehen.
//
// Welches Element die OrgNr trägt, ist nicht dokumentiert. Das Skript zeigt
// deshalb alle einfachen Felder und markiert Werte aus 6–9 Ziffern als
// Kandidaten, jeweils mit Elementnamen.

import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import * as cheerio from 'cheerio';

const USER_AGENT =
    'theologie.app-univis-probe/0.1 (+https://www.theologie.app; Machbarkeitstest)';
const SKIP = /mail|tel|fax|phone|mobil|street|address|sprech|office/i;

const { values } = parseArgs({
    options: {
        host: { type: 'string', default: 'univis.uni-kiel.de' },
        name: { type: 'string', default: 'Theologische Fakultät' },
        file: { type: 'string' },
    },
});

async function load() {
    if (values.file) return { xml: await readFile(values.file, 'utf8'), meta: { file: values.file } };
    const url = new URL(`https://${values.host}/prg`);
    url.searchParams.set('search', 'departments');
    url.searchParams.set('name', values.name);
    url.searchParams.set('show', 'xml');
    url.searchParams.set('noimports', '1');
    const response = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/xml, text/xml' },
        signal: AbortSignal.timeout(20000),
    });
    const xml = await response.text();
    return {
        xml,
        meta: {
            url: url.toString(),
            status: response.status,
            contentType: response.headers.get('content-type'),
            bytes: Buffer.byteLength(xml),
        },
    };
}

const { xml, meta } = await load();
const $ = cheerio.load(xml, { xml: true });
const root = $('UnivIS').first();

if (root.length === 0) {
    console.log(JSON.stringify({ meta, error: 'keine UnivIS-XML-Antwort', bodyStart: xml.slice(0, 500) }, null, 2));
    process.exit(1);
}

const counts = {};
const departments = [];

root.children().each((_, el) => {
    const tag = el.tagName ?? el.name;
    counts[tag] = (counts[tag] ?? 0) + 1;
    if (tag === 'Person') return;

    const fields = {};
    const candidates = [];
    $(el)
        .children()
        .each((_, child) => {
            const name = child.tagName ?? child.name;
            if (SKIP.test(name) || $(child).children().length > 0) return;
            const text = $(child).text().replace(/\s+/g, ' ').trim().slice(0, 120);
            if (!text) return;
            fields[name] = text;
            if (/^\d{6,9}$/.test(text)) candidates.push({ element: name, value: text });
        });
    departments.push({ tag, key: $(el).attr('key') ?? null, fields, orgNrCandidates: candidates });
});

console.log(JSON.stringify({ meta, counts, departments }, null, 2));
