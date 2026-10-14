// Tests des Katalog-Endpunkts /api/catalog ohne Netzwerk (Mock-Antworten
// aus fixtures/, künstliche Uhr):
//   node --test api/_lib/catalog/endpoint.test.mjs

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');
const out = join(root, 'node_modules', '.cache', 'catalog-endpoint-test');
const require = createRequire(join(root, 'package.json'));

execFileSync(process.execPath, [
    require.resolve('typescript/bin/tsc'),
    '--outDir', out, '--rootDir', join(root, 'api'),
    '--module', 'commonjs', '--moduleResolution', 'node10', '--target', 'es2022',
    '--esModuleInterop', '--skipLibCheck', '--strict', '--types', 'node',
    join(root, 'api', 'catalog.ts'),
    join(here, 'firestore-store.ts'),
], { stdio: 'inherit' });

const lib = (name) => require(join(out, '_lib', name));
const { createCatalogHandler, configFrom } = lib('catalog-endpoint.js');
const { UnivisSource, CAU_UNIVIS } = lib('catalog/univis/source.js');
const { FirestoreCatalogStore } = lib('catalog/firestore-store.js');
const { CatalogCache } = lib('catalog/cache.js');
const { offeredSemesters, CAU_SEMESTERS } = lib('catalog/semesters.js');
const guardedEndpoint = require(join(out, 'catalog.js')).default;

const xml = readFileSync(join(here, 'fixtures', 'synthetic-catalog.xml'), 'utf8');
const HOUR = 3_600_000;
const T0 = Date.parse('2026-10-14T10:00:00Z');

function setup({ body = () => xml, status = () => 200, persistent = null, env = {} } = {}) {
    const calls = [];
    const logs = [];
    let clock = T0;
    let failing = false;
    const fetchImpl = async (url) => {
        calls.push(String(url));
        await new Promise((r) => setTimeout(r, 5));
        if (failing) throw new TypeError('fetch failed');
        return new Response(body(calls.length), { status: status(calls.length), headers: { 'content-type': 'text/xml' } });
    };
    const handler = createCatalogHandler({
        source: new UnivisSource(CAU_UNIVIS, fetchImpl),
        persistent,
        env,
        now: () => clock,
        log: (m) => logs.push(m),
    });
    return {
        handler, calls, logs,
        advance: (ms) => { clock += ms; },
        fail: (value = true) => { failing = value; },
    };
}

async function call(handler, { method = 'GET', query = {}, headers = {} } = {}) {
    const result = { status: 200, headers: {}, body: undefined };
    const res = {
        setHeader(k, v) { result.headers[k.toLowerCase()] = v; },
        status(code) { result.status = code; return this; },
        json(b) { result.body = b; return this; },
        send(b) { result.body = b === '' ? '' : JSON.parse(b); return this; },
        end() { return this; },
        headersSent: false,
    };
    await handler({ method, query, headers }, res);
    return result;
}

test('Semesterliste: laufendes und nächstes konfiguriertes Semester', async () => {
    const { handler, calls } = setup();
    const r = await call(handler);
    assert.equal(r.status, 200);
    assert.deepEqual(r.body.semesters.map((s) => s.id), ['2026w', '2027s']);
    assert.deepEqual(r.body.organizations, [{ id: '010000000', name: 'Theologische Fakultät' }]);
    assert.equal(r.body.faculties.length, 9);
    assert.ok(r.body.faculties.some((f) => f.id === '050000000' && f.name === 'Philosophische Fakultät'));
    assert.equal(calls.length, 0);
    assert.deepEqual(offeredSemesters(CAU_SEMESTERS, '2027-04-10').map((s) => s.id), ['2027s']);
    assert.deepEqual(offeredSemesters(CAU_SEMESTERS, '2027-10-01'), []);
});

