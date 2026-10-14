// Gemeinsamer, schonender Abruf der UnivIS-PRG-Schnittstelle für die
// Prototyp-Skripte: ein Request, Zeitlimit, erkennbarer User-Agent,
// Zeichensatz aus Content-Type bzw. XML-Deklaration (UnivIS liefert
// teils ISO-8859-1, `Response.text()` würde stets UTF-8 annehmen).

const USER_AGENT =
    'theologie.app-univis-probe/0.1 (+https://www.theologie.app; Machbarkeitstest)';
const TIMEOUT_MS = 20000;

function charsetOf(contentType, bytes) {
    const header = /charset=([\w-]+)/i.exec(contentType ?? '')?.[1];
    if (header) return header;
    const head = Buffer.from(bytes.slice(0, 200)).toString('latin1');
    return /encoding=["']([\w-]+)["']/i.exec(head)?.[1] ?? 'utf-8';
}

function decode(bytes, charset) {
    const label = charset.toLowerCase().replace(/^iso8859/, 'iso-8859');
    try {
        return new TextDecoder(label).decode(bytes);
    } catch {
        return new TextDecoder('utf-8').decode(bytes);
    }
}

/** Sichtbarer Text einer HTML-Antwort (z. B. Fehlermeldung von UnivIS). */
export function htmlText(html) {
    return html
        .replace(/<(script|style)[\s\S]*?<\/\1>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 800);
}

export async function fetchUnivis(url) {
    const started = Date.now();
    const response = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: 'application/xml, text/xml' },
        signal: AbortSignal.timeout(TIMEOUT_MS),
        redirect: 'follow',
    });
    const bytes = new Uint8Array(await response.arrayBuffer());
    const contentType = response.headers.get('content-type');
    const charset = charsetOf(contentType, bytes);
    const body = decode(bytes, charset);
    return {
        ok: response.ok,
        body,
        meta: {
            url: url.toString(),
            status: response.status,
            contentType,
            charset,
            lastModified: response.headers.get('last-modified'),
            etag: response.headers.get('etag'),
            cacheControl: response.headers.get('cache-control'),
            bytes: bytes.length,
            ms: Date.now() - started,
        },
    };
}
