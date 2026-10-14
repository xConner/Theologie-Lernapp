// Tests der Katalogverarbeitung (UnivIS-Adapter, Terminauflösung, Dubletten,
// Überschneidungen) ohne Netzwerk:
//   node --test api/_lib/catalog/catalog.test.mjs
//
// Wie api/_lib/handlers.test.mjs: Übersetzung nach CommonJS in
// node_modules/.cache (nicht versioniert). Testdaten: fixtures/ – synthetisch
// bzw. aus dem öffentlichen, geschwärzten Protokoll rekonstruiert.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');
const out = join(root, 'node_modules', '.cache', 'catalog-test');
const require = createRequire(join(root, 'package.json'));

execFileSync(
    process.execPath,
    [
        require.resolve('typescript/bin/tsc'),
        '--outDir', out,
        '--rootDir', join(root, 'api'),
        '--module', 'commonjs',
        '--moduleResolution', 'node10',
        '--target', 'es2022',
        '--esModuleInterop',
        '--skipLibCheck',
        '--strict',
        '--types', 'node',
        join(here, 'source.ts'),
        join(here, 'overlap.ts'),
        join(here, 'univis', 'source.ts'),
        join(root, 'api', 'univis-reachability.ts'),
    ],
    { stdio: 'inherit' },
);

const lib = (name) => require(join(out, '_lib', 'catalog', name));
const { buildSnapshot, loadCatalog } = lib('source.js');
const { findOverlaps, overlapsBetween } = lib('overlap.js');
const { resolveCourse } = lib('schedule.js');
const { normalizeTitle } = lib('dedupe.js');
const { zonedDateTime, isoWeekday } = lib('time.js');
const { CAU_SEMESTERS } = lib('semesters.js');
const { UnivisSource, CAU_UNIVIS, decode } = lib('univis/source.js');
const { parseRepeat, moduleCodesFromTitle, parseUnivisXml, UnivisFormatError } = lib('univis/parse.js');

const reachability = require(join(out, '_lib', 'univis-reachability.js'));

const fixture = (name) => readFileSync(join(here, 'fixtures', name), 'utf8');
const query = { semesterId: '2026w', organizationId: '010000000' };
const source = new UnivisSource(CAU_UNIVIS, () => {
    throw new Error('kein Netzwerk in Tests');
});
const semester = CAU_SEMESTERS['2026w'];

function snapshotOf(xml) {
    return buildSnapshot(source, query, { body: xml, url: 'https://example.invalid/prg', status: 200, contentType: 'text/xml' }, new Date('2026-10-14T12:00:00Z'));
}

const snap = snapshotOf(fixture('synthetic-catalog.xml'));
const courseId = (key) => `cau-univis:2026w:${key}`;
const course = (key) => snap.courses.find((c) => c.id === courseId(key));
const occ = (key) => snap.occurrences.filter((o) => o.courseId === courseId(key));
const issues = (key) => snap.issues.filter((i) => i.courseId === courseId(key)).map((i) => i.code).sort();

// --- Zeit -------------------------------------------------------------------

test('Europe/Berlin: Sommer- und Winterzeit, Lücke und Doppelung der Umstellung', () => {
    assert.equal(zonedDateTime('2026-10-19', '10:15', 'Europe/Berlin'), '2026-10-19T10:15:00+02:00');
    assert.equal(zonedDateTime('2026-10-26', '10:15', 'Europe/Berlin'), '2026-10-26T10:15:00+01:00');
    // 25.10.2026, 02:30 gibt es zweimal → früherer Zeitpunkt (Sommerzeit).
    assert.equal(zonedDateTime('2026-10-25', '02:30', 'Europe/Berlin'), '2026-10-25T02:30:00+02:00');
    // 28.03.2027, 02:30 gibt es nicht.
    assert.equal(zonedDateTime('2027-03-28', '02:30', 'Europe/Berlin'), null);
    assert.equal(isoWeekday('2026-10-12'), 1);
    assert.equal(isoWeekday('2026-10-18'), 7);
});

// --- Wiederholungsmuster ----------------------------------------------------

