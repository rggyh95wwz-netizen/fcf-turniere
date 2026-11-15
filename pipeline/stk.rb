# encoding: utf-8
def stk_for(sub, info)
  s = []
  subd = sub =~ /\A[GFE]([123])\z/ ? $1 : nil
  t = info.to_s.gsub(/\d{4}/, "").gsub(/\d+\s*(vs\.?|\+|gegen|:)\s*\d+/i, "").gsub(/\d+\s*(Spieler|Feldspieler|Teams?|Min)/i, "")
  t.scan(/\b[GFE]([123])\b/) { s << $1 }
  if t =~ /st(ä|a)rke|stkl|klasse/i
    t.scan(/(?<![\d])([123])(?=\s*(\.|&|\/|und|\s|te|st|-))/) { s << $1 }
  end
  s << "P" if t =~ /promo|elite|höher/i
  s << "A" if t =~ /anfänger/i
  s << "V" if t =~ /fortgeschritt|mittel/i
  s << subd if subd && (s & %w[1 2 3]).empty?
  s.uniq.sort_by { |x| %w[P 1 2 3 V A].index(x) }
end
STKL = {"P"=>"Promotion/Elite", "1"=>"1. Stärkeklasse", "2"=>"2. Stärkeklasse", "3"=>"3. Stärkeklasse", "V"=>"Fortgeschrittene", "A"=>"Anfänger", "-"=>"ohne Angabe"}
