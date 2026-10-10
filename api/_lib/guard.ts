// Schutzhülle der Push-Endpunkte. Die eigentliche Funktion wird erst beim
// Aufruf geladen: Scheitert schon das Laden (fehlende oder unverträgliche
// Abhängigkeit), stürzt die Funktion nicht kommentarlos ab
// (FUNCTION_INVOCATION_FAILED), sondern antwortet mit einem lesbaren Fehler
// und schreibt ihn ins Protokoll.
//
// Diese Datei hat bewusst keine Abhängigkeiten.

import type { VercelRequest, VercelResponse } from '@vercel/node';

export type Handler = (
    req: VercelRequest,
    res: VercelResponse,
) => unknown | Promise<unknown>;

/** Kennung eines Fehlers ohne Inhalte: z. B. `ERR_REQUIRE_ESM`, `7`. */
export function errorCode(e: unknown): string {
    const code = (e as { code?: unknown } | null)?.code;

    if (typeof code === 'string' || typeof code === 'number') {
        return String(code).slice(0, 80);
    }

    return e instanceof Error ? e.name : 'unknown';
}

/** Erste Zeile der Fehlermeldung, gekürzt. */
function firstLine(e: unknown): string {
    const message = e instanceof Error ? e.message : String(e);

    return message.split('\n')[0].slice(0, 300);
}

/**
 * Lädt den Endpunkt mit [load] und führt ihn aus. [load] muss das Modul
 * wörtlich nennen (`() => require('./_lib/…')`), damit Vercel die Datei mit
 * ausliefert. Bewusst `require` statt `import()`: Vercel übersetzt nach
 * CommonJS, lässt `import()` aber stehen – und das findet Dateien ohne
 * Endung nicht.
 */
export function guarded(
    name: string,
    load: () => { default: Handler },
): Handler {
    return async (req, res) => {
        res.setHeader('Cache-Control', 'no-store');

        let handler: Handler;

        try {
            handler = load().default;
        } catch (e) {
            console.error(`[${name}] Laden fehlgeschlagen:`, e);

            // Die Meldung eines Ladefehlers nennt nur Module und Pfade,
            // keine Zugangsdaten.
            return res.status(500).json({
                error: 'Die Funktion konnte nicht geladen werden.',
                stage: 'load',
                code: errorCode(e),
                detail: firstLine(e),
            });
        }

        try {
            return await handler(req, res);
        } catch (e) {
            console.error(`[${name}] Fehler:`, errorCode(e), firstLine(e));

            if (res.headersSent) return;

            return res.status(500).json({
                error: 'Interner Fehler.',
                stage: 'run',
                code: errorCode(e),
            });
        }
    };
}
