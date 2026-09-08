-- Allow the existing authorized administrator to review all applications.
-- Employers and job seekers retain their existing scoped policies.
-- This is SELECT-only and does not grant application writes.

drop policy if exists "Admin can view all applications" on public.applications;

create policy "Admin can view all applications"
  on public.applications
  for select
  to authenticated
  using (
    lower(auth.jwt() ->> 'email') = 'beloveddavid41@gmail.com'
  );
