# encoding: utf-8
require_relative 'config'
require 'cgi'
require 'date'
DIR = File.join(CACHE, "ev")
MON = {"Jan"=>1,"Feb"=>2,"März"=>3,"Mär"=>3,"Apr"=>4,"Mai"=>5,"Juni"=>6,"Jun"=>6,"Juli"=>7,"Jul"=>7,"Aug"=>8,"Sep"=>9,"Sept"=>9,"Okt"=>10,"Nov"=>11,"Dez"=>12}
ENT = {"nbsp"=>" ","ndash"=>"–","mdash"=>"—","uuml"=>"ü","auml"=>"ä","ouml"=>"ö","Uuml"=>"Ü","Auml"=>"Ä","Ouml"=>"Ö","shy"=>"","raquo"=>"»","laquo"=>"«","bull"=>"•","agrave"=>"à","eacute"=>"é","egrave"=>"è","hellip"=>"…","szlig"=>"ss","copy"=>"©","ccedil"=>"ç","times"=>"×","middot"=>"·","rsquo"=>"’","lsquo"=>"‘","ldquo"=>"“","rdquo"=>"”","bdquo"=>"„","euro"=>"€"}
def txt(h); CGI.unescapeHTML(h.to_s.gsub(/&([a-zA-Z]+);/) { ENT[$1] || $& }.gsub(/<br\s*\/?>/i, "\n").gsub(/<\/p>/i, "\n").gsub(/<[^>]+>/, " ")).gsub(" ", " ").gsub(/[ \t]+/, " ").gsub(/ *\n */, "\n").gsub(/\n+/, "\n").strip; end
out = []
Dir[File.join(DIR, "*.html")].sort.each do |f|
  h = File.read(f, encoding: "utf-8")
  id = File.basename(f, ".html").to_i
  h1 = txt(h[/<h1 class="h1">(.*?)<\/h1>/m, 1])
  typ = h1[/\(([^()]*)\)\s*\z/, 1]
  name = h1.sub(/\s*\([^()]*\)\s*\z/, "")
  org = h[/<h2 class="event-info__title">Veranstalter<\/h2>.*?<p class="p">(.*?)<br>/m, 1]
  web = h[/href="([^"]+)" target="_blank" class="link">&raquo; Webseite/, 1]
  anm = h[/Anmeldeschluss:<\/strong>\s*([0-9.]+)/, 1]
  anm = anm ? Date.strptime(anm, "%d.%m.%Y").to_s : nil
  rg = h[/href="(\/ressources\/rules\/[^"]+)"/, 1]
  ortblk = h[/event-info__item--address">.*?<p class="p">(.*?)<a /m, 1]
  halle = txt(ortblk.to_s[/<strong>(.*?)<\/strong>/m, 1])
  adr = txt(ortblk.to_s.sub(/<strong>.*?<\/strong>/m, "")).gsub("\n", " ").strip
  desc = txt(h[/<div class="description js-description rich">(.*?)<\/div>\s*(<div class="event-competitions"|<a )/m, 1] || h[/<div class="description js-description rich">(.*?)<\/div>/m, 1])
  comps = []
  h.scan(/<tr class="competition js-competition">(.*?)<\/tr>/m).each do |(r)|
    cat = txt(r[/<td class="category">(.*?)<\/td>/m, 1])
    kat, info = cat.split("\n", 2)
    dt = txt(r[/<td class="date">(.*?)<\/td>/m, 1])
    dl, tl = dt.split("\n", 2)
    m = dl.to_s.match(/(\d+)\.\s*([A-Za-zä]+)\.?\s*(\d{4})/)
    datum = m ? Date.new(m[3].to_i, MON[m[2]] || MON[m[2][0,3]] || 0, m[1].to_i).to_s : nil rescue nil
    cost = txt(r[/<td class="cost">(.*?)<\/td>/m, 1])
    chf = cost[/(\d+)/, 1]&.to_i
    parts = txt(r[/<td class="participants">(.*?)<\/td>/m, 1])
    av = txt(r[/<td class="availability">(.*?)<\/td>/m, 1])
    btn = txt(r[/<td class="options">(.*?)<\/td>/m, 1])
    comps << {kat: kat.to_s.strip, info: info.to_s.strip, datum: datum, zeit: tl.to_s.strip.gsub(/\s*–\s*/, "–"), chf: chf, cost: cost,
              teams: parts.empty? ? [] : parts.split(/,\s*/), frei: (av =~ /\A\d+\z/ ? av.to_i : nil), av: av, btn: btn,
              reg: r[/href="([^"]*registration)"/, 1]}
  end
  out << {id: id, name: name, typ: typ, verein: txt(org), web: web, anm: anm, rg: rg ? "https://www.turnieragenda.ch#{rg}" : nil,
          halle: halle, adr: adr, desc: desc, comps: comps}
end
jwrite(File.join(CACHE, "events.json"), out)
puts out.size
puts out.map { |e| e[:typ] }.group_by{|x|x}.map{|k,v|[k,v.size]}.inspect
puts out.flat_map { |e| e[:comps].map { |c| c[:kat] } }.group_by{|x|x}.map{|k,v|[k,v.size]}.sort_by { |k, v| -v }.first(40).inspect
puts out.flat_map { |e| e[:comps].map { |c| c[:btn] } }.group_by{|x|x}.map{|k,v|[k,v.size]}.inspect
puts out.flat_map { |e| e[:comps].map { |c| c[:av] } }.group_by{|x|x}.map{|k,v|[k,v.size]}.inspect
