const CACHE = "labelverify-v6";
const ASSETS = ["./", "./index.html", "./manifest.json", "./icon-192.png", "./icon-512.png",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});
self.addEventListener("fetch", e => {
  const url = e.request.url;
  if (e.request.method !== "GET" || url.includes(".supabase.co")) return; // API는 SW 미개입

  // HTML(앱 본체)은 네트워크 우선 → 배포 즉시 반영, 오프라인이면 캐시 사용
  if (e.request.mode === "navigate" || url.endsWith("index.html")) {
    e.respondWith(
      fetch(e.request).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      }).catch(() => caches.match(e.request).then(h => h || caches.match("./index.html")))
    );
    return;
  }
  // 그 외 리소스(폰트/라이브러리/아이콘)는 캐시 우선
  e.respondWith(
    caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
      if (res.ok && (url.startsWith(self.location.origin) || url.includes("fonts.g") || url.includes("jsdelivr"))) {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
      }
      return res;
    }))
  );
});
