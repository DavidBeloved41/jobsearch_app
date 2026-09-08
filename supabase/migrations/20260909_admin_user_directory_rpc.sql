-- Secure admin-only user directory export.
-- This keeps the authoritative registration email in auth.users and exposes it only
-- to the authorized admin email via a server-side function.

create or replace function public.get_admin_user_directory()
returns table (
  id uuid,
  full_name text,
  account_type text,
  created_at timestamptz,
  email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    p.id,
    p.full_name,
    p.account_type,
    p.created_at,
    au.email
  from public.profiles p
  left join auth.users au on au.id = p.id
  join public.profiles admin_profile on admin_profile.id = auth.uid()
  where admin_profile.account_type = 'admin'
    and lower(
      (
        select au2.email
        from auth.users au2
        where au2.id = auth.uid()
      )
    ) = 'beloveddavid41@gmail.com'
  order by p.created_at desc;
$$;

grant execute on function public.get_admin_user_directory() to authenticated;
