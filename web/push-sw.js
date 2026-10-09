// Service Worker für Push-Benachrichtigungen (Web Push). Er läuft getrennt
// vom Service Worker von Flutter in einem eigenen Geltungsbereich (`push/`)
// und wird erst registriert, wenn der Nutzer Push einschaltet
// (lib/services/notifications/push_platform_web.dart).
//
// Nachrichten kommen verschlüsselt vom Server (api/_lib/push.ts) als JSON:
//   { title, body, link, tag }

const MESSAGE_TYPE = 'theologie-push-link';

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Nur App-Pfade; alles andere führt zur Startseite.
function appLink(value) {
  return typeof value === 'string' &&
    /^\/[A-Za-z0-9/._-]{0,120}$/.test(value) &&
    !value.startsWith('//')
    ? value
    : '/';
}

self.addEventListener('push', (event) => {
  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }

  const title =
    typeof data.title === 'string' && data.title ? data.title : 'theologie.app';

  // Jede Push-Nachricht muss sichtbar werden – Safari entzieht sonst das
  // Abonnement. Gleicher `tag` ersetzt eine ältere, noch nicht geöffnete
  // Erinnerung.
  event.waitUntil(
    self.registration.showNotification(title, {
      body: typeof data.body === 'string' ? data.body : '',
      tag: typeof data.tag === 'string' ? data.tag : 'theologie-app',
      icon: 'icons/Icon-192.png',
      data: { link: appLink(data.link) },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const link = appLink(event.notification.data && event.notification.data.link);
  const appPath = new URL('./', self.location.href).pathname;

  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });

      // Läuft die App schon, bekommt sie den Link und öffnet den Bereich
      // selbst; sonst startet sie mit dem Link in der Adresse.
      for (const client of windows) {
        const path = new URL(client.url).pathname;

        if (path !== appPath && path !== appPath + 'index.html') continue;

        try {
          await client.focus();
          client.postMessage({ type: MESSAGE_TYPE, link });
          return;
        } catch (_) {
          // Fenster nicht fokussierbar: neues öffnen.
        }
      }

      await self.clients.openWindow('./?open=' + encodeURIComponent(link));
    })(),
  );
});
