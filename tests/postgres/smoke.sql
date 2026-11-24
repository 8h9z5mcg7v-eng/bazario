\set ON_ERROR_STOP on

-- Seed two sellers and one administrator. The Auth trigger must create profiles.
insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000001', '{"display_name":"Satıcı Bir"}'),
  ('00000000-0000-4000-8000-000000000002', '{"display_name":"Satıcı İki"}'),
  ('00000000-0000-4000-8000-000000000003', '{"display_name":"Admin"}');

insert into public.admin_users (user_id)
values ('00000000-0000-4000-8000-000000000003');

insert into public.stores (id, owner_id, name, slug, status, approved_at) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
   'Satıcı Bir', 'seller-one', 'approved', now()),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002',
   'Satıcı İki', 'seller-two', 'pending', null);

insert into public.products (id, store_id, name, price, is_active) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   'Test məhsulu bir', 12.50, true),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
   'Test məhsulu iki', 30.00, true);

insert into public.orders (id, store_id, buyer_name, buyer_phone, status, total_amount) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   'Müştəri Bir', '0501112233', 'new', 12.50),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
   'Müştəri İki', '0502223344', 'new', 30.00);

do $$
begin
  if not exists (
    select 1 from public.profiles
    where id = '00000000-0000-4000-8000-000000000001'
      and display_name = 'Satıcı Bir'
  ) then
    raise exception 'Auth trigger did not create the seller profile';
  end if;
end;
$$;

-- Anonymous visitors can see only approved stores and their active products.
set role anon;
do $$
begin
  if not exists (select 1 from public.stores where id = '10000000-0000-4000-8000-000000000001') then
    raise exception 'Anonymous visitor cannot see an approved store';
  end if;
  if exists (select 1 from public.stores where id = '10000000-0000-4000-8000-000000000002') then
    raise exception 'Anonymous visitor can see a pending store';
  end if;
  if not exists (select 1 from public.products where id = '20000000-0000-4000-8000-000000000001') then
    raise exception 'Anonymous visitor cannot see an active product in an approved store';
  end if;
  if exists (select 1 from public.products where id = '20000000-0000-4000-8000-000000000002') then
    raise exception 'Anonymous visitor can see a product in a pending store';
  end if;
end;
$$;
reset role;

-- Seller one can read and edit only their own store/products/orders.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
do $$
begin
  if not exists (select 1 from public.stores where id = '10000000-0000-4000-8000-000000000001') then
    raise exception 'Seller cannot read their own store';
  end if;
  if exists (select 1 from public.stores where id = '10000000-0000-4000-8000-000000000002') then
    raise exception 'Seller can read another seller''s pending store';
  end if;
  if not exists (select 1 from public.orders where id = '30000000-0000-4000-8000-000000000001') then
    raise exception 'Seller cannot read their own order';
  end if;
  if exists (select 1 from public.orders where id = '30000000-0000-4000-8000-000000000002') then
    raise exception 'Seller can read another seller''s order';
  end if;
end;
$$;

update public.stores
set name = 'Satıcı Bir Yenilənib'
where id = '10000000-0000-4000-8000-000000000001';

update public.products
set price = 999.00
where id = '20000000-0000-4000-8000-000000000002';

select public.seller_update_order_status(
  '30000000-0000-4000-8000-000000000001',
  'confirmed'
);

do $$
begin
  begin
    perform public.seller_update_order_status(
      '30000000-0000-4000-8000-000000000001',
      'shipped'
    );
    raise exception 'Invalid order status transition was accepted' using errcode = 'P0002';
  exception when sqlstate '22023' then
    null;
  end;
end;
$$;
reset role;

do $$
begin
  if (select price from public.products where id = '20000000-0000-4000-8000-000000000002') <> 30.00 then
    raise exception 'Seller changed another seller''s product';
  end if;
  if (select status from public.orders where id = '30000000-0000-4000-8000-000000000001') <> 'confirmed' then
    raise exception 'Seller order status RPC did not update the owned order';
  end if;
end;
$$;

