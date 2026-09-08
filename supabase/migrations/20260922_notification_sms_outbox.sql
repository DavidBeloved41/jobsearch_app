-- Queue optional SMS delivery without blocking the underlying notification event.
-- A provider worker is intentionally not included until an SMS provider is configured.

create table if not exists public.notification_sms_outbox (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique references public.notifications(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  phone_number text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed', 'not_configured')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processing_started_at timestamptz,
  sent_at timestamptz
);

create index if not exists notification_sms_outbox_pending_idx
  on public.notification_sms_outbox(status, created_at)
  where status in ('pending', 'failed');

alter table public.notification_sms_outbox enable row level security;
revoke all on public.notification_sms_outbox from anon, authenticated;

create or replace function public.queue_notification_sms()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  should_send boolean;
  recipient_phone text;
begin
  select nullif(trim(p.phone_number), ''),
    case new.type
      when 'job_alert' then coalesce(p.notify_job_alerts, true)
      when 'application_update' then coalesce(p.notify_application_updates, true)
      when 'new_message' then coalesce(p.notify_messages, true)
      else true
    end
    into recipient_phone, should_send
  from public.profiles as p
  where p.id = new.user_id;

  if should_send = true
     and recipient_phone is not null
     and exists (select 1 from auth.users as u where u.id = new.user_id) then
    insert into public.notification_sms_outbox
      (notification_id, recipient_id, phone_number, status, last_error)
    values (
      new.id,
      new.user_id,
      recipient_phone,
      'not_configured',
      'SMS provider is not configured'
    )
    on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists notification_sms_outbox_insert on public.notifications;
create trigger notification_sms_outbox_insert
after insert on public.notifications
for each row execute function public.queue_notification_sms();

revoke execute on function public.queue_notification_sms() from public, anon, authenticated;
