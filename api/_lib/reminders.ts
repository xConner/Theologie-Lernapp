// Entscheidung, ob und woran die tägliche Push-Erinnerung erinnert – reine
// Funktionen ohne Firestore und ohne Netzwerk (Tests: reminders.test.mjs).
//
// Es wird nichts neu berechnet: Grundlage sind die Dokumente, die die App
// selbst schreibt (`users/{uid}/streaks/{trackId}`, `bible_reading/plan_*`,
// `bible_reading/log_<Jahr>`). Der Server liest nur ab, ob ein Tag bereits
// erledigt ist. Siehe docs/notifications.md.

export type Categories = {
    bibleReading: boolean;
    readingPlan: boolean;
    memorization: boolean;
    trainers: boolean;
};

/** Felder aus `users/{uid}/streaks/{trackId}` (lokale Tage `yyyy-MM-dd`). */
export type StreakDoc = {
    lastActivityDate?: unknown;
    lastCompletedDate?: unknown;
    currentStreak?: unknown;
};

/** `users/{uid}/bible_reading/plan_<Plan>`. */
export type PlanDoc = {
    planId?: unknown;
    paused?: unknown;
    complete?: unknown;
    /** Letzte Änderung als lokaler Kalendertag des Nutzers. */
    updatedOn?: string | null;
};

export type ReminderInput = {
    /** Heutiger lokaler Kalendertag des Nutzers. */
    today: string;
    categories: Categories;
    /** Track-ID → Dokument. */
    streaks: Record<string, StreakDoc | undefined>;
    plans: PlanDoc[];
    /** Plan-IDs, aus denen heute schon eine Lesung bestätigt wurde. */
    plansReadToday: string[];
};

export type Reason = {
    kind: 'plan' | 'bible' | 'memorization' | 'greek' | 'latin' | 'perikope';
    /** Kurzname für die zusammengefasste Nachricht. */
    label: string;
    title: string;
    body: string;
    /** App-Pfad (lib/services/notifications/app_deep_link.dart). */
    link: string;
};

export type PushMessage = {
    title: string;
    body: string;
    link: string;
    tag: string;
};

/** Ein Bereich, der so lange ruht, wird nicht mehr angemahnt. */
export const INACTIVE_AFTER_DAYS = 14;

/** Wie spät nach der gewünschten Uhrzeit noch gesendet wird. */
export const MAX_DELAY_MINUTES = 180;

const DATE = /^\d{4}-\d{2}-\d{2}$/;

function date(value: unknown): string | null {
    return typeof value === 'string' && DATE.test(value) ? value : null;
}

function dayNumber(day: string): number {
    const [y, m, d] = day.split('-').map(Number);
    return Math.round(Date.UTC(y, m - 1, d) / 86_400_000);
}

export function addDays(day: string, days: number): string {
    return new Date((dayNumber(day) + days) * 86_400_000)
        .toISOString()
        .slice(0, 10);
}

/** Tage von [from] bis [to]; null ohne gültiges [from]. */
function daysSince(from: string | null, to: string): number | null {
    return from === null ? null : dayNumber(to) - dayNumber(from);
}

type TrackStatus = {
    /** Tagesziel heute erreicht. */
    done: boolean;
    /** In den letzten Tagen genutzt. */
    inUse: boolean;
    /** Länge der Streak, die heute fortgesetzt werden kann (sonst 0). */
    running: number;
};

/** Liest einen Streak-Stand wie `StreakCalculator.snapshot` in der App. */
export function trackStatus(
    doc: StreakDoc | undefined,
    today: string,
): TrackStatus {
    const completed = date(doc?.lastCompletedDate);
    const activity = date(doc?.lastActivityDate);

    const last = [completed, activity]
        .filter((d): d is string => d !== null)
        .sort()
        .pop() ?? null;

    const idle = daysSince(last, today);
    const streak =
        typeof doc?.currentStreak === 'number' ? doc.currentStreak : 0;

    return {
        done: completed === today,
        inUse: idle !== null && idle >= 0 && idle <= INACTIVE_AFTER_DAYS,
        running: completed === addDays(today, -1) ? streak : 0,
    };
}

