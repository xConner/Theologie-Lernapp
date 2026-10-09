// Sendet dem angemeldeten Nutzer eine Testbenachrichtigung an seine eigenen
// Geräte (Einstellungen → Benachrichtigungen). Anmeldung über das
// Firebase-ID-Token; höchstens eine Nachricht je halbe Minute und Konto.

import type { VercelRequest, VercelResponse } from '@vercel/node';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { auth, firestore, NotConfiguredError, sendToUser } from './_lib/push';

const MIN_INTERVAL_MS = 30_000;

export default async function handler(
    req: VercelRequest,
    res: VercelResponse,
) {
    res.setHeader('Cache-Control', 'no-store');

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Nur POST.' });
    }

    const token = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];

    if (!token || token.length > 4096) {
        return res.status(401).json({ error: 'Nicht angemeldet.' });
    }

    try {
        let uid: string;

        try {
            uid = (await auth().verifyIdToken(token)).uid;
        } catch (e) {
            if (e instanceof NotConfiguredError) throw e;

            return res.status(401).json({ error: 'Nicht angemeldet.' });
        }

        const db = firestore();
        const user = db.collection('users').doc(uid);
        const now = Date.now();

        const allowed = await db.runTransaction(async (tx) => {
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

        if (!allowed) {
            return res.status(429).json({ error: 'Bitte kurz warten.' });
        }

        const result = await sendToUser(user, {
            title: 'theologie.app',
            body: 'Push-Benachrichtigungen sind eingerichtet.',
            link: '/settings/notifications',
            tag: 'test',
        });

        return res.status(200).json({ sent: result.sent });
    } catch (e) {
        if (e instanceof NotConfiguredError) {
            return res.status(503).json({ error: 'Push ist nicht eingerichtet.' });
        }

        console.error('Testnachricht fehlgeschlagen:', (e as Error).message);

        return res.status(500).json({ error: 'Versand fehlgeschlagen.' });
    }
}
