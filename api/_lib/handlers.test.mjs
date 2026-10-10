// Tests der Push-Endpunkte ohne Firebase und ohne Netzwerk:
//   node --test api/_lib/handlers.test.mjs
//
// Die Endpunkte werden dafür wie bei Vercel nach CommonJS übersetzt
// (nach node_modules/.cache, nicht versioniert) und von dort geladen.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createSign, generateKeyPairSync } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'node_modules', '.cache', 'api-test');
const require = createRequire(join(root, 'package.json'));

execFileSync(
    process.execPath,
    [
        require.resolve('typescript/bin/tsc'),
        '--outDir', out,
        '--rootDir', join(root, 'api'),
        '--module', 'commonjs',
        '--moduleResolution', 'node10',
        '--target', 'es2022',
        '--esModuleInterop',
        '--skipLibCheck',
        '--strict',
        '--types', 'node',
        join(root, 'api', 'push-test.ts'),
        join(root, 'api', 'send-reminders.ts'),
    ],
    { stdio: 'inherit' },
);

for (const name of [
    'FIREBASE_SERVICE_ACCOUNT',
    'WEB_PUSH_PUBLIC_KEY',
    'WEB_PUSH_PRIVATE_KEY',
    'CRON_SECRET',
]) {
    delete process.env[name];
}

// Protokollzeilen der Endpunkte gehören nicht in die Testausgabe.
console.error = console.warn = console.log = () => {};

const guard = require(join(out, '_lib', 'guard.js'));
const push = require(join(out, '_lib', 'push.js'));
const pushTest = require(join(out, '_lib', 'push-test.js'));
const idToken = require(join(out, '_lib', 'id-token.js'));
const pushTestEndpoint = require(join(out, 'push-test.js')).default;
const remindersEndpoint = require(join(out, 'send-reminders.js')).default;

/** Ruft einen Endpunkt auf und liefert Status, Antwort und Kopfzeilen. */
async function call(handler, { method = 'POST', authorization } = {}) {
    const result = { status: 200, body: undefined, headers: {} };

    const res = {
        headersSent: false,
        setHeader(key, value) {
            result.headers[key.toLowerCase()] = value;
        },
        status(code) {
            result.status = code;
            return this;
        },
        json(body) {
            result.body = body;
            this.headersSent = true;
            return this;
        },
    };

    await handler({ method, headers: { authorization } }, res);

    return result;
}

function dependencies(overrides = {}) {
    const calls = { allow: [], send: [] };

    return {
        calls,
        deps: {
            authenticate: async (token) => {
                if (token !== 'gueltig') throw new idToken.InvalidTokenError('signature');
                return 'u1';
            },
            allow: async (uid) => {
                calls.allow.push(uid);
                return true;
            },
            send: async (uid) => {
                calls.send.push(uid);
                return { sent: 2, removed: 1, failed: 0 };
            },
            ...overrides,
        },
    };
}

test('Testendpunkt: nur POST', async () => {
    const { deps, calls } = dependencies();
    const handler = pushTest.createHandler(deps);

    for (const method of ['GET', 'HEAD', 'PUT', 'DELETE']) {
        const result = await call(handler, { method, authorization: 'Bearer gueltig' });

        assert.equal(result.status, 405, method);
        assert.equal(result.headers.allow, 'POST');
    }

    assert.deepEqual(calls.send, []);
});

test('Testendpunkt: ohne oder mit ungültigem Token 401, kein Versand', async () => {
    const { deps, calls } = dependencies();
    const handler = pushTest.createHandler(deps);

    assert.equal((await call(handler)).status, 401);
    assert.equal((await call(handler, { authorization: 'gueltig' })).status, 401);
    assert.equal((await call(handler, { authorization: 'Bearer ' + 'x'.repeat(5000) })).status, 401);

    const invalid = await call(handler, { authorization: 'Bearer falsch' });

    assert.equal(invalid.status, 401);
    assert.equal(invalid.body.code, 'signature');
    assert.deepEqual(calls.allow, []);
    assert.deepEqual(calls.send, []);
});

