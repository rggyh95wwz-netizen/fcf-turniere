# encoding: utf-8
# Trainer-Anmeldungen aus Supabase lesen (nur im Abgleich/GitHub Actions, mit geheimem Schlüssel).
# Ohne SUPABASE_URL / SUPABASE_SERVICE_KEY -> nil (Kalender werden dann ohne Trainer gebaut).
require "net/http"; require "uri"

# Turnier-Schlüssel = gleiche Bildung wie die UID im Kalender-Abo (auch in der App: tkey())
def tkey(r) [r["id"], r["kat"], r["sub"], r["datum"], r["zeit"].to_s.gsub(/\D/, "")].join("-").gsub(/[^A-Za-z0-9-]/, ""); end

def sb_get(base, key, path)
  uri = URI("#{base.chomp('/')}/rest/v1/#{path}")
  req = Net::HTTP::Get.new(uri); req["apikey"] = key; req["Accept"] = "application/json"
  req["Authorization"] = "Bearer #{key}" unless key.start_with?("sb_")   # neue Schlüssel (sb_secret_…) nur im apikey-Header
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 40) { |h| h.request(req) }
  raise "Supabase #{path}: HTTP #{res.code} #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def trainer_data
  base = ENV["SUPABASE_URL"].to_s; key = ENV["SUPABASE_SERVICE_KEY"].to_s
  return nil if base.empty? || key.empty?
  tr = sb_get(base, key, "trainer?select=id,vorname,nachname,abo,aktiv&aktiv=eq.true&order=vorname,nachname")
  anm = sb_get(base, key, "anmeldung?select=tkey,trainer_id,erstellt&order=erstellt")
  plan = sb_get(base, key, "turnier_plan?select=tkey,prio")
  byid = tr.to_h { |t| [t["id"], t.merge("name" => "#{t['vorname']} #{t['nachname']}".strip)] }
  names = Hash.new { |h, k| h[k] = [] }
  anm.each { |a| names[a["tkey"]] << byid[a["trainer_id"]]["name"] if byid[a["trainer_id"]] }
  {"trainer" => byid.values, "anm" => anm.select { |a| byid[a["trainer_id"]] }, "names" => names, "prio" => plan.to_h { |p| [p["tkey"], p["prio"]] }}
rescue => e
  warn "Trainer-Daten nicht geladen (Kalender ohne Trainer): #{e.message}"
  nil
end