test('Wiederholungsmuster: Wochentage 1 = Montag, Blöcke, Unbekanntes', () => {
    assert.deepEqual(parseRepeat('w1 4'), { kind: 'weekly', intervalWeeks: 1, weekdays: [4] });
    assert.deepEqual(parseRepeat('w2 3,1'), { kind: 'weekly', intervalWeeks: 2, weekdays: [1, 3] });
    assert.deepEqual(parseRepeat('w1 0').weekdays, [7]);
    assert.equal(parseRepeat('s1').kind, 'single');
    assert.deepEqual(parseRepeat('bd 1,2,3,4,5'), { kind: 'block', intervalWeeks: null, weekdays: [1, 2, 3, 4, 5] });
    assert.deepEqual(parseRepeat('b1'), { kind: 'block', intervalWeeks: null, weekdays: [] });
    for (const raw of ['x9 sonderfall', 'w1 9', 'w0 1', 'w1', null, '']) {
        assert.equal(parseRepeat(raw).kind, 'unknown', String(raw));
    }
});

test('Modulkürzel nur aus eindeutigen Kürzellisten im Titel', () => {
    assert.deepEqual(
        moduleCodesFromTitle('Bibelkunde Altes Testament (DKA-Ein-ÜAT, DKA-AT1-Bib, erbATmH-01a-Ü)'),
        ['DKA-Ein-ÜAT', 'DKA-AT1-Bib', 'erbATmH-01a-Ü'],
    );
    assert.deepEqual(moduleCodesFromTitle('Testübung Griechisch (Teil 1)'), []);
    assert.deepEqual(moduleCodesFromTitle('Seminar (DKA-T1, mit Exkursion)'), []);
    assert.deepEqual(moduleCodesFromTitle('Ohne Klammer'), []);
    assert.deepEqual(course('Lecture.test.weekly').moduleCodes, ['DKA-T1-AT', 'EvRel-T-AT']);
});

// --- Terminauflösung --------------------------------------------------------

test('wöchentlich: Vorlesungszeit, ohne Weihnachtspause, Zeitumstellung', () => {
    const list = occ('Lecture.test.weekly');
    assert.equal(list.length, 16); // 18 Montage − 21.12. und 28.12.
    assert.equal(list[0].date, '2026-10-12');
    assert.equal(list.at(-1).date, '2027-02-08');
    assert.ok(!list.some((o) => o.date === '2026-12-21' || o.date === '2026-12-28'));
    assert.ok(list.every((o) => isoWeekday(o.date) === 1));
    assert.equal(list.find((o) => o.date === '2026-10-19').start, '2026-10-19T10:15:00+02:00');
    assert.equal(list.find((o) => o.date === '2026-10-26').end, '2026-10-26T11:45:00+01:00');
    assert.equal(list.find((o) => o.date === '2026-10-12').roomId, 'cau-univis:Room.test.hs1');
});

test('Ausfälle bleiben als abgesagt sichtbar; unpassende Ausfalldaten werden gemeldet', () => {
    const list = occ('Lecture.test.weekly');
    assert.equal(list.find((o) => o.date === '2026-11-02').status, 'cancelled');
    assert.equal(list.filter((o) => o.status === 'cancelled').length, 1);
    const hint = snap.issues.find((i) => i.courseId === courseId('Lecture.test.weekly') && i.code === 'exclude-not-matching');
    assert.match(hint.detail, /2026-11-04/);
    assert.equal(hint.severity, 'info');
});

test('mehrere Wochentage in einer Regel', () => {
    const list = occ('Lecture.test.twodays');
    assert.equal(list.filter((o) => isoWeekday(o.date) === 1).length, 16);
    assert.equal(list.filter((o) => isoWeekday(o.date) === 3).length, 16);
    assert.equal(list[0].start, '2026-10-12T08:00:00+02:00');
});

test('14-täglich nur mit Startdatum; ohne Startdatum keine erfundenen Termine', () => {
    const list = occ('Lecture.test.biweekly');
    assert.deepEqual(list.map((o) => o.date), ['2026-10-14', '2026-10-28', '2026-11-11', '2026-11-25', '2026-12-09']);
    assert.deepEqual(issues('Lecture.test.biweekly'), ['biweekly-phase-unknown']);
});

