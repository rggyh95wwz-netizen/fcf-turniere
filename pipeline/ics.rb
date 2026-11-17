# encoding: utf-8
# Kalender-Abos (.ics) pro Team: alle Turniere, an denen FC Frauenfeld angemeldet ist (aus turnieragenda),
# täglich neu erzeugt -> docs/kalender/<Team>.ics. Feste UIDs, damit Kalender-Apps Termine aktualisieren statt doppeln.
require_relative "config"; require_relative "trainer"
db = jread(File.join(DATA, "db.json"), nil) or abort "db.json fehlt"
FCF = /frauenfeld/i
STKL = {"P"=>"Promotion/Elite", "1"=>"1. Stkl.", "2"=>"2. Stkl.", "3"=>"3. Stkl.", "V"=>"Fortgeschrittene", "A"=>"Anfänger"}
SLOT = {"Vormittag"=>[8, 0, 12, 0], "Mittag"=>[11, 0, 14, 0], "Nachmittag"=>[13, 0, 17, 0], "Abend"=>[17, 0, 21, 0]}
TEAMS = {"FF-14"=>"Team FF-14", "FF-11"=>"Team FF-11", "FF-09"=>"Team FF-09", "D"=>"Team D", "E"=>"Team E", "F"=>"Team F", "G"=>"Team G"}
# Team D aufgeteilt wie im Budget
DSPLIT = {"D7"=>->(r, n) { r["sub"] == "D7" }, "D9b"=>->(r, n) { n =~ /frauenfeld b\b/i && r["sub"] != "D7" }, "D-Promotion"=>->(r, n) { r["sub"] != "D7" && n !~ /frauenfeld b\b/i }}
def esc(v) v.to_s.gsub("\\", "\\\\\\\\").gsub(";", "\;").gsub(",", "\\,").gsub(/\r?\n/, "\\n"); end
def asc(v) v.to_s.gsub(/[–—]/, "-").gsub("·", "|").gsub("~", "ca. "); end
def fold(line)
  out = []; cur = +""; len = 0
  line.each_char { |ch| b = ch.bytesize; if len + b > 74 then out << cur; cur = +" "; len = 1 end; cur << ch; len += b }
  (out << cur).join("\r\n")
