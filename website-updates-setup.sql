-- CBMS FPO Website Updates / Photo Gallery
-- Run this once in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.website_updates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null default 'Other',
  description text,
  image_url text,
  published boolean not null default true,
  published_at timestamptz not null default now(),
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.website_updates enable row level security;

drop policy if exists "CBMS website updates public read" on public.website_updates;
create policy "CBMS website updates public read"
on public.website_updates
for select
to anon, authenticated
using (published = true);

drop policy if exists "CBMS website updates officer insert" on public.website_updates;
create policy "CBMS website updates officer insert"
on public.website_updates
for insert
to authenticated
with check (
  exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
  and created_by = auth.uid()
);

drop policy if exists "CBMS website updates officer update" on public.website_updates;
create policy "CBMS website updates officer update"
on public.website_updates
for update
to authenticated
using (
  exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
)
with check (
  exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
);

drop policy if exists "CBMS website updates officer delete" on public.website_updates;
create policy "CBMS website updates officer delete"
on public.website_updates
for delete
to authenticated
using (
  exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
);

insert into storage.buckets (id,name,public,allowed_mime_types,file_size_limit)
values (
  'website-updates',
  'website-updates',
  true,
  array['image/jpeg','image/png','image/webp','image/gif'],
  10485760
)
on conflict (id) do update set
  public=true,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'],
  file_size_limit=10485760;

drop policy if exists "CBMS website updates public image read" on storage.objects;
create policy "CBMS website updates public image read"
on storage.objects for select
to public
using (bucket_id='website-updates');

drop policy if exists "CBMS website updates officer image insert" on storage.objects;
create policy "CBMS website updates officer image insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id='website-updates'
  and exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
);

drop policy if exists "CBMS website updates officer image update" on storage.objects;
create policy "CBMS website updates officer image update"
on storage.objects for update
to authenticated
using (
  bucket_id='website-updates'
  and exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
)
with check (
  bucket_id='website-updates'
  and exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
);

drop policy if exists "CBMS website updates officer image delete" on storage.objects;
create policy "CBMS website updates officer image delete"
on storage.objects for delete
to authenticated
using (
  bucket_id='website-updates'
  and exists (
    select 1 from public.officers o
    where o.auth_user_id = auth.uid()
      and lower(coalesce(o.status,'')) = 'active'
  )
);

create or replace function public.cbms_website_updates_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  if new.published = true and old.published = false then
    new.published_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists cbms_website_updates_touch on public.website_updates;
create trigger cbms_website_updates_touch
before update on public.website_updates
for each row execute function public.cbms_website_updates_touch_updated_at();

create index if not exists website_updates_published_at_idx
on public.website_updates (published, published_at desc);
