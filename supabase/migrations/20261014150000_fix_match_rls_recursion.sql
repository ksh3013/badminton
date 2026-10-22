-- Avoid the matches <-> match_members policy cycle during member reads.
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

alter policy "matches_member_select" on public.matches
  using (public.is_match_member(id));

alter policy "match_players_member_select" on public.match_players
  using (public.is_match_member(match_id));

alter policy "video_chunks_member_select" on public.video_chunks
  using (public.is_match_member(match_id));

alter policy "match_markers_member_select" on public.match_markers
  using (public.is_match_member(match_id));

alter policy "match_videos_member_select" on storage.objects
  using (
    bucket_id = 'match-videos'
    and public.is_match_member((storage.foldername(name))[2]::uuid)
  );
