// Führt die Katalogverarbeitung (api/_lib/catalog) mit EINER echten
// UnivIS-Anfrage aus und gibt nur Kennzahlen aus (catalogStats: keine Titel,
// Namen, Räume oder Freitexte) – geeignet für öffentliche Protokolle.
//
//   node tool/univis/catalog_stats.mjs [--sem 2026w] [--org 010000000]
//   node tool/univis/catalog_stats.mjs --file antwort.xml        (offline)

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'node_modules', '.cache', 'catalog-stats');
const require = createRequire(join(root, 'package.json'));

const { values } = parseArgs({
    options: {
        sem: { type: 'string', default: '2026w' },
        org: { type: 'string', default: '010000000' },
        file: { type: 'string' },
    },
});

execFileSync(process.execPath, [
    require.resolve('typescript/bin/tsc'),
    '--outDir', out, '--rootDir', join(root, 'api'),
    '--module', 'commonjs', '--moduleResolution', 'node10', '--target', 'es2022',
    '--esModuleInterop', '--skipLibCheck', '--strict', '--types', 'node',
    join(root, 'api', '_lib', 'catalog', 'stats.ts'),
    join(root, 'api', '_lib', 'catalog', 'univis', 'source.ts'),
], { stdio: 'inherit' });

const lib = (name) => require(join(out, '_lib', 'catalog', name));
const { buildSnapshot } = lib('source.js');
const { catalogStats } = lib('stats.js');
const { UnivisSource, CAU_UNIVIS } = lib('univis/source.js');

const query = { semesterId: values.sem, organizationId: values.org };
const source = new UnivisSource(CAU_UNIVIS);
const started = Date.now();
const raw = values.file
    ? { body: readFileSync(values.file, 'utf8'), url: values.file, status: 200, contentType: null }
    : await source.fetchRaw(query);
const ms = Date.now() - started;

const parsed = source.parse(raw.body, query);
const snapshot = buildSnapshot(source, query, raw, new Date(started));

console.log(JSON.stringify({
    url: raw.url,
    status: raw.status,
    contentType: raw.contentType,
    bytes: Buffer.byteLength(raw.body),
    ms,
    contentHash: snapshot.provenance.contentHash,
    stats: catalogStats(parsed, snapshot),
}, null, 2));
