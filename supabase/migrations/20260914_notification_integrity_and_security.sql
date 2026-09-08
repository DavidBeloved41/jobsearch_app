-- Harden event notifications and email delivery without trusting Flutter clients.
-- Notification recipients are always auth.users identities via user_id.

alter table if exists public.notifications
  add column if not exists dedup_key text;

create unique index if not exists notifications_dedup_key_unique
  on public.notifications(dedup_key)
  where dedup_key is not null;

alter table public.notifications enable row level security;

drop policy if exists "Users can view their own notifications" on public.notifications;
create policy "Users can view their own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can mark their own notifications read" on public.notifications;
create policy "Users can mark their own notifications read"
  on public.notifications for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke insert, delete, update on public.notifications from anon;
revoke insert, delete, update on public.notifications from authenticated;
grant select on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;

alter table public.notification_email_outbox enable row level security;
revoke all on public.notification_email_outbox from anon, authenticated;

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
  if new.status not in ('applied', 'interviewing', 'offered', 'declined') then return new; end if;

  select j.title into job_title from public.jobs j where j.id = new.job_id;
  notification_key := format('application_update:%s:%s', new.id, new.status);

  if exists (
    select 1 from public.profiles p
    where p.id = new.user_id
      and coalesce(p.notify_application_updates, true) = true
  ) then
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      new.user_id, 'application_update', 'Application update',
      format('Your application for %s has moved to %s.', coalesce(job_title, 'this job'), initcap(new.status)),
      new.id, false, notification_key
    ) on conflict (dedup_key) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.create_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  sender_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'Someone') into sender_name
  from public.profiles p where p.id = new.sender_id;

  if exists (
    select 1 from public.profiles p
    where p.id = new.receiver_id and coalesce(p.notify_messages, true) = true
  ) then
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      new.receiver_id, 'new_message', 'New message',
      format('You have a new message from %s.', coalesce(sender_name, 'someone')),
      new.id, false, format('new_message:%s', new.id)
    ) on conflict (dedup_key) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.create_job_alert_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  candidate record;
  job_text text;
begin
  if tg_op = 'UPDATE'
     and new.approval_status is not distinct from 'approved'
     and new.is_active is not distinct from true
     and old.approval_status is not distinct from 'approved'
     and old.is_active is not distinct from true then return new; end if;
  if new.approval_status <> 'approved' or new.is_active <> true then return new; end if;

  job_text := lower(concat_ws(' ', new.title, new.description, new.experience_level));
  for candidate in
    select p.id
    from public.profiles p
    left join public.job_seeker_profiles sp on sp.user_id = p.id
    where p.account_type = 'job_seeker'
      and coalesce(p.notify_job_alerts, true) = true
      and nullif(trim(p.job_title), '') is not null
      and job_text like '%' || lower(trim(p.job_title)) || '%'
      and (coalesce(sp.preferred_work_model, 'all') = 'all'
           or lower(coalesce(sp.preferred_work_model, 'all')) = lower(coalesce(new.work_model, '')))
      and (coalesce(sp.preferred_employment_type, 'all') = 'all'
           or lower(coalesce(sp.preferred_employment_type, 'all')) = lower(coalesce(new.employment_type, '')))
  loop
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      candidate.id, 'job_alert', 'New job matching your preferences',
      format('%s is now available.', new.title), new.id, false,
      format('job_alert:%s:%s', candidate.id, new.id)
    ) on conflict (dedup_key) do nothing;
  end loop;
  return new;
end;
$$;

create or replace function public.create_candidate_interest_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  recruiter_name text;
begin
  select coalesce(nullif(trim(full_name), ''), 'A recruiter') into recruiter_name
  from public.profiles where id = new.recruiter_id;

  insert into public.notifications
    (user_id, type, title, body, reference_id, is_read, dedup_key)
  values (
    new.candidate_id, 'recruiter_interest', 'Recruiter expressed interest',
    format('%s wants to connect about an opportunity.', recruiter_name),
    new.id, false, format('recruiter_interest:%s', new.id)
  ) on conflict (dedup_key) do nothing;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.candidate_interests') is not null then
    execute 'drop trigger if exists candidate_interest_notification on public.candidate_interests';
    execute 'create trigger candidate_interest_notification
      after insert on public.candidate_interests
      for each row execute function public.create_candidate_interest_notification()';
  end if;
end;
$$;

create or replace function public.queue_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  should_email boolean;
begin
  select coalesce(p.notify_email, true)
    and case new.type
      when 'job_alert' then coalesce(p.notify_job_alerts, true)
      when 'application_update' then coalesce(p.notify_application_updates, true)
      when 'new_message' then coalesce(p.notify_messages, true)
      else true
    end
    into should_email
  from public.profiles p where p.id = new.user_id;

  if should_email = true and exists (select 1 from auth.users u where u.id = new.user_id) then
    insert into public.notification_email_outbox (notification_id, recipient_id)
    values (new.id, new.user_id)
    on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;

revoke execute on function public.create_application_update_notification() from public, anon, authenticated;
revoke execute on function public.create_message_notification() from public, anon, authenticated;
revoke execute on function public.create_job_alert_notifications() from public, anon, authenticated;
revoke execute on function public.create_candidate_interest_notification() from public, anon, authenticated;
revoke execute on function public.queue_notification_email() from public, anon, authenticated;
