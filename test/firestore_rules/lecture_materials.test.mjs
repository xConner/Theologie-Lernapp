// Tests der Freigabe für Vorlesungsunterlagen (firestore.rules,
// docs/lecture-materials.md):
//   cd test/firestore_rules && npm ci && npm test
//
// lecture_access/check ist nur für Konten aus lecture_access/allowlist
// lesbar (daran entscheidet die App); niemand darf über den Client
// schreiben, auflisten oder die Freigabeliste lesen bzw. ändern.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
    arrayUnion,
    collection,
    deleteDoc,
    doc,
    getDoc,
    getDocs,
    setDoc,
    updateDoc,
} from 'firebase/firestore';

const OWNER = 'connerverlinden@gmail.com';

let env;

before(async () => {
    env = await initializeTestEnvironment({
        projectId: 'demo-theologie-rules',
        firestore: {
            rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
            host: '127.0.0.1',
            port: 8080,
        },
    });
});

after(async () => {
    await env?.cleanup();
});

async function seed(path, data) {
    await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), ...path), data);
    });
}

async function remove(path) {
    await env.withSecurityRulesDisabled(async (ctx) => {
        await deleteDoc(doc(ctx.firestore(), ...path));
    });
}

beforeEach(async () => {
    await env.clearFirestore();
    // Ausgangslage wie nach der Einrichtung: nur Conner freigeschaltet.
    await seed(['lecture_access', 'allowlist'], { emails: [OWNER], uids: [] });
});

const conner = (claims = {}) =>
    env.authenticatedContext('conner-uid', {
        email: OWNER,
        email_verified: true,
        ...claims,
    }).firestore();
const other = (claims = {}) =>
    env.authenticatedContext('other-uid', {
        email: 'someone@example.org',
        email_verified: true,
        ...claims,
    }).firestore();
const guest = () => env.unauthenticatedContext().firestore();

// Prüfdokument: muss nicht existieren, entscheidend ist, ob Lesen erlaubt ist.
const check = (db) => doc(db, 'lecture_access', 'check');
const allowlist = (db) => doc(db, 'lecture_access', 'allowlist');

describe('lecture_access/check: Freigabe prüfen', () => {
    test('freigeschaltetes Konto (connerverlinden@gmail.com) ist freigegeben', async () => {
        const db = conner();
        await assertSucceeds(getDoc(check(db)));
    });

    test('Groß-/Kleinschreibung der E-Mail-Adresse spielt keine Rolle', async () => {
        await assertSucceeds(getDoc(check(conner({ email: 'ConnerVerlinden@Gmail.com' }))));
    });

    test('anderes angemeldetes Konto: keine Freigabe', async () => {
        const db = other();
        await assertFails(getDoc(check(db)));
    });

    test('nicht angemeldet: kein Zugriff', async () => {
        const db = guest();
        await assertFails(getDoc(check(db)));
    });

    test('anonymes Gastkonto: kein Zugriff', async () => {
        const db = env.authenticatedContext('anon', {
            firebase: { sign_in_provider: 'anonymous' },
        }).firestore();
        await assertFails(getDoc(check(db)));
    });

    test('freigegebene E-Mail-Adresse ohne Bestätigung (email_verified) reicht nicht', async () => {
        await assertFails(getDoc(check(other({ email: OWNER, email_verified: false }))));
    });

    test('selbst gesetztes Feld im eigenen Nutzerdokument bewirkt keine Freigabe', async () => {
        const db = other();
        // Erlaubte Felder im Nutzerdokument; ein Feld wie lecture_access wird
        // schon abgewiesen …
        await assertFails(setDoc(doc(db, 'users', 'other-uid'), { lecture_access: true }));
        // … und ein vom Server angelegtes ändert nichts an den Regeln.
        await seed(['users', 'other-uid'], { lecture_access: true, email: OWNER });
        await seed(['users', 'other-uid', 'quiz_settings', 'lecture_access'], { allowed: true });
        await assertFails(getDoc(check(db)));
    });

    test('kein Auflisten, nur das Prüfdokument', async () => {
        await assertFails(getDocs(collection(conner(), 'lecture_access')));
        await assertFails(getDocs(collection(other(), 'lecture_access')));
        await assertFails(getDoc(doc(conner(), 'lecture_access', 'anderes')));
    });

    test('Freigabe über die Konto-ID (z. B. Telefon-Login ohne E-Mail)', async () => {
        const db = env.authenticatedContext('phone-uid', { phone_number: '+4917600000000' }).firestore();
        await assertFails(getDoc(check(db)));
        await seed(['lecture_access', 'allowlist'], { emails: [OWNER], uids: ['phone-uid'] });
        await assertSucceeds(getDoc(check(db)));
    });

    test('entzogene Freigabe verhindert weitere Abrufe', async () => {
        const db = conner();
        await assertSucceeds(getDoc(check(db)));
        await seed(['lecture_access', 'allowlist'], { emails: [], uids: [] });
        await assertFails(getDoc(check(db)));
    });

    test('ohne Freigabeliste ist niemand freigeschaltet', async () => {
        await remove(['lecture_access', 'allowlist']);
        await assertFails(getDoc(check(conner())));
    });

    test('neu freigeschaltetes Konto erhält Zugriff ohne App-Änderung', async () => {
        await assertFails(getDoc(check(other())));
        await seed(['lecture_access', 'allowlist'], {
            emails: [OWNER, 'someone@example.org'],
            uids: [],
        });
        await assertSucceeds(getDoc(check(other())));
    });
});

describe('lecture_access: Schreiben', () => {
    test('niemand schreibt das Prüfdokument über den Client', async () => {
        for (const db of [conner(), other(), guest()]) {
            await assertFails(setDoc(check(db), { allowed: true }));
            await assertFails(deleteDoc(check(db)));
        }
    });

    test('Freigabeliste ist für Clients weder lesbar noch änderbar', async () => {
        for (const db of [conner(), other(), guest()]) {
            await assertFails(getDoc(allowlist(db)));
            await assertFails(updateDoc(allowlist(db), { emails: arrayUnion('someone@example.org') }));
            await assertFails(setDoc(allowlist(db), { emails: ['someone@example.org'] }));
            await assertFails(setDoc(doc(db, 'lecture_access', 'other-uid'), { allowed: true }));
        }
        // Danach weiterhin keine Freigabe für das andere Konto.
        await assertFails(getDoc(check(other())));
    });
});

describe('übrige Regeln unverändert', () => {
    test('eigener Stundenplan und Lernstand weiterhin nutzbar (ohne Freigabe)', async () => {
        const db = other();
        await assertSucceeds(
            setDoc(doc(db, 'users', 'other-uid', 'quiz_settings', 'old_testament'), { cards: {} }),
        );
        await assertSucceeds(getDoc(doc(db, 'users', 'other-uid', 'quiz_settings', 'old_testament')));
        await assertSucceeds(getDocs(collection(db, 'users', 'other-uid', 'timetable')));
    });
});