end
def dlong(d) x = Date.parse(d); %w[So Mo Di Mi Do Fr Sa][x.wday] + " " + x.strftime("%d.%m.%Y"); end
PRIOT = {1=>"Prio 1 (muss)", 2=>"Prio 2 (wenn möglich)", 3=>"Prio 3 (Option)"}
TR = trainer_data
def vevent(r, title, summary_prefix = nil)
  z = r["zeit"].to_s; est = nil
  if (m = z.match(/(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})/)) then t = m.captures.map(&:to_i)
  elsif SLOT[z.strip] then t = SLOT[z.strip]; est = z.strip
  elsif (m = z.match(/ab (\d{1,2}):(\d{2})/)) then t = [m[1].to_i, m[2].to_i, m[1].to_i + 4, m[2].to_i]; est = z
  else t = [8, 0, 17, 0]; est = "Zeit noch offen"
  end
  d = r["datum"].delete("-"); p2 = ->(n) { n.to_s.rjust(2, "0") }
  von = "#{p2.(t[0])}:#{p2.(t[1])}-#{p2.(t[2])}:#{p2.(t[3])}"
  sub = r["sub"] && r["sub"] != r["kat"] ? r["sub"] : nil
  head = [title, sub ? "Kategorie #{sub}" : nil, (r["stk"] || []).reject { |x| x == "-" }.map { |x| STKL[x] }.join(" / ")].compact.reject(&:empty?).join(" | ")
  fcf = r["namen"].grep(FCF)
  blocks = [
    [head, r["info"].to_s.empty? ? nil : asc(r["info"])],
    ["Zeit: #{dlong(r['datum'])}, #{von}#{est ? " (#{est}, genaue Zeit gemäss Spielplan)" : ''}", "Treffpunkt: ca. 30 Min vor Spielbeginn"],
    ["#{r['typ'] == 'Aussen' ? 'Platz' : 'Halle'}: #{asc(r['halle'])}", "Adresse: #{asc(r['adr'])}", "Anfahrt: #{r['fz']} Min / #{r['km']} km ab Frauenfeld"],
    [fcf.empty? ? "FCF noch nicht angemeldet (markiert)" : "Angemeldet für FCF: #{fcf.join(', ')}", "Status: #{r['status']}"],
    TR ? ["Trainer: #{TR['names'][tkey(r)].empty? ? 'noch offen' : TR['names'][tkey(r)].join(', ')}", TR["prio"][tkey(r)] ? PRIOT[TR["prio"][tkey(r)]] : nil] : [],
    ["Angemeldete Teams (#{r['namen'].size}):"] + r["namen"].map { |n| "- #{asc(n)}" },
    ["Ausschreibung: #{r['url']}", r["rg"] ? "Reglement: #{r['rg']}" : nil]
  ]
  desc = blocks.map { |b| b.compact.join("\n") }.reject(&:empty?).join("\n\n")
  uid = [r["id"], r["kat"], r["sub"], r["datum"], r["zeit"].to_s.gsub(/\D/, "")].join("-").gsub(/[^A-Za-z0-9-]/, "") + (summary_prefix ? "-t" : "") + "@fcf-turniere"
  cancelled = r["status"] == "entfernt"
  ["BEGIN:VEVENT", "UID:#{uid}", "DTSTAMP:#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}",
   "DTSTART;TZID=Europe/Zurich:#{d}T#{p2.(t[0])}#{p2.(t[1])}00", "DTEND;TZID=Europe/Zurich:#{d}T#{p2.(t[2])}#{p2.(t[3])}00",
   "SUMMARY:#{esc(asc("#{cancelled ? 'ABGESAGT? ' : ''}#{summary_prefix}#{r['typ'] == 'Aussen' ? 'Turnier' : 'Hallenturnier'} #{sub || r['kat']}: #{r['name']} (#{r['ort']})"))}",
   "LOCATION:#{esc(asc("#{r['halle']}, #{r['adr']}"))}", "DESCRIPTION:#{esc(desc)}", "URL:#{r['url']}",
   "STATUS:#{cancelled ? 'CANCELLED' : 'CONFIRMED'}", "TRANSP:OPAQUE", "END:VEVENT"]
end
VTZ = ["BEGIN:VTIMEZONE", "TZID:Europe/Zurich", "BEGIN:DAYLIGHT", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0200", "TZNAME:CEST", "DTSTART:19700329T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT", "BEGIN:STANDARD", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0100", "TZNAME:CET", "DTSTART:19701025T030000", "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD", "END:VTIMEZONE"]
def cal(name, events)
  lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//FC Frauenfeld//Turnierplaner//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
           "X-WR-CALNAME:#{esc(name)}", "X-WR-TIMEZONE:Europe/Zurich", "REFRESH-INTERVAL;VALUE=DURATION:PT12H", "X-PUBLISHED-TTL:PT12H"] + VTZ
  events.each { |e| lines.concat(e) }
  lines << "END:VCALENDAR"
  lines.map { |l| fold(l) }.join("\r\n") + "\r\n"
end
dir = File.join(DOCS, "kalender"); FileUtils.mkdir_p(dir)
rows = db["rows"].values.select { |r| r["namen"].any? { |n| n =~ FCF } && r["datum"] >= (TODAYD - 60).to_s }.sort_by { |r| r["datum"] }
index = {}
TEAMS.each do |k, title|
  rs = rows.select { |r| r["kat"] == k }
  File.write(File.join(dir, "#{k}.ics"), cal("Turnierplaner #{title}", rs.map { |r| vevent(r, title) })); index[k] = rs.size
  next unless k == "D"
  DSPLIT.each do |part, f|
    ev = rs.select { |r| r["namen"].grep(FCF).any? { |n| f.(r, n) } }
    File.write(File.join(dir, "#{part}.ics"), cal("Turnierplaner #{part}", ev.map { |r| vevent(r, "Team #{part}") })); index[part] = ev.size
  end
end
jwrite(File.join(dir, "index.json"), index, true)
# Kalender-Abo pro Trainer: alle Turniere, bei denen er/sie «Ich kann hier» gewählt hat -> docs/kalender/trainer/<abo>.ics
if TR
  tdir = File.join(dir, "trainer"); FileUtils.mkdir_p(tdir)
  bykey = db["rows"].values.select { |r| r["datum"] >= (TODAYD - 60).to_s }.to_h { |r| [tkey(r), r] }
  keep = []
  TR["trainer"].each do |t|
    rs = TR["anm"].select { |a| a["trainer_id"] == t["id"] }.map { |a| bykey[a["tkey"]] }.compact.uniq.sort_by { |r| r["datum"] }
    f = "#{t['abo'].to_s.gsub(/[^a-z0-9]/i, '')}.ics"; next if f == ".ics"
    File.write(File.join(tdir, f), cal("FCF Trainer #{t['name']}", rs.map { |r| vevent(r, "Team #{r['kat']}", "Trainer: ") }))
    keep << f
  end
  (Dir.children(tdir) - keep).each { |f| File.delete(File.join(tdir, f)) if f.end_with?(".ics") }   # entfernte Trainer
  puts "Trainer-Abos: #{keep.size} Trainer, #{TR['anm'].size} Anmeldungen"
end
puts "Kalender-Abos: " + index.map { |k, v| "#{k}=#{v}" }.join(" ")