test('Einzeltermine: Datum genau, außerhalb des Semesters verworfen, Lücken gemeldet', () => {
    const list = occ('Lecture.test.singles');
    assert.deepEqual(list.map((o) => o.date), ['2026-11-02', '2026-12-22']);
    assert.equal(list[0].roomId, 'cau-univis:Room.test.online');
    assert.deepEqual(issues('Lecture.test.singles'), ['missing-date', 'outside-semester', 'unknown-pattern']);
    assert.ok(snap.rooms.find((r) => r.id === 'cau-univis:Room.test.online').online);
});

test('Blöcke: Tage im Zeitraum (als ungeprüft markiert), mehrtägig ohne Tage unklar', () => {
    const list = occ('Lecture.test.blocks');
    assert.deepEqual(list.map((o) => o.date), ['2027-02-18', '2027-02-19', '2027-03-01']);
    assert.deepEqual(issues('Lecture.test.blocks'), ['block-pattern-unclear', 'block-unverified', 'missing-date']);
});

test('fehlende, unsinnige und unbekannte Angaben erzeugen keine Termine', () => {
    assert.equal(occ('Lecture.test.broken').length, 0);
    assert.deepEqual(issues('Lecture.test.broken'), ['invalid-time', 'missing-time', 'unknown-pattern', 'unknown-pattern', 'unknown-pattern']);
    assert.deepEqual(issues('Lecture.test.noterms'), ['no-rules']);
    assert.ok(snap.issues.filter((i) => i.severity === 'warning').every((i) => i.ruleId !== undefined));
});

test('Semestergrenzen: kein Termin außerhalb des Semesters', () => {
    assert.ok(snap.occurrences.every((o) => o.date >= semester.start && o.date <= semester.end));
    const weekly = snap.occurrences.filter((o) => !o.ruleId.includes('blocks') && !o.ruleId.includes('singles'));
    assert.ok(weekly.every((o) => o.date >= semester.lectureStart && o.date <= semester.lectureEnd));
});

test('Termin- und Regelkennungen sind stabil, auch wenn ein Ausfall hinzukommt', () => {
    const xml = fixture('synthetic-catalog.xml');
    const again = snapshotOf(xml);
    assert.deepEqual(again.occurrences.map((o) => o.id), snap.occurrences.map((o) => o.id));
    const withNewExclude = snapshotOf(xml.replace('<exclude>2026-11-02</exclude>', '<exclude>2026-11-02</exclude><exclude>2026-11-09</exclude>'));
    const ids = (s) => s.occurrences.filter((o) => o.courseId === courseId('Lecture.test.weekly')).map((o) => o.id);
    assert.deepEqual(ids(withNewExclude), ids(snap));
    assert.equal(withNewExclude.occurrences.find((o) => o.id.endsWith('@2026-11-09') && o.courseId === courseId('Lecture.test.weekly')).status, 'cancelled');
    assert.equal(new Set(snap.occurrences.map((o) => o.id)).size, snap.occurrences.length);
});

// --- Dubletten --------------------------------------------------------------

test('Dublette über Import-Verknüpfung: zusammengeführt, alle Quellkennungen erhalten', () => {
    assert.equal(course('Lecture.test._import'), undefined);
    const merged = course('Lecture.test.orig');
    assert.deepEqual(merged.sources.map((s) => s.key), ['Lecture.test.orig', 'Lecture.test._import']);
    assert.deepEqual(merged.organizations, ['Testinstitut A', 'Testinstitut B']);
    assert.deepEqual(merged.classification, ['4. Altes Testament', '3. Fachergänzung']);
    assert.equal(merged.imported, false);
    assert.equal(occ('Lecture.test.orig').length, 16);
    assert.deepEqual(snap.mergedDuplicates.find((m) => m.courseId === merged.id), {
        courseId: merged.id, mergedKeys: ['Lecture.test._import'], reason: 'import',
    });
});

