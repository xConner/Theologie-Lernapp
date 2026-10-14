// Tests des UnivIS-Parsers ohne Netzwerk:
//   node --test tool/univis/univis_parser.test.mjs
//
// Grundlage ist eine SYNTHETISCHE Fixture (fixtures/synthetic_lectures.xml).
// Die Tests prüfen das Verhalten des Parsers, nicht die tatsächliche
// Struktur der Kieler UnivIS-Antworten.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
    parseRepeat,
    parseUnivisLectures,
    validateLectures,
} from './univis_parser.mjs';

const xml = readFileSync(
    new URL('./fixtures/synthetic_lectures.xml', import.meta.url),
    'utf8',
);
const result = parseUnivisLectures(xml);
const byKey = Object.fromEntries(result.lectures.map((l) => [l.sourceKey, l]));

test('liest Stammdaten einer Veranstaltung', () => {
    const lecture = byKey['Lecture.beispiel.at.vorl1'];
    assert.equal(lecture.name, 'Beispielvorlesung Altes Testament');
    assert.equal(lecture.id, '010001');
    assert.equal(lecture.type, 'V');
    assert.equal(lecture.ects, '3');
    assert.equal(lecture.hasSummary, true);
});

test('löst Lehrpersonen und Räume über UnivISRef auf', () => {
    const lecture = byKey['Lecture.beispiel.at.vorl1'];
    assert.deepEqual(lecture.lecturers, [
        { key: 'Person.beispiel.musterfrau', displayName: 'Prof. Dr. Erika Musterfrau' },
    ]);
    assert.deepEqual(lecture.sessions[0].room, {
        key: 'Room.beispiel.hs1',
        short: 'HS 1',
        name: 'Beispielhörsaal 1',
    });
});

test('meldet nicht auflösbare Verweise statt sie zu verwerfen', () => {
    assert.deepEqual(result.unresolvedRefs, ['Person.beispiel.fehlt']);
    const seminar = byKey['Lecture.beispiel.nt.sem1'];
    assert.equal(seminar.lecturers[1].displayName, null);
});

test('normalisiert Uhrzeiten und Daten', () => {
    const [biweekly, single] = byKey['Lecture.beispiel.nt.sem1'].sessions;
    assert.equal(biweekly.startTime, '08:30');
    assert.equal(single.startDate, '2027-01-30');
    assert.deepEqual(byKey['Lecture.beispiel.at.vorl1'].sessions[0].excludedDates, [
        '2026-12-22',
    ]);
});

test('deutet Wiederholungsmuster und behält Unbekanntes als Rohwert', () => {
    assert.deepEqual(parseRepeat('w1 2'), {
        kind: 'weekly',
        intervalWeeks: 1,
        weekdays: [2],
        raw: 'w1 2',
    });
    assert.deepEqual(parseRepeat('w2 4,1').weekdays, [1, 4]);
    assert.equal(parseRepeat('w1 0').weekdays[0], 7);
    assert.equal(parseRepeat('s1').kind, 'single');
    assert.deepEqual(parseRepeat('x9 sonderfall'), {
        kind: 'unknown',
        raw: 'x9 sonderfall',
    });
    assert.deepEqual(parseRepeat(null), { kind: 'unknown', raw: null });
});

test('Validierung zählt Lücken der Daten', () => {
    const v = validateLectures(result);
    assert.equal(v.lectures, 3);
    assert.equal(v.duplicateKeys, 0);
    assert.equal(v.lecturesWithoutSessions, 1);
    assert.equal(v.lecturesWithoutLecturer, 1);
    assert.equal(v.sessions, 4);
    assert.equal(v.sessionsWithTimes, 3);
    assert.equal(v.sessionsWithRoom, 2);
    assert.deepEqual(v.repeatKinds, { weekly: 2, single: 1, unknown: 1 });
    assert.deepEqual(v.unknownRepeatValues, ['x9 sonderfall']);
});

test('Inventar listet die tatsächlich vorkommenden Elemente', () => {
    assert.equal(result.inventory.UnivIS.Lecture, 3);
    assert.equal(result.inventory.term.repeat, 4);
});

test('lehnt Antworten ohne UnivIS-Wurzel ab (z. B. HTML-Fehlerseite)', () => {
    assert.throws(() => parseUnivisLectures('<html><body>Fehler</body></html>'));
});
