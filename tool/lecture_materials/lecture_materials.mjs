#!/usr/bin/env node
// Freigabe der Vorlesungsunterlagen verwalten (docs/lecture-materials.md).
//
//   node tool/lecture_materials/lecture_materials.mjs grant  <E-Mail|uid:KONTO-ID>
//   node tool/lecture_materials/lecture_materials.mjs revoke <E-Mail|uid:KONTO-ID>
//   node tool/lecture_materials/lecture_materials.mjs list
//
// Ändert die Freigabeliste lecture_access/allowlist.
//
// Zugang: Dienstkonto des Firebase-Projekts (Admin SDK, umgeht die Security
// Rules) – als Pfad in GOOGLE_APPLICATION_CREDENTIALS oder als JSON (roh oder
// Base64) in FIREBASE_SERVICE_ACCOUNT, wie bei den Vercel-Funktionen. Der
// Schlüssel wird nie ausgegeben.

import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ALLOWLIST = ['lecture_access', 'allowlist'];

/**
 * Eintrag der Freigabeliste: `uid:<Konto-ID>` oder eine E-Mail-Adresse
 * (klein geschrieben, wie die Regeln vergleichen).
 */
export function parseGrantee(value) {
    const text = String(value ?? '').trim();
    if (text.startsWith('uid:') && text.length > 4) {
        return { field: 'uids', value: text.slice(4) };
    }
    if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text)) {
        return { field: 'emails', value: text.toLowerCase() };
    }
    throw new Error(`Weder E-Mail-Adresse noch uid:<Konto-ID>: ${text}`);
}

function serviceAccount() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
    if (!raw) return null;
    const text = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
    return JSON.parse(text);
}

async function firestore() {
    const { cert, applicationDefault, initializeApp } = await import('firebase-admin/app');
    const { getFirestore } = await import('firebase-admin/firestore');
    const account = serviceAccount();
    const app = initializeApp({
        credential: account ? cert(account) : applicationDefault(),
        ...(account ? { projectId: account.project_id } : {}),
    });
    return getFirestore(app);
}

async function changeAccess(db, grantee, add) {
    const { FieldValue } = await import('firebase-admin/firestore');
    const { field, value } = parseGrantee(grantee);
    await db.doc(ALLOWLIST.join('/')).set(
        { [field]: add ? FieldValue.arrayUnion(value) : FieldValue.arrayRemove(value) },
        { merge: true },
    );
    console.log(`${add ? 'freigeschaltet' : 'Freigabe entzogen'}: ${value}`);
}

async function list(db) {
    const snapshot = await db.doc(ALLOWLIST.join('/')).get();
    const data = snapshot.data() ?? {};
    console.log('E-Mail-Adressen:', (data.emails ?? []).join(', ') || '–');
    console.log('Konto-IDs:', (data.uids ?? []).join(', ') || '–');
}

async function main([command, argument]) {
    switch (command) {
        case 'grant':
            return changeAccess(await firestore(), argument, true);
        case 'revoke':
            return changeAccess(await firestore(), argument, false);
        case 'list':
            return list(await firestore());
        default:
            console.error(
                'Aufruf: lecture_materials.mjs grant <E-Mail|uid:ID> | revoke <E-Mail|uid:ID> | list',
            );
            process.exitCode = 2;
    }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    main(process.argv.slice(2)).catch((e) => {
        // Nur die Meldung, nie Zugangsdaten.
        console.error(`Fehler: ${e instanceof Error ? e.message : String(e)}`);
        process.exitCode = 1;
    });
}
