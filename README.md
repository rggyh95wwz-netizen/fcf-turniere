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

## Trainer-Anmeldung pro Turnier
Im Trainer-Modus wählt jeder Trainer einmal seinen Namen (Menü ☰ → «👥 Trainer-Einsatz»; neue Trainer erfassen sich dort selbst). Danach:
- **Team-Tab → «👥 Trainer»:** Monatskalender mit allen Turnieren, die FCF angemeldet hat oder die markiert sind. Pro Turnier «✓ Ich kann hier» (mehrere Trainer pro Turnier).
- **Markieren mit Prio:** im 📅 Kalender / ☰ Liste bei jedem Turnier «☆ für Trainer markieren» bzw. Prio 1 (muss), 2 (wenn möglich), 3 (Option). Prio 1 ohne Trainer zeigt ⚠.
- **Kalender:** Team-Abos zeigen «Trainer: Vorname Nachname, …». Jeder Trainer hat ein eigenes Abo (`/kalender/trainer/<code>.ics`, Link im Menü). Aktualisierung alle 2 Std. tagsüber (`.github/workflows/kalender.yml`) und beim täglichen Abgleich.

**Speicher:** Datei `daten.json` in einem **privaten** GitHub-Repo. Die App schreibt direkt dorthin, mit einem Schlüssel, der nur für dieses eine Repo gilt. Der Schlüssel steckt verschlüsselt in `data/intern.enc.json` und ist nur mit dem Trainer-Passwort lesbar. Ohne Einrichtung bleibt die Funktion ausgeblendet.

Einrichtung (einmalig, alles auf github.com):
1. **Privates Repo** anlegen: github.com/new → Name `fcf-trainer-daten` → *Private* → Create (leer lassen, die App legt `daten.json` selbst an).
2. **Schlüssel** anlegen: Profilbild → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate new token. Name «FCF Trainer-App», Ablauf möglichst lang, *Repository access: Only select repositories* → `fcf-trainer-daten`, *Permissions → Contents: Read and write*. Token kopieren.
3. In **diesem** Repo (fcf-turniere) → Settings → Secrets and variables → Actions:
   - Tab *Secrets* → New repository secret `TRAINER_DATEN_TOKEN` = Token aus Schritt 2
   - Tab *Secrets* → New repository secret `TRAINER_PW` = das Trainer-Passwort der App
   - Tab *Variables* → New repository variable `TRAINER_DATEN_REPO` = `<dein-github-name>/fcf-trainer-daten`
4. Actions → **«Trainer-Zugang verschlüsseln»** → Run workflow. Danach ist «👥 Trainer» in der App sichtbar (nach Trainer-Login).

Schlüssel abgelaufen: neuen Token erzeugen, Secret `TRAINER_DATEN_TOKEN` ersetzen, Schritt 4 wiederholen. Trainer entfernen: in `daten.json` beim Trainer `"aktiv": false` setzen.
Hinweis: Wer das Trainer-Passwort hat, kann ins Daten-Repo schreiben (nur dort, nicht in die App).
