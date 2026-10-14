// Erzeugt den SYNTHETISCHEN Veranstaltungskatalog der App
// (assets/timetable/synthetic_catalog.json) aus tool/timetable/synthetic_catalog.xml
// mit derselben Verarbeitung wie später echte Quellen (api/_lib/catalog:
// Dublettenprüfung, Terminauflösung). Kein Netzwerk.
//
//   node tool/timetable/build_synthetic_catalog.mjs
//
// Solange die Nutzungsrechte an UnivIS-Daten ungeklärt sind, enthält die App
// nur diesen Katalog (docs/univis-integration-feasibility.md, Abschnitt 12).

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const out = join(root, 'node_modules', '.cache', 'timetable-catalog');
const require = createRequire(join(root, 'package.json'));

execFileSync(process.execPath, [
    require.resolve('typescript/bin/tsc'),
    '--outDir', out, '--rootDir', join(root, 'api'),
    '--module', 'commonjs', '--moduleResolution', 'node10', '--target', 'es2022',
    '--esModuleInterop', '--skipLibCheck', '--strict', '--types', 'node',
    join(root, 'api', '_lib', 'catalog', 'univis', 'source.ts'),
], { stdio: 'inherit' });

const lib = (name) => require(join(out, '_lib', 'catalog', name));
const { buildSnapshot } = lib('source.js');
const { UnivisSource } = lib('univis/source.js');
const { CAU_SEMESTERS } = lib('semesters.js');

// Eigene Quellkennung: Synthetische Einträge können nie mit echten
// (`cau-univis:…`) verwechselt werden – auch nicht in gespeicherten
// Stundenplänen.
const source = new UnivisSource({
    sourceId: 'synthetic',
    host: 'example.invalid',
    institution: 'Synthetische Testdaten',
    semesters: CAU_SEMESTERS,
}, () => { throw new Error('kein Netzwerk'); });

const xml = readFileSync(join(here, 'synthetic_catalog.xml'), 'utf8');
const snapshot = buildSnapshot(
    source,
    { semesterId: '2026w', organizationId: '000000000' },
    { body: xml, url: null, status: 200, contentType: 'text/xml' },
    new Date('2026-10-14T00:00:00Z'),
);

const result = {
    synthetic: true,
    notice: 'Synthetische Testdaten – keine echten Veranstaltungen.',
    ...snapshot,
    // Detailseiten der erfundenen Quelle gibt es nicht.
    courses: snapshot.courses.map((c) => ({ ...c, detailUrl: null })),
};
if (result.warnings.length > 0) throw new Error(`Warnungen: ${result.warnings.join('; ')}`);

const target = join(root, 'assets', 'timetable', 'synthetic_catalog.json');
mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, `${JSON.stringify(result)}\n`);
console.log(`${target}: ${result.courses.length} Veranstaltungen, ${result.occurrences.length} Termine, ${result.issues.length} Hinweise`);
