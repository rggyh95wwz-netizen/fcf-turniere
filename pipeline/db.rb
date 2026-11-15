# encoding: utf-8
# Fortlaufende Datenbank: neue Ausschreibungen dazu, bestehende aktualisieren, alte behalten (Status vorbei/entfernt) + Tages-Schnappschuss
require_relative "config"
cur = jread(File.join(CACHE, "current.json"), nil) or abort "current.json fehlt"
raise "Abgleich lieferte nur #{cur['rows'].size} Ausschreibungen – Abbruch, Datenbank bleibt unverändert" if cur["rows"].size < 100
db = jread(File.join(DATA, "db.json"), {"rows" => {}})
evdb = jread(File.join(DATA, "ev.json"), {})
today = TODAYD.to_s
key = ->(r) { [r["kat"], r["id"], r["sub"], r["info"], r["datum"], r["zeit"]].join("|") }
seen = {}; neu = 0; upd = 0
cur["rows"].each do |r|
  k = key.(r); old = db["rows"][k]
  neu += 1 unless old; upd += 1 if old && (old["frei"] != r["frei"] || old["status"] != r["status"] || old["namen"] != r["namen"])
  db["rows"][k] = r.merge("first_seen" => old ? old["first_seen"] : today, "last_seen" => today)
  seen[k] = true
end
weg = 0
db["rows"].each do |k, r|
  next if seen[k]
  if r["datum"] < today then r["status"] = "vorbei" unless r["status"] == "entfernt"
  elsif r["status"] != "entfernt" then r["status"] = "entfernt"; weg += 1
  end
end
# Abgelaufene Einträge ohne FCF-Beteiligung löschen (Wunsch 15.11.2026); mit FCF bleiben sie als Verlauf
del = db["rows"].select { |k, r| r["datum"] < today && !(r["namen"] || []).any? { |n| n =~ /frauenfeld/i } }.keys
del.each { |k| db["rows"].delete(k) }
db["updated"] = Time.now.strftime("%Y-%m-%d %H:%M")
evdb.merge!(cur["ev"].transform_keys(&:to_s))
jwrite(File.join(DATA, "db.json"), db)
jwrite(File.join(DATA, "ev.json"), evdb)
snap = cur["rows"].map { |r| [key.(r), r["frei"], r["teams"], r["status"]] }
jwrite(File.join(DATA, "snapshots", "#{today}.json"), snap)
puts "Datenbank: #{db['rows'].size} Ausschreibungen (neu #{neu}, geändert #{upd}, entfernt #{weg}, abgelaufen gelöscht #{del.size})"
