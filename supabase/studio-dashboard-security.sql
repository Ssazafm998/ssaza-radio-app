-- SSAZA FM Studio Dashboard: staff-only review permissions
-- Run after the Voice Connect intake setup.
-- Create staff users in Supabase Auth first, then add their UUIDs to voice_staff.

create table if not exists public.voice_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);

alter table public.voice_staff enable row level security;

drop policy if exists "Staff can view their own staff record" on public.voice_staff;
create policy "Staff can view their own staff record"
on public.voice_staff
for select
to authenticated
using (user_id = auth.uid());

grant select on public.voice_staff to authenticated;

-- Only authorised staff can read submissions.
drop policy if exists "Authorised staff can read voice submissions" on public.voice_submissions;
create policy "Authorised staff can read voice submissions"
on public.voice_submissions
for select
to authenticated
using (
  exists (
    select 1 from public.voice_staff
    where voice_staff.user_id = auth.uid()
  )
);

-- Staff can change only the status column (column-level grant below).
drop policy if exists "Authorised staff can update voice submission status" on public.voice_submissions;
create policy "Authorised staff can update voice submission status"
on public.voice_submissions
for update
to authenticated
using (
  exists (
    select 1 from public.voice_staff
    where voice_staff.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.voice_staff
    where voice_staff.user_id = auth.uid()
  )
  and status in ('pending','approved','rejected','archived')
);

grant select on public.voice_submissions to authenticated;
grant update (status) on public.voice_submissions to authenticated;

-- Private audio remains private. Only authorised staff can download/list objects.
drop policy if exists "Authorised staff can read voice note files" on storage.objects;
create policy "Authorised staff can read voice note files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'voice-notes'
  and (storage.foldername(name))[1] = 'submissions'
  and exists (
    select 1 from public.voice_staff
    where voice_staff.user_id = auth.uid()
  )
);

-- No public read policy is created. Existing anonymous upload policy remains unchanged.
