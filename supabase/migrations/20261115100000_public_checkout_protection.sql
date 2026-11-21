-- BAZARIO public checkout protection
-- Apply after 20261115000000_admin_approval_api.sql.

begin;

-- Keep the public rate-limit lookup efficient.
create index if not exists orders_store_phone_created_idx
  on public.orders (store_id, buyer_phone, created_at desc);

-- The original function remains an internal implementation detail. Public
-- callers must use create_order_protected so the honeypot and throttle run.
revoke all on function public.create_order(text, text, text, jsonb)
  from public, anon, authenticated;

create or replace function public.create_order_protected(
  p_store_slug text,
  p_buyer_name text,
  p_buyer_phone text,
  p_items jsonb,
  p_honeypot text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_recent_orders integer;
  v_order_id uuid;
  v_phone text;
begin
  if coalesce(p_honeypot, '') <> '' then
    raise exception 'Request rejected'
      using errcode = '22023';
  end if;

  -- Normalize formatting before the rate-limit lookup so spaces,
  -- dashes, and parentheses cannot create separate buckets for one number.
  if p_buyer_phone is null
     or pg_catalog.btrim(p_buyer_phone) = ''
     or p_buyer_phone !~ '^[0-9+() -]+$' then
    raise exception 'Enter a valid contact number'
      using errcode = '22023';
  end if;

  v_phone = pg_catalog.regexp_replace(p_buyer_phone, '[^0-9]', '', 'g');

  if pg_catalog.char_length(v_phone) < 7
     or pg_catalog.char_length(v_phone) > 15 then
    raise exception 'Enter a valid contact number'
      using errcode = '22023';
  end if;

  select s.id
    into v_store_id
  from public.stores s
  where s.slug = pg_catalog.lower(pg_catalog.btrim(coalesce(p_store_slug, '')))
    and s.status = 'approved'::public.store_status
  limit 1
  for share;

  if v_store_id is null then
    raise exception 'Store not found or not approved'
      using errcode = 'P0002';
  end if;

  -- Serialize requests for the same store and phone number so parallel
  -- requests cannot bypass the per-phone hourly limit.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_store_id::text || ':' || v_phone, 0)
  );

  select count(*)::integer
    into v_recent_orders
  from public.orders o
  where o.store_id = v_store_id
    and o.buyer_phone = v_phone
    and o.created_at > now() - interval '1 hour';

  if v_recent_orders >= 3 then
    raise exception 'Too many orders from this number. Try again later.'
      using errcode = 'P0001';
  end if;

  v_order_id := public.create_order(
    p_store_slug,
    p_buyer_name,
    v_phone,
    p_items
  );

  return v_order_id;
end;
$$;

revoke all on function public.create_order_protected(text, text, text, jsonb, text)
  from public;
grant execute on function public.create_order_protected(text, text, text, jsonb, text)
  to anon, authenticated;

comment on function public.create_order_protected(text, text, text, jsonb, text) is
  'Public checkout wrapper with a honeypot and a per-store/per-phone limit of three orders per hour; server-side prices are still calculated by create_order.';

commit;
