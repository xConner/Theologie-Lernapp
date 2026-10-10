// Gemeinsamer Unterbau der Push-Funktionen: Firebase Admin SDK und Versand
// über das Web-Push-Protokoll (VAPID). Dateien unter `api/_lib/` sind keine
// eigenen Endpunkte.
//
// Geheimnisse kommen ausschließlich aus Umgebungsvariablen des
// Vercel-Projekts (siehe docs/notifications.md) – nie aus dem Repository:
//   FIREBASE_SERVICE_ACCOUNT   Dienstkonto-JSON (roh oder Base64)
//   WEB_PUSH_PUBLIC_KEY        öffentlicher VAPID-Schlüssel
//   WEB_PUSH_PRIVATE_KEY       privater VAPID-Schlüssel
//   WEB_PUSH_SUBJECT           Kontakt für die Push-Dienste (mailto: oder https:)

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import {
    getFirestore,
    type DocumentReference,
    type Firestore,
} from 'firebase-admin/firestore';
import { sendNotification, WebPushError } from 'web-push';

import type { PushMessage } from './reminders';

export class NotConfiguredError extends Error {}

function env(name: string): string {
    const value = process.env[name]?.trim();

    if (!value) {
        throw new NotConfiguredError(`${name} ist nicht gesetzt.`);
    }

    return value;
}

function app() {
    const [existing] = getApps();

    if (existing) return existing;

    return initializeApp({ credential: cert(serviceAccount()) });
}

function serviceAccount(): ServiceAccount {
    return parseServiceAccount(env('FIREBASE_SERVICE_ACCOUNT'));
}

/** Firebase-Projekt, für das ID-Tokens ausgestellt sein müssen. */
export function projectId(): string {
    return serviceAccount().projectId;
}

/**
 * Ersetzt echte Zeilenumbrüche und Tabulatoren innerhalb von Zeichenketten
 * durch ihre JSON-Schreibweise. Beim Eintragen der Dienstkonto-Datei werden
 * die `\n` des privaten Schlüssels leicht zu echten Zeilenumbrüchen – dann
 * ist der Wert kein gültiges JSON mehr.
 */
function escapeLineBreaks(json: string): string {
    let result = '';
    let inString = false;
    let escaped = false;

    for (const char of json) {
        if (inString && !escaped && char === '\n') {
            result += '\\n';
        } else if (inString && !escaped && char === '\r') {
            // Entfällt: Teil eines Windows-Zeilenumbruchs.
        } else if (inString && !escaped && char === '\t') {
            result += '\\t';
        } else {
            result += char;
        }

        if (escaped) {
            escaped = false;
        } else if (char === '\\') {
            escaped = inString;
        } else if (char === '"') {
            inString = !inString;
        }
    }

    return result;
}

export type ServiceAccount = {
    projectId: string;
    clientEmail: string;
    privateKey: string;
};

/**
 * Liest das Dienstkonto aus dem Wert der Umgebungsvariable: JSON, roh oder
 * Base64. Fehlermeldungen nennen nur, was fehlt – nie den Inhalt.
 */
