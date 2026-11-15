# encoding: utf-8
require_relative 'config'
Dir.chdir(DATA)
require 'json'
g = JSON.parse(File.read("geo.json")); out = File.exist?("kt.json") ? JSON.parse(File.read("kt.json")) : {}
M = {"Thurgau"=>"TG","St. Gallen"=>"SG","Zürich"=>"ZH","Schaffhausen"=>"SH","Appenzell Ausserrhoden"=>"AR","Appenzell Innerrhoden"=>"AI","Glarus"=>"GL","Graubünden"=>"GR","Graubünden/Grischun/Grigioni"=>"GR","Aargau"=>"AG","Schwyz"=>"SZ"}
g.each do |a, (la, lo)|
  next unless la && !out[a]
  j = JSON.parse(`curl -s -A "fcf-turniere-bot/1.0" "https://nominatim.openstreetmap.org/reverse?format=json&zoom=10&accept-language=de&lat=#{la}&lon=#{lo}"`) rescue {}
  st = j.dig("address", "state"); out[a] = M[st] || st
  sleep 1.1
end
File.write("kt.json", JSON.generate(out)); p out.values.group_by{|x|x}.map{|k,v|[k,v.size]}
