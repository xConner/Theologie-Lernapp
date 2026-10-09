// Tests der Erinnerungslogik: `node --test api/_lib/reminders.test.mjs`
// (Node ab 24 liest die TypeScript-Datei direkt).

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
    composeMessage,
    instantOf,
    localDate,
    nextReminder,
    reasonsFor,
    shouldSendNow,
    trackStatus,
} from './reminders.ts';

const all = {
    bibleReading: true,
    readingPlan: true,
    memorization: true,
    trainers: true,
};

const today = '2026-10-10';

function input(overrides = {}) {
    return {
        today,
        categories: all,
        streaks: {},
        plans: [],
        plansReadToday: [],
        ...overrides,
    };
}

const kinds = (value) => reasonsFor(value).map((reason) => reason.kind);

test('Streak-Stand wird wie in der App gelesen', () => {
    assert.deepEqual(trackStatus(undefined, today), {
        done: false,
        inUse: false,
        running: 0,
    });

    assert.deepEqual(
        trackStatus(
            { lastCompletedDate: today, lastActivityDate: today, currentStreak: 4 },
            today,
        ),
        { done: true, inUse: true, running: 0 },
    );

    assert.deepEqual(
        trackStatus(
            {
                lastCompletedDate: '2026-10-09',
                lastActivityDate: '2026-10-09',
                currentStreak: 4,
            },
            today,
        ),
        { done: false, inUse: true, running: 4 },
    );

    // Unterbrochene Streak zählt nicht mehr als laufend.
    assert.equal(
        trackStatus({ lastCompletedDate: '2026-10-07', currentStreak: 9 }, today)
            .running,
        0,
    );
});

test('ohne Nutzung oder nach langer Pause keine Erinnerung', () => {
    assert.deepEqual(kinds(input()), []);

    assert.deepEqual(
        kinds(input({ streaks: { bible: { lastCompletedDate: '2026-09-20' } } })),
        [],
    );

    assert.deepEqual(
        kinds(input({ streaks: { bible: { lastCompletedDate: '2026-09-26' } } })),
        ['bible'],
    );
});

test('bestätigte Bibellese wird nicht angemahnt', () => {
    assert.deepEqual(
        kinds(input({ streaks: { bible: { lastCompletedDate: today } } })),
        [],
    );
});

test('offene Planlesung ersetzt die allgemeine Bibellese-Erinnerung', () => {
    const value = input({
        streaks: { bible: { lastCompletedDate: '2026-10-09', currentStreak: 3 } },
        plans: [{ planId: 'nt-90-days', updatedOn: '2026-10-09' }],
    });

    const reasons = reasonsFor(value);

    assert.deepEqual(
        reasons.map((r) => r.kind),
        ['plan'],
    );
    assert.equal(reasons[0].link, '/bible/plan/nt-90-days');
    assert.match(reasons[0].body, /Streak: 3 Tage/);
});

test('pausierte, beendete, heute gelesene und ruhende Pläne zählen nicht', () => {
    const plans = [
        { planId: 'paused-plan', paused: true, updatedOn: today },
        { planId: 'done-plan', complete: true, updatedOn: today },
        { planId: 'read-plan', updatedOn: today },
        { planId: 'old-plan', updatedOn: '2026-08-01' },
        { planId: '../kaputt', updatedOn: today },
    ];

    assert.deepEqual(
        kinds(input({ plans, plansReadToday: ['read-plan'] })),
        [],
    );
});

test('ausgeschaltete Kategorien erzeugen keine Erinnerung', () => {
    const streaks = {
        bible: { lastCompletedDate: '2026-10-09' },
        memorization: { lastActivityDate: '2026-10-09' },
        greek: { lastCompletedDate: '2026-10-09' },
        latin: { lastCompletedDate: today },
        perikope: { lastActivityDate: '2026-10-08' },
    };

    assert.deepEqual(kinds(input({ streaks })), [
        'bible',
        'memorization',
        'greek',
        'perikope',
    ]);

    assert.deepEqual(
        kinds(
            input({
                streaks,
                categories: { ...all, bibleReading: false, trainers: false },
            }),
        ),
        ['memorization'],
    );
});

