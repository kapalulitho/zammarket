// ZamNexus service worker: keeps the app fast and usable on flaky
// connections, and makes it installable as an app on phones and desktops.
// Strategy:
//  - Cross-origin requests (Supabase database, storage) are never cached.
//  - Page navigations: network first, so new deploys arrive immediately;
//    the cached copy keeps the app open when the network drops.
//  - Static assets (hashed JS/CSS, images): cache first, filled as seen.
const VERSION = 'zamnexus-v1';
const CORE = ['/', '/site.webmanifest', '/icon-192.png', '/icon-512.png', '/favicon.svg'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(VERSION).then(cache => cache.addAll(CORE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== VERSION).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).then(response => {
        const copy = response.clone();
        caches.open(VERSION).then(cache => cache.put('/index.html', copy));
        return response;
      }).catch(() => caches.match('/index.html').then(hit => hit || caches.match('/')))
    );
    return;
  }

  event.respondWith(
    caches.match(request).then(hit => hit || fetch(request).then(response => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(VERSION).then(cache => cache.put(request, copy));
      }
      return response;
    }))
  );
});
