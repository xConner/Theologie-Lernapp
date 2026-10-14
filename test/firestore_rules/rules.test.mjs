// Tests der firestore.rules im Firestore-Emulator:
//   cd test/firestore_rules && npm ci && npm test
// (startet den Emulator über firebase-tools; braucht Java). In CI:
// .github/workflows/firestore-rules.yml.
//
// Schwerpunkt: persönlicher Stundenplan unter users/{uid}/timetable – nur der
// Nutzer selbst, nur gültige Einträge, keine Unterdokumente, keine Gäste.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
    collection,
    deleteDoc,
    doc,
    getDoc,
    getDocs,
    serverTimestamp,
    setDoc,
    Timestamp,
    updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
    env = await initializeTestEnvironment({
        projectId: 'demo-theologie-rules',
        firestore: {
            // Immer die Regeln aus dem Repository (nicht die Kopie für den Emulatorstart).
            rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
            host: '127.0.0.1',
            port: 8080,
        },
    });
});

after(async () => {
    await env?.cleanup();
});

beforeEach(async () => {
    await env.clearFirestore();
});

// Wie TimetableEntry.toMap() + FirestoreTimetableBackend.put().
function entry(overrides = {}) {
    return {
        courseId: 'cau-univis:2026w:Lecture.theol.altte.relig.bibelk',
        semesterId: '2026w',
        sources: [{ sourceId: 'cau-univis', key: 'Lecture.theol.altte.relig.bibelk' }],
        title: 'Bibelkunde Altes Testament',
        number: '010076',
        scheduleSignature: 'weekly|1|4|16:15|17:45|||cau-univis:Room.x',
        addedAt: serverTimestamp(),
        ...overrides,
    };
}

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const guest = () => env.unauthenticatedContext().firestore();
const entryRef = (db, uid = 'alice', id = 'e1') => doc(db, 'users', uid, 'timetable', id);

async function seed(path, data) {
    await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), ...path), data);
    });
}

