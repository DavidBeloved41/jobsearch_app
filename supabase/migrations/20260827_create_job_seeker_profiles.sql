-- Keep job-seeker-only preferences separate from the shared profiles table.
create table if not exists public.job_seeker_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferred_work_model text not null default 'all',
  preferred_employment_type text not null default 'all',
  desired_min_salary integer,
  desired_max_salary integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.job_seeker_profiles enable row level security;

drop policy if exists "Job seekers can view their preferences"
  on public.job_seeker_profiles;
create policy "Job seekers can view their preferences"
  on public.job_seeker_profiles for select
  using (auth.uid() = user_id);

drop policy if exists "Job seekers can create their preferences"
  on public.job_seeker_profiles;
create policy "Job seekers can create their preferences"
  on public.job_seeker_profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Job seekers can update their preferences"
  on public.job_seeker_profiles;
create policy "Job seekers can update their preferences"
  on public.job_seeker_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);