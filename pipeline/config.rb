# encoding: utf-8
# Gemeinsame Pfade/Einstellungen der Pipeline
require 'json'; require 'date'; require 'fileutils'
Encoding.default_external = Encoding::UTF_8
ROOT  = File.expand_path("..", __dir__)
CACHE = File.join(ROOT, "cache")
DATA  = File.join(ROOT, "data")
DOCS  = File.join(ROOT, "docs")
TODAYD = Date.today
UA = "fcf-turniere-bot/1.0 (Vereinsplanung Kinderfussball)"
REGION = "TG_SG_ZH_AR_AI_SH"
CATS = {"G"=>"1_76_77_78", "F"=>"46_2_3_65_74_75", "E"=>"45_4_5_72", "D"=>"44_6_7_8_73_90_92_97", "FF14"=>"37", "FF11"=>"56", "FF09"=>"83"}
EXTRA_EVENTS = [9209]   # Ausnahme ausserhalb Region: Swiss Girls Cup Bern (nur Mädchen)
def jread(path, default) File.exist?(path) ? JSON.parse(File.read(path, encoding: "UTF-8")) : default; end
def jwrite(path, obj, pretty = false) FileUtils.mkdir_p(File.dirname(path)); File.write(path, pretty ? JSON.pretty_generate(obj) : JSON.generate(obj)); end
def http_get(url, out = nil)
  args = ["curl", "-sSL", "--retry", "3", "--max-time", "60", "-A", UA, url]
  args += ["-o", out] if out
  res = IO.popen(args, &:read)
  raise "Download fehlgeschlagen: #{url}" unless $?.success?
  res
end