test('Eingaben: nur angebotene Semester und feste Einrichtungen, nur GET', async () => {
    const { handler, calls } = setup();
    for (const query of [
        { semester: '2025w' },
        { semester: '2026w&host=evil.example' },
        { semester: ['2026w', '2027s'] },
        { semester: '' },
        { semester: '2026w', organization: '020000000' },
        { semester: '2026w', organization: 'https://evil.example/' },
    ]) {
        const r = await call(handler, { query });
        assert.equal(r.status, 400, JSON.stringify(query));
    }
    assert.equal((await call(handler, { method: 'POST', query: { semester: '2026w' } })).status, 405);
    assert.equal(calls.length, 0);
});

test('Katalog: genau eine Anfrage an die feste UnivIS-Adresse, öffentliche Felder', async () => {
    const { handler, calls } = setup();
    const r = await call(handler, { query: { semester: '2026w' } });
    assert.equal(r.status, 200);
    assert.deepEqual(calls, ['https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&department=010000000']);
    assert.equal(r.body.synthetic, false);
    assert.equal(r.body.semester.id, '2026w');
    assert.equal(r.body.courses.length, 12);
    assert.equal(r.body.cache.state, 'refreshed');
    assert.equal(r.headers['x-catalog-state'], 'refreshed');
    assert.match(r.headers['cache-control'], /s-maxage=86400/);
    assert.ok(r.body.occurrences.length > 0);
    assert.deepEqual(Object.keys(r.body.courses[0]).sort(), [
        'classification', 'detailUrl', 'ects', 'endDate', 'id', 'imported', 'lecturerIds', 'moduleCodes',
        'number', 'organizationPath', 'organizations', 'rules', 'semesterId', 'sources', 'startDate', 'sws', 'title', 'type',
    ]);
});

test('Datenschutz: keine Freitexte, keine Personenschlüssel, keine internen Nummern, kein XML', async () => {
    const { handler, logs } = setup();
    const r = await call(handler, { query: { semester: '2026w' } });
    const json = JSON.stringify(r.body);
    for (const forbidden of ['example.org', 'Anmeldung', 'Person.test', 'internalId', 'importParentId', '<UnivIS', 'Verwendet', 'warnings']) {
        assert.ok(!json.includes(forbidden), forbidden);
    }
    assert.deepEqual(Object.keys(r.body.persons[0]).sort(), ['displayName', 'id']);
    assert.match(r.body.persons[0].id, /^cau-univis:p[0-9a-f]{16}$/);
    const lecturer = r.body.courses.find((c) => c.lecturerIds.length > 0).lecturerIds[0];
    assert.ok(r.body.persons.some((p) => p.id === lecturer));
    // ECTS nur aus der Quelle.
    assert.ok(r.body.courses.every((c) => c.ects === null || c.ects === 3));
    assert.ok(logs.every((m) => !/Lecture|Test|example/.test(m)));
});

test('Cache: frisch ohne Abruf, parallele Anfragen teilen einen Abruf, nach Ablauf neu', async () => {
    const { handler, calls, advance } = setup();
    const parallel = await Promise.all(Array.from({ length: 6 }, () => call(handler, { query: { semester: '2026w' } })));
    assert.equal(calls.length, 1);
    assert.ok(parallel.every((r) => r.status === 200));
    advance(23 * HOUR);
    assert.equal((await call(handler, { query: { semester: '2026w' } })).body.cache.state, 'fresh');
    assert.equal(calls.length, 1);
    advance(2 * HOUR);
    assert.equal((await call(handler, { query: { semester: '2026w' } })).body.cache.state, 'refreshed');
    assert.equal(calls.length, 2);
    // Andere Semester haben einen eigenen Eintrag.
    await call(handler, { query: { semester: '2027s' } });
    assert.equal(calls.length, 3);
    assert.match(calls[2], /sem=2027s/);
});

