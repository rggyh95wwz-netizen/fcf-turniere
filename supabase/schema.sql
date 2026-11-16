-- FCF Turniere: Trainer-Anmeldung pro Turnier (Supabase / Postgres)
-- Einmal komplett im Supabase «SQL Editor» ausführen. Mehrfaches Ausführen ist unschädlich.
--
-- Datenschutz: Die Tabellen sind von aussen NICHT direkt lesbar/schreibbar (RLS ohne Policies).
-- Die Webseite benutzt nur die Funktionen fcf_* unten. Schreiben braucht eine Sitzung (Trainer + PIN).

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.trainer (
  id          uuid primary key default gen_random_uuid(),
  vorname     text not null,
  nachname    text not null,
  teams       text[] not null default '{}',          -- z.B. {FF-11,FF-09}: Vorauswahl in der App
  admin       boolean not null default false,
  aktiv       boolean not null default true,
  pin_hash    text,                                  -- leer = PIN wird beim ersten Login festgelegt
  fehl        int not null default 0,
  fehl_zeit   timestamptz,
  abo         text not null unique default encode(extensions.gen_random_bytes(10), 'hex')  -- Teil des Kalender-Abo-Links
);

create table if not exists public.sitzung (
  token       text primary key default encode(extensions.gen_random_bytes(24), 'hex'),
  trainer_id  uuid not null references public.trainer(id) on delete cascade,
  bis         timestamptz not null default now() + interval '180 days'
);

-- Markierung + Prio pro Turnier (1 = muss, 2 = wenn möglich, 3 = Option)
create table if not exists public.turnier_plan (
  tkey        text primary key,                      -- gleicher Schlüssel wie die UID im Kalender-Abo
  kat         text not null,
  prio        int not null check (prio between 1 and 3),
  von         uuid references public.trainer(id) on delete set null,
  geaendert   timestamptz not null default now()
);

-- «Ich kann hier»: mehrere Trainer pro Turnier
create table if not exists public.anmeldung (
  tkey        text not null,
  trainer_id  uuid not null references public.trainer(id) on delete cascade,
  kat         text not null,
  erstellt    timestamptz not null default now(),
  primary key (tkey, trainer_id)
);

alter table public.trainer      enable row level security;
alter table public.sitzung      enable row level security;
alter table public.turnier_plan enable row level security;
alter table public.anmeldung    enable row level security;
revoke all on public.trainer, public.sitzung, public.turnier_plan, public.anmeldung from anon, authenticated;

-- Lesen (öffentlich): Trainernamen, Markierungen, Anmeldungen. Keine PINs, keine Abo-Links.
create or replace function public.fcf_daten() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'trainer', (select coalesce(json_agg(json_build_object('id', id, 'name', vorname || ' ' || nachname, 'teams', teams, 'pin', pin_hash is not null) order by vorname, nachname), '[]'::json) from trainer where aktiv),
    'plan',    (select coalesce(json_object_agg(tkey, prio), '{}'::json) from turnier_plan),
    'anm',     (select coalesce(json_agg(json_build_object('k', a.tkey, 't', a.trainer_id) order by a.erstellt), '[]'::json) from anmeldung a join trainer t on t.id = a.trainer_id and t.aktiv)
  );
$$;

