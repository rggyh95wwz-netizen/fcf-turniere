# encoding: utf-8
# Baut die Webseite docs/index.html (+ Manifest, Service Worker, Icons) aus Datenbank und Template
require_relative "config"; require "base64"
T = File.join(ROOT, "template")
db = jread(File.join(DATA, "db.json"), nil) or abort "db.json fehlt"
ev = jread(File.join(DATA, "ev.json"), {})
rows = db["rows"].values.sort_by { |r| [r["datum"], r["kat"], r["fz"] || 999] }
logo = "data:image/gif;base64," + Base64.strict_encode64(File.binread(File.join(T, "logo_fcf.gif")))
logo_ew = "data:image/png;base64," + Base64.strict_encode64(File.binread(File.join(T, "logo_ew.png")))
html = File.read(File.join(T, "app.html"), encoding: "UTF-8")
{ "__BASECSS__" => File.read(File.join(T, "base.css"), encoding: "UTF-8"),
  "__DATA_ALL__" => JSON.generate(rows), "__EV_ALL__" => JSON.generate(ev),
  "__STAND__" => TODAYD.strftime("%d.%m.%Y"), "__TODAY__" => TODAYD.to_s, "__UPDATED__" => db["updated"].to_s,
  "__LOGO_EW__" => logo_ew, "__LOGO__" => logo }.each { |k, v| html = html.gsub(k) { v } }
FileUtils.mkdir_p(DOCS)
File.write(File.join(DOCS, "index.html"), html)
FileUtils.cp(File.join(T, "logo_fcf.gif"), File.join(DOCS, "icon.gif"))
File.write(File.join(DOCS, "manifest.webmanifest"), JSON.pretty_generate({
  name: "FCF Turniere", short_name: "FCF Turniere", start_url: "./", scope: "./", display: "standalone",
  background_color: "#f6f7f9", theme_color: "#c8102e", icons: [{src: "icon.gif", sizes: "80x80", type: "image/gif"}]}))
File.write(File.join(DOCS, "sw.js"), <<~JS)
  // Offline-Cache: zuerst Netz (immer aktuelle Daten), sonst letzte gespeicherte Version
  const C = "fcf-#{TODAYD}";
  self.addEventListener("install", e => { self.skipWaiting(); e.waitUntil(caches.open(C).then(c => c.addAll(["./", "./index.html", "./manifest.webmanifest", "./icon.gif"]))); });
  self.addEventListener("activate", e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim())));
  self.addEventListener("fetch", e => { if (e.request.method !== "GET") return; e.respondWith(fetch(e.request).then(r => { const cp = r.clone(); caches.open(C).then(c => c.put(e.request, cp)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match("./index.html")))); });
JS
File.write(File.join(DOCS, ".nojekyll"), "")
puts "Webseite gebaut: docs/index.html (#{(html.bytesize / 1024.0).round} KB, #{rows.size} Ausschreibungen)"
