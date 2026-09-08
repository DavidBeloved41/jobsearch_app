-- Queue eligible in-app notifications for server-side email delivery.
-- The recipient is identified by auth.users.id; email is resolved by the worker.
-- No client can insert or update this queue because it has no client policies.

create table if not exists public.notification_email_outbox (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique references public.notifications(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processing_started_at timestamptz,
  sent_at timestamptz
);

create index if not exists notification_email_outbox_pending_idx
  on public.notification_email_outbox(status, created_at)
  where status in ('pending', 'failed');

alter table public.notification_email_outbox enable row level security;

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
  from public.profiles p
  where p.id = new.user_id;

  if should_email = true
     and exists (select 1 from auth.users u where u.id = new.user_id) then
    insert into public.notification_email_outbox (notification_id, recipient_id)
    values (new.id, new.user_id)
    on conflict (notification_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists notification_email_outbox_insert
  on public.notifications;
create trigger notification_email_outbox_insert
after insert on public.notifications
for each row execute function public.queue_notification_email();
