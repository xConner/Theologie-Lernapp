// Versand der fälligen Push-Erinnerungen (Zeitplaner, CRON_SECRET).
// Umsetzung: api/_lib/send-reminders.ts – hier nur die Schutzhülle, die
// Ladefehler abfängt (api/_lib/guard.ts).

import { guarded } from './_lib/guard';

export const config = { maxDuration: 60 };

export default guarded(
    'send-reminders',
    () =>
        require('./_lib/send-reminders') as typeof import('./_lib/send-reminders'),
);
