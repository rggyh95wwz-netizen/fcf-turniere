#!/usr/bin/env bash
# Kompletter Abgleich: turnieragenda.ch -> Datenbank -> Webseite
set -euo pipefail
cd "$(dirname "$0")"
export LANG=en_US.UTF-8
R="ruby -E UTF-8"
$R fetch.rb
$R parse.rb
$R filt_all.rb
$R geo.rb
$R route.rb
$R kt.rb
$R regl.rb
$R data_all.rb
$R db.rb
$R build.rb
$R ics.rb