test('Testendpunkt: gültiges Token sendet an das eigene Konto', async () => {
    const { deps, calls } = dependencies();
    const result = await call(pushTest.createHandler(deps), { authorization: 'Bearer gueltig' });

    assert.equal(result.status, 200);
    assert.deepEqual(result.body, { sent: 2, removed: 1, failed: 0 });
    assert.deepEqual(calls.send, ['u1']);
    assert.equal(result.headers['cache-control'], 'no-store');
});

test('Testendpunkt: zu schnell hintereinander 429', async () => {
    const { deps, calls } = dependencies({ allow: async () => false });
    const result = await call(pushTest.createHandler(deps), { authorization: 'Bearer gueltig' });

    assert.equal(result.status, 429);
    assert.deepEqual(calls.send, []);
});

test('Testendpunkt: fehlende Konfiguration 503, andere Fehler 500 mit Schritt', async () => {
    const missing = dependencies({
        authenticate: async () => {
            throw new push.NotConfiguredError('FIREBASE_SERVICE_ACCOUNT ist nicht gesetzt.');
        },
    });

    const notConfigured = await call(pushTest.createHandler(missing.deps), { authorization: 'Bearer gueltig' });

    assert.equal(notConfigured.status, 503);
    assert.equal(notConfigured.body.stage, 'auth');
    assert.equal(notConfigured.body.code, 'not-configured');

    // Kann der Server das Token nicht prüfen (z. B. Schlüssel nicht
    // abrufbar), ist das kein Anmeldefehler des Nutzers.
    const unreachable = dependencies({
        authenticate: async () => {
            throw new Error('Schlüssel nicht abrufbar (Status 503).');
        },
    });

    const authFailed = await call(pushTest.createHandler(unreachable.deps), { authorization: 'Bearer gueltig' });

    assert.equal(authFailed.status, 500);
    assert.equal(authFailed.body.stage, 'auth');

    const denied = dependencies({
        allow: async () => {
            throw Object.assign(new Error('geheime Einzelheiten'), { code: 7 });
        },
    });

    const failed = await call(pushTest.createHandler(denied.deps), { authorization: 'Bearer gueltig' });

    assert.equal(failed.status, 500);
    assert.equal(failed.body.stage, 'firestore');
    assert.equal(failed.body.code, '7');
    assert.ok(!JSON.stringify(failed.body).includes('geheime'));
});

test('ausgelieferte Endpunkte laden und antworten ohne Konfiguration', async () => {
    assert.equal((await call(pushTestEndpoint, { method: 'GET' })).status, 405);
    assert.equal((await call(pushTestEndpoint)).status, 401);

    const unconfigured = await call(pushTestEndpoint, { authorization: 'Bearer irgendein-token' });

    assert.equal(unconfigured.status, 503);
    assert.equal(unconfigured.body.code, 'not-configured');

    assert.equal((await call(remindersEndpoint, { method: 'GET' })).status, 503);

    process.env.CRON_SECRET = 'geheim';

    try {
        assert.equal((await call(remindersEndpoint, { method: 'GET' })).status, 401);
        assert.equal(
            (await call(remindersEndpoint, { method: 'GET', authorization: 'Bearer falsch' })).status,
            401,
        );
    } finally {
        delete process.env.CRON_SECRET;
    }
});

const project = 'theologie-test';
const signer = generateKeyPairSync('rsa', { modulusLength: 2048 });
const stranger = generateKeyPairSync('rsa', { modulusLength: 2048 });
const now = Date.UTC(2026, 9, 10, 12);

const publicKeys = async () => ({
    k1: signer.publicKey.export({ type: 'spki', format: 'pem' }),
});

function token(claims = {}, { key = signer.privateKey, header = {} } = {}) {
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const seconds = now / 1000;

    const head = encode({ alg: 'RS256', kid: 'k1', typ: 'JWT', ...header });
    const body = encode({
        aud: project,
        iss: `https://securetoken.google.com/${project}`,
        sub: 'u1',
        iat: seconds - 60,
        exp: seconds + 3000,
        ...claims,
    });

    const signature = createSign('RSA-SHA256').update(`${head}.${body}`).sign(key, 'base64url');

    return `${head}.${body}.${signature}`;
}

const verify = (value) => idToken.verifyIdToken(value, project, publicKeys, now);

const rejected = (code) => (e) => e instanceof idToken.InvalidTokenError && e.code === code;

test('ID-Token: gültiges Token liefert die Konto-ID', async () => {
    assert.equal(await verify(token()), 'u1');
});