test('Dublette ohne Verknüpfung: gleiche Nummer, gleicher Titel (normalisiert), gleiche Termine', () => {
    assert.equal(normalizeTitle('Einführung in die  Kirchengeschichte.'), normalizeTitle('Einführung in die Kirchengeschichte'));
    const merged = course('Lecture.test.copy1');
    assert.equal(course('Lecture.test.copy2'), undefined);
    assert.deepEqual(merged.sources.map((s) => s.key), ['Lecture.test.copy1', 'Lecture.test.copy2']);
    assert.equal(snap.mergedDuplicates.find((m) => m.courseId === merged.id).reason, 'number-title-schedule');
});

test('Parallelgruppen und ähnliche Titel werden NICHT zusammengeführt', () => {
    assert.ok(course('Lecture.test.groupA') && course('Lecture.test.groupB'));
    assert.ok(course('Lecture.test.similar'));
    assert.deepEqual(snap.possibleDuplicates, [{
        courseIds: [courseId('Lecture.test.groupA'), courseId('Lecture.test.groupB')],
        reason: 'same-number-schedule-differs',
    }]);
    assert.equal(snap.courses.length, 12); // 14 vollständige − 2 Dubletten
});

// --- Überschneidungen -------------------------------------------------------

test('direkt aufeinanderfolgende Termine überschneiden sich nicht', () => {
    assert.deepEqual(overlapsBetween(snap.occurrences, [courseId('Lecture.test.groupA'), courseId('Lecture.test.groupB')]), []);
    assert.deepEqual(overlapsBetween(snap.occurrences, [courseId('Lecture.test.weekly'), courseId('Lecture.test.twodays')]), []);
});

test('gleichzeitige Veranstaltungen: jede Sitzung einzeln erkannt', () => {
    const list = overlapsBetween(snap.occurrences, [courseId('Lecture.test.copy1'), courseId('Lecture.test.similar')]);
    assert.equal(list.length, 16);
    assert.ok(list.every((o) => o.minutes === 90 && !o.sameCourse && o.a.date === o.b.date));
});

function o(id, courseId, start, end, status = 'scheduled') {
    return { id, courseId, ruleId: `${courseId}#r`, date: start.slice(0, 10), start, end, roomId: null, status };
}

test('Überschneidungen: teilweise, enthalten, drei gleichzeitig, abgesagt ignoriert', () => {
    const t = (h) => `2026-11-03T${h}:00+01:00`;
    const result = findOverlaps([
        o('a', 'A', t('10:00'), t('12:00')),
        o('b', 'B', t('11:30'), t('13:00')), // teilweise mit a
        o('c', 'C', t('10:30'), t('11:00')), // in a enthalten
        o('d', 'D', t('12:00'), t('12:30')), // berührt a, überschneidet b
        o('e', 'E', t('10:00'), t('12:00'), 'cancelled'),
    ]);
    const pairs = result.map((r) => `${r.a.id}${r.b.id}:${r.minutes}`).sort();
    assert.deepEqual(pairs, ['ab:30', 'ac:30', 'bd:30']);
});

test('Überschneidung über die Zeitumstellung wird in echter Zeit gerechnet', () => {
    // 25.10.2026: 02:30 Sommerzeit und 02:15 Winterzeit liegen 45 min auseinander.
    const r = findOverlaps([
        o('x', 'X', '2026-10-25T02:00:00+02:00', '2026-10-25T02:50:00+02:00'),
        o('y', 'Y', '2026-10-25T02:15:00+01:00', '2026-10-25T03:00:00+01:00'),
    ]);
    assert.equal(r.length, 0);
});

// --- Echte Struktur (Kiel, rekonstruiert) ------------------------------------

