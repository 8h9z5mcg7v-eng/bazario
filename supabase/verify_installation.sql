-- BAZARIO backend installation verification
-- Run this only AFTER applying all three migrations in timestamp order.
-- This script is read-only: it checks catalog metadata and does not change data or schema.

do $$
declare
  v_rls_count integer;
  v_public_policy_count integer;
  v_storage_policy_count integer;
  v_bucket_public boolean;
  v_bucket_size bigint;
  v_bucket_mimes text[];
  v_auth_trigger_count integer;
begin
  -- Required tables and the private helper schema.
  if to_regclass('public.profiles') is null
     or to_regclass('public.admin_users') is null
     or to_regclass('public.stores') is null
     or to_regclass('public.products') is null
     or to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regnamespace('private') is null then
    raise exception 'BAZARIO: one or more required tables/schemas are missing. Apply the migrations in order.';
  end if;

  -- All six application tables must have Row Level Security enabled.
  select count(*)::integer
    into v_rls_count
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('profiles', 'admin_users', 'stores', 'products', 'orders', 'order_items')
    and c.relrowsecurity;

  if v_rls_count <> 6 then
    raise exception 'BAZARIO: expected RLS on 6 application tables, found %.', v_rls_count;
  end if;

  -- The initial schema defines 14 application-table policies.
  select count(*)::integer
    into v_public_policy_count
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in ('profiles', 'admin_users', 'stores', 'products', 'orders', 'order_items');

  if v_public_policy_count <> 14 then
    raise exception 'BAZARIO: expected 14 application RLS policies, found %.', v_public_policy_count;
  end if;

  -- Product images must use the intended public bucket and upload limits.
  select b.public, b.file_size_limit, b.allowed_mime_types
    into v_bucket_public, v_bucket_size, v_bucket_mimes
  from storage.buckets b
  where b.id = 'bazario-products';

  if not found
     or v_bucket_public is distinct from true
     or v_bucket_size is distinct from 1048576
     or v_bucket_mimes is distinct from array['image/jpeg', 'image/png', 'image/webp']::text[] then
    raise exception 'BAZARIO: product image bucket settings are missing or do not match the expected limits.';
  end if;

  select count(*)::integer
    into v_storage_policy_count
  from pg_catalog.pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and policyname like 'BAZARIO store owners % product images';

  if v_storage_policy_count <> 3 then
    raise exception 'BAZARIO: expected 3 BAZARIO Storage policies, found %.', v_storage_policy_count;
  end if;

  -- New Auth users must receive a profile automatically.
  select count(*)::integer
    into v_auth_trigger_count
  from pg_catalog.pg_trigger t
  join pg_catalog.pg_class c on c.oid = t.tgrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and t.tgname = 'on_auth_user_created'
    and not t.tgisinternal;

  if v_auth_trigger_count <> 1 then
    raise exception 'BAZARIO: Auth profile-creation trigger is missing.';
  end if;

  -- Public checkout is callable without a customer account; seller status changes are not.
  if to_regprocedure('public.create_order(text,text,text,jsonb)') is null
     or not has_function_privilege('anon', 'public.create_order(text,text,text,jsonb)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.create_order(text,text,text,jsonb)', 'EXECUTE') then
    raise exception 'BAZARIO: public checkout function or its expected grants are missing.';
  end if;

  if to_regprocedure('public.seller_update_order_status(uuid,public.order_status)') is null
     or not has_function_privilege('authenticated', 'public.seller_update_order_status(uuid,public.order_status)', 'EXECUTE')
     or has_function_privilege('anon', 'public.seller_update_order_status(uuid,public.order_status)', 'EXECUTE') then
    raise exception 'BAZARIO: seller order-status function grants are incorrect.';
  end if;

  -- Prevent direct edits to order records and direct reading of the admin allow-list.
  if has_table_privilege('authenticated', 'public.orders', 'UPDATE')
     or has_table_privilege('authenticated', 'public.admin_users', 'SELECT')
     or has_table_privilege('anon', 'public.admin_users', 'SELECT') then
    raise exception 'BAZARIO: an unexpected direct table privilege is present.';
  end if;

  raise notice 'BAZARIO verification passed: 6 tables with RLS, 14 application policies, image bucket and 3 Storage policies, Auth trigger, checkout grants, and guarded order-status grants.';
end;
$$;
