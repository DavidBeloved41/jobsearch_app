-- Return only the identity needed by an authorized messaging participant.
-- This lets job seekers see an employer logo without exposing employer profiles
-- to unrelated clients.

create or replace function public.get_messaging_participant(participant_id uuid)
returns table (
  id uuid,
  full_name text,
  headline text,
  job_title text,
  company_name text,
  profile_photo_url text,
  logo_url text,
  account_type text
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.full_name,
    null::text as headline,
    p.job_title,
    ep.company_name,
    p.profile_photo_url,
    ep.logo_url,
    p.account_type
  from public.profiles p
  left join public.employer_profiles ep on ep.user_id = p.id
  where p.id = participant_id
    and (
      auth.uid() = p.id
      or exists (
        select 1
        from public.messages m
        where (m.sender_id = auth.uid() and m.receiver_id = participant_id)
           or (m.sender_id = participant_id and m.receiver_id = auth.uid())
      )
      or exists (
        select 1
        from public.profiles caller
        where caller.id = auth.uid()
          and caller.account_type = 'employer'
          and p.account_type = 'job_seeker'
          and p.is_open_to_work = true
      )
      or exists (
        select 1
        from public.profiles caller
        join public.applications a on a.user_id = caller.id
        join public.jobs j on j.id = a.job_id
        where caller.id = auth.uid()
          and caller.account_type = 'job_seeker'
          and j.poster_id = participant_id
      )
    );
$$;

grant execute on function public.get_messaging_participant(uuid) to authenticated;