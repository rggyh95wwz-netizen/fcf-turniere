# encoding: utf-8
# Trainer-Anmeldungen lesen: Datei daten.json im privaten Repo TRAINER_DATEN_REPO (Schlüssel TRAINER_DATEN_TOKEN).
# Ohne diese Angaben -> nil (Kalender werden dann ohne Trainer gebaut).
require "net/http"; require "uri"; require "base64"

# Turnier-Schlüssel = gleiche Bildung wie die UID im Kalender-Abo (auch in der App: tkey())
def tkey(r) [r["id"], r["kat"], r["sub"], r["datum"], r["zeit"].to_s.gsub(/\D/, "")].join("-").gsub(/[^A-Za-z0-9-]/, ""); end

def trainer_data
  repo = ENV["TRAINER_DATEN_REPO"].to_s.strip; tok = ENV["TRAINER_DATEN_TOKEN"].to_s.strip
  return nil if repo.empty? || tok.empty?
  uri = URI(ENV.fetch("GITHUB_API_URL", "https://api.github.com") + "/repos/#{repo}/contents/daten.json")
  req = Net::HTTP::Get.new(uri); req["Authorization"] = "Bearer #{tok}"; req["Accept"] = "application/vnd.github+json"; req["User-Agent"] = UA
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 40) { |h| h.request(req) }
  d = if res.code == "404" then {}
      elsif res.is_a?(Net::HTTPSuccess) then JSON.parse(Base64.decode64(JSON.parse(res.body)["content"].to_s).force_encoding("UTF-8"))
      else raise "GitHub #{res.code}: #{res.body.to_s[0, 200]}" end
  tr = (d["trainer"] || []).select { |t| t["aktiv"] != false && t["id"] && t["abo"] }.map { |t| t.merge("name" => "#{t['vorname']} #{t['nachname']}".strip) }
  byid = tr.to_h { |t| [t["id"], t] }
  anm = (d["anm"] || []).select { |a| byid[a["t"]] }
  names = Hash.new { |h, k| h[k] = [] }
  anm.each { |a| names[a["k"]] << byid[a["t"]]["name"] unless names[a["k"]].include?(byid[a["t"]]["name"]) }
  {"trainer" => tr, "anm" => anm.map { |a| {"tkey" => a["k"], "trainer_id" => a["t"]} }, "names" => names, "prio" => (d["plan"] || {}).select { |_, v| [1, 2, 3].include?(v) }}
rescue => e
  warn "Trainer-Daten nicht geladen (Kalender ohne Trainer): #{e.message}"
  nil
end
