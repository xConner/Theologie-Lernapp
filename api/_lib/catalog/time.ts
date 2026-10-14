// Datums- und Zeitzonenhilfen ohne Abhängigkeiten. Kalenderdaten werden als
// `YYYY-MM-DD` geführt und über UTC-Tage gerechnet (keine Sommerzeitfallen);
// erst beim Erzeugen eines Termins wird die Ortszeit in einen Zeitpunkt mit
// Offset der Zeitzone (Europe/Berlin) umgerechnet.

import type { IsoDate, IsoDateTime, LocalTime } from './model';

const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const TIME = /^([01]?\d|2[0-3]):([0-5]\d)$/;
const DAY_MS = 86_400_000;

export function isIsoDate(value: unknown): value is IsoDate {
    if (typeof value !== 'string') return false;
    const m = DATE.exec(value);
    if (!m) return false;
    const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
    return d.getUTCFullYear() === +m[1] && d.getUTCMonth() === +m[2] - 1 && d.getUTCDate() === +m[3];
}

/** `8:30` → `08:30`; ungültig → null. */
export function normalizeTime(value: string | null | undefined): LocalTime | null {
    if (value == null) return null;
    const m = TIME.exec(value.trim());
    return m ? `${m[1].padStart(2, '0')}:${m[2]}` : null;
}

export function minutesOf(time: LocalTime): number {
    const [h, m] = time.split(':').map(Number);
    return h * 60 + m;
}

function toDay(date: IsoDate): number {
    const m = DATE.exec(date)!;
    return Date.UTC(+m[1], +m[2] - 1, +m[3]) / DAY_MS;
}

function fromDay(day: number): IsoDate {
    return new Date(day * DAY_MS).toISOString().slice(0, 10);
}

export function addDays(date: IsoDate, days: number): IsoDate {
    return fromDay(toDay(date) + days);
}

/** ISO-Wochentag: 1 = Montag … 7 = Sonntag. */
export function isoWeekday(date: IsoDate): number {
    const d = new Date(toDay(date) * DAY_MS).getUTCDay();
    return d === 0 ? 7 : d;
}

/** Alle Daten von [from] bis [to] einschließlich. */
export function* eachDay(from: IsoDate, to: IsoDate): Generator<IsoDate> {
    for (let day = toDay(from); day <= toDay(to); day++) yield fromDay(day);
}

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(timeZone: string): Intl.DateTimeFormat {
    let f = formatters.get(timeZone);
    if (!f) {
        f = new Intl.DateTimeFormat('en-US', {
            timeZone,
            hourCycle: 'h23',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
        });
        formatters.set(timeZone, f);
    }
    return f;
}

/** Offset der Zeitzone zum UTC-Zeitpunkt [utcMs] in Minuten (Berlin: 60/120). */
function offsetMinutes(utcMs: number, timeZone: string): number {
    const parts: Record<string, number> = {};
    for (const p of formatter(timeZone).formatToParts(new Date(utcMs))) {
        if (p.type !== 'literal') parts[p.type] = Number(p.value);
    }
    const asUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
    return Math.round((asUtc - utcMs) / 60_000);
}

function formatOffset(minutes: number): string {
    const sign = minutes >= 0 ? '+' : '-';
    const abs = Math.abs(minutes);
    return `${sign}${String(Math.floor(abs / 60)).padStart(2, '0')}:${String(abs % 60).padStart(2, '0')}`;
}

/**
 * Ortszeit [date] [time] in [timeZone] → Zeitpunkt mit Offset.
 * Liegt die Ortszeit in der Lücke der Zeitumstellung (gibt es nicht), ist das
 * Ergebnis null. Doppelt vorhandene Zeiten (Rückstellung) nehmen den
 * früheren Zeitpunkt (Sommerzeit).
 */
export function zonedDateTime(date: IsoDate, time: LocalTime, timeZone: string): IsoDateTime | null {
    const [y, mo, d] = date.split('-').map(Number);
    const [h, mi] = time.split(':').map(Number);
    const wallAsUtc = Date.UTC(y, mo - 1, d, h, mi);

    // Kandidaten mit beiden Offsets rund um den Zeitpunkt; gültig ist, was
    // zurückgerechnet wieder genau die gewünschte Ortszeit ergibt.
    const offsets = [...new Set([
        offsetMinutes(wallAsUtc - 3 * 3_600_000, timeZone),
        offsetMinutes(wallAsUtc + 3 * 3_600_000, timeZone),
    ])].sort((a, b) => b - a);

    for (const offset of offsets) {
        const utc = wallAsUtc - offset * 60_000;
        if (offsetMinutes(utc, timeZone) === offset) {
            return `${date}T${time}:00${formatOffset(offset)}`;
        }
    }
    return null;
}

/** Millisekunden seit 1970 eines Zeitpunkts mit Offset. */
export function epochMs(value: IsoDateTime): number {
    return Date.parse(value);
}
