// Versendet die fälligen Push-Erinnerungen. Wird regelmäßig von einem
// Zeitplaner aufgerufen (.github/workflows/push-reminders.yml) und ist mit
// CRON_SECRET geschützt. Ablauf und Regeln: docs/notifications.md.
//
// Sparsam: Gelesen werden nur Konten, deren `nextReminderAt` erreicht ist –
// ein Lauf ohne fällige Konten kostet einen Lesezugriff.

import { timingSafeEqual } from 'node:crypto';

import type { VercelRequest, VercelResponse } from '@vercel/node';
import {
    FieldPath,
    FieldValue,
    Timestamp,
    type DocumentReference,
    type Firestore,
} from 'firebase-admin/firestore';

import { firestore, NotConfiguredError, sendToUser } from './_lib/push';
import {
    composeMessage,
    localDate,
    nextReminder,
    reasonsFor,
    shouldSendNow,
    validMinutes,
    type PlanDoc,
    type StreakDoc,
    type Zone,
} from './_lib/reminders';

export const config = { maxDuration: 60 };

/** Obergrenze je Lauf; der Rest folgt beim nächsten Aufruf. */
const MAX_USERS_PER_RUN = 300;
const CONCURRENCY = 8;

const SETTINGS = 'notification_settings';

function authorized(req: VercelRequest): boolean {
    const secret = process.env.CRON_SECRET?.trim();

    if (!secret) throw new NotConfiguredError('CRON_SECRET ist nicht gesetzt.');

    const encoder = new TextEncoder();
    const given = encoder.encode(req.headers.authorization ?? '');
    const expected = encoder.encode(`Bearer ${secret}`);

    return given.length === expected.length && timingSafeEqual(given, expected);
}

async function inBatches<T>(
    items: T[],
    task: (item: T) => Promise<void>,
): Promise<void> {
    for (let i = 0; i < items.length; i += CONCURRENCY) {
        await Promise.all(items.slice(i, i + CONCURRENCY).map(task));
    }
}

type Claim = { settings: Record<string, any>; today: string };

/**
 * Plant die nächste Erinnerung und meldet, ob jetzt eine zu senden ist. In
 * einer Transaktion, damit zwei gleichzeitige Läufe nie doppelt senden.
 */
function claim(
    db: Firestore,
    user: DocumentReference,
    now: Date,
): Promise<Claim | null> {
    return db.runTransaction(async (tx) => {
        const settings = (await tx.get(user)).get(SETTINGS) ?? {};
        const dueAt =
            settings.nextReminderAt instanceof Timestamp
                ? settings.nextReminderAt.toDate()
                : null;

        if (dueAt === null || dueAt.getTime() > now.getTime()) return null;

        if (settings.push?.enabled !== true) {
            tx.update(user, {
                [`${SETTINGS}.nextReminderAt`]: FieldValue.delete(),
            });
            return null;
        }

        const zone: Zone = settings;
        const today = localDate(zone, dueAt);
        const send = shouldSendNow(zone, dueAt, now, settings.lastReminderDate);

        tx.update(user, {
            [`${SETTINGS}.nextReminderAt`]: Timestamp.fromDate(
                nextReminder(zone, validMinutes(settings.reminderMinutes), now),
            ),
            ...(send ? { [`${SETTINGS}.lastReminderDate`]: today } : {}),
        });

        return send ? { settings, today } : null;
    });
}

async function remind(
    user: DocumentReference,
    { settings, today }: Claim,
): Promise<number> {
    const push = settings.push ?? {};

    const categories = {
        bibleReading: push.bibleReading !== false,
        readingPlan: push.readingPlan !== false,
        memorization: push.memorization !== false,
        trainers: push.trainers !== false,
    };

    if (!Object.values(categories).includes(true)) return 0;

    const streaks: Record<string, StreakDoc> = {};

    for (const doc of (await user.collection('streaks').get()).docs) {
        streaks[doc.id] = doc.data();
    }

    const plans: PlanDoc[] = [];
    const plansReadToday: string[] = [];

    if (categories.readingPlan) {
        const reading = user.collection('bible_reading');

        const planDocs = await reading
            .where(FieldPath.documentId(), '>=', 'plan_')
            .where(FieldPath.documentId(), '<', 'plan_')
            .get();

        for (const doc of planDocs.docs) {
            const updatedAt = doc.get('updatedAt');

            plans.push({
                ...doc.data(),
                updatedOn:
                    updatedAt instanceof Timestamp
                        ? localDate(settings, updatedAt.toDate())
                        : null,
            });
        }

        if (plans.length > 0) {
            const log = await reading.doc(`log_${today.slice(0, 4)}`).get();
            const entries = log.get('days')?.[today];

            for (const entry of Array.isArray(entries) ? entries : []) {
                if (typeof entry?.plan === 'string') {
                    plansReadToday.push(entry.plan);
                }
            }
        }
    }

    const message = composeMessage(
        reasonsFor({ today, categories, streaks, plans, plansReadToday }),
    );

    if (message === null) return 0;

    return (await sendToUser(user, message)).sent;
}

