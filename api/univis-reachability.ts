// Erreichbarkeitstest UnivIS (nur Preview-Deployments).
// Umsetzung: api/_lib/univis-reachability.ts – hier nur die Schutzhülle, die
// Ladefehler abfängt (api/_lib/guard.ts).

import { guarded } from './_lib/guard';

export const config = { maxDuration: 30 };

export default guarded(
    'univis-reachability',
    () =>
        require('./_lib/univis-reachability') as typeof import('./_lib/univis-reachability'),
);