test('Kieler Auszug: Import-Dublette, Donnerstage, Einzeltermine online', () => {
    const kiel = snapshotOf(fixture('kiel-2026w-excerpt.xml'));
    assert.equal(kiel.courses.length, 2);
    const bib = kiel.courses.find((c) => c.number === '010076');
    assert.equal(bib.id, 'cau-univis:2026w:Lecture.theol.altte.relig.bibelk');
    assert.deepEqual(bib.sources.map((s) => s.key).sort(), ['Lecture.theol.altte.relig._bibel', 'Lecture.theol.altte.relig.bibelk']);
    assert.ok(bib.moduleCodes.includes('DKA-AT1-Bib'));
    assert.equal(bib.detailUrl, 'https://univis.uni-kiel.de/prg?search=lectures&number=010076&sem=2026w&show=llong');
    const thursdays = kiel.occurrences.filter((x) => x.courseId === bib.id);
    assert.equal(thursdays.length, 16);
    assert.ok(thursdays.every((x) => isoWeekday(x.date) === 4 && x.start.includes('T16:15:00')));
    // Veranstaltungszeitraum (18.10.–07.02., Sonntage) schränkt nicht ein, wird aber gemeldet.
    assert.match(kiel.issues.find((i) => i.code === 'course-range-differs').detail, /^2 Termin/);
    const rv = kiel.occurrences.filter((x) => x.courseId.endsWith('_human'));
    assert.deepEqual(rv.map((x) => x.start), [
        '2026-11-02T18:15:00+01:00', '2026-11-09T18:15:00+01:00', '2027-01-11T18:15:00+01:00', '2027-02-01T18:15:00+01:00',
    ]);
});

test('Kieler Auszug ohne Import-Verknüpfung: Nummer + Titel + Termine genügen', () => {
    const kiel = snapshotOf(fixture('kiel-2026w-excerpt.xml').replace('<import_parent_id>42619541</import_parent_id>', ''));
    assert.equal(kiel.courses.length, 2);
    assert.equal(kiel.mergedDuplicates[0].reason, 'number-title-schedule');
});

// --- Datenschutz und fehlerhafte Daten --------------------------------------

test('keine Freitexte und keine unbenutzten Personen im Ergebnis', () => {
    const json = JSON.stringify(snap);
    assert.ok(!json.includes('example.org'));
    assert.ok(!json.includes('Anmeldung'));
    assert.ok(!json.includes('Verwendet'));
    assert.deepEqual(snap.persons.map((p) => p.displayName).sort(), ['Max Mustermann', 'Prof. Dr. Erika Musterfrau']);
    assert.deepEqual(Object.keys(snap.persons[0]).sort(), ['displayName', 'id', 'source']);
});

test('unvollständige Datensätze und unbekannte Verweise werden gemeldet, nicht geraten', () => {
    assert.ok(snap.warnings.includes('Veranstaltung ohne Kennung übersprungen'));
    assert.ok(snap.warnings.includes('Veranstaltung ohne Titel übersprungen (Lecture.test.notitle)'));
    assert.ok(snap.warnings.some((w) => w.includes('Person.test.unbekannt')));
    assert.ok(snap.warnings.some((w) => w.includes('Room.test.unbekannt')));
    assert.deepEqual(course('Lecture.test.broken').lecturerIds, []);
});

test('fehlerhafte Antworten: HTML wird abgelehnt, leere und abgeschnittene XML führen nicht zum Absturz', () => {
    assert.throws(() => parseUnivisXml('<html><body>UnivIS Anfrage</body></html>', { sourceId: 's', semesterId: '2026w', host: 'h' }), UnivisFormatError);
    assert.throws(() => parseUnivisXml('', { sourceId: 's', semesterId: '2026w', host: 'h' }), UnivisFormatError);
    assert.equal(snapshotOf('<UnivIS version="1.6"/>').courses.length, 0);
    const cut = snapshotOf('<UnivIS><Lecture key="L.a"><name>Abgeschnitten</name><terms><term><repeat>w1 1</repeat><starttime>10:00');
    assert.equal(cut.courses.length, 1);
    assert.equal(cut.occurrences.length, 0);
    assert.deepEqual(cut.issues.map((i) => i.code), ['missing-time']);
});

test('Termine ohne konfiguriertes Semester werden abgelehnt', () => {
    assert.throws(() => buildSnapshot(source, { ...query, semesterId: '2030w' }, { body: '<UnivIS/>', url: '', status: 200, contentType: null }, new Date()), /nicht konfiguriert/);
});

// --- Adapter ----------------------------------------------------------------

