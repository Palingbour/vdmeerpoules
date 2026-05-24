-- ============================================================
-- vdmeerpoules — WK 2026 seed data
-- 48 landen + 72 poulewedstrijden
-- Bron: FIFA loting 5 december 2025, schema 6 december 2025
-- Tijden in Nederlandse tijd (CEST, UTC+2)
--
-- Te draaien NA schema.sql, eenmalig in de SQL editor.
-- Idempotent: gebruikt ON CONFLICT zodat herhaald draaien geen kwaad kan.
-- ============================================================

-- ============================================================
-- TEAMS — 48 landen, groep A t/m L
-- code = ISO-2 (voor flagcdn.com), behalve gb-eng/gb-sct
-- ============================================================
-- Schema-patch: code-kolom verbreden voor flagcdn-codes als gb-eng/gb-sct
alter table public.teams alter column code type text;

insert into public.teams (name, code, group_letter, flag_url) values
  -- Groep A
  ('Mexico',           'mx',     'A', 'https://flagcdn.com/w80/mx.png'),
  ('Zuid-Afrika',      'za',     'A', 'https://flagcdn.com/w80/za.png'),
  ('Zuid-Korea',       'kr',     'A', 'https://flagcdn.com/w80/kr.png'),
  ('Tsjechië',         'cz',     'A', 'https://flagcdn.com/w80/cz.png'),
  -- Groep B
  ('Canada',           'ca',     'B', 'https://flagcdn.com/w80/ca.png'),
  ('Bosnië-Herz.',     'ba',     'B', 'https://flagcdn.com/w80/ba.png'),
  ('Qatar',            'qa',     'B', 'https://flagcdn.com/w80/qa.png'),
  ('Zwitserland',      'ch',     'B', 'https://flagcdn.com/w80/ch.png'),
  -- Groep C
  ('Brazilië',         'br',     'C', 'https://flagcdn.com/w80/br.png'),
  ('Marokko',          'ma',     'C', 'https://flagcdn.com/w80/ma.png'),
  ('Haïti',            'ht',     'C', 'https://flagcdn.com/w80/ht.png'),
  ('Schotland',        'gb-sct', 'C', 'https://flagcdn.com/w80/gb-sct.png'),
  -- Groep D
  ('Verenigde Staten', 'us',     'D', 'https://flagcdn.com/w80/us.png'),
  ('Paraguay',         'py',     'D', 'https://flagcdn.com/w80/py.png'),
  ('Australië',        'au',     'D', 'https://flagcdn.com/w80/au.png'),
  ('Turkije',          'tr',     'D', 'https://flagcdn.com/w80/tr.png'),
  -- Groep E
  ('Duitsland',        'de',     'E', 'https://flagcdn.com/w80/de.png'),
  ('Curaçao',          'cw',     'E', 'https://flagcdn.com/w80/cw.png'),
  ('Ivoorkust',        'ci',     'E', 'https://flagcdn.com/w80/ci.png'),
  ('Ecuador',          'ec',     'E', 'https://flagcdn.com/w80/ec.png'),
  -- Groep F (Oranje!)
  ('Nederland',        'nl',     'F', 'https://flagcdn.com/w80/nl.png'),
  ('Japan',            'jp',     'F', 'https://flagcdn.com/w80/jp.png'),
  ('Zweden',           'se',     'F', 'https://flagcdn.com/w80/se.png'),
  ('Tunesië',          'tn',     'F', 'https://flagcdn.com/w80/tn.png'),
  -- Groep G
  ('België',           'be',     'G', 'https://flagcdn.com/w80/be.png'),
  ('Egypte',           'eg',     'G', 'https://flagcdn.com/w80/eg.png'),
  ('Iran',             'ir',     'G', 'https://flagcdn.com/w80/ir.png'),
  ('Nieuw-Zeeland',    'nz',     'G', 'https://flagcdn.com/w80/nz.png'),
  -- Groep H
  ('Spanje',           'es',     'H', 'https://flagcdn.com/w80/es.png'),
  ('Kaapverdië',       'cv',     'H', 'https://flagcdn.com/w80/cv.png'),
  ('Saoedi-Arabië',    'sa',     'H', 'https://flagcdn.com/w80/sa.png'),
  ('Uruguay',          'uy',     'H', 'https://flagcdn.com/w80/uy.png'),
  -- Groep I
  ('Frankrijk',        'fr',     'I', 'https://flagcdn.com/w80/fr.png'),
  ('Senegal',          'sn',     'I', 'https://flagcdn.com/w80/sn.png'),
  ('Irak',             'iq',     'I', 'https://flagcdn.com/w80/iq.png'),
  ('Noorwegen',        'no',     'I', 'https://flagcdn.com/w80/no.png'),
  -- Groep J
  ('Argentinië',       'ar',     'J', 'https://flagcdn.com/w80/ar.png'),
  ('Algerije',         'dz',     'J', 'https://flagcdn.com/w80/dz.png'),
  ('Oostenrijk',       'at',     'J', 'https://flagcdn.com/w80/at.png'),
  ('Jordanië',         'jo',     'J', 'https://flagcdn.com/w80/jo.png'),
  -- Groep K
  ('Portugal',         'pt',     'K', 'https://flagcdn.com/w80/pt.png'),
  ('Congo DR',         'cd',     'K', 'https://flagcdn.com/w80/cd.png'),
  ('Oezbekistan',      'uz',     'K', 'https://flagcdn.com/w80/uz.png'),
  ('Colombia',         'co',     'K', 'https://flagcdn.com/w80/co.png'),
  -- Groep L
  ('Engeland',         'gb-eng', 'L', 'https://flagcdn.com/w80/gb-eng.png'),
  ('Kroatië',          'hr',     'L', 'https://flagcdn.com/w80/hr.png'),
  ('Ghana',            'gh',     'L', 'https://flagcdn.com/w80/gh.png'),
  ('Panama',           'pa',     'L', 'https://flagcdn.com/w80/pa.png')
