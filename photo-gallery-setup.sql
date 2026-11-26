-- CBMS FPO Photo Gallery setup
-- Run once in Supabase SQL Editor.

insert into storage.buckets (id, name, public, allowed_mime_types, file_size_limit)
values ('fpo-gallery', 'fpo-gallery', true, array['image/jpeg','image/png','image/webp','image/gif'], 10485760)
on conflict (id) do update
set public=true, allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'], file_size_limit=10485760;

drop policy if exists "CBMS gallery public read" on storage.objects;
create policy "CBMS gallery public read"
on storage.objects for select
to public
using (bucket_id='fpo-gallery');

drop policy if exists "CBMS gallery authenticated upload" on storage.objects;
create policy "CBMS gallery authenticated upload"
on storage.objects for insert
to authenticated
with check (bucket_id='fpo-gallery');

drop policy if exists "CBMS gallery authenticated update" on storage.objects;
create policy "CBMS gallery authenticated update"
on storage.objects for update
to authenticated
using (bucket_id='fpo-gallery')
with check (bucket_id='fpo-gallery');

drop policy if exists "CBMS gallery authenticated delete" on storage.objects;
create policy "CBMS gallery authenticated delete"
on storage.objects for delete
to authenticated
using (bucket_id='fpo-gallery');
