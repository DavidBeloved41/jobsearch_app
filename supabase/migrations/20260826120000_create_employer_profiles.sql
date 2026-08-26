-- Separate employer organization data from auth-linked account data.
-- This migration is additive and does not alter profiles, companies, jobs, or applications.
create table if not exists public.employer_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  company_name text,
  company_email text,
  company_phone text,
  industry text,
  company_size text,
  location text,
  website text,
  description text,
  founded_year integer,
  logo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists employer_profiles_user_id_idx
  on public.employer_profiles(user_id);

alter table public.employer_profiles enable row level security;

create policy "Employers can view their company profile"
  on public.employer_profiles for select
  using (auth.uid() = user_id);

create policy "Employers can create their company profile"
  on public.employer_profiles for insert
  with check (auth.uid() = user_id);

create policy "Employers can update their company profile"
  on public.employer_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.set_employer_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists employer_profiles_updated_at on public.employer_profiles;
create trigger employer_profiles_updated_at
before update on public.employer_profiles
for each row execute function public.set_employer_profiles_updated_at();