-- Seller two cannot update seller one's order or approve stores.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', false);
do $$
begin
  begin
    perform public.seller_update_order_status(
      '30000000-0000-4000-8000-000000000001',
      'completed'
    );
    raise exception 'Cross-seller order update was accepted' using errcode = 'P0002';
  exception when sqlstate '42501' then
    null;
  end;

  begin
    perform public.admin_review_store(
      '10000000-0000-4000-8000-000000000002',
      'approved'
    );
    raise exception 'A seller approved a store' using errcode = 'P0002';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;
reset role;

-- Anonymous callers cannot use the seller-only status RPC, but can use protected checkout.
set role anon;
do $$
begin
  begin
    perform public.seller_update_order_status(
      '30000000-0000-4000-8000-000000000001',
      'cancelled'
    );
    raise exception 'Anonymous order-status RPC execution was accepted' using errcode = 'P0002';
  exception when insufficient_privilege then
    null;
  end;

  perform public.create_order_protected(
    'seller-one',
    'Sınaq Müştərisi',
    '+994 50 123 45 67',
    jsonb_build_array(jsonb_build_object(
      'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 2
    )),
    ''
  );

  begin
    perform public.create_order_protected(
      'seller-one',
      'Spam Müştərisi',
      '0501234567',
      jsonb_build_array(jsonb_build_object(
        'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
        'quantity', 1
      )),
      'bot-filled-this'
    );
    raise exception 'Checkout honeypot did not reject the request' using errcode = 'P0002';
  exception when sqlstate '22023' then
    null;
  end;

  -- Formatting variants of the same phone number must share one rate-limit bucket.
  perform public.create_order_protected(
    'seller-one', 'Limit Müştərisi', '+994 50 111 22 33',
    jsonb_build_array(jsonb_build_object(
      'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1
    )), ''
  );
  perform public.create_order_protected(
    'seller-one', 'Limit Müştərisi', '994501112233',
    jsonb_build_array(jsonb_build_object(
      'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1
    )), ''
  );
  perform public.create_order_protected(
    'seller-one', 'Limit Müştərisi', '994501112233',
    jsonb_build_array(jsonb_build_object(
      'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
      'quantity', 1
    )), ''
  );

  begin
    perform public.create_order_protected(
      'seller-one', 'Limit Müştərisi', '994501112233',
      jsonb_build_array(jsonb_build_object(
        'product_id', '20000000-0000-4000-8000-000000000001'::uuid,
        'quantity', 1
      )), ''
    );
    raise exception 'Checkout hourly limit did not reject the fourth order' using errcode = 'P0002';
  exception when sqlstate 'P0001' then
    null;
  end;
end;
$$;
reset role;

do $$
begin
  if not exists (
    select 1 from public.orders
    where buyer_phone = '994501234567'
      and total_amount = 25.00
  ) then
    raise exception 'Checkout did not normalize the phone or calculate the database price';
  end if;
  if (select count(*) from public.orders where buyer_phone = '994501112233') <> 3 then
    raise exception 'Phone-format normalization or hourly checkout limit is incorrect';
  end if;
  if not exists (
    select 1 from public.order_items
    where product_id = '20000000-0000-4000-8000-000000000001'
      and product_name = 'Test məhsulu bir'
      and unit_price = 12.50
      and quantity = 2
  ) then
    raise exception 'Checkout did not save the product price/name snapshot';
  end if;
end;
$$;

-- Storage policies allow the owner folder and reject another seller's folder.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
insert into storage.objects (bucket_id, name)
values ('bazario-products', '10000000-0000-4000-8000-000000000001/product.webp');

do $$
begin
  begin
    insert into storage.objects (bucket_id, name)
    values ('bazario-products', '10000000-0000-4000-8000-000000000002/foreign.webp');
    raise exception 'Seller uploaded an image into another seller''s folder' using errcode = 'P0002';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- Only an allow-listed administrator can approve a pending store.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000003', false);
do $$
begin
  if public.current_user_is_admin() is distinct from true then
    raise exception 'Administrator allow-list check failed';
  end if;
end;
$$;
select public.admin_review_store(
  '10000000-0000-4000-8000-000000000002',
  'approved'
);
reset role;

do $$
begin
  if not exists (
    select 1 from public.stores
    where id = '10000000-0000-4000-8000-000000000002'
      and status = 'approved'
      and approved_at is not null
  ) then
    raise exception 'Admin approval did not set the approved status and timestamp';
  end if;
end;
$$;

\echo 'BAZARIO PostgreSQL smoke tests passed.'