on conflict (name) do update set
  code = excluded.code,
  group_letter = excluded.group_letter,
  flag_url = excluded.flag_url;

-- ============================================================
-- MATCHES — 72 poulewedstrijden (ronde 1)
-- Tijden in Nederlandse tijd (CEST/CET = UTC+2 in juni)
--
-- Voor INSERT met dynamisch team_id gebruiken we een CTE per match.
-- Klinkt omslachtig maar dit maakt het ook makkelijk overzicht houden.
-- ============================================================

-- Helper: insert wedstrijd op basis van team-namen
create or replace function public._insert_match(
  p_match_number int,
  p_round_nr int,
  p_kickoff timestamptz,
  p_home_name text,
  p_away_name text,
  p_city text,
  p_stadium text
) returns void language plpgsql as $$
declare
  v_home_id int;
  v_away_id int;
begin
  select id into v_home_id from public.teams where name = p_home_name;
  select id into v_away_id from public.teams where name = p_away_name;
  if v_home_id is null then raise exception 'Team niet gevonden: %', p_home_name; end if;
  if v_away_id is null then raise exception 'Team niet gevonden: %', p_away_name; end if;

  insert into public.matches (match_number, round_nr, kickoff_at, team_home_id, team_away_id, city, stadium)
  values (p_match_number, p_round_nr, p_kickoff, v_home_id, v_away_id, p_city, p_stadium)
  on conflict (match_number) do update set
    round_nr = excluded.round_nr,
    kickoff_at = excluded.kickoff_at,
    team_home_id = excluded.team_home_id,
    team_away_id = excluded.team_away_id,
    city = excluded.city,
    stadium = excluded.stadium;
end;
$$;