test('Ausfall: alter Stand als stale, nach Höchstdauer 503 ohne erfundene Daten', async () => {
    const { handler, advance, fail, logs } = setup();
    await call(handler, { query: { semester: '2026w' } });
    advance(25 * HOUR);
    fail();
    const stale = await call(handler, { query: { semester: '2026w' } });
    assert.equal(stale.status, 200);
    assert.equal(stale.body.cache.state, 'stale');
    assert.equal(stale.body.cache.reason, 'source-unavailable');
    assert.equal(stale.headers['x-catalog-state'], 'stale');
    assert.match(stale.headers['cache-control'], /s-maxage=600/);
    assert.equal(stale.body.courses.length, 12);
    assert.ok(logs.some((m) => m.startsWith('refresh-failed')));

    advance(15 * 24 * HOUR);
    const gone = await call(handler, { query: { semester: '2026w' } });
    assert.equal(gone.status, 503);
    assert.equal(gone.body.code, 'source-unavailable');
    assert.equal(gone.headers['cache-control'], 'no-store');
    assert.equal(gone.body.courses, undefined);
});

test('Fehlerhafte Antworten: HTML, HTTP-Fehler, abgeschnitten, unplausibel leer', async () => {
    const html = setup({ body: () => '<html><body>UnivIS Anfrage</body></html>' });
    const r1 = await call(html.handler, { query: { semester: '2026w' } });
    assert.equal(r1.status, 503);
    assert.ok(!JSON.stringify(r1.body).includes('UnivIS Anfrage'));

    const http = setup({ status: () => 500 });
    assert.equal((await call(http.handler, { query: { semester: '2026w' } })).status, 503);

    // Erst vollständig, dann plötzlich leer → alter Stand bleibt (stale, implausible).
    const shrink = setup({ body: (n) => (n === 1 ? xml : '<UnivIS version="1.6"/>') });
    await call(shrink.handler, { query: { semester: '2026w' } });
    shrink.advance(25 * HOUR);
    const r2 = await call(shrink.handler, { query: { semester: '2026w' } });
    assert.equal(r2.body.cache.state, 'stale');
    assert.equal(r2.body.cache.reason, 'implausible');
    assert.equal(r2.body.courses.length, 12);

    // Ohne früheren Stand ist ein leerer Katalog gültig (Semester noch nicht gepflegt).
    const empty = setup({ body: () => '<UnivIS version="1.6"/>' });
    const r3 = await call(empty.handler, { query: { semester: '2027s' } });
    assert.equal(r3.status, 200);
    assert.deepEqual(r3.body.courses, []);
});

test('ETag: unveränderter Stand → 304', async () => {
    const { handler } = setup();
    const first = await call(handler, { query: { semester: '2026w' } });
    const again = await call(handler, { query: { semester: '2026w' }, headers: { 'if-none-match': first.headers.etag } });
    assert.equal(again.status, 304);
});

test('Dauerhafter Speicher: Kaltstart ohne neuen Abruf, Rundreise komprimiert', async () => {
    const docs = new Map();
    const store = new FirestoreCatalogStore((key) => ({
        async get() { return { exists: docs.has(key), data: () => docs.get(key) }; },
        async set(data) { docs.set(key, data); },
    }), 1);
    const a = setup({ persistent: store });
    await call(a.handler, { query: { semester: '2026w' } });
    assert.equal(docs.size, 1);
    const stored = [...docs.values()][0];
    assert.equal(typeof stored.gz, 'string');
    assert.ok(!stored.gz.includes('Test'));

    const b = setup({ persistent: store });
    const r = await call(b.handler, { query: { semester: '2026w' } });
    assert.equal(b.calls.length, 0);
    assert.equal(r.body.cache.state, 'fresh');
    assert.equal(r.body.courses.length, 12);
    assert.equal(await new FirestoreCatalogStore(() => ({ async get() { return { exists: true, data: () => ({ version: 0 }) }; }, async set() {} }), 1).read('x'), null);
});

test('Lese-/Schreibfehler des dauerhaften Speichers stören den Abruf nicht', async () => {
    const broken = { async read() { throw new Error('down'); }, async write() { throw new Error('down'); } };
    const s = setup({ persistent: broken });
    const r = await call(s.handler, { query: { semester: '2026w' } });
    assert.equal(r.status, 200);
    assert.ok(s.logs.some((m) => m.startsWith('persistent-read-failed')));
    assert.ok(s.logs.some((m) => m.startsWith('persistent-write-failed')));
});

