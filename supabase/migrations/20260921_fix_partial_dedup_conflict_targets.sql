-- Fix the shared 42P10 failure in message/application transactions.
-- notifications_dedup_key_unique is partial (dedup_key IS NOT NULL), so every
-- dedup_key conflict target must include the same predicate.

create or replace function public.create_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  sender_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'Someone')
    into sender_name
  from public.profiles as p
  where p.id = new.sender_id;

  if exists (
    select 1
    from public.profiles as p
    where p.id = new.receiver_id
      and coalesce(p.notify_messages, true) = true
  ) then
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      new.receiver_id,
      'new_message',
      'New message',
      format('You have a new message from %s.', coalesce(sender_name, 'someone')),
      new.id,
      false,
      format('new_message:%s', new.id)
    )
    on conflict (dedup_key) where dedup_key is not null do nothing;
  end if;
  return new;
end;
$$;

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

  select j.title into job_title
  from public.jobs as j
  where j.id = new.job_id;

  notification_key := format('application_update:%s:%s', new.id, new.status::text);

  if exists (
    select 1
    from public.profiles as p
    where p.id = new.user_id
      and coalesce(p.notify_application_updates, true) = true
  ) then
    insert into public.notifications
      (user_id, type, title, body, reference_id, is_read, dedup_key)
    values (
      new.user_id,
      'application_update',
      'Application update',
      format(
        'Your application for %s has moved to %s.',
        coalesce(job_title, 'this job'),
        initcap(new.status::text)
      ),
      new.id,
      false,
      notification_key
    )
    on conflict (dedup_key) where dedup_key is not null do nothing;
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
     and old.is_active is not distinct from true then
    return new;
  end if;
  if new.approval_status <> 'approved' or new.is_active <> true then
    return new;
  end if;

  job_text := lower(concat_ws(' ', new.title, new.description, new.experience_level));
  for candidate in
    select p.id
    from public.profiles as p
    left join public.job_seeker_profiles as sp on sp.user_id = p.id
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
      candidate.id,
      'job_alert',
      'New job matching your preferences',
      format('%s is now available.', new.title),
      new.id,
      false,
      format('job_alert:%s:%s', candidate.id, new.id)
    )
    on conflict (dedup_key) where dedup_key is not null do nothing;
  end loop;
  return new;
end;
$$;

revoke execute on function public.create_message_notification() from public, anon, authenticated;
revoke execute on function public.create_application_update_notification() from public, anon, authenticated;
revoke execute on function public.create_job_alert_notifications() from public, anon, authenticated;
