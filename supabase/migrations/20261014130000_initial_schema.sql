-- RALLY MVP schema: matches, upload chunks, markers, and private video storage
create extension if not exists pgcrypto;

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  place text not null check (char_length(trim(place)) between 1 and 200),
  status text not null default 'draft'
    check (status in ('draft', 'recording', 'paused', 'uploading', 'complete')),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  upload_progress integer not null default 0 check (upload_progress between 0 and 100),
  played_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_players (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  position smallint not null check (position > 0),
  created_at timestamptz not null default now(),
  unique (match_id, position)
);

create table if not exists public.video_chunks (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  sequence_no integer not null check (sequence_no >= 0),
  started_at timestamptz not null,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  local_path text,
  storage_path text,
  upload_status text not null default 'pending'
    check (upload_status in ('pending', 'uploading', 'uploaded', 'failed')),
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (match_id, sequence_no)
);

create table if not exists public.match_markers (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  position_seconds integer not null check (position_seconds >= 0),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists matches_owner_created_idx
  on public.matches(owner_id, created_at desc);
create index if not exists video_chunks_match_sequence_idx
  on public.video_chunks(match_id, sequence_no);
create index if not exists match_markers_match_position_idx
  on public.match_markers(match_id, position_seconds);

alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.video_chunks enable row level security;
alter table public.match_markers enable row level security;

create policy "matches_owner_select" on public.matches
  for select to authenticated using (owner_id = auth.uid());
create policy "matches_owner_insert" on public.matches
  for insert to authenticated with check (owner_id = auth.uid());
create policy "matches_owner_update" on public.matches
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "matches_owner_delete" on public.matches
  for delete to authenticated using (owner_id = auth.uid());

create policy "match_players_owner_all" on public.match_players
  for all to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_players.match_id and m.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.matches m
    where m.id = match_players.match_id and m.owner_id = auth.uid()
  ));

create policy "video_chunks_owner_all" on public.video_chunks
  for all to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = video_chunks.match_id and m.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.matches m
    where m.id = video_chunks.match_id and m.owner_id = auth.uid()
  ));

create policy "match_markers_owner_all" on public.match_markers
  for all to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_markers.match_id and m.owner_id = auth.uid()
  ))
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_markers.match_id and m.owner_id = auth.uid()
    )
  );

insert into storage.buckets (id, name, public)
values ('match-videos', 'match-videos', false)
on conflict (id) do update set public = excluded.public;

create policy "match_videos_owner_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'match-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "match_videos_owner_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'match-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "match_videos_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'match-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'match-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "match_videos_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'match-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
