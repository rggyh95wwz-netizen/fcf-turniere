# encoding: utf-8
# 1) Suche auf turnieragenda.ch (alle 7 Kategorien, Region, nächste 10 Monate) und Turnierseiten frisch laden
require_relative "config"
months = (0..9).map { |i| (TODAYD >> i).strftime("%Y-%m") }.join("_")
ids = []
CATS.each do |name, cat|
  html = http_get("https://www.turnieragenda.ch/de/searchresults?category=#{cat}&location=#{REGION}&time=#{months}")
  found = html.scan(%r{event/detail/(\d+)}).flatten.uniq
  puts "Suche #{name}: #{found.size} Turniere"
  raise "Suche #{name} lieferte 0 Treffer – Seite geändert?" if found.empty? && %w[E F D].include?(name)
  ids.concat(found); sleep 0.5
end
ids = (ids.map(&:to_i) + EXTRA_EVENTS).uniq.sort
FileUtils.rm_rf(File.join(CACHE, "ev")); FileUtils.mkdir_p(File.join(CACHE, "ev"))
ids.each do |id|
  http_get("https://www.turnieragenda.ch/de/event/detail/#{id}", File.join(CACHE, "ev", "#{id}.html")); sleep 0.25
end
bad = Dir[File.join(CACHE, "ev", "*.html")].select { |f| File.size(f) < 5000 }
raise "#{bad.size} Turnierseiten unvollständig" if bad.size > ids.size / 10
puts "Turnierseiten geladen: #{ids.size}"