test('Konfiguration: Gültigkeit begrenzt, ungültige Werte → Standard', () => {
    assert.equal(configFrom({}).ttlMs, 24 * HOUR);
    assert.equal(configFrom({ CATALOG_CACHE_TTL_HOURS: '6' }).ttlMs, 6 * HOUR);
    assert.equal(configFrom({ CATALOG_CACHE_TTL_HOURS: '0' }).ttlMs, 24 * HOUR);
    assert.equal(configFrom({ CATALOG_CACHE_TTL_HOURS: 'x' }).ttlMs, 24 * HOUR);
    assert.equal(configFrom({ CATALOG_MAX_STALE_HOURS: '48' }).maxStaleMs, 48 * HOUR);
});

test('Cache-Baustein: parallele Fehler teilen einen Versuch', async () => {
    let n = 0;
    const cache = new CatalogCache({ ttlMs: 1000, maxStaleMs: 2000, sizeOf: () => 1, now: () => 0 });
    const results = await Promise.allSettled([1, 2, 3].map(() => cache.get('k', async () => { n++; throw new Error('x'); })));
    assert.equal(n, 1);
    assert.ok(results.every((r) => r.status === 'rejected' && r.reason.name !== undefined));
});

test('Schutzhülle: Endpunkt lädt über guarded', async () => {
    assert.equal(typeof guardedEndpoint, 'function');
    const r = await call(guardedEndpoint, { method: 'DELETE', query: {} });
    assert.equal(r.status, 405);
});

// --- Fakultätsübergreifende Suche (search.ts) -------------------------------

const { latin1Component, normalizeSearchText, rankOf, trimSnapshot } = lib('catalog/search.js');

test('Suche: Eingaben prüfen, nichts Unbekanntes an UnivIS weitergeben', async () => {
    const { handler, calls } = setup();
    for (const query of [
        { semester: '2026w', q: 'ab' },
        { semester: '2026w', q: 'x'.repeat(81) },
        { semester: '2026w', q: ['Ethik', 'Recht'] },
        { semester: '2026w', q: 'Ethik&department=1' },
        { semester: '2026w', q: '<script>' },
        { semester: '2026w', q: 'Καινή' },
        { semester: '2026w', q: '---' },
        { semester: '2026w', number: '12345' },
        { semester: '2026w', number: '0100761' },
        { semester: '2026w', q: 'Ethik', number: '010076' },
        { semester: '2026w', q: 'Ethik', faculty: '999999999' },
        { semester: '2026w', q: 'Ethik', faculty: ['050000000'] },
        { semester: '1999w', q: 'Ethik' },
    ]) {
        const r = await call(handler, { query });
        assert.equal(r.status, 400, JSON.stringify(query));
    }
    assert.equal(calls.length, 0);
    assert.equal(normalizeSearchText('  Einführung   in  die  Ethik '), 'Einführung in die Ethik');
    assert.equal(normalizeSearchText('Ethik – Grundlagen'), 'Ethik - Grundlagen');
});

test('Suche: Umlaute in ISO-8859-1, Fakultät als department, Nummer', async () => {
    const { handler, calls } = setup();
    assert.equal(latin1Component('Einführung Ethik'), 'Einf%FChrung%20Ethik');
    assert.throws(() => latin1Component('Ω'));
    let r = await call(handler, { query: { semester: '2026w', q: 'Einführung', faculty: '050000000' } });
    assert.equal(r.status, 200);
    r = await call(handler, { query: { semester: '2026w', number: '010076' } });
    assert.equal(r.status, 200);
    assert.deepEqual(calls, [
        'https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&name=Einf%FChrung&department=050000000',
        'https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&number=010076',
    ]);
    assert.equal(r.body.search.number, '010076');
    assert.equal(r.body.synthetic, false);
});

