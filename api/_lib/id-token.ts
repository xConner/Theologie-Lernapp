// Prüft ein Firebase-ID-Token (Anmeldung des Nutzers am Testendpunkt) nach
// dem von Firebase dokumentierten Verfahren: Signatur (RS256) gegen die
// öffentlichen Schlüssel von Google, dazu Projekt, Aussteller und Ablauf.
//
// Bewusst ohne `firebase-admin/auth`: Dessen Abhängigkeit `jose` ist ein
// reines ES-Modul und lässt sich in der Vercel-Laufzeit nicht per `require`
// laden – die ganze Funktion stürzte dadurch schon beim Laden ab.

import { createPublicKey, createVerify } from 'node:crypto';

const KEYS_URL =
    'https://www.googleapis.com/robot/v1/metadata/x509/' +
    'securetoken@system.gserviceaccount.com';

/** Zulässige Abweichung der Uhren in Sekunden. */
const CLOCK_SKEW_SECONDS = 300;

export class InvalidTokenError extends Error {
    constructor(public readonly code: string) {
        super(`ID-Token ungültig (${code}).`);
    }
}

/** Schlüssel-ID → öffentlicher Schlüssel bzw. Zertifikat (PEM). */
export type KeySet = Record<string, string>;

let cached: { keys: KeySet; expires: number } | null = null;

/** Lädt die Schlüssel von Google und merkt sie sich für ihre Gültigkeit. */
export async function googleKeys(now = Date.now()): Promise<KeySet> {
    if (cached !== null && cached.expires > now) return cached.keys;

    const response = await fetch(KEYS_URL, {
        signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
        throw new Error(`Schlüssel nicht abrufbar (Status ${response.status}).`);
    }

    const keys = (await response.json()) as KeySet;
    const maxAge = /max-age=(\d+)/.exec(
        response.headers.get('cache-control') ?? '',
    );

    cached = {
        keys,
        expires: now + (maxAge ? Number(maxAge[1]) : 3600) * 1000,
    };

    return keys;
}

function decode(part: string): Record<string, unknown> {
    try {
        const value = JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));

        if (typeof value === 'object' && value !== null) return value;
    } catch {
        // Unten als ungültig gemeldet.
    }

    throw new InvalidTokenError('malformed');
}

/**
 * Liefert die Konto-ID zu [token]; wirft [InvalidTokenError], wenn das
 * Token nicht für [projectId] ausgestellt, abgelaufen oder gefälscht ist.
 */
export async function verifyIdToken(
    token: string,
    projectId: string,
    // Nur für Tests ersetzbar.
    loadKeys: () => Promise<KeySet> = googleKeys,
    now = Date.now(),
): Promise<string> {
    const parts = token.split('.');

    if (parts.length !== 3 || parts.some((part) => part === '')) {
        throw new InvalidTokenError('malformed');
    }

    const [head, body, signature] = parts;
    const header = decode(head);
    const payload = decode(body);

    if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
        throw new InvalidTokenError('algorithm');
    }

    const keys = await loadKeys();
    const pem = Object.prototype.hasOwnProperty.call(keys, header.kid) ? keys[header.kid] : undefined;

    if (typeof pem !== 'string') throw new InvalidTokenError('unknown-key');

    const valid = createVerify('RSA-SHA256')
        .update(`${head}.${body}`)
        .verify(createPublicKey(pem), signature, 'base64url');

    if (!valid) throw new InvalidTokenError('signature');

    const seconds = now / 1000;
    const number = (value: unknown) =>
        typeof value === 'number' && Number.isFinite(value) ? value : NaN;

    if (payload.aud !== projectId) throw new InvalidTokenError('audience');

    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
        throw new InvalidTokenError('issuer');
    }

    if (!(number(payload.exp) > seconds - CLOCK_SKEW_SECONDS)) {
        throw new InvalidTokenError('expired');
    }

    if (!(number(payload.iat) <= seconds + CLOCK_SKEW_SECONDS)) {
        throw new InvalidTokenError('issued-in-future');
    }

    const uid = payload.sub;

    if (typeof uid !== 'string' || uid === '' || uid.length > 128) {
        throw new InvalidTokenError('subject');
    }

    return uid;
}