/**
 * Veröffentlichte Nachrichten (`notifications/{id}`) mit `channels.push`,
 * je Nachricht genau einmal, nur an Konten mit passender Einstellung.
 */
async function broadcast(db: Firestore, now: Date): Promise<number> {
    const recent = await db
        .collection('notifications')
        .where('createdAt', '>=', Timestamp.fromMillis(now.getTime() - 86_400_000))
        .get();

    let sent = 0;

    for (const doc of recent.docs) {
        const data = doc.data();

        const setting =
            data.category === 'content'
                ? 'newContent'
                : data.category === 'system'
                  ? 'systemMessages'
                  : null;

        if (
            setting === null ||
            data.channels?.push !== true ||
            data.pushSentAt !== undefined ||
            typeof data.title !== 'string' ||
            (data.createdAt as Timestamp).toMillis() > now.getTime()
        ) {
            continue;
        }

        const first = await db.runTransaction(async (tx) => {
            if ((await tx.get(doc.ref)).get('pushSentAt') !== undefined) {
                return false;
            }

            tx.update(doc.ref, { pushSentAt: FieldValue.serverTimestamp() });
            return true;
        });

        if (!first) continue;

        const users = await db
            .collection('users')
            .where(`${SETTINGS}.push.enabled`, '==', true)
            .get();

        // Wie in der App: neue Inhalte nur auf Wunsch, Systemnachrichten
        // standardmäßig.
        const recipients = users.docs.filter((user) => {
            const value = user.get(`${SETTINGS}.push.${setting}`);

            return setting === 'newContent' ? value === true : value !== false;
        });

        const link =
            typeof data.deepLink === 'string' && data.deepLink.startsWith('/')
                ? data.deepLink
                : '/';

        await inBatches(recipients, async (user) => {
            const result = await sendToUser(user.ref, {
                title: data.title,
                body: typeof data.body === 'string' ? data.body : '',
                link,
                tag: `message-${doc.id}`,
            });

            sent += result.sent;
        });
    }

    return sent;
}

export default async function handler(
    req: VercelRequest,
    res: VercelResponse,
) {
    res.setHeader('Cache-Control', 'no-store');

    try {
        if (!authorized(req)) {
            return res.status(401).json({ error: 'Nicht berechtigt.' });
        }

        const db = firestore();
        const now = new Date();

        const due = await db
            .collection('users')
            .where(`${SETTINGS}.nextReminderAt`, '<=', Timestamp.fromDate(now))
            .orderBy(`${SETTINGS}.nextReminderAt`)
            .limit(MAX_USERS_PER_RUN)
            .get();

        let reminders = 0;
        let errors = 0;

        await inBatches(due.docs, async (doc) => {
            try {
                const claimed = await claim(db, doc.ref, now);

                if (claimed !== null) {
                    reminders += await remind(doc.ref, claimed);
                }
            } catch (e) {
                if (e instanceof NotConfiguredError) throw e;

                errors++;
                console.error('Erinnerung fehlgeschlagen:', (e as Error).message);
            }
        });

        const messages = await broadcast(db, now);

        return res.status(200).json({
            due: due.size,
            reminders,
            messages,
            errors,
        });
    } catch (e) {
        if (e instanceof NotConfiguredError) {
            return res.status(503).json({ error: e.message });
        }

        console.error('Versand fehlgeschlagen:', (e as Error).message);

        return res.status(500).json({ error: 'Versand fehlgeschlagen.' });
    }
}