export function parseServiceAccount(raw: string): ServiceAccount {
    let text = raw.trim();

    // Versehentlich mit umschließenden Anführungszeichen eingetragen.
    if (/^(['"]).*\1$/s.test(text)) text = text.slice(1, -1).trim();

    if (!text.startsWith('{')) {
        text = Buffer.from(text, 'base64').toString('utf8').trim();
    }

    // Versehentlich zweimal hintereinander eingefügt: Sind beide Hälften
    // gleich, gilt eine davon.
    const half = text.slice(0, Math.floor(text.length / 2)).trim();

    if (half !== '' && text.slice(half.length).trim() === half) text = half;

    let account: Record<string, unknown>;

    try {
        account = JSON.parse(text);
    } catch {
        try {
            account = JSON.parse(escapeLineBreaks(text));
        } catch {
            // Form des Werts ohne Inhalt, damit sich der Fehler beim
            // Eintragen erkennen lässt.
            const shape = [
                `Länge ${text.length}`,
                text.startsWith('{') ? 'beginnt mit {' : 'beginnt nicht mit {',
                text.endsWith('}') ? 'endet mit }' : 'endet nicht mit }',
                `"private_key" ${text.split('"private_key"').length - 1}-mal`,
                `${text.split('\n').length} Zeilen`,
            ].join(', ');

            throw new NotConfiguredError(
                `FIREBASE_SERVICE_ACCOUNT ist kein gültiges JSON (${shape}).`,
            );
        }
    }

    const field = (name: string): string => {
        const value = account?.[name];

        if (typeof value !== 'string' || value.trim() === '') {
            throw new NotConfiguredError(
                `FIREBASE_SERVICE_ACCOUNT: Feld "${name}" fehlt.`,
            );
        }

        return value;
    };

    return {
        projectId: field('project_id'),
        clientEmail: field('client_email'),
        // Zeilenumbrüche des Schlüssels können beim Eintragen als die zwei
        // Zeichen "\n" erhalten geblieben sein.
        privateKey: field('private_key').replace(/\\n/g, '\n'),
    };
}

export function firestore(): Firestore {
    return getFirestore(app());
}

// Nur die Push-Dienste der Browser: Die Adresse eines Abonnements stammt
// vom Client und darf den Server nicht zu beliebigen Zielen schicken.
const PUSH_HOSTS = [
    'fcm.googleapis.com',
    '.push.services.mozilla.com',
    '.notify.windows.com',
    '.push.apple.com',
];

export function isPushEndpoint(value: unknown): value is string {
    if (typeof value !== 'string' || value.length > 2000) return false;

    let url: URL;

    try {
        url = new URL(value);
    } catch {
        return false;
    }

    return (
        url.protocol === 'https:' &&
        PUSH_HOSTS.some((host) =>
            host.startsWith('.')
                ? url.hostname.endsWith(host)
                : url.hostname === host,
        )
    );
}

export type SendResult = { sent: number; removed: number; failed: number };

/** Wie lange der Push-Dienst eine nicht zustellbare Nachricht aufbewahrt. */
const TTL_SECONDS = 4 * 60 * 60;

/**
 * Sendet [message] an alle Geräte unter `users/{uid}/push_tokens`.
 * Abgelaufene oder widerrufene Abonnements (404/410) werden gelöscht.
 */
export async function sendToUser(
    user: Pick<DocumentReference, 'collection'>,
    message: PushMessage,
    // Nur für Tests ersetzbar.
    send: typeof sendNotification = sendNotification,
): Promise<SendResult> {
    const vapidDetails = {
        subject: process.env.WEB_PUSH_SUBJECT?.trim() || 'https://www.theologie.app',
        publicKey: env('WEB_PUSH_PUBLIC_KEY'),
        privateKey: env('WEB_PUSH_PRIVATE_KEY'),
    };

    const tokens = await user.collection('push_tokens').get();
    const result: SendResult = { sent: 0, removed: 0, failed: 0 };

    const payload = JSON.stringify({
        title: message.title.slice(0, 120),
        body: message.body.slice(0, 300),
        link: message.link,
        tag: message.tag,
    });

    await Promise.all(
        tokens.docs.map(async (doc) => {
            const endpoint = doc.get('endpoint');
            const keys = doc.get('keys');

            if (
                !isPushEndpoint(endpoint) ||
                typeof keys?.p256dh !== 'string' ||
                typeof keys?.auth !== 'string'
            ) {
                await doc.ref.delete();
                result.removed++;
                return;
            }

            try {
                await send(
                    { endpoint, keys: { p256dh: keys.p256dh, auth: keys.auth } },
                    payload,
                    { vapidDetails, TTL: TTL_SECONDS, timeout: 8000 },
                );
                result.sent++;
            } catch (e) {
                const status = e instanceof WebPushError ? e.statusCode : 0;

                if (status === 404 || status === 410) {
                    await doc.ref.delete();
                    result.removed++;
                } else {
                    // Keine Adresse und keine Schlüssel ins Protokoll.
                    console.error(
                        `[push] Zustellung fehlgeschlagen (Status ${status}, ` +
                            `${new URL(endpoint).hostname}).`,
                    );
                    result.failed++;
                }
            }
        }),
    );

    return result;
}
