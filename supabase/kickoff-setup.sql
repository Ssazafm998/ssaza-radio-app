-- KICKOFF 99.8 public football centre
-- Run in the existing SSAZAFM-NEWSROOM Supabase SQL Editor.
-- Public visitors can read fixtures, predictions and results.
-- Only trusted server-side jobs using the service role should insert/update data.
create extension if not exists pgcrypto;

create table if not exists public.football_matches (
  id uuid primary key default gen_random_uuid(),
  provider_match_id text unique,
  competition text not null,
  home_team text not null,
  away_team text not null,
  kickoff_at timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled','live','half_time','finished','postponed','cancelled','abandoned')),
  home_score integer,
  away_score integer,
  source_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.football_predictions (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.football_matches(id) on delete cascade,
  home_win_pct numeric(5,2) not null check (home_win_pct between 0 and 100),
  draw_pct numeric(5,2) not null check (draw_pct between 0 and 100),
  away_win_pct numeric(5,2) not null check (away_win_pct between 0 and 100),
  predicted_outcome text not null check (predicted_outcome in ('home','draw','away')),
  over_2_5_pct numeric(5,2) check (over_2_5_pct between 0 and 100),
  btts_pct numeric(5,2) check (btts_pct between 0 and 100),
  explanation text,
  model_version text,
  generated_at timestamptz not null default now(),
  check (abs(home_win_pct + draw_pct + away_win_pct - 100) <= 1.00)
);

create index if not exists football_matches_kickoff_idx on public.football_matches(kickoff_at);
create index if not exists football_matches_status_idx on public.football_matches(status);
create index if not exists football_predictions_generated_idx on public.football_predictions(generated_at desc);

alter table public.football_matches enable row level security;
alter table public.football_predictions enable row level security;

drop policy if exists "Anyone can read football matches" on public.football_matches;
create policy "Anyone can read football matches" on public.football_matches
for select to anon, authenticated using (true);

drop policy if exists "Anyone can read football predictions" on public.football_predictions;
create policy "Anyone can read football predictions" on public.football_predictions
for select to anon, authenticated using (true);

grant select on public.football_matches to anon, authenticated;
grant select on public.football_predictions to anon, authenticated;
-- No anonymous write policies or grants: automation must run server-side.