function days(count: number): string {
    return count === 1 ? '1 Tag' : `${count} Tage`;
}

const PLAN_ID = /^[a-z0-9][a-z0-9._-]{1,62}$/;

/** Erster laufender, unvollständiger Plan ohne heutige Lesung. */
function openPlan(input: ReminderInput): string | null {
    for (const plan of input.plans) {
        const id = plan.planId;

        if (typeof id !== 'string' || !PLAN_ID.test(id)) continue;
        if (plan.paused === true || plan.complete === true) continue;
        if (input.plansReadToday.includes(id)) continue;

        const idle = daysSince(date(plan.updatedOn), input.today);

        if (idle !== null && idle > INACTIVE_AFTER_DAYS) continue;

        return id;
    }

    return null;
}

function trainerReason(
    kind: 'greek' | 'latin' | 'perikope',
    label: string,
    link: string,
    input: ReminderInput,
): Reason | null {
    const status = trackStatus(input.streaks[kind], input.today);

    if (status.done || !status.inUse) return null;

    return {
        kind,
        label,
        title: label,
        body:
            status.running > 0
                ? `Deine Streak (${days(status.running)}) wartet – ` +
                  'dein Tagesziel ist noch offen.'
                : 'Dein Tagesziel für heute ist noch offen.',
        link,
    };
}

/** Alle heute noch offenen Gründe, wichtigster zuerst. */
export function reasonsFor(input: ReminderInput): Reason[] {
    const reasons: Reason[] = [];
    const { categories, today } = input;

    const bible = trackStatus(input.streaks['bible'], today);
    const streakHint =
        !bible.done && bible.running > 0
            ? ` Deine Bibellese-Streak: ${days(bible.running)}.`
            : '';

    const plan = categories.readingPlan ? openPlan(input) : null;

    if (plan !== null) {
        reasons.push({
            kind: 'plan',
            label: 'Bibelleseplan',
            title: 'Bibelleseplan',
            body: `Deine heutige Lesung wartet noch auf dich.${streakHint}`,
            link: `/bible/plan/${plan}`,
        });
    } else if (categories.bibleReading && !bible.done && bible.inUse) {
        // Eine offene Planlesung deckt die Bibellese bereits ab.
        reasons.push({
            kind: 'bible',
            label: 'Bibellese',
            title: 'Bibellese',
            body: `Zeit für deine tägliche Bibellektüre.${streakHint}`,
            link: '/bible',
        });
    }

    if (categories.memorization) {
        const status = trackStatus(input.streaks['memorization'], today);

        if (!status.done && status.inUse) {
            reasons.push({
                kind: 'memorization',
                label: 'Texte auswendig lernen',
                title: 'Texte auswendig lernen',
                body:
                    status.running > 0
                        ? 'Zeit, deine Texte zu wiederholen. ' +
                          `Deine Streak: ${days(status.running)}.`
                        : 'Zeit, deine Texte zu wiederholen.',
                link: '/memorize',
            });
        }
    }

    if (categories.trainers) {
        const trainers = [
            trainerReason('greek', 'Altgriechisch', '/greek', input),
            trainerReason('latin', 'Latein', '/latin', input),
            trainerReason('perikope', 'Perikopenquiz', '/perikopen', input),
        ];

        for (const reason of trainers) {
            if (reason !== null) reasons.push(reason);
        }
    }

    return reasons;
}

/** Eine einzige Nachricht für alle Gründe; null, wenn nichts offen ist. */
export function composeMessage(reasons: Reason[]): PushMessage | null {
    if (reasons.length === 0) return null;

    const tag = 'daily-reminder';

    if (reasons.length === 1) {
        const [reason] = reasons;

        return { title: reason.title, body: reason.body, link: reason.link, tag };
    }

    return {
        title: 'Heute noch offen',
        body: reasons.map((reason) => reason.label).join(' · '),
        // Mehrere Bereiche: Startseite mit der Übersicht aller Streaks.
        link: '/',
        tag,
    };
}

