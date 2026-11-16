# encoding: utf-8
# Verschlüsselt interne Daten (Budgets) für den Trainer-Modus -> data/intern.enc.json
# Aufruf:  TRAINER_PW='…' ruby pipeline/intern_encrypt.rb   (Passwort wird NICHT gespeichert)
# Optional für die Trainer-Anmeldung: TRAINER_DATEN_REPO='besitzer/fcf-trainer-daten' TRAINER_DATEN_TOKEN='github_pat_…'
# Einfacher: GitHub → Actions → «Trainer-Zugang verschlüsseln» (nimmt alles aus den Secrets).
require_relative "config"; require "openssl"; require "base64"
pw = ENV["TRAINER_PW"].to_s; abort "TRAINER_PW fehlt" if pw.empty?
intern = {
  "budgets" => {"FF-14" => 240, "D" => 960, "E" => 2880, "F" => 2160, "G" => 1620},
  "parts"   => {"D" => [["D7", 480], ["D9b", 240], ["D-Promotion", 240]]},
  "stand"   => "Budget Kinderfussball / 7er- und 9er-Fussball, Stand 14./15.11.2026"
}
repo = ENV["TRAINER_DATEN_REPO"].to_s.strip; tok = ENV["TRAINER_DATEN_TOKEN"].to_s.strip
intern["gh"] = {"repo" => repo, "token" => tok} if repo =~ %r{\A[\w.-]+/[\w.-]+\z} && !tok.empty?
salt = OpenSSL::Random.random_bytes(16); iv = OpenSSL::Random.random_bytes(16); iter = 150_000
key = OpenSSL::PKCS5.pbkdf2_hmac(pw, salt, iter, 32, OpenSSL::Digest::SHA256.new)
c = OpenSSL::Cipher.new("aes-256-cbc").encrypt; c.key = key; c.iv = iv
ct = c.update(JSON.generate(intern.merge("check" => "FCF"))) + c.final
b = ->(x) { Base64.strict_encode64(x) }
jwrite(File.join(DATA, "intern.enc.json"), {"v" => 1, "iter" => iter, "salt" => b.(salt), "iv" => b.(iv), "alg" => "AES-CBC", "ct" => b.(ct)}, true)
puts "intern.enc.json geschrieben (#{ct.bytesize} Bytes)#{intern['gh'] ? ", mit Zugang zu #{intern['gh']['repo']}" : ', ohne Trainer-Daten-Repo'}"
