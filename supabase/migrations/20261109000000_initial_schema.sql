-- BAZARIO initial multi-tenant schema
-- Target: a new Supabase PostgreSQL project. This file does not create a project or deploy anything.

begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create type public.store_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type public.order_status as enum ('new', 'confirmed', 'preparing', 'shipped', 'completed', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) <= 100),
  constraint profiles_phone_length check (phone is null or char_length(phone) <= 30)
);

-- Admin membership is deliberately not writable or readable by client roles.
-- Add an administrator manually from the SQL editor after that person signs up.
create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text not null default '',
  status public.store_status not null default 'pending',
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stores_name_length check (char_length(btrim(name)) between 2 and 100),
  constraint stores_slug_format check (
    char_length(slug) between 3 and 40
    and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
  ),
  constraint stores_description_length check (char_length(description) <= 1000),
  constraint stores_approval_timestamp check (status <> 'approved' or approved_at is not null)
);

create index stores_owner_id_idx on public.stores(owner_id);
create index stores_status_idx on public.stores(status);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  description text not null default '',
  price numeric(12,2) not null check (price > 0),
  image_path text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_name_length check (char_length(btrim(name)) between 2 and 120),
  constraint products_description_length check (char_length(description) <= 2000),
  constraint products_image_path_length check (image_path is null or char_length(image_path) <= 500)
);

create index products_store_active_idx on public.products(store_id, is_active);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete restrict,
  buyer_name text not null,
  buyer_phone text not null,
  status public.order_status not null default 'new',
  total_amount numeric(16,2) not null check (total_amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_buyer_name_length check (char_length(btrim(buyer_name)) between 2 and 100),
  constraint orders_buyer_phone_length check (char_length(btrim(buyer_phone)) between 7 and 30)
);

create index orders_store_created_idx on public.orders(store_id, created_at desc);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price > 0),
  quantity integer not null check (quantity between 1 and 99),
  line_total numeric(16,2) generated always as (unit_price * quantity) stored
);

create index order_items_order_id_idx on public.order_items(order_id);

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = auth.uid()
  );
$$;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to anon, authenticated;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function private.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger stores_set_updated_at
before update on public.stores
for each row execute function private.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function private.set_updated_at();

create trigger orders_set_updated_at
before update on public.orders
for each row execute function private.set_updated_at();

create or replace function private.guard_store_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not private.is_admin() then
    if new.id is distinct from old.id
       or new.owner_id is distinct from old.owner_id
       or new.created_at is distinct from old.created_at
       or new.status is distinct from old.status
       or new.approved_at is distinct from old.approved_at then
      raise exception 'Only an administrator can change protected store fields'
        using errcode = '42501';
    end if;
  end if;

  if new.status = 'approved' and new.approved_at is null then
    new.approved_at = now();
  elsif new.status <> 'approved' then
    new.approved_at = null;
  end if;

  return new;
end;
$$;
revoke all on function private.guard_store_admin_fields() from public, anon, authenticated;

create trigger stores_guard_admin_fields
before update on public.stores
for each row execute function private.guard_store_admin_fields();

create or replace function private.guard_product_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not private.is_admin() then
    if new.id is distinct from old.id
       or new.store_id is distinct from old.store_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Only an administrator can change product identity or store ownership'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.guard_product_identity() from public, anon, authenticated;

create trigger products_guard_identity
before update on public.products
for each row execute function private.guard_product_identity();

alter table public.profiles enable row level security;
alter table public.admin_users enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create policy "Profiles readable by owner or admin"
on public.profiles for select
to authenticated
using (id = auth.uid() or private.is_admin());

create policy "Users update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Approved stores are public; owners and admins can read"
on public.stores for select
to anon, authenticated
using (status = 'approved' or owner_id = auth.uid() or private.is_admin());

create policy "Users create pending stores for themselves"
on public.stores for insert
to authenticated
with check (owner_id = auth.uid() and status = 'pending' and approved_at is null);

create policy "Owners and admins update stores"
on public.stores for update
to authenticated
using (owner_id = auth.uid() or private.is_admin())
with check (owner_id = auth.uid() or private.is_admin());

create policy "Admins manage stores"
on public.stores for all
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "Public sees active products in approved stores"
on public.products for select
to anon, authenticated
using (
  (
    is_active
    and exists (
      select 1 from public.stores s
      where s.id = store_id and s.status = 'approved'
    )
  )
  or exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
  or private.is_admin()
);

create policy "Store owners add products"
on public.products for insert
to authenticated
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
);