test('ID-Token: Fälschungen und fremde Tokens werden abgelehnt', async () => {
    await assert.rejects(verify('kein-token'), rejected('malformed'));
    await assert.rejects(verify('a.b.c'), rejected('malformed'));
    await assert.rejects(verify(token({}, { key: stranger.privateKey })), rejected('signature'));
    await assert.rejects(verify(token({}, { header: { kid: 'unbekannt' } })), rejected('unknown-key'));
    await assert.rejects(verify(token({}, { header: { kid: 'constructor' } })), rejected('unknown-key'));
    await assert.rejects(verify(token({}, { header: { alg: 'none' } })), rejected('algorithm'));
    await assert.rejects(verify(token({}, { header: { alg: 'HS256' } })), rejected('algorithm'));

    // Nachträglich veränderter Inhalt passt nicht mehr zur Signatur.
    const [head, , signature] = token().split('.');
    const other = token({ sub: 'u2' }, { key: stranger.privateKey }).split('.')[1];

    await assert.rejects(verify(`${head}.${other}.${signature}`), rejected('signature'));

    await assert.rejects(verify(token({ aud: 'anderes-projekt' })), rejected('audience'));
    await assert.rejects(verify(token({ iss: 'https://example.org' })), rejected('issuer'));
    await assert.rejects(verify(token({ exp: now / 1000 - 3600 })), rejected('expired'));
    await assert.rejects(verify(token({ exp: undefined })), rejected('expired'));
    await assert.rejects(verify(token({ iat: now / 1000 + 3600 })), rejected('issued-in-future'));
    await assert.rejects(verify(token({ sub: '' })), rejected('subject'));
    await assert.rejects(verify(token({ sub: 5 })), rejected('subject'));
});

test('Schutzhülle: Ladefehler und Laufzeitfehler werden zu Antworten', async () => {
    const broken = guard.guarded('test', () => {
        throw Object.assign(new Error("Cannot find module 'x'\nRequire stack: …"), {
            code: 'MODULE_NOT_FOUND',
        });
    });

    const load = await call(broken);

    assert.equal(load.status, 500);
    assert.deepEqual(
        { stage: load.body.stage, code: load.body.code, detail: load.body.detail },
        { stage: 'load', code: 'MODULE_NOT_FOUND', detail: "Cannot find module 'x'" },
    );

    const throwing = guard.guarded('test', () => ({
        default: () => {
            throw new TypeError('intern');
        },
    }));

    const run = await call(throwing);

    assert.equal(run.status, 500);
    assert.deepEqual(run.body, { error: 'Interner Fehler.', stage: 'run', code: 'TypeError' });
});

test('Dienstkonto: JSON, Base64, Anführungszeichen und \\n im Schlüssel', () => {
    const account = {
        project_id: 'projekt',
        client_email: 'konto@projekt.iam.gserviceaccount.com',
        private_key: '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
    };

    const expected = {
        projectId: account.project_id,
        clientEmail: account.client_email,
        privateKey: account.private_key,
    };

    const json = JSON.stringify(account);

    assert.deepEqual(push.parseServiceAccount(json), expected);
    assert.deepEqual(push.parseServiceAccount(`  '${json}'  `), expected);
    assert.deepEqual(
        push.parseServiceAccount(Buffer.from(json).toString('base64')),
        expected,
    );

    // Doppelt maskierte Zeilenumbrüche werden zu echten.
    assert.deepEqual(
        push.parseServiceAccount(
            JSON.stringify({ ...account, private_key: account.private_key.replaceAll('\n', '\\n') }),
        ),
        expected,
    );
});

test('Dienstkonto: ungültige Werte nennen nur, was fehlt', () => {
    const isNotConfigured = (pattern) => (e) =>
        e instanceof push.NotConfiguredError && pattern.test(e.message);

    assert.throws(() => push.parseServiceAccount('kein json'), isNotConfigured(/kein gültiges JSON/));
    assert.throws(() => push.parseServiceAccount('{"project_id": "p"'), isNotConfigured(/kein gültiges JSON/));
    assert.throws(() => push.parseServiceAccount('null'), isNotConfigured(/kein gültiges JSON|fehlt/));

    assert.throws(
        () => push.parseServiceAccount(JSON.stringify({ project_id: 'p', client_email: 'e' })),
        (e) => isNotConfigured(/"private_key" fehlt/)(e) && !e.message.includes('"p"'),
    );

    assert.throws(() => push.firestore(), isNotConfigured(/FIREBASE_SERVICE_ACCOUNT ist nicht gesetzt/));
});