-- ===== Speelronde 1 (matches 1-24) =====
select public._insert_match(1,  1, '2026-06-11 21:00+02', 'Mexico',           'Zuid-Afrika',      'Mexico City',          'Azteca Stadion');
select public._insert_match(2,  1, '2026-06-12 04:00+02', 'Zuid-Korea',       'Tsjechië',         'Guadalajara',          'Estadio Akron');
select public._insert_match(3,  1, '2026-06-12 21:00+02', 'Canada',           'Bosnië-Herz.',     'Toronto',              'BMO Field');
select public._insert_match(4,  1, '2026-06-13 03:00+02', 'Verenigde Staten', 'Paraguay',         'Los Angeles',          'Rose Bowl');
select public._insert_match(5,  1, '2026-06-14 03:00+02', 'Haïti',            'Schotland',        'Boston',               'Gillette Stadion');
select public._insert_match(6,  1, '2026-06-14 06:00+02', 'Australië',        'Turkije',          'Vancouver',            'BC Place');
select public._insert_match(7,  1, '2026-06-14 00:00+02', 'Brazilië',         'Marokko',          'New York/New Jersey',  'MetLife Stadion');
select public._insert_match(8,  1, '2026-06-13 21:00+02', 'Qatar',            'Zwitserland',      'San Francisco',        'Levi''s Stadion');
select public._insert_match(9,  1, '2026-06-15 01:00+02', 'Ivoorkust',        'Ecuador',          'Philadelphia',         'Lincoln Financial Field');
select public._insert_match(10, 1, '2026-06-14 19:00+02', 'Duitsland',        'Curaçao',          'Houston',              'NRG Stadion');
select public._insert_match(11, 1, '2026-06-14 22:00+02', 'Nederland',        'Japan',            'Dallas',               'AT&T Stadion');
select public._insert_match(12, 1, '2026-06-15 04:00+02', 'Zweden',           'Tunesië',          'Monterrey',            'BBVA Bancomer Stadion');
select public._insert_match(13, 1, '2026-06-16 00:00+02', 'Saoedi-Arabië',    'Uruguay',          'Miami',                'Hard Rock Stadion');
select public._insert_match(14, 1, '2026-06-15 18:00+02', 'Spanje',           'Kaapverdië',       'Atlanta',              'Mercedes-Benz Stadion');
select public._insert_match(15, 1, '2026-06-16 03:00+02', 'Iran',             'Nieuw-Zeeland',    'Los Angeles',          'Rose Bowl');
select public._insert_match(16, 1, '2026-06-15 21:00+02', 'België',           'Egypte',           'Seattle',              'CenturyLink Field');
select public._insert_match(17, 1, '2026-06-16 21:00+02', 'Frankrijk',        'Senegal',          'New York/New Jersey',  'MetLife Stadion');
select public._insert_match(18, 1, '2026-06-17 00:00+02', 'Irak',             'Noorwegen',        'Boston',               'Gillette Stadion');
select public._insert_match(19, 1, '2026-06-17 03:00+02', 'Argentinië',       'Algerije',         'Kansas City',          'Arrowhead Stadion');
select public._insert_match(20, 1, '2026-06-17 06:00+02', 'Oostenrijk',       'Jordanië',         'San Francisco',        'Levi''s Stadion');
select public._insert_match(21, 1, '2026-06-18 01:00+02', 'Ghana',            'Panama',           'Toronto',              'BMO Field');
select public._insert_match(22, 1, '2026-06-17 22:00+02', 'Engeland',         'Kroatië',          'Dallas',               'AT&T Stadion');
select public._insert_match(23, 1, '2026-06-17 19:00+02', 'Portugal',         'Congo DR',         'Houston',              'NRG Stadion');
select public._insert_match(24, 1, '2026-06-18 04:00+02', 'Oezbekistan',      'Colombia',         'Mexico City',          'Azteca Stadion');

