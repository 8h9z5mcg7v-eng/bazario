-- BAZARIO seller order-status workflow
-- Apply after 20261109000000_initial_schema.sql and 20261110000000_product_image_storage.sql.

begin;

-- Sellers must change order status through the guarded RPC below.
-- This prevents direct edits to totals, buyer details, or store ownership.
revoke update on public.orders from authenticated;

create or replace function public.seller_update_order_status(
  p_order_id uuid,
  p_new_status public.order_status
)
returns public.order_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_status public.order_status;
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_order_id is null or p_new_status is null then
    raise exception 'Order and new status are required'
      using errcode = '22023';
  end if;

  select o.status, s.owner_id
    into v_current_status, v_owner_id
  from public.orders o
  join public.stores s on s.id = o.store_id
  where o.id = p_order_id
  for update of o;

  if not found then
    raise exception 'Order not found'
      using errcode = 'P0002';
  end if;

  -- Administrators may correct any status. Sellers can only update orders
  -- belonging to their own store and must follow the allowed state sequence.
  if not private.is_admin() then
    if v_owner_id <> auth.uid() then
      raise exception 'You cannot update this order'
        using errcode = '42501';
    end if;

    if not (
      (v_current_status = 'new'::public.order_status
        and p_new_status in ('confirmed'::public.order_status, 'cancelled'::public.order_status))
      or
      (v_current_status = 'confirmed'::public.order_status
        and p_new_status in ('preparing'::public.order_status, 'cancelled'::public.order_status))
      or
      (v_current_status = 'preparing'::public.order_status
        and p_new_status in ('shipped'::public.order_status, 'cancelled'::public.order_status))
      or
      (v_current_status = 'shipped'::public.order_status
        and p_new_status = 'completed'::public.order_status)
    ) then
      raise exception 'Invalid order status transition'
        using errcode = '22023';
    end if;
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id;

  return p_new_status;
end;
$$;

revoke all on function public.seller_update_order_status(uuid, public.order_status) from public;
grant execute on function public.seller_update_order_status(uuid, public.order_status) to authenticated;

comment on function public.seller_update_order_status(uuid, public.order_status) is
  'Allows a store owner to advance or cancel their own orders through the defined workflow; administrators may override status.';

commit;
