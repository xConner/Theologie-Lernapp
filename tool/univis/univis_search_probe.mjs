// Prüft die Titelsuche der UnivIS-PRG-Schnittstelle (`search=lectures&name=`)
// und ermittelt die Organisationsnummern der Fakultäten – Grundlage für die
// fakultätsübergreifende Veranstaltungssuche (docs/univis-integration-feasibility.md,
// Abschnitt 14).
//
//   node tool/univis/univis_search_probe.mjs --sem 2026w
//
// Höchstens sechs Anfragen mit Pause dazwischen. Ausgegeben werden nur
// Kennzahlen, Elementnamen und Namen/Nummern von Einrichtungen – keine
// Titel, Personen oder Freitexte (öffentliches Protokoll).

import { parseArgs } from 'node:util';
import * as cheerio from 'cheerio';
import { fetchUnivis, htmlText } from './univis_http.mjs';

const { values } = parseArgs({
    options: {
        host: { type: 'string', default: 'univis.uni-kiel.de' },
        sem: { type: 'string', default: '2026w' },
    },
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function prg(params, rawQuery = '') {
    const url = new URL(`https://${values.host}/prg`);
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
    // Für Latin-1-kodierte Umlaute: URLSearchParams würde UTF-8 kodieren.
    return rawQuery ? new URL(`${url}&${rawQuery}`) : url;
}

async function load(url) {
    const { body, meta } = await fetchUnivis(url);
    const $ = cheerio.load(body, { xml: true });
    const root = $('UnivIS').first();
    return { $, root, meta: { status: meta.status, contentType: meta.contentType, bytes: meta.bytes, ms: meta.ms }, body };
}

/** Kennzahlen einer Veranstaltungssuche, ohne Titel. */
function lectureStats($, root, term) {
    const lectures = root.children('Lecture');
    const orgnames = {};
    const depth = {};
    let titleContains = 0;
    const needle = term?.toLowerCase();
    lectures.each((_, el) => {
        const org = $(el).children('orgname').first().text().trim() || '(ohne)';
        orgnames[org] = (orgnames[org] ?? 0) + 1;
        const units = $(el).children('orgunits').children();
        depth[units.length] = (depth[units.length] ?? 0) + 1;
        if (needle && $(el).children('name').first().text().toLowerCase().includes(needle)) titleContains++;
    });
    const sample = lectures
        .slice(0, 3)
        .map((_, el) => ({
            orgname: $(el).children('orgname').first().text().trim(),
            orgunits: $(el)
                .children('orgunits')
                .children()
                .map((_, u) => ({ tag: u.tagName ?? u.name, text: $(u).text().trim().slice(0, 100) }))
                .get(),
        }))
        .get();
    const top = Object.entries(orgnames).sort((a, b) => b[1] - a[1]).slice(0, 12);
    const counts = {};
    root.children().each((_, el) => {
        const tag = el.tagName ?? el.name;
        counts[tag] = (counts[tag] ?? 0) + 1;
    });
    return { counts, lectures: lectures.length, titleContains, orgunitDepth: depth, distinctOrgnames: Object.keys(orgnames).length, topOrgnames: top, sample };
}

async function step(label, url, fn) {
    console.log(`\n== ${label}`);
    console.log(`URL: ${url}`);
    try {
        const r = await load(url);
        if (r.root.length === 0) {
            console.log(JSON.stringify({ meta: r.meta, error: 'keine UnivIS-XML-Antwort', text: htmlText(r.body).slice(0, 200) }));
            return null;
        }
        const out = fn(r);
        console.log(JSON.stringify({ meta: r.meta, ...out }, null, 1));
        return out;
    } catch (e) {
        console.log(`Fehler: ${e?.name} ${String(e?.message ?? '').slice(0, 120)}`);
        return null;
    }
}

// 1. Fakultäten (Name enthält „Fakult“, ohne Umlaut).
const faculties = await step(
    'Einrichtungen mit „Fakult“ im Namen',
    prg({ search: 'departments', name: 'Fakult', show: 'xml', noimports: '1' }),
    ({ $, root }) => ({
        orgs: root
            .children('Org')
            .map((_, el) => ({
                name: $(el).children('name').first().text().trim(),
                orgnr: $(el).children('orgnr').first().text().trim(),
            }))
            .get(),
    }),
);

await sleep(4000);
// 2. Titelsuche, ein Wort ohne Umlaut.
await step('Titelsuche name=Ethik', prg({ search: 'lectures', name: 'Ethik', sem: values.sem, show: 'xml' }), ({ $, root }) =>
    lectureStats($, root, 'ethik'),
);

await sleep(4000);
// 3. Titelsuche mit zwei Wörtern.
await step(
    'Titelsuche name=Altes Testament',
    prg({ search: 'lectures', name: 'Altes Testament', sem: values.sem, show: 'xml' }),
    ({ $, root }) => lectureStats($, root, 'altes testament'),
);

await sleep(4000);
// 4. Umlaut als ISO-8859-1 (%FC = ü).
await step(
    'Titelsuche name=Einführung (Latin-1)',
    prg({ search: 'lectures', sem: values.sem, show: 'xml' }, 'name=Einf%FChrung'),
    ({ $, root }) => lectureStats($, root, 'einführung'),
);

await sleep(4000);
// 5. Teilwort (Substring?) und Groß-/Kleinschreibung.
await step('Titelsuche name=ethik (klein)', prg({ search: 'lectures', name: 'ethik', sem: values.sem, show: 'xml' }), ({ $, root }) =>
    lectureStats($, root, 'ethik'),
);

// 6. Titelsuche, eingeschränkt auf eine andere Fakultät.
const phil = faculties?.orgs?.find((o) => /^Philosophische Fakult/.test(o.name) && /^\d{9}$/.test(o.orgnr));
if (phil) {
    await sleep(4000);
    await step(
        `Titelsuche name=Ethik&department=${phil.orgnr}`,
        prg({ search: 'lectures', name: 'Ethik', department: phil.orgnr, sem: values.sem, show: 'xml' }),
        ({ $, root }) => lectureStats($, root, 'ethik'),
    );
}