test('Suche: Ergebnis in öffentlicher Form mit Einrichtungshierarchie, Zwischenspeicher', async () => {
    const { handler, calls } = setup();
    const r = await call(handler, { query: { semester: '2026w', q: 'Test' } });
    assert.equal(r.status, 200);
    assert.equal(r.body.search.text, 'Test');
    assert.equal(r.body.search.total, 12);
    assert.equal(r.body.search.truncated, false);
    const weekly = r.body.courses.find((c) => c.sources.some((s) => s.key === 'Lecture.test.weekly'));
    assert.deepEqual(weekly.organizationPath, ['Testfakultät', 'Testinstitut A']);
    assert.ok(!JSON.stringify(r.body).includes('example.org'));
    // Gleiche Suche (andere Schreibweise): aus dem Zwischenspeicher.
    const again = await call(handler, { query: { semester: '2026w', q: ' test ' } });
    assert.equal(again.body.cache.state, 'fresh');
    assert.equal(calls.length, 1);
    assert.match(again.headers['cache-control'], /s-maxage=3600/);
});

test('Suche: Kürzung auf die besten Treffer, ohne Termine entfallener Veranstaltungen', () => {
    assert.equal(rankOf('Ethik', 'ethik'), 0);
    assert.equal(rankOf('Ethik der Medizin (MED-1)', 'Ethik'), 1);
    assert.equal(rankOf('Einführung in die Ethik', 'ethik'), 2);
    assert.equal(rankOf('Medizinethik', 'ethik'), 3);
    const course = (id, title) => ({ id, title, lecturerIds: [`p-${id}`], rules: [{ roomId: `r-${id}` }] });
    const snapshot = {
        courses: [course('a', 'Medizinethik'), course('b', 'Ethik'), course('c', 'Einführung in die Ethik')],
        persons: ['a', 'b', 'c'].map((id) => ({ id: `p-${id}` })),
        rooms: ['a', 'b', 'c'].map((id) => ({ id: `r-${id}` })),
        occurrences: ['a', 'b', 'c'].map((id) => ({ courseId: id })),
        issues: [], mergedDuplicates: [], possibleDuplicates: [],
    };
    const trimmed = trimSnapshot(snapshot, { semesterId: '2026w', text: 'Ethik' }, 2);
    assert.deepEqual(trimmed.courses.map((c) => c.id), ['b', 'c']);
    assert.equal(trimmed.total, 3);
    assert.deepEqual(trimmed.persons.map((p) => p.id), ['p-b', 'p-c']);
    assert.deepEqual(trimmed.occurrences.map((o) => o.courseId), ['b', 'c']);
});

test('Suche: Drosselung je Instanz, zu große Antworten, Ausfall der Quelle', async () => {
    const { handler, calls, advance, fail } = setup({ env: { CATALOG_SEARCH_PER_MINUTE: '2' } });
    assert.equal((await call(handler, { query: { semester: '2026w', q: 'Test eins' } })).status, 200);
    assert.equal((await call(handler, { query: { semester: '2026w', q: 'Test zwei' } })).status, 200);
    const limited = await call(handler, { query: { semester: '2026w', q: 'Test drei' } });
    assert.equal(limited.status, 429);
    assert.equal(limited.headers['retry-after'], '30');
    // Bereits gespeicherte Suche geht trotz Drosselung.
    assert.equal((await call(handler, { query: { semester: '2026w', q: 'Test eins' } })).status, 200);
    assert.equal(calls.length, 2);
    advance(61_000);
    fail();
    const down = await call(handler, { query: { semester: '2026w', q: 'Test vier' } });
    assert.equal(down.status, 503);
    assert.equal(down.body.code, 'source-unavailable');

    const big = setup({ body: () => 'x'.repeat(8 * 1024 * 1024 + 1) });
    const tooMany = await call(big.handler, { query: { semester: '2026w', q: 'Einf' } });
    assert.equal(tooMany.status, 422);
    assert.equal(tooMany.body.code, 'too-many-results');
});