create policy "Store owners update products"
on public.products for update
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
);

create policy "Store owners delete products"
on public.products for delete
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
);

create policy "Admins manage products"
on public.products for all
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "Store owners and admins read orders"
on public.orders for select
to authenticated
using (
  exists (
    select 1 from public.stores s
    where s.id = store_id and s.owner_id = auth.uid()
  )
  or private.is_admin()
);

create policy "Admins manage orders"
on public.orders for all
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "Store owners and admins read order items"
on public.order_items for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.stores s on s.id = o.store_id
    where o.id = order_id
      and (s.owner_id = auth.uid() or private.is_admin())
  )
);

-- Public checkout is only possible through this function. It calculates prices
-- from the database and never trusts a price supplied by the customer's browser.
create or replace function public.create_order(
  p_store_slug text,
  p_buyer_name text,
  p_buyer_phone text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_order_id uuid;
  v_input_count integer;
  v_distinct_count integer;
  v_valid_count integer;
  v_total numeric;
begin
  if p_store_slug is null or char_length(btrim(p_store_slug)) < 3 then
    raise exception 'Invalid store address' using errcode = '22023';
  end if;

  if p_buyer_name is null
     or char_length(btrim(p_buyer_name)) < 2
     or char_length(btrim(p_buyer_name)) > 100 then
    raise exception 'Enter a valid customer name' using errcode = '22023';
  end if;

  if p_buyer_phone is null
     or char_length(btrim(p_buyer_phone)) < 7
     or char_length(btrim(p_buyer_phone)) > 30 then
    raise exception 'Enter a valid contact number' using errcode = '22023';
  end if;

  if p_items is null or pg_catalog.jsonb_typeof(p_items) <> 'array' then
    raise exception 'Order items must be a list' using errcode = '22023';
  end if;

  v_input_count = pg_catalog.jsonb_array_length(p_items);
  if v_input_count < 1 or v_input_count > 20 then
    raise exception 'An order must contain between 1 and 20 different products'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
    where x.product_id is null
       or x.quantity is null
       or x.quantity < 1
       or x.quantity > 99
  ) then
    raise exception 'Invalid product or quantity' using errcode = '22023';
  end if;

  select count(*)::integer, count(distinct x.product_id)::integer
  into v_input_count, v_distinct_count
  from pg_catalog.jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer);

  if v_input_count <> v_distinct_count then
    raise exception 'Each product may appear only once in an order' using errcode = '22023';
  end if;

  select s.id
  into v_store_id
  from public.stores s
  where s.slug = pg_catalog.lower(btrim(p_store_slug))
    and s.status = 'approved'
  limit 1
  for share;

  if v_store_id is null then
    raise exception 'Store not found or not approved' using errcode = 'P0002';
  end if;

  -- Lock the selected product rows so prices/availability cannot change
  -- between validation, total calculation, and snapshot insertion.
  perform p.id
  from pg_catalog.jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
  join public.products p
    on p.id = x.product_id
   and p.store_id = v_store_id
   and p.is_active
  order by p.id
  for share of p;

  select count(*)::integer, coalesce(sum(p.price * x.quantity), 0)
  into v_valid_count, v_total
  from pg_catalog.jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
  join public.products p
    on p.id = x.product_id
   and p.store_id = v_store_id
   and p.is_active;

  if v_valid_count <> v_input_count then
    raise exception 'One or more products are unavailable' using errcode = '22023';
  end if;

  insert into public.orders (store_id, buyer_name, buyer_phone, total_amount)
  values (v_store_id, btrim(p_buyer_name), btrim(p_buyer_phone), v_total)
  returning id into v_order_id;

  insert into public.order_items (order_id, product_id, product_name, unit_price, quantity)
  select v_order_id, p.id, p.name, p.price, x.quantity
  from pg_catalog.jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
  join public.products p
    on p.id = x.product_id
   and p.store_id = v_store_id
   and p.is_active;

  return v_order_id;
end;
$$;

revoke all on function public.create_order(text, text, text, jsonb) from public;
grant execute on function public.create_order(text, text, text, jsonb) to anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, phone) on public.profiles to authenticated;

grant select on public.stores to anon, authenticated;
grant insert, update on public.stores to authenticated;

grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;

grant select, update on public.orders to authenticated;
grant select on public.order_items to authenticated;

comment on table public.admin_users is
  'Private administrator allow-list. Manage membership only through trusted SQL/service-role access.';
comment on function public.create_order(text, text, text, jsonb) is
  'Creates a customer order for an approved store; prices are read from active database products.';

commit;
