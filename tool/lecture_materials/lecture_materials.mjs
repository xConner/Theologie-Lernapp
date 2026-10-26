#!/usr/bin/env node
// Verwaltung der geschützten Vorlesungsunterlagen (docs/lecture-materials.md).
//
//   node tool/lecture_materials/lecture_materials.mjs upload [Verzeichnis]
//   node tool/lecture_materials/lecture_materials.mjs grant  <E-Mail|uid:KONTO-ID>
//   node tool/lecture_materials/lecture_materials.mjs revoke <E-Mail|uid:KONTO-ID>
//   node tool/lecture_materials/lecture_materials.mjs list
//
// upload: lädt alle Dateien aus dem Verzeichnis (Standard: lecture_materials/
// im Repository, nicht versioniert) nach Firestore lecture_materials/{Datei},
// schreibt lecture_materials/manifest und löscht Dokumente nicht mehr
// vorhandener Dateien.
// grant/revoke/list: Freigabeliste lecture_access/allowlist.
//
// Zugang: Dienstkonto des Firebase-Projekts (Admin SDK, umgeht die Security
// Rules) – als Pfad in GOOGLE_APPLICATION_CREDENTIALS oder als JSON (roh oder
// Base64) in FIREBASE_SERVICE_ACCOUNT, wie bei den Vercel-Funktionen. Der
// Schlüssel wird nie ausgegeben.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

export const COLLECTION = 'lecture_materials';
export const ALLOWLIST = ['lecture_access', 'allowlist'];

/** Größte Datei je Dokument (Firestore erlaubt knapp 1 MiB je Dokument). */
export const MAX_FILE_BYTES = 900 * 1024;

/** Dokument-ID einer Datei: Pfad mit „~“ statt „/“ (wie in der App). */
export function documentId(path) {
    if (path === 'manifest' || path.includes('~') || path.startsWith('/')) {
        throw new Error(`Ungültiger Dateipfad: ${path}`);
    }
    return path.split('/').join('~');
}

/** Alle Dateien unter [dir], als Pfade mit „/“, sortiert. */
export function collectFiles(dir) {
    const files = [];
    const walk = (current) => {
        for (const name of readdirSync(current)) {
            if (name.startsWith('.')) continue;
            const full = join(current, name);
            if (statSync(full).isDirectory()) walk(full);
            else files.push(relative(dir, full).split(sep).join('/'));
        }
    };
    walk(dir);
    return files.sort();
}

export function contentType(path) {
    const ext = path.slice(path.lastIndexOf('.') + 1).toLowerCase();
    return (
        {
            json: 'application/json',
            png: 'image/png',
            jpg: 'image/jpeg',
            jpeg: 'image/jpeg',
            webp: 'image/webp',
            pdf: 'application/pdf',
        }[ext] ?? 'application/octet-stream'
    );
}

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

async function upload(db, dir) {
    const files = collectFiles(dir);
    if (files.length === 0) throw new Error(`Keine Dateien in ${dir}`);

    for (const path of files) {
        const size = statSync(join(dir, path)).size;
        if (size > MAX_FILE_BYTES) {
            throw new Error(`${path} ist zu groß (${size} Bytes, höchstens ${MAX_FILE_BYTES}).`);
        }
    }

    const collection = db.collection(COLLECTION);
    for (const path of files) {
        await collection.doc(documentId(path)).set({
            path,
            contentType: contentType(path),
            data: readFileSync(join(dir, path)),
        });
        console.log(`hochgeladen: ${path}`);
    }

    // Manifest zuletzt: Erst damit gelten neue Dateien als vorhanden.
    await collection.doc('manifest').set({ files, updatedAt: new Date() });

    const keep = new Set([...files.map(documentId), 'manifest']);
    const existing = await collection.listDocuments();
    for (const ref of existing) {
        if (!keep.has(ref.id)) {
            await ref.delete();
            console.log(`entfernt: ${ref.id}`);
        }
    }

    console.log(`${files.length} Dateien, Manifest aktualisiert.`);
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
    const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
    switch (command) {
        case 'upload':
            return upload(await firestore(), resolve(argument ?? join(root, 'lecture_materials')));
        case 'grant':
            return changeAccess(await firestore(), argument, true);
        case 'revoke':
            return changeAccess(await firestore(), argument, false);
        case 'list':
            return list(await firestore());
        default:
            console.error(
                'Aufruf: lecture_materials.mjs upload [Verzeichnis] | grant <E-Mail|uid:ID> | revoke <E-Mail|uid:ID> | list',
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
