# FCF Turniere

Turnierplanung FC Frauenfeld (Kinderfussball): Turniere aus turnieragenda.ch für die Teams FF-14, FF-11, FF-09, D, E, F, G – Halle und Aussen, Ostschweiz und Kanton Zürich (Ausnahme: Swiss Girls Cup Bern für die Mädchen).

- **Webseite:** `docs/index.html` (über GitHub Pages veröffentlicht, auf dem Handy «Zum Home-Bildschirm»)
- **Täglicher Abgleich:** `.github/workflows/abgleich.yml` startet jeden Morgen `pipeline/run.sh`
- **Datenbank:** `data/db.json` – alle je gesehenen Ausschreibungen. Neue kommen dazu, bestehende werden aktualisiert, vergangene bleiben als «vorbei», verschwundene als «entfernt». `data/snapshots/` enthält pro Tag Plätze/Teams/Status (Verlauf).
- **Handrecherche:** `data/extras.json` (Modus/Bemerkungen, Hallen-Infos) wird bei jedem Abgleich wieder eingespielt.

## Ablauf `pipeline/run.sh`
1. `fetch.rb` – Suche je Kategorie (Region, nächste 10 Monate) und Turnierseiten laden
2. `parse.rb` – Turnierseiten auslesen
3. `filt_all.rb` – Kategorien den Teams zuordnen
4. `geo.rb`, `route.rb`, `kt.rb` – Ort, Fahrzeit ab Bahnhof Frauenfeld, Kanton (nur neue Adressen)
5. `regl.rb` – Reglement-PDFs neuer Turniere als Text
6. `data_all.rb` – Ausschreibungen mit Spielzeit, Stärkeklasse, Besonderheiten
7. `db.rb` – Datenbank fortschreiben + Schnappschuss (bricht ab, wenn der Abgleich verdächtig wenig liefert)
8. `build.rb` – Webseite bauen

Lokal: `./pipeline/run.sh` (Ruby ≥ 2.6, curl; auf Linux zusätzlich `pdftotext`).

Hinweis: höchstens ein Abgleich pro Tag, mit Pausen zwischen den Abrufen. Freie Plätze vor der Anmeldung immer auf turnieragenda.ch prüfen.
