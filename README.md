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

## Trainer-Anmeldung pro Turnier (Supabase)
Im Trainer-Modus wählt jeder Trainer einmal seinen Namen und eine eigene PIN (Menü ☰ → «👥 Trainer-Einsatz»). Danach:
- **Team-Tab → «👥 Trainer»:** Monatskalender mit allen Turnieren, die FCF angemeldet hat oder die markiert sind. Pro Turnier «✓ Ich kann hier» (mehrere Trainer pro Turnier).
- **Markieren mit Prio:** im 📅 Kalender / ☰ Liste bei jedem Turnier «☆ für Trainer markieren» bzw. Prio 1 (muss), 2 (wenn möglich), 3 (Option). Prio 1 ohne Trainer zeigt ⚠.
- **Kalender:** Team-Abos zeigen «Trainer: Vorname Nachname, …». Jeder Trainer hat ein eigenes Abo (`/kalender/trainer/<code>.ics`, Link im Menü). Aktualisierung alle 2 Std. tagsüber (`.github/workflows/kalender.yml`) und beim täglichen Abgleich.

Ohne `data/supabase.json` bleibt die Funktion ausgeblendet. Einrichtung (einmalig):
1. Auf [supabase.com](https://supabase.com) mit GitHub anmelden → **New project** (Region Europa, z.B. Zürich/Frankfurt; Gratis-Plan).
2. **SQL Editor** → Inhalt von `supabase/schema.sql` einfügen → **Run**.
3. **Table Editor → trainer → Insert row**: Vorname, Nachname, Teams (z.B. `{FF-11,FF-09}`). PIN leer lassen, die legt jeder beim ersten Login selbst fest.
4. **Project Settings → API Keys**: Project URL, *publishable* (anon) Schlüssel und *secret* (service_role) Schlüssel kopieren.
5. Im Repo die Datei `data/supabase.json` anlegen: `{"url": "https://<projekt>.supabase.co", "key": "<publishable-Schlüssel>"}` (öffentlich, darf ins Repo).
6. GitHub → Settings → Secrets and variables → Actions → zwei Secrets: `SUPABASE_URL` und `SUPABASE_SERVICE_KEY` (= secret-Schlüssel, **nie** ins Repo).
7. Actions → «Täglicher Abgleich» → Run workflow.

PIN vergessen: im Table Editor bei diesem Trainer `pin_hash` leeren. Trainer entfernen: `aktiv` auf false.