describe('users/{uid}/timetable', () => {
    test('Eigentümer: anlegen, lesen, auflisten, ändern, löschen', async () => {
        const db = alice();
        await assertSucceeds(setDoc(entryRef(db), entry()));
        await assertSucceeds(getDoc(entryRef(db)));
        await assertSucceeds(getDocs(collection(db, 'users', 'alice', 'timetable')));
        await assertSucceeds(setDoc(entryRef(db), entry({ title: 'Neu' })));
        await assertSucceeds(deleteDoc(entryRef(db)));
    });

    test('Eintrag ohne Nummer ist gültig', async () => {
        const { number: _n, ...withoutNumber } = entry();
        await assertSucceeds(setDoc(entryRef(alice()), withoutNumber));
    });

    test('andere Nutzer: weder lesen noch schreiben noch löschen', async () => {
        await seed(['users', 'alice', 'timetable', 'e1'], { ...entry(), addedAt: Timestamp.now() });
        const db = bob();
        await assertFails(getDoc(entryRef(db)));
        await assertFails(getDocs(collection(db, 'users', 'alice', 'timetable')));
        await assertFails(setDoc(entryRef(db, 'alice', 'e2'), entry()));
        await assertFails(updateDoc(entryRef(db), { title: 'fremd', addedAt: serverTimestamp() }));
        await assertFails(deleteDoc(entryRef(db)));
    });

    test('Gäste (nicht angemeldet): kein Zugriff – sie speichern nur lokal', async () => {
        await seed(['users', 'alice', 'timetable', 'e1'], { ...entry(), addedAt: Timestamp.now() });
        const db = guest();
        await assertFails(getDoc(entryRef(db)));
        await assertFails(setDoc(entryRef(db, 'alice', 'e2'), entry()));
        await assertFails(deleteDoc(entryRef(db)));
    });

    test('ungültige Einträge werden abgelehnt', async () => {
        const db = alice();
        const { addedAt: _a, ...withoutTime } = entry();
        for (const [label, data] of [
            ['unbekanntes Feld', entry({ email: 'x@example.org' })],
            ['ohne addedAt', withoutTime],
            ['Zeitpunkt vom Client', entry({ addedAt: Timestamp.fromMillis(0) })],
            ['courseId leer', entry({ courseId: '' })],
            ['courseId kein Text', entry({ courseId: 42 })],
            ['Titel zu lang', entry({ title: 'x'.repeat(501) })],
            ['sources kein Array', entry({ sources: 'x' })],
            ['zu viele sources', entry({ sources: Array.from({ length: 21 }, () => ({ sourceId: 's', key: 'k' })) })],
            ['Nummer kein Text', entry({ number: 10076 })],
            ['Signatur zu lang', entry({ scheduleSignature: 'x'.repeat(4001) })],
        ]) {
            await assertFails(setDoc(entryRef(db, 'alice', label.replace(/\W/g, '_')), data), label);
        }
    });

    // put() ersetzt das Dokument immer vollständig mit addedAt =
    // serverTimestamp(); erneutes Hinzufügen setzt den Zeitpunkt neu.
    test('addedAt bei Aktualisierung: nur Serverzeit, kein Teil-Update', async () => {
        const db = alice();
        await seed(['users', 'alice', 'timetable', 'e1'], { ...entry(), addedAt: Timestamp.fromMillis(1000) });
        await assertFails(setDoc(entryRef(db), entry({ addedAt: Timestamp.fromMillis(0) })), 'gefälschter Zeitpunkt');
        await assertFails(setDoc(entryRef(db), entry({ addedAt: Timestamp.fromMillis(1000) })), 'alter Zeitpunkt vom Client');
        await assertFails(updateDoc(entryRef(db), { title: 'Neu' }), 'Teil-Update ohne addedAt');
        await assertSucceeds(setDoc(entryRef(db), entry({ title: 'Neu' })), 'wie put()');
        const saved = (await getDoc(entryRef(db))).data();
        if (!(saved.addedAt instanceof Timestamp) || saved.addedAt.toMillis() <= 1000) {
            throw new Error('addedAt wurde nicht auf die Serverzeit gesetzt');
        }
    });

    test('Gast-Übernahme: lokaler Zeitstempel (Zahl) wird abgelehnt', async () => {
        await assertFails(setDoc(entryRef(alice()), entry({ addedAt: Date.now() })));
    });

    test('keine Unterdokumente unterhalb eines Eintrags', async () => {
        const db = alice();
        await assertFails(setDoc(doc(db, 'users', 'alice', 'timetable', 'e1', 'extra', 'x'), { a: 1 }));
        await assertFails(getDoc(doc(db, 'users', 'alice', 'timetable', 'e1', 'extra', 'x')));
    });
});

describe('übrige Pfade', () => {
    test('allgemeine Nutzer-Collections weiterhin nur für den Eigentümer', async () => {
        await assertSucceeds(setDoc(doc(alice(), 'users', 'alice', 'greek_exam', 'settings'), { config: {} }));
        await assertFails(setDoc(doc(bob(), 'users', 'alice', 'greek_exam', 'settings'), { config: {} }));
        await assertFails(setDoc(doc(alice(), 'users', 'alice', 'unbekannt', 'x'), { a: 1 }));
    });

    test('Server-Zwischenspeicher des Katalogs ist für Clients gesperrt', async () => {
        await seed(['catalog_cache', 'k'], { gz: 'x' });
        for (const db of [alice(), guest()]) {
            await assertFails(getDoc(doc(db, 'catalog_cache', 'k')));
            await assertFails(setDoc(doc(db, 'catalog_cache', 'k'), { gz: 'y' }));
        }
    });

    test('users/{uid}-Dokument: nur erlaubte Felder, nur der Eigentümer', async () => {
        await assertSucceeds(setDoc(doc(alice(), 'users', 'alice'), { notification_settings: {} }, { merge: true }));
        await assertFails(setDoc(doc(alice(), 'users', 'alice'), { timetable: [] }, { merge: true }));
        await assertFails(getDoc(doc(bob(), 'users', 'alice')));
    });
});
