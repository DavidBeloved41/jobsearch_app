-- Event-driven in-app notifications for the existing notifications table.
-- SECURITY DEFINER keeps clients from fabricating notifications for other users.
-- No new tables or columns are introduced.

create or replace function public.create_application_update_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  job_title text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status not in ('applied', 'interviewing', 'offered', 'declined') then
    return new;
  end if;

  select j.title into job_title
  from public.jobs j
  where j.id = new.job_id;

  if exists (
    select 1 from public.profiles p
    where p.id = new.user_id
      and coalesce(p.notify_application_updates, true) = true
  ) then
    insert into public.notifications (user_id, type, title, body, reference_id, is_read)
    values (
      new.user_id,
      'application_update',
      'Application update',
      format('Your application for %s has moved to %s.', coalesce(job_title, 'this job'), initcap(new.status)),
      new.id,
      false
    );
  end if;

  return new;
end;
$$;

drop trigger if exists application_status_notification on public.applications;
create trigger application_status_notification
after update of status on public.applications
for each row execute function public.create_application_update_notification();

create or replace function public.create_message_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'Someone') into sender_name
  from public.profiles p
  where p.id = new.sender_id;

  if exists (
    select 1 from public.profiles p
    where p.id = new.receiver_id
      and coalesce(p.notify_messages, true) = true
  ) then
    insert into public.notifications (user_id, type, title, body, reference_id, is_read)
    values (
      new.receiver_id,
      'new_message',
      'New message',
      format('You have a new message from %s.', coalesce(sender_name, 'someone')),
      new.id,
      false
    );
  end if;

  return new;
end;
$$;

drop trigger if exists message_notification on public.messages;
create trigger message_notification
after insert on public.messages
for each row execute function public.create_message_notification();

create or replace function public.create_job_alert_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
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
    select p.id, p.job_title
    from public.profiles p
    left join public.job_seeker_profiles sp on sp.user_id = p.id
    where p.account_type = 'job_seeker'
      and coalesce(p.notify_job_alerts, true) = true
      and (coalesce(sp.preferred_work_model, 'all') = 'all'
           or lower(coalesce(sp.preferred_work_model, 'all')) = lower(coalesce(new.work_model, '')))
      and (coalesce(sp.preferred_employment_type, 'all') = 'all'
           or lower(coalesce(sp.preferred_employment_type, 'all')) = lower(coalesce(new.employment_type, '')))
      and (p.job_title is null or p.job_title = '' or job_text like '%' || lower(p.job_title) || '%')
  loop
    insert into public.notifications (user_id, type, title, body, reference_id, is_read)
    select candidate.id, 'job_alert', 'New job matching your preferences',
           format('%s is now available.', new.title), new.id, false
    where not exists (
      select 1 from public.notifications n
      where n.user_id = candidate.id
        and n.type = 'job_alert'
        and n.reference_id = new.id
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists approved_job_alert_notification on public.jobs;
create trigger approved_job_alert_notification
after insert or update of approval_status, is_active on public.jobs
for each row execute function public.create_job_alert_notifications();
