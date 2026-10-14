// Veranstaltungskatalog (UnivIS der CAU, Theologische Fakultät).
// Umsetzung: api/_lib/catalog-endpoint.ts – hier nur die Schutzhülle, die
// Ladefehler abfängt (api/_lib/guard.ts).

import { guarded } from './_lib/guard';

export const config = { maxDuration: 30 };

export default guarded(
    'catalog',
    () => require('./_lib/catalog-endpoint') as typeof import('./_lib/catalog-endpoint'),
);
