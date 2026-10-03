# Security-, Datenschutz- und Production-Readiness-Audit

Stand: 2026-10-03 · Commit-Basis `53f5fd4` · Flutter 3.44.2 · Node 24

> Dieser Bericht beruht auf einer Analyse des Quellcodes, der Git-Historie,
> der Abhängigkeiten und der öffentlich abrufbaren Antworten von
> www.theologie.app. Er ist **keine Rechtsberatung** und keine Garantie für
> Sicherheit oder Rechtskonformität. Punkte mit „OFFEN“ brauchen eine
> Entscheidung oder Prüfung durch den Betreiber.

## Inhalt

- [Architektur und Datenflüsse](#architektur-und-datenflüsse)
- [Übersicht der Funde](#übersicht-der-funde)
- [A. Kritische Sicherheitsprobleme](#a-kritische-sicherheitsprobleme)
- [B. Datenschutz](#b-datenschutz)
- [C. Rechtliches / öffentliche Website](#c-rechtliches--öffentliche-website)
- [D. Firebase](#d-firebase)
- [E. Web-Security](#e-web-security)
- [F. Dependencies](#f-dependencies)
- [G. GitHub / Supply Chain](#g-github--supply-chain)
- [H. Durchgeführte Änderungen](#h-durchgeführte-änderungen)
- [I. Nicht automatisch behobene Punkte](#i-nicht-automatisch-behobene-punkte)
- [J. Tests](#j-tests)
- [K. Restrisiken](#k-restrisiken)
- [Deployment-Checkliste](#deployment-checkliste)

---

## Architektur und Datenflüsse

Nur tatsächlich im Code bzw. im Browser-Test beobachtete Flüsse:

```text
Browser ──HTTPS──▶ Vercel (www.theologie.app)
                    ├─ statische Flutter-Web-App (build/web)
                    └─ /api/greek-noun, /api/greek-verb  ──▶ en.wiktionary.org
                                                           (serverseitig, ohne Nutzer-IP)

Browser ──▶ www.gstatic.com/firebasejs/…     Firebase JS SDK (von FlutterFire nachgeladen)
Browser ──▶ fonts.gstatic.com                Roboto + Noto-Fallback-Schriften (Flutter-Engine)
Browser ──▶ identitytoolkit / securetoken    Firebase Authentication (E-Mail, Google, Telefon, MFA)
Browser ──▶ firestore.googleapis.com         Cloud Firestore (Lerndaten, Nachrichten, Meldungen)
Browser ──▶ www.google.com/recaptcha         nur bei Telefon-Login / SMS-MFA
Browser ──▶ localStorage / IndexedDB         Gastdaten, Einstellungen, Auth-Sitzung
```

Nicht vorhanden (geprüft): Analytics/Tracking (kein `firebase_analytics`;
die ungenutzte `measurementId` wurde aus `firebase_options.dart` entfernt), Crash
Reporting, Cookies der App, Push (FCM nur vorbereitet), Datei-Uploads,
Firebase Storage, Cloud Functions, WebViews (Pakete waren eingebunden, aber
ungenutzt – entfernt), HTML-/Markdown-Rendering von Nutzerinhalten.

### Gespeicherte Daten (Firestore)

| Pfad | Inhalt | Zugriff | Löschung |
|---|---|---|---|
| `users/{uid}` | `vocabulary_settings`, `latin_vocabulary_settings`, `greek_grammar_settings`, `notification_settings` (inkl. `utcOffsetMinutes`) | nur Nutzer | Kontolöschung |
| `users/{uid}/vocabulary`, `learning_cards`, `latin_vocabulary`, `grammar` | SRS-Werte, `lastReviewed`, **Merkhilfe (Freitext)** | nur Nutzer | Reset / Kontolöschung |
| `users/{uid}/quiz_settings`, `pericope_overrides` | Buchauswahl, Overrides | nur Nutzer | Kontolöschung |
| `users/{uid}/statistics/{trainer}` | Tageszähler je Datum (unbegrenzt wachsend) | nur Nutzer | Kontolöschung |
| `users/{uid}/streaks/{track}` | Streak-Zustand | nur Nutzer | Kontolöschung |
| `users/{uid}/notification_state/inbox` | Lesestatus | nur Nutzer | Kontolöschung |
| `users/{uid}/push_tokens/{token}` | vorbereitet, derzeit ungenutzt | nur Nutzer | Kontolöschung |
| `users/{uid}/inbox/{id}` | persönliche Nachrichten (Server) | Nutzer lesen/löschen | Kontolöschung |
| `notifications/{id}` | globale Nachrichten | alle lesen, niemand schreiben | Console |
| `reports/{id}` | Meldungen ohne Kontobezug | nur anlegen | **keine Frist (OFFEN)** |

Datenminimierung: Die Modelle speichern keine Klarnamen o. ä. in Firestore;
Meldungen enthalten bewusst keine UID. Lokal wird unter
`guest.transferDeclinedFor` eine Liste von UIDs gespeichert (nur im Browser,
vertretbar). Die Tagesstatistik wächst unbegrenzt – optional später auf z. B.
365 Tage begrenzen (NIEDRIG).

---

## Übersicht der Funde

| # | Prio | Fund | Status |
|---|---|---|---|
| 1 | HOCH | Keine Kontolöschung (Art. 17 DSGVO); Firestore-Daten blieben bestehen | **behoben** |
| 2 | HOCH | Kein Impressum, keine Datenschutzhinweise | **Seiten angelegt, Betreiberangaben OFFEN** |
| 3 | HOCH | Wahrscheinlich urheberrechtlich geschützte Liedtexte (132 Lieder) | **OFFEN** (nichts entfernt) |
| 4 | HOCH | Google Fonts + Firebase SDK + (bisher) CanvasKit von Google-CDNs ohne Hinweis | CanvasKit lokal **behoben**; Fonts/SDK dokumentiert, **OFFEN** |
| 5 | MITTEL | Keine Security-Header (außer HSTS) auf der Live-Seite | **behoben** (`vercel.json`) |
| 6 | MITTEL | Firestore-Regeln: beliebige Subcollections und Felder in `users/{uid}` schreibbar | **behoben** (Regeln müssen manuell deployed werden) |
| 7 | MITTEL | Öffentliche API ohne Eingabelimits/Timeout | **behoben** |
| 8 | MITTEL | Report-Spam: kein serverseitiges Rate-Limit, App Check inaktiv | **OFFEN** (s. D) |
| 9 | MITTEL | `node_modules/` (4024 Dateien) im Git-Repository | **behoben** (aus Index entfernt) |
| 10 | MITTEL | Merkhilfen aller Vokabeln per `print` in die Browser-Konsole | **behoben** |
| 11 | MITTEL | Prod-Abhängigkeit `undici` (über `cheerio`) mit bekannter Lücke | **behoben** (`npm audit fix`) |
| 12 | MITTEL | Native Builds (Android/iOS) kompilieren nicht (`dart:js_interop` in Trainern); Android-Release ohne INTERNET-Permission, Debug-Signing, `com.example`-ID | **OFFEN** (nur Web betroffen ist produktiv) |
| 13 | NIEDRIG | Rohe Firebase-Meldungen / „(Debug: …)“ in der UI | **behoben** |
| 14 | NIEDRIG | 5 ungenutzte Pakete inkl. WebView und `flutter_html` | **entfernt** |
| 15 | NIEDRIG | Kein `SECURITY.md`, kein Dependency-Monitoring | **behoben** |
| 16 | NIEDRIG | SEO/Meta: kein `lang`, keine OG-Tags, kein `robots.txt` | **behoben** |
| 17 | NIEDRIG | UI-Texte des Frameworks englisch („Back“, „2000 characters remaining“) – fehlende Lokalisierung, auch für Screenreader | OFFEN |
| 18 | NIEDRIG | Passwort wird bei Login/Registrierung `trim()`-t, beim Ändern nicht | OFFEN (Änderung könnte bestehende Konten aussperren) |
| 19 | OFFEN | Projektlizenz fehlt (kein `LICENSE`) | Entscheidung Betreiber |

Keine echten Secrets gefunden – weder im aktuellen Stand noch in der
Git-Historie (geprüft: alle jemals hinzugefügten Dateien, u. a. die
gelöschten `dev_data/server.py` und `api/wiktionary.ts`, sowie Muster für
API-Keys, Tokens, private Schlüssel). `.env.local` (enthält ein
`VERCEL_OIDC_TOKEN`) und `.vercel/` sind korrekt ignoriert und nie
committet worden.

---

## A. Kritische Sicherheitsprobleme

**Es wurde kein kritisches Problem** (Accountübernahme, Fremdzugriff,
Secret-Leak, Datenverlust) gefunden. Die Firestore-Regeln isolierten
Nutzerdaten bereits korrekt per `request.auth.uid == uid`.

---

## B. Datenschutz

### Drittanbieter

| Dienst | Zweck | Daten | Notwendig | Drittland |
|---|---|---|---|---|
| Vercel Inc. | Hosting, API | IP, Request-Daten (Logs) | ja | USA – Garantien prüfen (OFFEN) |
| Google Firebase Auth | Konten, MFA, SMS | E-Mail, Telefon, Google-Profil, IP | ja (für Konten) | USA möglich – prüfen |
| Google Cloud Firestore | Lerndaten, Meldungen | s. Tabelle oben | ja | Region in Console prüfen (OFFEN) |
| Google reCAPTCHA | SMS-Missbrauchsschutz | Browser-/Geräte-Signale, IP | nur Telefon-Login/SMS-MFA | USA |
| Google Fonts (fonts.gstatic.com) | Schriften der Flutter-Engine | IP | technisch vermeidbar | USA |
| Google CDN (www.gstatic.com) | Firebase JS SDK | IP | technisch vermeidbar | USA |
| Wikimedia (Wiktionary) | Flexionstabellen | Wort + Form, **ohne** Nutzer-IP (serverseitig) | ja | USA |
| GitHub | nur Link | erst beim Klick | – | – |

Offene Datenschutzpunkte:

1. **Schriften von fonts.gstatic.com** (LG München I, Urt. v. 20.01.2022 –
   3 O 17493/20 betraf dynamisch eingebundene Google Fonts). Abhilfe-Optionen:
   (a) Schriften als Assets bündeln und `fontFallbackBaseUrl` in
   `web/flutter_bootstrap.js` auf einen eigenen Pfad setzen – erfordert,
   alle benötigten Noto-Dateien in der Pfadstruktur von fonts.gstatic.com
   bereitzustellen und gründlich zu testen (griechische Polytonik!);
   (b) rechtlich bewerten lassen und in der Datenschutzerklärung belassen.
   Nicht automatisch umgesetzt, weil eine falsche Konfiguration griechische
   Zeichen unlesbar machen würde.
2. **Firebase JS SDK von www.gstatic.com**: wird von FlutterFire zur
   Laufzeit geladen. Selbsthosting ist möglich (FlutterFire-Option bzw.
   eigene Kopie), aber ein Eingriff in den Build – OFFEN.
3. **Auftragsverarbeitung**: Firebase-Datenverarbeitungsbedingungen in der
   Console akzeptieren, Vercel-DPA prüfen.
4. **Aufbewahrung von Meldungen** festlegen (z. B. Löschung nach
   Bearbeitung) – derzeit unbegrenzt.
5. **Datenexport (Art. 20)** ist nicht als Funktion vorhanden; Auskunft/Export
   ist derzeit nur auf Anfrage (manuell über die Console) möglich.

### Kontolöschung (neu)

`Einstellungen → Konto & Sicherheit → Konto löschen`:

1. Bestätigungsdialog.
2. Erneute Anmeldung (Passwort bzw. Google, ggf. zweiter Faktor). Reine
   Telefon-Konten müssen sich innerhalb der letzten 4 Minuten angemeldet
   haben, sonst wird um Ab-/Anmeldung gebeten (Firebase verlangt eine
   kürzliche Anmeldung; vorher werden keine Daten gelöscht).
3. Löschen aller Subcollections und des `users/{uid}`-Dokuments
   (`AccountDeletionService`), danach `user.delete()`.
4. Scheitert nur der letzte Schritt, wird das klar gemeldet.

Grenze: Clientseitige Löschung. Robuster wäre die Firebase-Extension
„Delete User Data“ bzw. eine Cloud Function auf `auth.user().onDelete`
(benötigt Blaze-Tarif) – empfohlen, sobald ein Backend existiert.

---

## C. Rechtliches / öffentliche Website

| Thema | Status |
|---|---|
| Impressum | `web/impressum.html` – auf § 18 Abs. 1 MStV reduziert; **Platzhalter für Name, Anschrift, E-Mail** |
| Datenschutz | `web/datenschutz.html` – aus den realen Datenflüssen abgeleitet, ohne Platzhalter (Verantwortlicher per Verweis aufs Impressum) |
| Erreichbarkeit | Login-Screen (Fußzeile), „Über die App → Rechtliches“, `<noscript>` in `index.html`; Seiten funktionieren ohne JavaScript |
| Kontakt | nur Platzhalter (OFFEN) |
| KI-Transparenz | bereits in „Über die App“ vorhanden; im Impressum ergänzt |
| Quellen | bereits pro Bereich (`AppModules`) – ohne erfundene Quellen |
| Open-Source-Lizenzen | neu: „Über die App → Rechtliches → Open-Source-Lizenzen“ (Flutter-Lizenzseite) |
| Projektlizenz | fehlt – OFFEN |
| Nutzungsbedingungen | nicht vorhanden; ob nötig, entscheidet der Betreiber (OFFEN) |
| Impressumspflicht | hängt u. a. von Geschäftsmäßigkeit / redaktionellem Charakter ab (§ 5 DDG, § 18 MStV) – OFFEN |

**Urheberrecht der Inhalte** – Details und vollständige Liste:
[`docs/content-rights-review.md`](content-rights-review.md).

- 132 von 535 Liedern zeigen einen Liedtext und nennen eine Textangabe ab
  1900 (z. B. Henkys 1981, Trautwein 1963, Schulz 1975). Solche Texte sind
  wahrscheinlich noch geschützt (70 Jahre nach Tod). **Vor öffentlichem
  Betrieb einzeln prüfen**; die App kann Texte bereits ausblenden
  (leere `lyrics`).
- Wochensprüche/Perikopenüberschriften: Übersetzung bzw. Ausgabe nicht
  dokumentiert (moderne Übersetzungen geschützt).
- Liederklärungen/Schlagworte: Herkunft (ggf. KI) nicht dokumentiert.
- Wiktionary-Formen: CC BY-SA 4.0 ist in der App angegeben; einzelne
  Wortformen sind i. d. R. nicht schutzfähig, die Attribution ist trotzdem
  sinnvoll.

---

## D. Firebase

### Authentication

- Methoden: E-Mail/Passwort (mit Pflicht zur E-Mail-Bestätigung im
  `AuthGate`), Google, Telefon, MFA per SMS und TOTP. Solide umgesetzt
  (Reauth vor sensiblen Aktionen, Timeouts für reCAPTCHA).
- Enumeration: „Passwort vergessen“ behandelt unbekannte Adressen wie
  Erfolg ✓. Registrierung meldet „E-Mail bereits registriert“ – das ist bei
  Registrierungen kaum vermeidbar. In der Firebase Console
  **„E-Mail-Aufzählungsschutz“** aktiviert lassen/aktivieren (OFFEN, nur in
  der Console prüfbar).
- Passwortrichtlinie: In der Console (Authentication → Einstellungen →
  Passwortrichtlinie) Mindestlänge setzen, z. B. 10 Zeichen (OFFEN).
- SMS-Kosten/Missbrauch: In der Console SMS-Regionen auf benötigte Länder
  beschränken (Schutz vor SMS-Pumping) – OFFEN.
- `signInAnonymously` existiert im Service, wird aber nicht aufgerufen.

### Firestore Rules (geändert, `firestore.rules`)

Vorher: Eigentümer durfte unter `users/{uid}` **beliebige** Subcollections
in beliebiger Tiefe und beliebige Felder anlegen (Speicher-/Kostenmissbrauch,
unkontrolliertes Datenmodell).

Nachher:

- nur die 10 im Code verwendeten Subcollections, eine Ebene tief,
- im `users/{uid}`-Dokument dürfen nur die 4 bekannten Einstellungsfelder
  **geändert** werden (Prüfung über `diff().affectedKeys()`, damit ältere,
  bereits vorhandene Felder bestehende Dokumente nicht sperren),
- `inbox`: Nutzer darf lesen **und löschen** (für Kontolöschung), nicht
  anlegen/ändern,
- `reports`, `notifications`: unverändert (waren bereits restriktiv).

Ein Test (`test/account_deletion_test.dart`) prüft, dass Regeln,
Kontolöschung und Gastdaten-Übernahme dieselben Collections/Felder kennen.

> **Wichtig:** Das Projekt hat kein `firebase.json`; die Regeln müssen
> **manuell** in der Firebase Console eingetragen werden. Vorher im
> **Rules Playground** prüfen (lesen/schreiben eigener Daten, fremde UID,
> unbekannte Collection, Feld `isAdmin` im User-Dokument). Ein Emulator-Test
> war hier nicht möglich (keine Java-Laufzeit installiert).

Nicht über Regeln lösbar: Wertebereiche/Typen innerhalb der
Einstellungs-Maps und Größe der Lernkarten-Dokumente werden nicht validiert.
Ein Nutzer kann nur seine **eigenen** Daten beschädigen; Risiko gering.

### App Check

- Paket eingebunden, `AppCheckService.activate()` wird **nicht** aufgerufen;
  der eingetragene reCAPTCHA-v3-Site-Key ist öffentlich (kein Secret).
- Empfehlung (OFFEN, nicht automatisch, weil Auswirkungen auf alle Nutzer):
  1. Site-Key in der Console verifizieren, `activate()` in `main.dart`
     aufrufen, deployen,
  2. in der Console einige Tage im **Monitoring** die Metriken ansehen
     (verifizierte vs. unverifizierte Anfragen),
  3. erst dann **Enforcement** für Firestore (und Auth) aktivieren.
  Danach ist Report-Spam per Skript deutlich erschwert. Achtung: reCAPTCHA v3
  lädt dann auf jeder Seite Google-Skripte → Datenschutzerklärung anpassen;
  CSP um `https://www.google.com` (bereits enthalten) prüfen.

### Storage

Firebase Storage wird nicht verwendet; Uploads gibt es nicht (gut so).

---

## E. Web-Security

| Thema | Ergebnis |
|---|---|
| XSS | Kein HTML-Rendering von Daten (Flutter rendert Text in Canvas; `flutter_html` war ungenutzt und ist entfernt). Kein `innerHTML`. JS-Interop nur für Tastatur-Listener. |
| Injection | Firestore-Pfade nur aus festen Namen + UID/Karten-IDs aus Assets. API: Lemma wird mit `encodeURIComponent` an eine feste Wiktionary-URL gehängt → kein SSRF. |
| Open Redirect / URL Launcher | Externe Ziele sind Konstanten oder Deep Links aus `notifications` (nur Admin schreibbar; `AppDeepLink.parse` erlaubt nur bekannte App-Pfade oder `https:`). Kein `javascript:`/Datei-Schema möglich. |
| WebView | nicht verwendet; Pakete entfernt. |
| Security-Header | neu in `vercel.json`: `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `X-Frame-Options: DENY`, `COOP: same-origin-allow-popups` (Google-Popup-Login bleibt funktionsfähig), CSP. HSTS setzt Vercel bereits (`max-age=63072000`); `includeSubDomains`/`preload` bewusst nicht gesetzt (Entscheidung Betreiber). |
| CSP | **Erzwungen** nur risikofrei: `frame-ancestors 'none'; object-src 'none'; base-uri 'self'`. Vollständige Policy als **`Content-Security-Policy-Report-Only`**. Browser-Test: einzige Meldungen sind 4 Inline-Skripte, die FlutterFire zum Laden des Firebase-SDK einfügt. Eine erzwungene `script-src` bräuchte deren Hashes (ändern sich mit jedem FlutterFire-Update) oder `'unsafe-inline'`. Vor dem Erzwingen in Produktion die Konsole bei Login (E-Mail, Google, Telefon) prüfen. |
| CORS | `/api/*` liefert `Access-Control-Allow-Origin: *` für **öffentliche, unauthentifizierte, nur lesende** GET-Endpunkte ohne Cookies – bewusst beibehalten (Einschränkung würde lokale Entwicklung/Vorschau-Deployments brechen und brächte keinen Schutz). Vercel setzt `*` auch für statische Dateien – unkritisch. |
| API-Missbrauch | neu: Längenlimits (Lemma ≤ 64, sonstige ≤ 32 Zeichen), keine Steuerzeichen, 8-s-Timeout zum Upstream. Weiterhin kein Rate-Limit: Ein Angreifer kann die Funktion mit wechselnden Wörtern aufrufen (Kosten auf Vercel, Last auf Wiktionary). Abhilfe bei Bedarf: Vercel Firewall/Rate-Limit-Regel für `/api/` (OFFEN). |
| Fehlerseiten | 404 ist Vercels Standardseite (ohne Interna). API gibt generische Fehlermeldungen zurück. |
| Service Worker / Cache | Flutters Service Worker deregistriert sich selbst (kein Offline-Cache). Nutzerdaten werden nicht per HTTP gecacht; nur erfolgreiche API-Antworten (öffentliche Wortformen) im CDN. |
| Externe Ressourcen | CanvasKit jetzt lokal (`web/flutter_bootstrap.js`); Fonts/SDK siehe B. |

---

## F. Dependencies

`flutter pub outdated`: Firebase-Pakete und weitere einige Minor-Versionen
zurück (z. B. `cloud_firestore` 6.6.0 → 6.10.0, `firebase_auth` 6.5.4 →
6.7.0). **Nicht aktualisiert** – kein bekannter Sicherheitsbezug; ein Update
sollte gemeinsam mit einem manuellen Login-Test (E-Mail, Google, Telefon,
MFA) erfolgen. Für Dart-Pakete gibt es kein `pub audit`; Dependabot
(neu) meldet Updates.

Entfernt (nirgends importiert): `webview_flutter`, `webview_flutter_web`,
`flutter_html`, `html`, `csv` – inklusive 5 transitiver Pakete.

npm:

- Produktion: `cheerio` → `undici` 7.29.0 mit bekannter Lücke →
  `npm audit fix` → 7.30.0, **0 Schwachstellen** (`npm audit --omit=dev`).
- Entwicklung: `@vercel/node@6` bringt `undici@5.28.4` mit 5 gemeldeten
  Schwachstellen. Nur für Typdefinitionen genutzt (`import type`), läuft
  nicht in Produktion. Der vorgeschlagene „Fix“ (`--force`) wäre ein
  Downgrade auf `@vercel/node@3` – **nicht** ausgeführt. Option: auf ein
  neueres `@vercel/node` warten oder durch `@vercel/node`-freie Typen
  ersetzen.

---

## G. GitHub / Supply Chain

- **`node_modules/` war versioniert** (4024 Dateien) – aus dem Index
  entfernt (`git rm --cached`, Dateien lokal unverändert) und in
  `.gitignore` aufgenommen. Die Dateien bleiben in der Historie (kein
  History-Rewrite; enthalten keine Secrets).
- Keine GitHub Actions, keine npm-Install-Skripte im Projekt, keine
  Downloads im Build. `package.json` hat keine `scripts`.
- Neu: `SECURITY.md` (private Meldung über GitHub), `.github/dependabot.yml`
  (pub + npm, wöchentlich).
- Empfohlen in den Repository-Einstellungen (OFFEN): Secret Scanning +
  Push Protection, Private Vulnerability Reporting, Branch Protection für
  `main`.
- Firebase-Web-Konfiguration (`lib/firebase_options.dart`) ist öffentlich
  und **kein Secret**. Empfohlen: in der Google Cloud Console den Browser-
  API-Key auf HTTP-Referrer `www.theologie.app/*`, `theologie.app/*`,
  `localhost` und die benötigten APIs (Identity Toolkit, Token Service,
  Firestore, ggf. App Check) beschränken – vorher testen (OFFEN).

---

## H. Durchgeführte Änderungen

| Datei | Änderung |
|---|---|
| `firestore.rules` | Subcollection-Whitelist, Feld-Whitelist (geänderte Felder) für `users/{uid}`, `inbox` löschbar durch Eigentümer |
| `vercel.json` (neu) | Security-Header, minimale erzwungene CSP + Report-Only-CSP |
| `web/flutter_bootstrap.js` (neu) | CanvasKit aus eigenem Build statt Google-CDN |
| `web/impressum.html`, `web/datenschutz.html`, `web/legal.css` (neu) | Rechtsseiten mit Platzhaltern |
| `web/robots.txt` (neu) | Indexierung erlaubt, `/api/` ausgeschlossen |
| `web/index.html` | `lang="de"`, Beschreibung, Open-Graph, Canonical, `<noscript>` mit Rechtslinks |
| `lib/widgets/legal_links.dart` (neu), `login_screen.dart`, `about_screen.dart`, `app_info.dart` | Links zu Impressum/Datenschutz, Open-Source-Lizenzen |
| `lib/services/account_deletion_service.dart` (neu), `account_security_screen.dart` | Kontolöschung |
| `lib/screens/greek/vocabulary_trainer_screen.dart` | `print` von Merkhilfen und Debug-Ausgabe entfernt |
| `lib/services/auth_error_translator.dart` | keine rohen Firebase-Meldungen; Diagnose-Logs nur in Debug-Builds; UI zeigt nur den Fehlercode |
| `lib/screens/greek/grammar_trainer_screen.dart` | verständliche Meldung statt `e.toString()` beim Laden |
| `api/greek-noun.ts`, `api/greek-verb.ts` | Eingabelimits, Upstream-Timeout |
| `pubspec.yaml`, `pubspec.lock` | 5 ungenutzte Pakete entfernt |
| `package-lock.json` | `undici` 7.29.0 → 7.30.0 |
| `.gitignore`, Git-Index | `node_modules/` nicht mehr versioniert |
| `SECURITY.md`, `.github/dependabot.yml` (neu) | Meldeweg, Dependency-Monitoring |
| `test/account_deletion_test.dart` (neu) | Konsistenz Regeln ↔ Code |
| `docs/security-audit.md`, `docs/content-rights-review.md` (neu) | dieser Bericht, Prüfliste Inhalte |

---

## I. Nicht automatisch behobene Punkte

Betreiberangaben / Recht:

- Impressum und Datenschutz ausfüllen (alle gelb markierten Stellen) und
  rechtlich prüfen lassen; danach die Entwurfshinweise entfernen.
- Urheberrecht der Liedtexte, Wochensprüche, Perikopenüberschriften,
  Übersetzungen (siehe `content-rights-review.md`).
- Projektlizenz festlegen (`LICENSE`).
- Rechtsgrundlagen, Auftragsverarbeitung (Google, Vercel),
  Drittlandübermittlung, Aufbewahrungsfristen (Meldungen, Logs).
- Google Fonts / Firebase-SDK-CDN: selbst hosten oder rechtlich bewerten.

Konfiguration in Konsolen (nicht im Repo):

- Firestore-Regeln deployen (manuell) und im Rules Playground prüfen.
- Firebase Auth: E-Mail-Aufzählungsschutz, Passwortrichtlinie,
  SMS-Regionen.
- App Check: Monitoring → Enforcement (siehe D).
- API-Key-Beschränkungen in der Google Cloud Console.
- Vercel: Rate-Limit/Firewall für `/api/`, Log-Aufbewahrung prüfen,
  Preview-Deployments ggf. mit Deployment Protection schützen.
- GitHub: Secret Scanning, Push Protection, Branch Protection,
  Private Vulnerability Reporting.

Technik (bewusst nicht angefasst, Risiko für bestehende Funktion):

- Native Builds: `dart:js_interop`/`package:web` in den Trainern verhindert
  Android/iOS-Builds und den `widget_test`; Android-Release ohne
  `INTERNET`-Permission, Debug-Signatur, `applicationId com.example…`.
  Vor einer Store-Veröffentlichung beheben (bedingter Import).
- Report-Rate-Limit nur clientseitig (30 s) – serverseitig erst mit App
  Check oder Backend möglich.
- Lokalisierung (`flutter_localizations`, `locale: de`) für deutsche
  Framework-Texte und Screenreader.
- Passwort-`trim()` vereinheitlichen (Migration nötig).
- Datenexport-Funktion (Art. 20).
- Firebase-Pakete aktualisieren (mit manuellem Login-Test).

---

## J. Tests

```text
flutter analyze:  7 Hinweise (5 info, 2 warning) – alle vorbestehend, keiner in
                  geänderten Zeilen; die zuvor gemeldeten avoid_print-Stellen
                  sind entfernt.
flutter test:     160 bestanden, 1 fehlgeschlagen – test/widget_test.dart kann
                  main.dart in der VM nicht laden (dart:js_interop); bestand
                  bereits vor dem Audit.
flutter build web: erfolgreich (nach `flutter clean`, da der alte
                  Plugin-Registrant noch die entfernten WebView-Pakete
                  referenzierte).
npm audit --omit=dev: 0 vulnerabilities
npm audit (inkl. dev): 5 (2 moderate, 3 high) – nur @vercel/node → undici 5.x,
                  devDependency, siehe F.
tsc --noEmit --strict (api/*.ts): fehlerfrei
```

API lokal (Handler mit echten Wiktionary-Abrufen): gültige Nomen-/Verbform
200, zu langes Lemma 400, Steuerzeichen 400, fehlende Parameter 400, POST
405, Person 9 → 400.

Browser-Smoke-Test (Chrome headless, `build/web` lokal mit den Headern aus
`vercel.json`):

| Bereich | Ergebnis |
|---|---|
| Startseite/Login, Links Impressum/Datenschutz | ✓ |
| Gastmodus, Startseite | ✓ |
| Perikopenquiz, Griechisch (Vokabel-, Grammatiktrainer inkl. API), Latein-Vokabeltrainer | ✓ öffnen, keine Exceptions |
| Bekenntnisse, Gebete, Gesangbuch, Kalender | ✓ |
| Einstellungen, Über die App, Rechtliches, Open-Source-Lizenzen | ✓ |
| Meldeformular öffnen, leere Eingabe (Validierung), abbrechen | ✓ (nichts gesendet) |
| `impressum.html`, `datenschutz.html` (auch ohne JS, kein horizontales Scrollen), `robots.txt` | ✓ |
| CSP Report-Only | nur FlutterFire-Inline-Skripte |
| Externe Hosts | fonts.gstatic.com, www.gstatic.com (Firebase SDK), firestore.googleapis.com, www.theologie.app/api – **kein** CanvasKit-CDN mehr |

**Nicht getestet** (benötigt echte Konten bzw. würde Produktionsdaten
verändern): Registrierung, Login (E-Mail/Google/Telefon/MFA), Logout,
Passwort zurücksetzen, **Kontolöschung**, Schreiben/Lesen eigener
Firestore-Daten, Absenden einer Meldung, die neuen Firestore-Regeln.
Diese Abläufe bitte nach dem Deployment mit einem Testkonto prüfen (siehe
Checkliste).

---

## K. Restrisiken

- Die neuen Firestore-Regeln sind nur per Review und Konsistenztest
  geprüft, nicht im Emulator.
- Die Kontolöschung ist nicht end-to-end getestet.
- Die Report-Only-CSP schützt nicht; die erzwungene CSP deckt nur Framing,
  Plugins und `<base>` ab.
- Öffentliche Endpunkte (Reports, API) sind ohne App Check/Rate-Limit
  automatisiert aufrufbar (Spam, Kosten).
- Urheberrechtliche Lage der Inhalte ist ungeklärt.
- Datenschutzerklärung ist ein Entwurf; Rechtsgrundlagen und
  Drittlandfragen sind nicht bewertet.
- KI-generierter Code wurde stichprobenartig, nicht Zeile für Zeile über
  alle ~23 600 Zeilen, geprüft; Schwerpunkt lag auf Auth, Datenzugriff,
  Eingaben, externen Aufrufen und Logging.

---

## Deployment-Checkliste

1. Platzhalter in `web/impressum.html` und `web/datenschutz.html` ausfüllen.
2. `flutter build web --release` (bei Problemen vorher `flutter clean`).
3. Deployen (Vercel liest `vercel.json` automatisch).
4. Header prüfen: `curl -sI https://www.theologie.app/`.
5. `firestore.rules` in der Firebase Console eintragen (vorher Rules
   Playground).
6. Mit einem Testkonto: Registrierung, E-Mail-Bestätigung, Login (E-Mail,
   Google, Telefon), MFA, Passwort zurücksetzen, Lernen in allen Trainern,
   Statistik, Einstellungen, Glocke, Meldung absenden, **Konto löschen**
   (danach in der Console prüfen, dass `users/{uid}` weg ist).
7. Browser-Konsole auf `Content-Security-Policy-Report-Only`-Meldungen
   prüfen (v. a. beim Google- und Telefon-Login).
