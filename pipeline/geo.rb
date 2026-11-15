# encoding: utf-8
require_relative 'config'
Dir.chdir(DATA)
require 'json'; require 'net/http'; require 'uri'
cache = File.exist?("geo.json") ? JSON.parse(File.read("geo.json")) : {}
def q(s)
  u = URI("https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=ch&q=" + URI.encode_www_form_component(s))
  r = (http_get(u.to_s) rescue "[]")
  j = JSON.parse(r) rescue []
  sleep 1.1
  j[0] ? [j[0]["lat"].to_f, j[0]["lon"].to_f] : nil
end
def qplz(p)
  return nil unless p
  j = JSON.parse(http_get("https://nominatim.openstreetmap.org/search?format=json&limit=1&country=ch&postalcode=#{p}")) rescue []
  sleep 1.1
  j[0] ? [j[0]["lat"].to_f, j[0]["lon"].to_f] : nil
end
lines = File.readlines(File.join(CACHE, "addr.txt"), encoding: "utf-8").reject { |l| l.strip.empty? }.map { |l| l.chomp.split("|", 2) }
lines.unshift(["start", "Bahnhofplatz, 8500 Frauenfeld"])
lines.each do |id, a0|
  a = a0; a0 = a0.to_s
  next if cache[a]
  qa = a.gsub(/,\s*,/, ",").gsub(/\s+/, " ")
  c = q(qa) || q(qa.sub(/\(.*?\)/, "")) || q(a.sub(/\A[^,]*,\s*/, "")) || q(a[/\d{4}.*/].to_s) || qplz(a[/\b(\d{4})\b/, 1])
  cache[a] = c
  STDERR.puts "#{id} #{a} -> #{c.inspect}"
end
File.write("geo.json", JSON.generate(cache))
