# encoding: utf-8
# Baut rows (eine Zeile pro offener Kategorie-Konkurrenz) aus keep.json + Reglementen
require_relative 'config'
SP = __dir__
TODAY = Date.new(2026, 11, 14)
ARR = 30
TA = "https://www.turnieragenda.ch/de/event/detail/"
KEEP = jread(File.join(CACHE, "keep.json"), [])
ROUTE = jread(File.join(DATA, "route.json"), {})
KT = jread(File.join(DATA, "kt.json"), {})

def regl(id)
  f = File.join(CACHE, "regl", "#{id}.txt")
  File.exist?(f) ? File.read(f, encoding: "utf-8").scrub("") : ""
end

LBAD = /(strafe|verspät|spätestens|protest|kaution|vor (dem|ihrem|seinem|beginn|turnier|spielbeginn|ihrem)|nach (spielende|abpfiff|ende|dem)|vor jedem|melde|eintreffen|anwesend|bereit)/i
LGOOD = /(mind|für|kategorie|je nach|spiel|dauer|zeit|seitenwechsel|durchlaufend|à|\ba\b|pro\b|je\b)/i
def minutes(text)
  res = []
  text.to_s.split(/\n|(?<=[.;])\s/).each do |line|
    next if line =~ LBAD && line !~ /spieldauer|spielzeit|pro spiel|minuten pro|min\.? pro/i
    line.scan(/(\d{1,2})(?:\s*(?:-|–|bis)\s*(\d{1,2}))?\s*(?:Min\.?|Minuten|min\b|')/i) do
      a = $1.to_i
      post = $'[0, 12].to_s
      next if post =~ /\A\s*(vor|nach|pause|zeitstrafe)/i
      next unless (6..15).include?(a)
      res << [a, line.strip, (line =~ LGOOD ? 1 : 0)]
    end
  end
  res
end

def lines_for(text, lk)
  text.to_s.split(/\n/).select { |l| l =~ /(Junioren\s*#{lk}\b|Jun\.?\s*#{lk}\b|\b#{lk}[123]?-?Junioren|\b#{lk}[123]?\s*[:\-–]|\b#{lk}[123]\b|Kategorie\s*#{lk}\b)/ }
end

def dauer_for(c, lk, desc, rg)
  m = minutes(c["info"]); return [m[0][0], "Ausschreibung"] if m.any?
  m = minutes(lines_for(desc, lk).join("\n")); return [m[0][0], "Beschreibung"] if m.any?
  m = minutes(lines_for(rg, lk).join("\n")).select { |x| x[2] == 1 }; return [m[0][0], "Reglement"] if m.any?
  m = minutes(desc).select { |x| x[2] == 1 }; return [m[0][0], "Beschreibung"] if m.any?
  m = minutes(rg).select { |x| x[2] == 1 }; return [m[0][0], "Reglement"] if m.any?
  [nil, nil]
end

def spiele_for(c, lk, desc, rg, n)
  [c["info"], lines_for(desc, lk).join("\n"), lines_for(rg, lk).join("\n")].each do |t|
    if t.to_s =~ /(?:mind(?:estens|\.)?\s*)?(\d{1,2})\s*(?:garantierte\s*)?Spiele\b/i
      v = $1.to_i; return [v, false] if (3..10).include?(v)
    end
  end
  return [nil, true] if n.nil? || n < 2
  est = n <= 6 ? n - 1 : (n <= 8 ? 4 : 5)
  [est, true]
end

def slot_min(z)
  m = z.to_s.match(/(\d{1,2}):(\d{2})\s*–\s*(\d{1,2}):(\d{2})/) or return nil
  (m[3].to_i * 60 + m[4].to_i) - (m[1].to_i * 60 + m[2].to_i)
end

TAGRX = [
  ["3-fach-Halle", /drei[- ]?fach|3[- ]?fach|dreifachhalle|dreifachturnhalle/i],
  ["Kunstrasen", /kunstrasen/i],
  ["Jubiläum", /jubil/i],
  ["Special Guests", /special guest|stargast|ehrengast|überraschungsgast|prominente/i],
  ["Tombola", /tombola|verlosung/i],
  ["Play More Football", /play more football|\bpmf\b|3\s*(gegen|vs\.?|:)\s*3/i],
  ["ohne Rangliste", /ohne (rangliste|resultat|wertung)|keine (rangliste|resultate|wertung)|ohne siegerehrung/i],
  ["Futsal", /futsal/i],
  ["ohne Banden", /(ohne|keine) bande|outlinie|seitenaus/i],
  ["Banden", /bande(n|nspiel)?\b/i],
  ["geteilte Halle", /\bquer\b|zwei spielfelder|2 spielfelder|drei spielfelder|3 spielfelder|zwei felder|2 felder|geteilt/i],
  ["Tribüne", /tribüne|galerie/i],
  ["moderne Halle", /moderne|neue[nr]? (halle|sporthalle|turnhalle)|neubau|neu eröffnet/i],
  ["Turnier-App", /turnier-?app|live-?resultat|liveticker/i],
  ["All-Star/Best Player", /best player|all.?star|bester (spieler|torhüter|torwart)|torschützenkönig/i],
  ["Pokale", /pokal/i],
  ["Preis/Medaille für alle", /medaille|erinnerungspreis|preis für (jede|alle)|kinder erhalten/i],
  ["Festwirtschaft", /festwirtschaft|kiosk|verpflegung|grill|bistro|kaffeestube|beizli|cafeteria|kuchenbuffet/i],
  ["Stärkeklassen", /stärkeklasse|stkl/i],
]
HIGHLIGHT = ["3-fach-Halle", "Kunstrasen", "Jubiläum", "Special Guests", "Tombola"]

def tags_for(e, rg)
  t = [e["name"], e["halle"], e["desc"], e["open"].map { |c| c["info"] }.join(" "), rg].join("\n")
  tags = TAGRX.select { |_, rx| t =~ rx }.map(&:first)
  tags.delete("Banden") if tags.include?("ohne Banden") && t !~ /mit bande|bandenspiel|rundum bande|banden (erlaubt|rundum)/i
  tags << "Jubiläum" if e["name"] =~ /\A(10|20|25|30|40|50|60|75)\.\s/ && !tags.include?("Jubiläum")
  tags.uniq
end

KEYW = /(spieldauer|spielzeit|minuten|min\.|spieler|torhüter|torwart|feldspieler|\d\s*\+\s*1|bande|futsal|ball|einsatz|startgeld|teilnahmebeitrag|bezahl|twint|bar |abmeld|nichterscheinen|forfait|medaille|preis|pokal|modus|gruppe|quer|kleintor|handballtor|schienbein|hallenschuh)/i
def kernpunkte(text, max = 8)
  seen = {}
  out = []
  text.to_s.split(/\n|(?<=\.)\s+(?=[A-ZÄÖÜ])/).each do |l|
    l = l.gsub(/[¨•▪➢✓]/, "").gsub(/\s+/, " ").strip
    next if l.size < 13 || l.split.size < 5 || l !~ KEYW || seen[l.downcase]
    seen[l.downcase] = true
    out << (l.size > 170 ? l[0, 167] + "…" : l)
    break if out.size >= max
  end
  out
end

def ort_of(adr) adr.to_s[/\d{4}\s+(.+)\z/, 1] || adr; end

load File.join(SP, "stk.rb")
FCFRX = /frauenfeld/i
X = jread(File.join(DATA, "extras.json"), {"rows"=>{}, "hd"=>{}})   # Handrecherche (Modus, Hallen-Infos)
OLD = Hash.new { |h, k| h[k] = X["rows"]["#{k[0]}|#{k[1]}"] || {} }; OLDHD = Hash.new { |h, k| h[k] = X["hd"][k.to_s] }
LK = {"G"=>"G", "F"=>"F", "E"=>"E", "D"=>"D", "FF-14"=>"(?:FF-?14|Juniorinnen D)", "FF-11"=>"(?:FF-?11|Juniorinnen E)", "FF-09"=>"(?:FF-?0?9|Juniorinnen F)"}
KTFIX = {"Bern"=>"BE", "Baden-Württemberg"=>"DE"}
ROWS = []; EVX = {}
KEEP.each do |e|
  rt = ROUTE[e["adr"]] || {}; next if rt["fz"].nil?   # nicht lokalisierbar
  ktx = KTFIX[KT[e["adr"]]] || KT[e["adr"]]
  next unless %w[TG SG ZH AR AI SH SZ GL DE].include?(ktx) || EXTRA_EVENTS.include?(e["id"])   # Region (Ausnahme: Swiss Girls Cup Bern)
  rg = regl(e["id"])
  tags = tags_for(e.merge("open" => e["sel"]), rg)
  typ = e["typ"] == "Rasenturnier" ? "Aussen" : "Halle"
  kt = KTFIX[KT[e["adr"]]] || KT[e["adr"]]
  ort = ort_of(e["adr"]).to_s.sub(/\A\d{4,5}[[:space:]]+/, "").sub(/\s*\(D\)\z/, "")
  EVX[e["id"]] = {desc: e["desc"], kern: kernpunkte(rg), web: e["web"]}
  e["sel"].each do |c|
    t = c["team"]
    case t
    when "G", "F", "E" then sub = c["kat"].sub("Junioren ", ""); rest = ""; stk = stk_for(sub, c["info"])
    when "D" then sub = c["kat"][/\AJunioren (D\d?)/, 1]; rest = c["kat"].sub(/\AJunioren D\d?\s*-?\s*/, ""); stk = stk_for(sub, [rest, c["info"]].join(" "))
    else sub = t; rest = ""; stk = ["-"]
    end
    info = [rest, c["info"]].reject { |x| x.to_s.strip.empty? }.join(" · ")
    n = c["teams"].size + c["frei"].to_i
    d, dsrc = dauer_for(c, LK[t], e["desc"], rg); sp, est = spiele_for(c, LK[t], e["desc"], rg, n); slot = slot_min(c["zeit"])
    old = OLD[[e["id"], t]] || {}
    r = {id: e["id"], name: e["name"], verein: e["verein"], ort: ort, kt: kt, halle: e["halle"], adr: e["adr"],
         km: rt["km"], fz: rt["fz"], anm: e["anm"], rg: e["rg"], url: TA + e["id"].to_s, reg: c["reg"], typ: typ,
         kat: t, sub: sub, info: info, datum: c["datum"], zeit: c["zeit"], kosten: c["chf"], namen: c["teams"], teams: c["teams"].size,
         frei: c["frei"], dauer: d || old["dauer"], dsrc: d ? dsrc : (old["dauer"] ? "Reglement" : nil), spiele: sp, spiele_est: est,
         hallenzeit: slot ? slot + ARR : nil, status: c["status"], tags: (typ == "Aussen" ? ["Aussen/Rasen"] : []) + tags,
         stk: stk.empty? ? ["-"] : stk, fmt: old["fmt"], bem: old["bem"], hd: OLDHD[e["id"]], gq: "#{e['halle']} #{e['adr']}"}
    r[:spielzeit] = r[:dauer] && sp ? r[:dauer] * sp : nil
    ROWS << r.reject { |_, v| v.nil? }
  end
end
ROWS.sort_by! { |r| [r[:datum], r[:kat], r[:fz] || 999] }
if __FILE__ == $0
  puts "rows #{ROWS.size}; " + ROWS.group_by { |r| r[:kat] }.map { |k, v| "#{k}=#{v.size}" }.join(" ")
  puts "fz nil: #{ROWS.count { |r| r[:fz].nil? }} #{ROWS.select { |r| r[:fz].nil? }.map { |r| r[:adr] }.uniq}"
  puts "fmt übernommen: #{ROWS.count { |r| r[:fmt] }}, hd: #{ROWS.count { |r| r[:hd] }}, dauer: #{ROWS.count { |r| r[:dauer] }}"
  puts "Monate: " + ROWS.map { |r| r[:datum][0, 7] }.group_by { |x| x }.map { |k, v| "#{k}:#{v.size}" }.sort.join(" ")
  jwrite(File.join(CACHE, "current.json"), {rows: ROWS, ev: EVX})
end
