-- BAZARIO product image storage
-- Apply after 20261109000000_initial_schema.sql in a Supabase project.

begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'bazario-products',
  'bazario-products',
  true,
  1048576,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "BAZARIO store owners upload product images" on storage.objects;
create policy "BAZARIO store owners upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'bazario-products'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "BAZARIO store owners update product images" on storage.objects;
create policy "BAZARIO store owners update product images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'bazario-products'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = auth.uid()
  )
)
with check (
  bucket_id = 'bazario-products'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = auth.uid()
  )
);

drop policy if exists "BAZARIO store owners delete product images" on storage.objects;
create policy "BAZARIO store owners delete product images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'bazario-products'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[1]
      and s.owner_id = auth.uid()
  )
);

commit;
