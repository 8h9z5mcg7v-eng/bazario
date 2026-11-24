-- Minimal Supabase-compatible PostgreSQL fixture for CI only.
-- This is not deployed to or connected to any Supabase project.

create extension if not exists pgcrypto;

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

grant usage on schema public to anon, authenticated, service_role;

create schema auth;
create table auth.users (
  id uuid primary key,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);

create or replace function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

create schema storage;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null
);

alter table storage.objects enable row level security;
grant usage on schema storage to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;

create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case
    when pg_catalog.strpos(name, '/') > 0
      then array[pg_catalog.split_part(name, '/', 1)]
    else array[]::text[]
  end;
$$;

grant execute on function storage.foldername(text) to authenticated;
