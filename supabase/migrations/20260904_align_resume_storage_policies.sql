-- Reconcile the already-applied resume policies with the production bucket ID.
-- This does not create, rename, or make the existing `resumes` bucket public.

drop policy if exists "resume_upload_own_prefix" on storage.objects;
drop policy if exists "resume_read_own_prefix" on storage.objects;
drop policy if exists "resume_update_own_prefix" on storage.objects;
drop policy if exists "resume_delete_own_prefix" on storage.objects;

create policy "resume_upload_own_prefix"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "resume_read_own_prefix"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "resume_update_own_prefix"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "resume_delete_own_prefix"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'resumes'
  and (storage.foldername(name))[1] = auth.uid()::text
);