test('mehrere Gründe ergeben eine einzige Nachricht', () => {
    assert.equal(composeMessage([]), null);

    const one = reasonsFor(
        input({ streaks: { memorization: { lastActivityDate: '2026-10-09' } } }),
    );

    assert.deepEqual(composeMessage(one), {
        title: 'Texte auswendig lernen',
        body: 'Zeit, deine Texte zu wiederholen.',
        link: '/memorize',
        tag: 'daily-reminder',
    });

    const several = reasonsFor(
        input({
            streaks: {
                bible: { lastCompletedDate: '2026-10-09' },
                greek: { lastCompletedDate: '2026-10-09' },
            },
        }),
    );

    assert.deepEqual(composeMessage(several), {
        title: 'Heute noch offen',
        body: 'Bibellese · Altgriechisch',
        link: '/',
        tag: 'daily-reminder',
    });
});

const berlin = { timeZone: 'Europe/Berlin' };

test('lokaler Tag und Zeitpunkt folgen der Zeitzone samt Sommerzeit', () => {
    assert.equal(localDate(berlin, new Date('2026-10-10T21:59:00Z')), '2026-10-10');
    assert.equal(localDate(berlin, new Date('2026-10-10T22:00:00Z')), '2026-10-11');

    // Sommerzeit (UTC+2) und nach der Umstellung am 25.10.2026 (UTC+1).
    assert.equal(
        instantOf(berlin, '2026-10-24', 18 * 60).toISOString(),
        '2026-10-24T16:00:00.000Z',
    );
    assert.equal(
        instantOf(berlin, '2026-10-25', 18 * 60).toISOString(),
        '2026-10-25T17:00:00.000Z',
    );

    // Unbekannte Zeitzone: fester Abstand als Ersatz.
    assert.equal(
        localDate(
            { timeZone: 'Nirgendwo/Nichts', utcOffsetMinutes: -300 },
            new Date('2026-10-10T03:00:00Z'),
        ),
        '2026-10-09',
    );
});

test('nächste Erinnerung liegt immer nach jetzt', () => {
    // 18:05 Ortszeit → morgen 18:00.
    assert.equal(
        nextReminder(berlin, 18 * 60, new Date('2026-10-10T16:05:00Z')).toISOString(),
        '2026-10-11T16:00:00.000Z',
    );

    // Geplant für 23:55, Lauf erst 00:05 → heute 23:55, nicht übermorgen.
    assert.equal(
        nextReminder(berlin, 23 * 60 + 55, new Date('2026-10-10T22:05:00Z')).toISOString(),
        '2026-10-11T21:55:00.000Z',
    );

    // Über die Zeitumstellung hinweg bleibt es bei 18:00 Ortszeit.
    assert.equal(
        nextReminder(berlin, 18 * 60, new Date('2026-10-24T16:01:00Z')).toISOString(),
        '2026-10-25T17:00:00.000Z',
    );
});

test('nie doppelt am selben Tag und nicht mehr nach Stunden', () => {
    const dueAt = new Date('2026-10-10T16:00:00Z');

    assert.equal(
        shouldSendNow(berlin, dueAt, new Date('2026-10-10T16:07:00Z'), '2026-10-09'),
        true,
    );
    assert.equal(
        shouldSendNow(berlin, dueAt, new Date('2026-10-10T16:07:00Z'), '2026-10-10'),
        false,
    );
    assert.equal(
        shouldSendNow(berlin, dueAt, new Date('2026-10-10T20:00:00Z'), null),
        false,
    );

    // Kurz vor Mitternacht geplant, kurz danach gesendet: zählt für den
    // geplanten Tag.
    assert.equal(
        shouldSendNow(
            berlin,
            new Date('2026-10-10T21:55:00Z'),
            new Date('2026-10-10T22:05:00Z'),
            '2026-10-10',
        ),
        false,
    );
});
