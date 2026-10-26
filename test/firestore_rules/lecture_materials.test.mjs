// Tests der Freigabe für geschützte Vorlesungsunterlagen (firestore.rules,
// docs/lecture-materials.md):
//   cd test/firestore_rules && npm ci && npm test
//
// lecture_materials/{fileId} ist nur für Konten aus lecture_access/allowlist
// einzeln lesbar; niemand darf über den Client schreiben, auflisten oder die
// Freigabeliste lesen bzw. ändern.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
    Bytes,
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
    await seed(['lecture_materials', 'manifest'], {
        files: ['old_testament/course.json', 'old_testament/slides/e01-folie-01.png'],
    });
    await seed(['lecture_materials', 'old_testament~course.json'], {
        path: 'old_testament/course.json',
        data: Bytes.fromUint8Array(new TextEncoder().encode('{"course":{"lecturer":"X"}}')),
    });
    await seed(['lecture_materials', 'old_testament~slides~e01-folie-01.png'], {
        path: 'old_testament/slides/e01-folie-01.png',
        data: Bytes.fromUint8Array(new Uint8Array([137, 80, 78, 71])),
    });
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

const manifest = (db) => doc(db, 'lecture_materials', 'manifest');
const course = (db) => doc(db, 'lecture_materials', 'old_testament~course.json');
const slide = (db) => doc(db, 'lecture_materials', 'old_testament~slides~e01-folie-01.png');
const allowlist = (db) => doc(db, 'lecture_access', 'allowlist');

describe('lecture_materials: Lesen', () => {
    test('freigeschaltetes Konto (connerverlinden@gmail.com) liest Manifest, Daten und Folien', async () => {
        const db = conner();
        await assertSucceeds(getDoc(manifest(db)));
        await assertSucceeds(getDoc(course(db)));
        await assertSucceeds(getDoc(slide(db)));
    });

    test('Groß-/Kleinschreibung der E-Mail-Adresse spielt keine Rolle', async () => {
        await assertSucceeds(getDoc(course(conner({ email: 'ConnerVerlinden@Gmail.com' }))));
    });

    test('anderes angemeldetes Konto: weder Daten noch Metadaten', async () => {
        const db = other();
        await assertFails(getDoc(manifest(db)));
        await assertFails(getDoc(course(db)));
        await assertFails(getDoc(slide(db)));
    });

    test('nicht angemeldet: kein Zugriff', async () => {
        const db = guest();
        await assertFails(getDoc(manifest(db)));
        await assertFails(getDoc(course(db)));
        await assertFails(getDoc(slide(db)));
    });

    test('anonymes Gastkonto: kein Zugriff', async () => {
        const db = env.authenticatedContext('anon', {
            firebase: { sign_in_provider: 'anonymous' },
        }).firestore();
        await assertFails(getDoc(course(db)));
    });

    test('freigegebene E-Mail-Adresse ohne Bestätigung (email_verified) reicht nicht', async () => {
        await assertFails(getDoc(course(other({ email: OWNER, email_verified: false }))));
    });

    test('selbst gesetztes Feld im eigenen Nutzerdokument bewirkt keine Freigabe', async () => {
        const db = other();
        // Erlaubte Felder im Nutzerdokument; ein Feld wie lecture_access wird
        // schon abgewiesen …
        await assertFails(setDoc(doc(db, 'users', 'other-uid'), { lecture_access: true }));
        // … und ein vom Server angelegtes ändert nichts an den Regeln.
        await seed(['users', 'other-uid'], { lecture_access: true, email: OWNER });
        await seed(['users', 'other-uid', 'quiz_settings', 'lecture_access'], { allowed: true });
        await assertFails(getDoc(course(db)));
    });

    test('kein Auflisten der Sammlung, auch nicht freigeschaltet', async () => {
        await assertFails(getDocs(collection(conner(), 'lecture_materials')));
        await assertFails(getDocs(collection(other(), 'lecture_materials')));
        await assertFails(getDocs(collection(guest(), 'lecture_materials')));
    });

    test('Freigabe über die Konto-ID (z. B. Telefon-Login ohne E-Mail)', async () => {
        const db = env.authenticatedContext('phone-uid', { phone_number: '+4917600000000' }).firestore();
        await assertFails(getDoc(course(db)));
        await seed(['lecture_access', 'allowlist'], { emails: [OWNER], uids: ['phone-uid'] });
        await assertSucceeds(getDoc(course(db)));
    });

    test('entzogene Freigabe verhindert weitere Abrufe', async () => {
        const db = conner();
        await assertSucceeds(getDoc(course(db)));
        await seed(['lecture_access', 'allowlist'], { emails: [], uids: [] });
        await assertFails(getDoc(manifest(db)));
        await assertFails(getDoc(course(db)));
        await assertFails(getDoc(slide(db)));
    });

    test('ohne Freigabeliste ist niemand freigeschaltet', async () => {
        await remove(['lecture_access', 'allowlist']);
        await assertFails(getDoc(course(conner())));
    });

    test('neu freigeschaltetes Konto erhält Zugriff ohne App-Änderung', async () => {
        await assertFails(getDoc(course(other())));
        await seed(['lecture_access', 'allowlist'], {
            emails: [OWNER, 'someone@example.org'],
            uids: [],
        });
        await assertSucceeds(getDoc(course(other())));
    });
});

describe('lecture_materials und lecture_access: Schreiben', () => {
    test('niemand schreibt Unterlagen über den Client', async () => {
        for (const db of [conner(), other(), guest()]) {
            await assertFails(setDoc(doc(db, 'lecture_materials', 'neu'), { data: 'x' }));
            await assertFails(updateDoc(course(db), { path: 'x' }));
            await assertFails(deleteDoc(slide(db)));
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
        await assertFails(getDoc(course(other())));
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