test('nur Adressen der Push-Dienste sind erlaubt', () => {
    for (const url of [
        'https://fcm.googleapis.com/fcm/send/abc',
        'https://updates.push.services.mozilla.com/wpush/v2/abc',
        'https://web.push.apple.com/abc',
        'https://db5p.notify.windows.com/w/?token=abc',
    ]) {
        assert.equal(push.isPushEndpoint(url), true, url);
    }

    for (const url of [
        'http://fcm.googleapis.com/fcm/send/abc',
        'https://example.org/fcm.googleapis.com',
        'https://fcm.googleapis.com.example.org/x',
        'https://169.254.169.254/latest/meta-data',
        'kein-url',
        42,
        null,
    ]) {
        assert.equal(push.isPushEndpoint(url), false, String(url));
    }
});

function subscription(id, data, deleted) {
    return {
        get: (field) => data[field],
        ref: { delete: async () => deleted.push(id) },
    };
}

function account(docs) {
    return { collection: () => ({ get: async () => ({ docs }) }) };
}

const message = { title: 'Titel', body: 'Text', link: '/bible', tag: 'test' };

test('Versand: stellt zu, löscht Abgelaufenes und Ungültiges, zählt Fehler', async () => {
    const keys = require('web-push').generateVAPIDKeys();

    process.env.WEB_PUSH_PUBLIC_KEY = keys.publicKey;
    process.env.WEB_PUSH_PRIVATE_KEY = keys.privateKey;

    const { WebPushError } = require('web-push');
    const deleted = [];
    const sentTo = [];

    const valid = { p256dh: 'p', auth: 'a' };

    const docs = [
        subscription('ok', { endpoint: 'https://fcm.googleapis.com/fcm/send/ok', keys: valid }, deleted),
        subscription('abgelaufen', { endpoint: 'https://fcm.googleapis.com/fcm/send/alt', keys: valid }, deleted),
        subscription('gestoert', { endpoint: 'https://web.push.apple.com/kaputt', keys: valid }, deleted),
        subscription('fremd', { endpoint: 'https://example.org/hook', keys: valid }, deleted),
        subscription('ohne-schluessel', { endpoint: 'https://fcm.googleapis.com/fcm/send/x' }, deleted),
    ];

    const send = async (target, payload, options) => {
        sentTo.push({ target, payload: JSON.parse(payload), options });

        if (target.endpoint.endsWith('/alt')) {
            throw new WebPushError('gone', 410, {}, '', target.endpoint);
        }

        if (target.endpoint.endsWith('/kaputt')) {
            throw new WebPushError('server', 500, {}, '', target.endpoint);
        }

        return { statusCode: 201 };
    };

    try {
        const result = await push.sendToUser(account(docs), message, send);

        assert.deepEqual(result, { sent: 1, removed: 3, failed: 1 });
        assert.deepEqual(deleted.sort(), ['abgelaufen', 'fremd', 'ohne-schluessel']);

        // Fremde Adressen werden nie angefragt.
        assert.deepEqual(
            sentTo.map((s) => new URL(s.target.endpoint).hostname).sort(),
            ['fcm.googleapis.com', 'fcm.googleapis.com', 'web.push.apple.com'],
        );

        const [first] = sentTo;

        assert.deepEqual(first.payload, message);
        assert.deepEqual(first.target.keys, valid);
        assert.equal(first.options.vapidDetails.publicKey, keys.publicKey);
        assert.ok(first.options.TTL > 0);
    } finally {
        delete process.env.WEB_PUSH_PUBLIC_KEY;
        delete process.env.WEB_PUSH_PRIVATE_KEY;
    }
});

test('Versand: ohne VAPID-Schlüssel nicht eingerichtet', async () => {
    await assert.rejects(
        () => push.sendToUser(account([]), message, async () => ({})),
        (e) => e instanceof push.NotConfiguredError && /WEB_PUSH_PUBLIC_KEY/.test(e.message),
    );
});
