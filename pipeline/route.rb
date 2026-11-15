# encoding: utf-8
require_relative 'config'
Dir.chdir(DATA)
require 'json'
g = JSON.parse(File.read("geo.json"))
start = g["Bahnhofplatz, 8500 Frauenfeld"]
keys = g.keys.select { |k| g[k] } - ["Bahnhofplatz, 8500 Frauenfeld"]
coords = ([start] + keys.map { |k| g[k] }).map { |la, lo| "#{lo},#{la}" }.join(";")
r = JSON.parse(`curl -s "https://router.project-osrm.org/table/v1/driving/#{coords}?sources=0&annotations=duration,distance"`)
res = {}
keys.each_with_index { |k, i| res[k] = {"km" => (r["distances"][0][i+1] / 1000.0).round, "fz" => (r["durations"][0][i+1] / 60.0).round} }
File.write("route.json", JSON.generate(res))
puts res.values.map { |v| v["fz"] }.minmax.inspect
puts res.sort_by { |k, v| -v["fz"] }.first(8).map { |k, v| "#{k}: #{v}" }
