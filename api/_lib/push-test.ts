// Sendet dem angemeldeten Nutzer eine Testbenachrichtigung an seine eigenen
// Geräte (Einstellungen → Benachrichtigungen). Anmeldung über das
// Firebase-ID-Token; höchstens eine Nachricht je halbe Minute und Konto.

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { errorCode } from './guard';
import { InvalidTokenError, verifyIdToken } from './id-token';
import {
    firestore,
    NotConfiguredError,
    projectId,
    sendToUser,
    type SendResult,
} from './push';

const MIN_INTERVAL_MS = 30_000;

/** Zugriffe des Endpunkts auf Firebase und den Push-Versand (in Tests ersetzbar). */
export type TestDependencies = {
    /** Konto-ID zum ID-Token; wirft bei ungültigem Token. */
    authenticate(token: string): Promise<string>;
    /** Vermerkt den Versuch; false, wenn der letzte zu kurz zurückliegt. */
    allow(uid: string): Promise<boolean>;
    send(uid: string): Promise<SendResult>;
};

const firebase: TestDependencies = {
    authenticate(token) {
        return verifyIdToken(token, projectId());
    },

    allow(uid) {
        const db = firestore();
        const user = db.collection('users').doc(uid);
        const now = Date.now();

        return db.runTransaction(async (tx) => {
            const last = (await tx.get(user)).get(
                'notification_settings.lastTestAt',
            );

            if (
                last instanceof Timestamp &&
                now - last.toMillis() < MIN_INTERVAL_MS
            ) {
                return false;
            }

            tx.set(
                user,
                {
                    notification_settings: {
                        lastTestAt: FieldValue.serverTimestamp(),
                    },
                },
                { merge: true },
            );

            return true;
        });
    },

    send(uid) {
        return sendToUser(firestore().collection('users').doc(uid), {
            title: 'theologie.app',
            body: 'Push-Benachrichtigungen sind eingerichtet.',
            link: '/settings/notifications',
            tag: 'test',
        });
    },
};

export function createHandler(deps: TestDependencies) {
    return async (req: VercelRequest, res: VercelResponse) => {
        res.setHeader('Cache-Control', 'no-store');

        if (req.method !== 'POST') {
            res.setHeader('Allow', 'POST');
            return res.status(405).json({ error: 'Nur POST.' });
        }

        const token = /^Bearer (.+)$/.exec(
            req.headers.authorization ?? '',
        )?.[1];

        if (!token || token.length > 4096) {
            return res.status(401).json({ error: 'Nicht angemeldet.' });
        }

        // Jeder Schritt wird einzeln protokolliert (ohne Token, Schlüssel
        // oder Abonnementdaten), damit ein Fehler zuzuordnen ist.
        let stage = 'auth';

        try {
            let uid: string;

            try {
                uid = await deps.authenticate(token);
            } catch (e) {
                // Nur ein abgelehntes Token ist eine fehlende Anmeldung;
                // alles andere (Konfiguration, Schlüsselabruf) ist ein
                // Fehler des Servers.
                if (!(e instanceof InvalidTokenError)) throw e;

                console.warn('[push-test] Token abgelehnt:', errorCode(e));

                return res.status(401).json({
                    error: 'Nicht angemeldet.',
                    code: errorCode(e),
                });
            }

            stage = 'firestore';

            if (!(await deps.allow(uid))) {
                return res.status(429).json({ error: 'Bitte kurz warten.' });
            }

            stage = 'send';

            const result = await deps.send(uid);

            console.log(
                `[push-test] gesendet: ${result.sent}, entfernt: ` +
                    `${result.removed}, fehlgeschlagen: ${result.failed}`,
            );

            return res.status(200).json({
                sent: result.sent,
                removed: result.removed,
                failed: result.failed,
            });
        } catch (e) {
            if (e instanceof NotConfiguredError) {
                console.error('[push-test] Nicht eingerichtet:', e.message);

                return res.status(503).json({
                    error: 'Push ist nicht eingerichtet.',
                    stage,
                    code: 'not-configured',
                });
            }

            console.error(
                `[push-test] Fehler (${stage}):`,
                errorCode(e),
                (e as Error).message,
            );

            return res.status(500).json({
                error: 'Versand fehlgeschlagen.',
                stage,
                code: errorCode(e),
            });
        }
    };
}

export default createHandler(firebase);
