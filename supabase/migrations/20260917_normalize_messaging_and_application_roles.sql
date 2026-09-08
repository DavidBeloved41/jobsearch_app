-- Existing profiles may contain legacy role values (recruiter/candidate).
-- Match the app's canonical role normalization without broadening authorization.

alter table public.messages enable row level security;

drop policy if exists "Employers and job seekers can send messages" on public.messages;
create policy "Employers and job seekers can send messages"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and receiver_id <> auth.uid()
    and lower(trim((
      select sender_profile.account_type
      from public.profiles sender_profile
      where sender_profile.id = auth.uid()
    ))) in ('employer', 'recruiter', 'job_seeker', 'job seeker', 'jobseeker', 'candidate')
    and lower(trim((
      select receiver_profile.account_type
      from public.profiles receiver_profile
      where receiver_profile.id = receiver_id
    ))) in ('employer', 'recruiter', 'job_seeker', 'job seeker', 'jobseeker', 'candidate')
    and (
      lower(trim((select sender_profile.account_type from public.profiles sender_profile where sender_profile.id = auth.uid())))
        in ('employer', 'recruiter')
      and lower(trim((select receiver_profile.account_type from public.profiles receiver_profile where receiver_profile.id = receiver_id)))
        in ('job_seeker', 'job seeker', 'jobseeker', 'candidate')
      or
      lower(trim((select sender_profile.account_type from public.profiles sender_profile where sender_profile.id = auth.uid())))
        in ('job_seeker', 'job seeker', 'jobseeker', 'candidate')
      and lower(trim((select receiver_profile.account_type from public.profiles receiver_profile where receiver_profile.id = receiver_id)))
        in ('employer', 'recruiter')
    )
  );

create or replace function public.send_message(
  p_receiver_id uuid,
  p_content text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  sender_id uuid := auth.uid();
  inserted_message jsonb;
  sender_role text;
  receiver_role text;
  normalized_content text := trim(coalesce(p_content, ''));
begin
  if sender_id is null then raise exception 'Authentication required'; end if;
  if p_receiver_id is null or p_receiver_id = sender_id then
    raise exception 'A valid other participant is required';
  end if;
  if normalized_content = '' then raise exception 'Message content is required'; end if;

  select lower(trim(p.account_type)) into sender_role
  from public.profiles p where p.id = sender_id;
  select lower(trim(p.account_type)) into receiver_role
  from public.profiles p where p.id = p_receiver_id;

  if sender_role in ('employer', 'recruiter')
     and receiver_role in ('job_seeker', 'job seeker', 'jobseeker', 'candidate')
     or sender_role in ('job_seeker', 'job seeker', 'jobseeker', 'candidate')
     and receiver_role in ('employer', 'recruiter') then
    null;
  else
    raise exception 'Only employer and job seeker conversations are allowed';
  end if;

  insert into public.messages (sender_id, receiver_id, content)
  values (sender_id, p_receiver_id, normalized_content)
  returning to_jsonb(messages.*) into inserted_message;
  return inserted_message;
end;
$$;

revoke all on function public.send_message(uuid, text) from public, anon;
grant execute on function public.send_message(uuid, text) to authenticated;

create or replace function public.employer_update_application_status(
  p_application_id uuid,
  p_status text
)
returns table (id uuid, status text)
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  application_job_owner uuid;
  normalized_status text := lower(trim(coalesce(p_status, '')));
  status_type text;
  updated_id uuid;
  updated_status text;
  caller_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_status not in
    ('applied', 'reviewing', 'interviewing', 'offered', 'rejected', 'declined') then
    raise exception 'Invalid application status';
  end if;

  select lower(trim(p.account_type)) into caller_role
  from public.profiles p where p.id = auth.uid();
  if caller_role not in ('employer', 'recruiter') then
    raise exception 'Not authorized to update this application';
  end if;

  select j.poster_id into application_job_owner
  from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.id = p_application_id and j.poster_id = auth.uid();
  if application_job_owner is null then
    raise exception 'Not authorized to update this application';
  end if;

  select format('%I.%I', n.nspname, t.typname) into status_type
  from pg_attribute a
  join pg_type t on t.oid = a.atttypid
  join pg_namespace n on n.oid = t.typnamespace
  where a.attrelid = 'public.applications'::regclass
    and a.attname = 'status' and not a.attisdropped;
  if status_type is null then raise exception 'Application status column is not available'; end if;

  execute format(
    'update public.applications set status = $1::%s where id = $2 returning id, status::text',
    status_type
  ) into updated_id, updated_status using normalized_status, p_application_id;
  if updated_id is null then raise exception 'Application was not found'; end if;

  id := updated_id;
  status := updated_status;
  return next;
end;
$$;

revoke all on function public.employer_update_application_status(uuid, text) from public, anon;
grant execute on function public.employer_update_application_status(uuid, text) to authenticated;
