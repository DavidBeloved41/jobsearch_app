-- Allow employers to update applications only for jobs they own.
-- Job seekers have no UPDATE policy and cannot change recruitment status.
-- This does not change application columns or disable RLS.

drop policy if exists "Employers can update application status for their jobs"
  on public.applications;

create policy "Employers can update application status for their jobs"
  on public.applications
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.jobs j
      join public.profiles p on p.id = auth.uid()
      where j.id = applications.job_id
        and j.poster_id = auth.uid()
        and p.account_type = 'employer'
    )
  )
  with check (
    exists (
      select 1
      from public.jobs j
      join public.profiles p on p.id = auth.uid()
      where j.id = applications.job_id
        and j.poster_id = auth.uid()
        and p.account_type = 'employer'
    )
  );
