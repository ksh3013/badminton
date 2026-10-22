create table if not exists public.match_members (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'participant' check (role in ('participant', 'coach')),
  created_at timestamptz not null default now(),
  unique (match_id, user_id)
);

alter table public.match_members enable row level security;

create policy "match_members_self_or_owner_select" on public.match_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.matches m
      where m.id = match_members.match_id and m.owner_id = auth.uid()
    )
  );

create policy "match_members_owner_manage" on public.match_members
  for all to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_members.match_id and m.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.matches m
      where m.id = match_members.match_id and m.owner_id = auth.uid()
    )
  );

create or replace function public.is_match_member(target_match_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.match_members
    where match_id = target_match_id
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_match_member(uuid) from public;
grant execute on function public.is_match_member(uuid) to authenticated;

create policy "matches_member_select" on public.matches
  for select to authenticated
  using (public.is_match_member(id));

create policy "match_players_member_select" on public.match_players
  for select to authenticated
  using (public.is_match_member(match_id));

create policy "video_chunks_member_select" on public.video_chunks
  for select to authenticated
  using (public.is_match_member(match_id));

create policy "match_markers_member_select" on public.match_markers
  for select to authenticated
  using (public.is_match_member(match_id));

create policy "match_videos_member_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'match-videos'
    and public.is_match_member((storage.foldername(name))[2]::uuid)
  );