test('UnivIS-Adapter: genau eine Anfrage, geprüfte Parameter, Zeichensatz', async () => {
    const calls = [];
    const latin1 = Buffer.from('<?xml version="1.0" encoding="ISO-8859-1"?><UnivIS><Lecture key="L.x"><name>Übung für Anfänger</name></Lecture></UnivIS>', 'latin1');
    const fake = async (url, init) => {
        calls.push({ url: String(url), init });
        return new Response(latin1, { status: 200, headers: { 'content-type': 'text/xml' } });
    };
    const s = new UnivisSource(CAU_UNIVIS, fake);
    const result = await loadCatalog(s, query, { now: () => new Date('2026-10-14T00:00:00Z') });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, 'https://univis.uni-kiel.de/prg?search=lectures&show=xml&sem=2026w&department=010000000');
    assert.match(calls[0].init.headers['User-Agent'], /theologie\.app/);
    assert.equal(result.courses[0].title, 'Übung für Anfänger');
    assert.equal(result.provenance.fetchedAt, '2026-10-14T00:00:00.000Z');
    assert.match(result.provenance.contentHash, /^[0-9a-f]{64}$/);
    assert.equal(result.provenance.system, 'univis');

    assert.throws(() => s.url({ semesterId: '2026w', organizationId: 'Theologische Fakultät' }), /neunstellig/);
    assert.throws(() => s.url({ semesterId: '2031w', organizationId: '010000000' }), /nicht konfiguriert/);
    const failing = new UnivisSource(CAU_UNIVIS, async () => new Response('x', { status: 503 }));
    await assert.rejects(() => failing.fetchRaw(query), /HTTP 503/);
    assert.equal(decode(new TextEncoder().encode('ä'), 'text/xml; charset=utf-8'), 'ä');
});

test('Termine eines Kurses lassen sich unabhängig auflösen (für Aktualisierungen)', () => {
    const c = course('Lecture.test.biweekly');
    const r = resolveCourse(c, semester);
    assert.equal(r.occurrences.length, 5);
});

// --- Erreichbarkeitstest (Vercel) --------------------------------------------

async function call(handler, method = 'GET') {
    const result = { status: 200, body: undefined };
    const res = {
        status(code) { result.status = code; return this; },
        json(body) { result.body = body; return this; },
        setHeader() {},
    };
    await handler({ method }, res);
    return result;
}

test('Erreichbarkeitstest: nur Preview, nur GET, gedrosselt, nur Kennzahlen', async () => {
    const xml = fixture('synthetic-catalog.xml');
    let calls = 0;
    const fake = async () => {
        calls++;
        return new Response(xml, { status: 200, headers: { 'content-type': 'text/xml' } });
    };
    let clock = 1_000_000;
    const now = () => clock;

    reachability.resetThrottle();
    assert.equal((await call(reachability.createHandler(fake, { VERCEL_ENV: 'production' }, now))).status, 404);
    const handler = reachability.createHandler(fake, { VERCEL_ENV: 'preview', VERCEL_REGION: 'fra1' }, now);
    assert.equal((await call(handler, 'POST')).status, 405);
    assert.equal(calls, 0);

    const ok = await call(handler);
    assert.equal(ok.status, 200);
    assert.equal(calls, 1);
    assert.equal(ok.body.region, 'fra1');
    assert.equal(ok.body.stats.coursesParsed, 14);
    assert.equal(ok.body.stats.courses, 12);
    assert.deepEqual(ok.body.stats.merged, { import: 1, 'number-title-schedule': 1 });
    assert.equal(ok.body.stats.importParentsResolved, 1);
    assert.deepEqual(ok.body.stats.samples.biweekly, ['090003']);
    const json = JSON.stringify(ok.body);
    for (const secret of ['Testvorlesung', 'Musterfrau', 'HS 1', 'example.org', 'Anmeldung']) {
        assert.ok(!json.includes(secret), secret);
    }

    assert.equal((await call(handler)).status, 429);
    assert.equal(calls, 1);

    clock += 61_000;
    const down = reachability.createHandler(async () => { throw new TypeError('fetch failed', { cause: { code: 'ENOTFOUND' } }); }, {}, now);
    const failed = await call(down);
    assert.equal(failed.status, 502);
    assert.deepEqual([failed.body.reachable, failed.body.cause], [false, 'ENOTFOUND']);
});
