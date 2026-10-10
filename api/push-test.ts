// Testbenachrichtigung für das eigene Konto (POST, Firebase-ID-Token).
// Umsetzung: api/_lib/push-test.ts – hier nur die Schutzhülle, die Lade-
// fehler abfängt (api/_lib/guard.ts).

import { guarded } from './_lib/guard';

export default guarded(
    'push-test',
    () => require('./_lib/push-test') as typeof import('./_lib/push-test'),
);
