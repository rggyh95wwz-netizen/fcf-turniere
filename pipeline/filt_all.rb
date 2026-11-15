# encoding: utf-8
require_relative 'config'
T0 = TODAYD.to_s
E = jread(File.join(CACHE, "events.json"), [])
def team(k)
  case k
  when /\AJunioren G\d?\z/ then "G"
  when /\AJunioren F\d?\z/ then "F"
  when /\AJunioren E\d?\z/ then "E"
  when /\AJunioren D(7|9)?\b/ then "D"
  when /FF-14/ then "FF-14"
  when /FF-11/ then "FF-11"
  when /FF-09/ then "FF-09"
  end
end
ALLST = %w[FF-11 FF-09]           # Mädchen E/F: alle Ausschreibungen (auch ausgebucht)
FCF = /frauenfeld/i; EW = /wiesendangen|\belgg\b/i
keep = []
E.each do |e|
  next unless %w[Hallenturnier Rasenturnier].include?(e["typ"])
  sel = []
  e["comps"].each do |c|
    t = team(c["kat"]) or next
    next unless c["datum"] && c["datum"] >= T0
    next if EXTRA_EVENTS.include?(e["id"]) && t !~ /\AFF/   # Bern nur für Mädchen
    open = c["frei"].to_i > 0 && c["btn"] == "anmelden" && (e["anm"].nil? || e["anm"] >= T0)
    st = open ? "offen" : (c["frei"].nil? ? "geschlossen" : (c["frei"] == 0 ? "ausgebucht" : "Anmeldeschluss vorbei"))
    girl = t.start_with?("FF")
    take = true   # alle Ausschreibungen speichern (Status bekannt); die App filtert «nur freie Plätze»
    sel << c.merge("team" => t, "status" => st) if take
  end
  keep << e.merge("sel" => sel) if sel.any?
end
jwrite(File.join(CACHE, "keep.json"), keep)
puts "Events #{keep.size}"
keep.flat_map { |e| e["sel"].map { |c| [c["team"], e["typ"], c["status"]] } }.group_by { |x| x[0] }.sort.each { |t, v| puts "#{t}: #{v.size} (Halle #{v.count { |x| x[1]=='Hallenturnier' }}, Aussen #{v.count { |x| x[1]=='Rasenturnier' }}, offen #{v.count { |x| x[2]=='offen' }})" }
g = jread(File.join(DATA, "geo.json"), {})
miss = keep.map { |e| e["adr"] }.uniq.reject { |a| g[a] }
File.write(File.join(CACHE, "addr.txt"), miss.each_with_index.map { |a, i| "x#{i}|#{a}" }.join("\n") + "\n")
puts "neue Adressen: #{miss.size}"
File.write(File.join(CACHE, "rg.txt"), keep.select { |e| e["rg"] }.map { |e| "#{e['id']} #{e['rg']}" }.join("\n") + "\n")