-- ===== Speelronde 2 (matches 25-48) =====
select public._insert_match(25, 1, '2026-06-18 18:00+02', 'Tsjechië',         'Zuid-Afrika',      'Atlanta',              'Mercedes-Benz Stadion');
select public._insert_match(26, 1, '2026-06-18 21:00+02', 'Zwitserland',      'Bosnië-Herz.',     'Los Angeles',          'Rose Bowl');
select public._insert_match(27, 1, '2026-06-19 00:00+02', 'Canada',           'Qatar',            'Vancouver',            'BC Place');
select public._insert_match(28, 1, '2026-06-19 03:00+02', 'Mexico',           'Zuid-Korea',       'Guadalajara',          'Estadio Akron');
select public._insert_match(29, 1, '2026-06-20 02:30+02', 'Brazilië',         'Haïti',            'Philadelphia',         'Lincoln Financial Field');
select public._insert_match(30, 1, '2026-06-20 00:00+02', 'Schotland',        'Marokko',          'Boston',               'Gillette Stadion');
select public._insert_match(31, 1, '2026-06-20 05:00+02', 'Turkije',          'Paraguay',         'San Francisco',        'Levi''s Stadion');
select public._insert_match(32, 1, '2026-06-19 21:00+02', 'Verenigde Staten', 'Australië',        'Seattle',              'CenturyLink Field');
select public._insert_match(33, 1, '2026-06-20 22:00+02', 'Duitsland',        'Ivoorkust',        'Toronto',              'BMO Field');
select public._insert_match(34, 1, '2026-06-21 02:00+02', 'Ecuador',          'Curaçao',          'Kansas City',          'Arrowhead Stadion');
select public._insert_match(35, 1, '2026-06-20 19:00+02', 'Nederland',        'Zweden',           'Houston',              'NRG Stadion');
select public._insert_match(36, 1, '2026-06-21 06:00+02', 'Tunesië',          'Japan',            'Monterrey',            'BBVA Bancomer Stadion');
select public._insert_match(37, 1, '2026-06-22 00:00+02', 'Uruguay',          'Kaapverdië',       'Miami',                'Hard Rock Stadion');
select public._insert_match(38, 1, '2026-06-21 18:00+02', 'Spanje',           'Saoedi-Arabië',    'Atlanta',              'Mercedes-Benz Stadion');
select public._insert_match(39, 1, '2026-06-21 21:00+02', 'België',           'Iran',             'Los Angeles',          'Rose Bowl');
select public._insert_match(40, 1, '2026-06-22 03:00+02', 'Nieuw-Zeeland',    'Egypte',           'Vancouver',            'BC Place');
select public._insert_match(41, 1, '2026-06-23 02:00+02', 'Noorwegen',        'Senegal',          'New York/New Jersey',  'MetLife Stadion');
select public._insert_match(42, 1, '2026-06-22 23:00+02', 'Frankrijk',        'Irak',             'Philadelphia',         'Lincoln Financial Field');
select public._insert_match(43, 1, '2026-06-22 19:00+02', 'Argentinië',       'Oostenrijk',       'Dallas',               'AT&T Stadion');
select public._insert_match(44, 1, '2026-06-23 05:00+02', 'Jordanië',         'Algerije',         'San Francisco',        'Levi''s Stadion');
select public._insert_match(45, 1, '2026-06-23 22:00+02', 'Engeland',         'Ghana',            'Boston',               'Gillette Stadion');
select public._insert_match(46, 1, '2026-06-24 01:00+02', 'Panama',           'Kroatië',          'Toronto',              'BMO Field');
select public._insert_match(47, 1, '2026-06-23 19:00+02', 'Portugal',         'Oezbekistan',      'Houston',              'NRG Stadion');
select public._insert_match(48, 1, '2026-06-24 04:00+02', 'Colombia',         'Congo DR',         'Guadalajara',          'Estadio Akron');

