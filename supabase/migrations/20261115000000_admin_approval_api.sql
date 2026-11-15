-- BAZARIO administrator store-approval API
-- Apply after the initial schema and seller order workflow migrations.

begin;

-- Exposes only the caller's own administrator flag; it never exposes the
-- admin_users table or another user's membership.
create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin();
$$;

revoke all on function public.current_user_is_admin() from public, anon;
grant execute on function public.current_user_is_admin() to authenticated;

-- Only administrators can review stores. A store can be reviewed only once
-- while pending, and approval timestamps are controlled by the database.
create or replace function public.admin_review_store(
  p_store_id uuid,
  p_decision public.store_status
)
returns public.store_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_status public.store_status;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required'
      using errcode = '42501';
  end if;

  if p_store_id is null
     or p_decision is null
     or p_decision not in (
       'approved'::public.store_status,
       'rejected'::public.store_status
     ) then
    raise exception 'Invalid store review request'
      using errcode = '22023';
  end if;

  select s.status
    into v_current_status
  from public.stores s
  where s.id = p_store_id
  for update;

  if not found then
    raise exception 'Store not found'
      using errcode = 'P0002';
  end if;

  if v_current_status <> 'pending'::public.store_status then
    raise exception 'Only pending stores can be reviewed'
      using errcode = '22023';
  end if;

  update public.stores
  set
    status = p_decision,
    approved_at = case
      when p_decision = 'approved'::public.store_status then now()
      else null
    end
  where id = p_store_id;

  return p_decision;
end;
$$;

revoke all on function public.admin_review_store(uuid, public.store_status) from public, anon;
grant execute on function public.admin_review_store(uuid, public.store_status) to authenticated;

-- Authenticated users may edit only public-facing store details directly.
-- Approval state and timestamps can be changed only through the guarded RPC.
revoke update on public.stores from authenticated;
grant update (name, slug, description) on public.stores to authenticated;

comment on function public.current_user_is_admin() is
  'Returns whether the currently authenticated user is in the private administrator allow-list.';
comment on function public.admin_review_store(uuid, public.store_status) is
  'Allows an administrator to approve or reject a pending store; the decision and approval timestamp are enforced by the database.';

commit;
