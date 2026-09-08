-- Job alerts must be relevant to a candidate's declared target role.
-- This replaces only the existing job-alert trigger function; no schema changes.

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
      and nullif(trim(p.job_title), '') is not null
      and job_text like '%' || lower(trim(p.job_title)) || '%'
      and (coalesce(sp.preferred_work_model, 'all') = 'all'
           or lower(coalesce(sp.preferred_work_model, 'all')) = lower(coalesce(new.work_model, '')))
      and (coalesce(sp.preferred_employment_type, 'all') = 'all'
           or lower(coalesce(sp.preferred_employment_type, 'all')) = lower(coalesce(new.employment_type, '')))
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