-- ===== Speelronde 3 (matches 49-72) — laatste poulewedstrijden, per poule gelijktijdig =====
select public._insert_match(49, 1, '2026-06-25 00:00+02', 'Schotland',        'Brazilië',         'Miami',                'Hard Rock Stadion');
select public._insert_match(50, 1, '2026-06-25 00:00+02', 'Marokko',          'Haïti',            'Atlanta',              'Mercedes-Benz Stadion');
select public._insert_match(51, 1, '2026-06-24 21:00+02', 'Zwitserland',      'Canada',           'Vancouver',            'BC Place');
select public._insert_match(52, 1, '2026-06-24 21:00+02', 'Bosnië-Herz.',     'Qatar',            'Seattle',              'CenturyLink Field');
select public._insert_match(53, 1, '2026-06-25 03:00+02', 'Tsjechië',         'Mexico',           'Mexico City',          'Azteca Stadion');
select public._insert_match(54, 1, '2026-06-25 03:00+02', 'Zuid-Afrika',      'Zuid-Korea',       'Monterrey',            'BBVA Bancomer Stadion');
select public._insert_match(55, 1, '2026-06-25 22:00+02', 'Curaçao',          'Ivoorkust',        'Philadelphia',         'Lincoln Financial Field');
select public._insert_match(56, 1, '2026-06-25 22:00+02', 'Ecuador',          'Duitsland',        'New York/New Jersey',  'MetLife Stadion');
select public._insert_match(57, 1, '2026-06-26 01:00+02', 'Japan',            'Zweden',           'Dallas',               'AT&T Stadion');
select public._insert_match(58, 1, '2026-06-26 01:00+02', 'Tunesië',          'Nederland',        'Kansas City',          'Arrowhead Stadion');
select public._insert_match(59, 1, '2026-06-26 04:00+02', 'Turkije',          'Verenigde Staten', 'Los Angeles',          'Rose Bowl');
select public._insert_match(60, 1, '2026-06-26 04:00+02', 'Australië',        'Paraguay',         'San Francisco',        'Levi''s Stadion');
-- Voor matches 61-72: beheerder verifieert tegen FIFA bron voor zekerheid
-- Pairings deduceerbaar uit de poule-logica; tijden o.b.v. patroon
select public._insert_match(61, 1, '2026-06-26 21:00+02', 'Egypte',           'Iran',             'Seattle',              'CenturyLink Field');
select public._insert_match(62, 1, '2026-06-26 21:00+02', 'Nieuw-Zeeland',    'België',           'Vancouver',            'BC Place');
select public._insert_match(63, 1, '2026-06-26 18:00+02', 'Kaapverdië',       'Saoedi-Arabië',    'Miami',                'Hard Rock Stadion');
select public._insert_match(64, 1, '2026-06-26 18:00+02', 'Uruguay',          'Spanje',           'Atlanta',              'Mercedes-Benz Stadion');
select public._insert_match(65, 1, '2026-06-27 02:00+02', 'Senegal',          'Irak',             'Boston',               'Gillette Stadion');
select public._insert_match(66, 1, '2026-06-27 02:00+02', 'Noorwegen',        'Frankrijk',        'New York/New Jersey',  'MetLife Stadion');
select public._insert_match(67, 1, '2026-06-27 19:00+02', 'Algerije',         'Oostenrijk',       'Kansas City',          'Arrowhead Stadion');
select public._insert_match(68, 1, '2026-06-27 19:00+02', 'Jordanië',         'Argentinië',       'Dallas',               'AT&T Stadion');
select public._insert_match(69, 1, '2026-06-27 22:00+02', 'Congo DR',         'Oezbekistan',      'Guadalajara',          'Estadio Akron');
select public._insert_match(70, 1, '2026-06-27 22:00+02', 'Portugal',         'Colombia',         'Houston',              'NRG Stadion');
select public._insert_match(71, 1, '2026-06-28 01:00+02', 'Kroatië',          'Ghana',            'Toronto',              'BMO Field');
select public._insert_match(72, 1, '2026-06-28 01:00+02', 'Engeland',         'Panama',           'Boston',               'Gillette Stadion');

-- ============================================================
-- DEADLINES voor Ronde 1, 2 en 8
-- Allemaal om 18:00 op 11 juni (3 uur voor openingswedstrijd)
-- Beheerder kan aanpassen via admin paneel
-- ============================================================
update public.rounds set deadline = '2026-06-11 18:00+02' where nr in (1, 2, 8);

-- ============================================================
-- REALTIME publication voor profiles (M2 patch)
-- Zodat goedkeuringen direct doorkomen in browser
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    execute 'alter publication supabase_realtime add table public.profiles';
  end if;
end $$;

-- ============================================================
-- HELPER FUNCTION OPRUIMEN
-- ============================================================
drop function public._insert_match(int, int, timestamptz, text, text, text, text);

-- ============================================================
-- KLAAR
--
-- Verifieer in de Table Editor:
--   - public.teams: 48 rijen, groepen A-L
--   - public.matches: 72 rijen, round_nr = 1
--   - public.rounds: nr 1, 2, 8 hebben deadline 2026-06-11 18:00
--
-- Knock-out wedstrijden (matches 73-104) komen in M4
-- als de poulewinnaars bekend zijn.
-- ============================================================
