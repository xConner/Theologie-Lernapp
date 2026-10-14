// Prüft die Links der Studienunterlagen (assets/study/documents.json) bzw.
// eine Kandidatenliste und liest von offiziellen Übersichtsseiten die
// verlinkten Dokumente aus:
//
//   node tool/study_documents/check_links.mjs [--file liste.json] [--discover]
//
// Läuft in GitHub Actions (.github/workflows/study-documents.yml), weil die
// Entwicklungsumgebung uni-kiel.de nicht erreicht. Ausgabe: Status,
// Inhaltstyp, Größe, Seitentitel; bei PDFs der Anfang der ersten Seite
// (pdftotext), E-Mail-Adressen entfernt. Eine Anfrage je URL, mit Pause.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import * as cheerio from 'cheerio';

const { values } = parseArgs({
    options: {
        file: { type: 'string', default: 'assets/study/documents.json' },
        discover: { type: 'boolean', default: false },
    },
});

const USER_AGENT = 'theologie.app-linkcheck/1.0 (+https://www.theologie.app)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const scrub = (s) => s.replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[E-Mail]').replace(/\s+/g, ' ').trim();
const work = mkdtempSync(join(tmpdir(), 'linkcheck-'));

function urlsFrom(json) {
    if (Array.isArray(json)) return json.map((u) => (typeof u === 'string' ? { url: u } : u));
    const out = [];
    for (const group of json.groups ?? []) {
        for (const doc of group.documents ?? []) {
            out.push({ url: doc.url, id: doc.id, kind: 'document' });
            if (doc.sourcePage) out.push({ url: doc.sourcePage, id: `${doc.id}#Fundstelle`, kind: 'page' });
        }
    }
    for (const page of json.overviewPages ?? []) out.push({ url: page.url, id: page.id, kind: 'page' });
    return [...new Map(out.map((e) => [e.url, e])).values()];
}

async function check({ url, id }) {
    const result = { id: id ?? null, url };
    try {
        const res = await fetch(url, {
            headers: { 'User-Agent': USER_AGENT },
            redirect: 'follow',
            signal: AbortSignal.timeout(30_000),
        });
        const bytes = new Uint8Array(await res.arrayBuffer());
        Object.assign(result, {
            status: res.status,
            finalUrl: res.url !== url ? res.url : undefined,
            contentType: res.headers.get('content-type'),
            lastModified: res.headers.get('last-modified') ?? undefined,
            bytes: bytes.length,
        });
        const type = result.contentType ?? '';
        if (type.includes('pdf') || Buffer.from(bytes.slice(0, 5)).toString() === '%PDF-') {
            const file = join(work, 'doc.pdf');
            writeFileSync(file, bytes);
            try {
                const text = execFileSync('pdftotext', ['-l', '2', '-enc', 'UTF-8', file, '-'], { encoding: 'utf8' });
                result.pdfStart = scrub(text).slice(0, 700);
                const info = execFileSync('pdfinfo', [file], { encoding: 'utf8' });
                result.pdfInfo = Object.fromEntries(
                    info.split('\n').map((l) => l.split(/:\s+/, 2)).filter(([k]) => ['Title', 'CreationDate', 'ModDate', 'Pages'].includes(k)),
                );
            } catch (e) {
                result.pdfError = String(e.message).slice(0, 100);
            }
        } else if (type.includes('html')) {
            const $ = cheerio.load(Buffer.from(bytes).toString('utf8'));
            result.title = scrub($('title').first().text()).slice(0, 200);
            result.h1 = scrub($('h1').first().text()).slice(0, 200);
            if (values.discover) {
                const links = [];
                $('a[href]').each((_, a) => {
                    const href = $(a).attr('href');
                    let abs;
                    try {
                        abs = new URL(href, res.url).toString();
                    } catch {
                        return;
                    }
                    if (!/\.pdf($|\?)|\/sta\/|amtl-bekannt|modulhandbuch|pruefungsordnung|studienverlauf|studienplan/i.test(abs)) return;
                    if (abs.startsWith('mailto:')) return;
                    links.push({ text: scrub($(a).text()).slice(0, 160), href: abs });
                });
                result.links = [...new Map(links.map((l) => [l.href, l])).values()].slice(0, 80);
            }
        }
    } catch (e) {
        result.error = `${e?.name}: ${String(e?.cause?.code ?? e?.message ?? '').slice(0, 120)}`;
    }
    return result;
}

const entries = urlsFrom(JSON.parse(readFileSync(values.file, 'utf8')));
let failures = 0;
for (const entry of entries) {
    const r = await check(entry);
    if (r.error || r.status >= 400) failures++;
    console.log(JSON.stringify(r, null, 1));
    await sleep(1500);
}
console.log(`\n${entries.length} URLs geprüft, ${failures} nicht erreichbar.`);
process.exitCode = failures > 0 && !values.discover ? 1 : 0;
