-- Fix the two runtime paths without weakening authorization.
-- The RPCs keep authorization checks explicit and retain existing RLS policies.

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
  if sender_id is null then
    raise exception 'Authentication required';
  end if;
  if p_receiver_id is null or p_receiver_id = sender_id then
    raise exception 'A valid other participant is required';
  end if;
  if normalized_content = '' then
    raise exception 'Message content is required';
  end if;

  select p.account_type into sender_role
  from public.profiles p
  where p.id = sender_id;

  select p.account_type into receiver_role
  from public.profiles p
  where p.id = p_receiver_id;

  if sender_role not in ('employer', 'job_seeker')
     or receiver_role not in ('employer', 'job_seeker')
     or sender_role = receiver_role then
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
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if normalized_status not in
    ('applied', 'reviewing', 'interviewing', 'offered', 'rejected', 'declined') then
    raise exception 'Invalid application status';
  end if;

  select j.poster_id into application_job_owner
  from public.applications a
  join public.jobs j on j.id = a.job_id
  join public.profiles p on p.id = auth.uid()
  where a.id = p_application_id
    and j.poster_id = auth.uid()
    and p.account_type = 'employer';

  if application_job_owner is null then
    raise exception 'Not authorized to update this application';
  end if;

  select format('%I.%I', n.nspname, t.typname)
    into status_type
  from pg_attribute a
  join pg_type t on t.oid = a.atttypid
  join pg_namespace n on n.oid = t.typnamespace
  where a.attrelid = 'public.applications'::regclass
    and a.attname = 'status'
    and not a.attisdropped;

  if status_type is null then
    raise exception 'Application status column is not available';
  end if;

  execute format(
    'update public.applications
     set status = $1::%s
     where id = $2
     returning id, status::text',
    status_type
  ) into updated_id, updated_status
  using normalized_status, p_application_id;

  if updated_id is null then
    raise exception 'Application was not found';
  end if;

  id := updated_id;
  status := updated_status;
  return next;
end;
$$;

revoke all on function public.employer_update_application_status(uuid, text)
  from public, anon;
grant execute on function public.employer_update_application_status(uuid, text)
  to authenticated;