// ==========================
// ZEIT
// ==========================

export type Zone = {
    /** IANA-Zeitzone, z. B. "Europe/Berlin". */
    timeZone?: unknown;
    /** Ersatz, falls die Zeitzone fehlt oder unbekannt ist. */
    utcOffsetMinutes?: unknown;
};

function formatter(timeZone: string): Intl.DateTimeFormat | null {
    try {
        return new Intl.DateTimeFormat('en-CA', {
            timeZone,
            hourCycle: 'h23',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });
    } catch {
        return null;
    }
}

/** Abstand der lokalen Zeit zu UTC in Minuten zum Zeitpunkt [at]. */
export function offsetMinutes(zone: Zone, at: Date): number {
    const format =
        typeof zone.timeZone === 'string' ? formatter(zone.timeZone) : null;

    if (format !== null) {
        const parts: Record<string, number> = {};

        for (const part of format.formatToParts(at)) {
            if (part.type !== 'literal') parts[part.type] = Number(part.value);
        }

        const local = Date.UTC(
            parts.year,
            parts.month - 1,
            parts.day,
            parts.hour,
            parts.minute,
        );

        return Math.round((local - at.getTime()) / 60_000);
    }

    const fallback = zone.utcOffsetMinutes;

    return typeof fallback === 'number' &&
        Number.isFinite(fallback) &&
        Math.abs(fallback) <= 16 * 60
        ? Math.round(fallback)
        : 0;
}

/** Lokaler Kalendertag (`yyyy-MM-dd`) des Nutzers zum Zeitpunkt [at]. */
export function localDate(zone: Zone, at: Date): string {
    return new Date(at.getTime() + offsetMinutes(zone, at) * 60_000)
        .toISOString()
        .slice(0, 10);
}

/** Zeitpunkt, an dem es am lokalen Tag [day] [minutes] nach Mitternacht ist. */
export function instantOf(zone: Zone, day: string, minutes: number): Date {
    const wall = dayNumber(day) * 86_400_000 + minutes * 60_000;

    // Zweimal annähern, damit die Abweichung am Zielzeitpunkt gilt
    // (Sommerzeit-Umstellung).
    let at = new Date(wall - offsetMinutes(zone, new Date(wall)) * 60_000);
    at = new Date(wall - offsetMinutes(zone, at) * 60_000);

    return at;
}

export function validMinutes(value: unknown, fallback = 18 * 60): number {
    return typeof value === 'number' &&
        Number.isInteger(value) &&
        value >= 0 &&
        value < 24 * 60
        ? value
        : fallback;
}

/** Erster Zeitpunkt nach [now], an dem es lokal [minutes] Uhr ist. */
export function nextReminder(zone: Zone, minutes: number, now: Date): Date {
    const today = localDate(zone, now);
    const candidate = instantOf(zone, today, minutes);

    return candidate.getTime() > now.getTime()
        ? candidate
        : instantOf(zone, addDays(today, 1), minutes);
}

/**
 * Darf zum Zeitpunkt [now] die für [dueAt] geplante Erinnerung noch
 * gesendet werden? Nicht mehr nach einem Ausfall von Stunden und nie zweimal
 * für denselben lokalen Tag. Maßgeblich ist der Tag von [dueAt], damit eine
 * kurz vor Mitternacht geplante Erinnerung nicht den neuen Tag anmahnt.
 */
export function shouldSendNow(
    zone: Zone,
    dueAt: Date,
    now: Date,
    lastReminderDate: unknown,
): boolean {
    const late = (now.getTime() - dueAt.getTime()) / 60_000;

    if (late < 0 || late > MAX_DELAY_MINUTES) return false;

    return lastReminderDate !== localDate(zone, dueAt);
}
