-- Add explicit message delivery states while preserving existing is_read behavior.
-- Timestamps are monotonic and only the authenticated receiver may advance them.

alter table public.messages
  add column if not exists delivered_at timestamptz,
  add column if not exists seen_at timestamptz;

create or replace function public.mark_messages_delivered(p_sender_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  changed_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.messages as m
  set delivered_at = coalesce(m.delivered_at, now())
  where m.sender_id = p_sender_id
    and m.receiver_id = auth.uid()
    and m.delivered_at is null;
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$$;

create or replace function public.mark_messages_seen(p_sender_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  changed_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.messages as m
  set delivered_at = coalesce(m.delivered_at, now()),
      seen_at = coalesce(m.seen_at, now()),
      is_read = true
  where m.sender_id = p_sender_id
    and m.receiver_id = auth.uid()
    and m.seen_at is null;
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$$;

revoke all on function public.mark_messages_delivered(uuid) from public, anon;
revoke all on function public.mark_messages_seen(uuid) from public, anon;
grant execute on function public.mark_messages_delivered(uuid) to authenticated;
grant execute on function public.mark_messages_seen(uuid) to authenticated;

-- Normalize Ghana local numbers at queue time without changing profile storage.
create or replace function public.normalize_ghana_phone(raw_phone text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  value text := regexp_replace(trim(coalesce(raw_phone, '')), '[^0-9+]', '', 'g');
begin
  if value like '+233%' and length(value) between 13 and 14 then return value; end if;
  if value like '233%' and length(value) between 12 and 13 then return '+' || value; end if;
  if value like '0%' and length(value) = 10 then return '+233' || substring(value from 2); end if;
  return null;
end;
$$;

create or replace function public.queue_notification_sms()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  should_send boolean;
  recipient_phone text;
  normalized_phone text;
begin
  select public.normalize_ghana_phone(p.phone_number),
    case new.type
      when 'job_alert' then coalesce(p.notify_job_alerts, true)
      when 'application_update' then coalesce(p.notify_application_updates, true)
      when 'new_message' then coalesce(p.notify_messages, true)
      else true
    end
    into normalized_phone, should_send
  from public.profiles as p
  where p.id = new.user_id;

  if should_send = true and normalized_phone is not null
     and exists (select 1 from auth.users as u where u.id = new.user_id) then
    insert into public.notification_sms_outbox
      (notification_id, recipient_id, phone_number, status, last_error)
    values (new.id, new.user_id, normalized_phone, 'pending', null)
    on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;

revoke execute on function public.normalize_ghana_phone(text) from public, anon, authenticated;
revoke execute on function public.queue_notification_sms() from public, anon, authenticated;
