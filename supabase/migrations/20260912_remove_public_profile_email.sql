-- Registration email is authoritative in auth.users.
-- Remove the legacy duplicate from public.profiles so normal clients cannot
-- retrieve unrelated users' email addresses through profile reads.

alter table if exists public.profiles
  drop column if exists email;