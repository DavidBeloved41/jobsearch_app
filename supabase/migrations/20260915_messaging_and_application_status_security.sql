-- Secure the two production paths that require server-authoritative identity.

alter table public.messages enable row level security;

drop policy if exists "Users can view their conversations" on public.messages;
create policy "Users can view their conversations"
  on public.messages for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Employers and job seekers can send messages" on public.messages;
create policy "Employers and job seekers can send messages"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and receiver_id <> auth.uid()
    and exists (
      select 1 from public.profiles sender_profile
      where sender_profile.id = auth.uid()
        and sender_profile.account_type in ('employer', 'job_seeker')
    )
    and exists (
      select 1 from public.profiles receiver_profile
      where receiver_profile.id = receiver_id
        and receiver_profile.account_type in ('employer', 'job_seeker')
    )
  );

drop policy if exists "Recipients can mark messages read" on public.messages;
create policy "Recipients can mark messages read"
  on public.messages for update
  to authenticated
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

revoke insert, update, delete on public.messages from anon;
grant select, insert, update on public.messages to authenticated;

create or replace function public.prevent_message_identity_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sender_id is distinct from old.sender_id
     or new.receiver_id is distinct from old.receiver_id
     or new.content is distinct from old.content then
    raise exception 'Message identity and content cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_message_identity on public.messages;
create trigger protect_message_identity
before update on public.messages
for each row execute function public.prevent_message_identity_changes();
revoke execute on function public.prevent_message_identity_changes() from public, anon, authenticated;

create or replace function public.employer_update_application_status(
  p_application_id uuid,
  p_status text
)
returns table (id uuid, status text)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  application_job_owner uuid;
  normalized_status text := lower(trim(p_status));
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

  return query
  update public.applications a
  set status = normalized_status
  where a.id = p_application_id
  returning a.id, a.status::text;
end;
$$;

revoke all on function public.employer_update_application_status(uuid, text)
  from public, anon;
grant execute on function public.employer_update_application_status(uuid, text)
  to authenticated;

create or replace function public.create_application_update_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  job_title text;
  notification_key text;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status::text not in
    ('applied', 'reviewing', 'interviewing', 'offered', 'rejected', 'declined') then
    return new;
  end if;

  select j.title into job_title from public.jobs j where j.id = new.job_id;
  notification_key := format('application_update:%s:%s', new.id, new.status::text);

  if exists (
    select 1 from public.profiles p
    where p.id = new.user_id
      and coalesce(p.notify_application_updates, true) = true
  ) then
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      new.user_id, 'application_update', 'Application update',
      format('Your application for %s has moved to %s.', coalesce(job_title, 'this job'), initcap(new.status::text)),
      new.id, false, notification_key
    ) on conflict (dedup_key) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists application_status_notification on public.applications;
create trigger application_status_notification
after update of status on public.applications
for each row execute function public.create_application_update_notification();
revoke execute on function public.create_application_update_notification() from public, anon, authenticated;
