# encoding: utf-8
# Reglement-PDFs nur für neue Turniere laden und als Text speichern (pdftotext auf Linux, PDFKit auf macOS)
require_relative "config"
dir = File.join(CACHE, "regl"); FileUtils.mkdir_p(dir)
n = 0
File.readlines(File.join(CACHE, "rg.txt"), encoding: "UTF-8").each do |l|
  id, url = l.split(" ", 2); next unless url
  txt = File.join(dir, "#{id}.txt"); next if File.exist?(txt)
  pdf = File.join(CACHE, "tmp.pdf")
  begin
    http_get(url.strip, pdf)
    out = if system("which pdftotext > /dev/null 2>&1")
      IO.popen(["pdftotext", "-layout", pdf, "-"], &:read)
    else
      IO.popen(["osascript", "-l", "JavaScript", File.join(__dir__, "pdf2txt.js"), pdf], &:read)
    end
    File.write(txt, out.to_s.scrub("")); n += 1
  rescue => e
    warn "Reglement #{id}: #{e.message}"; File.write(txt, "")
  end
  sleep 0.25
end
puts "Reglemente neu: #{n}"
