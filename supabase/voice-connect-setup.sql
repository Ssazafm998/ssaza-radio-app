-- SSAZA FM Voice Connect: first-version Supabase setup
-- Run this in the SQL Editor of the existing SSAZAFM-NEWSROOM project.
-- This creates a private audio bucket and a public submission-only intake.
-- No anonymous read, list, update, or delete access is granted.

create extension if not exists pgcrypto;

create table if not exists public.voice_submissions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 70),
  location text not null check (char_length(location) between 1 and 90),
  category text not null check (category in ('Greeting','Birthday wish','Song request','Dedication','Shout-out','Other')),
  message text,
  file_path text not null unique,
  mime_type text,
  duration_seconds integer not null check (duration_seconds between 1 and 120),
  status text not null default 'pending' check (status = 'pending'),
  consent boolean not null default false check (consent = true),
  created_at timestamptz not null default now()
);

alter table public.voice_submissions enable row level security;

drop policy if exists "Public can submit pending voice messages" on public.voice_submissions;
create policy "Public can submit pending voice messages"
on public.voice_submissions
for insert
to anon, authenticated
with check (
  status = 'pending'
  and consent = true
  and duration_seconds between 1 and 120
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'voice-notes',
  'voice-notes',
  false,
  26214400,
  array['audio/webm','audio/mp4','audio/mpeg','audio/ogg','audio/wav','audio/x-wav','audio/aac','audio/mp4a-latm']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 26214400,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can upload voice note files" on storage.objects;
create policy "Public can upload voice note files"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'voice-notes'
  and (storage.foldername(name))[1] = 'submissions'
);

-- Deliberately no public SELECT policy: listeners cannot view or download submissions.
-- The studio review dashboard will be added with authenticated staff access in the next phase.