-- Login mit Trainer + PIN. Erster Login legt die PIN fest. Nach 8 Fehlversuchen 15 Min. Sperre.
create or replace function public.fcf_login(p_trainer uuid, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t trainer; tok text;
begin
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then return json_build_object('error', 'Die PIN hat 4 bis 8 Ziffern.'); end if;
  select * into t from trainer where id = p_trainer and aktiv;
  if not found then return json_build_object('error', 'Trainer nicht gefunden.'); end if;
  if t.fehl >= 8 and t.fehl_zeit > now() - interval '15 minutes' then
    return json_build_object('error', 'Zu viele Fehlversuche. Bitte in 15 Minuten nochmals versuchen.');
  end if;
  if t.pin_hash is null then
    update trainer set pin_hash = crypt(p_pin, gen_salt('bf')) where id = t.id;
  elsif t.pin_hash <> crypt(p_pin, t.pin_hash) then
    update trainer set fehl = case when fehl_zeit > now() - interval '15 minutes' then fehl + 1 else 1 end, fehl_zeit = now() where id = t.id;
    return json_build_object('error', 'PIN falsch.');
  end if;
  update trainer set fehl = 0, fehl_zeit = null where id = t.id;
  delete from sitzung where bis < now();
  insert into sitzung (trainer_id) values (t.id) returning token into tok;
  return json_build_object('token', tok, 'id', t.id, 'name', t.vorname || ' ' || t.nachname, 'abo', t.abo, 'admin', t.admin);
end $$;

create or replace function public.fcf_wer(p_token text) returns uuid
language sql stable security definer set search_path = public as $$
  select s.trainer_id from sitzung s join trainer t on t.id = s.trainer_id and t.aktiv where s.token = p_token and s.bis > now();
$$;

-- «Ich kann hier» an/aus
create or replace function public.fcf_anmelden(p_token text, p_tkey text, p_kat text, p_an boolean) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := fcf_wer(p_token);
begin
  if me is null then return json_build_object('error', 'Bitte neu anmelden (Trainer + PIN).'); end if;
  if length(coalesce(p_tkey, '')) not between 5 and 120 or length(coalesce(p_kat, '')) not between 1 and 20 then return json_build_object('error', 'Ungültiges Turnier.'); end if;
  if p_an then insert into anmeldung (tkey, trainer_id, kat) values (p_tkey, me, p_kat) on conflict do nothing;
  else delete from anmeldung where tkey = p_tkey and trainer_id = me; end if;
  return json_build_object('ok', true);
end $$;

-- Markieren mit Prio (1–3), null = Markierung entfernen
create or replace function public.fcf_prio(p_token text, p_tkey text, p_kat text, p_prio int) returns json
language plpgsql security definer set search_path = public as $$
declare me uuid := fcf_wer(p_token);
begin
  if me is null then return json_build_object('error', 'Bitte neu anmelden (Trainer + PIN).'); end if;
  if length(coalesce(p_tkey, '')) not between 5 and 120 or length(coalesce(p_kat, '')) not between 1 and 20 then return json_build_object('error', 'Ungültiges Turnier.'); end if;
  if p_prio is null then delete from turnier_plan where tkey = p_tkey;
  elsif p_prio between 1 and 3 then
    insert into turnier_plan (tkey, kat, prio, von) values (p_tkey, p_kat, p_prio, me)
    on conflict (tkey) do update set prio = excluded.prio, von = excluded.von, geaendert = now();
  else return json_build_object('error', 'Prio 1 bis 3.'); end if;
  return json_build_object('ok', true);
end $$;

create or replace function public.fcf_logout(p_token text) returns json
language sql security definer set search_path = public as $$
  delete from sitzung where token = p_token; select json_build_object('ok', true);
$$;

revoke all on function public.fcf_daten(), public.fcf_login(uuid, text), public.fcf_wer(text), public.fcf_anmelden(text, text, text, boolean), public.fcf_prio(text, text, text, int), public.fcf_logout(text) from public, anon, authenticated;
grant execute on function public.fcf_daten(), public.fcf_login(uuid, text), public.fcf_anmelden(text, text, text, boolean), public.fcf_prio(text, text, text, int), public.fcf_logout(text) to anon, authenticated;

-- Trainer erfassen (Beispiel, anpassen und ausführen; oder im «Table Editor» → trainer → Insert row):
-- insert into public.trainer (vorname, nachname, teams, admin) values
--   ('Vorname', 'Nachname', '{FF-11,FF-09}', true),
--   ('Anna', 'Muster', '{FF-11}', false);
-- PIN vergessen? Im Table Editor bei diesem Trainer pin_hash leeren → nächster Login legt neue PIN fest.
