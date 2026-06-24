-- TEST FIXTURE ONLY — host apps NEVER apply this file. It is the minimal tenancy
-- context that the DEFAULT sql/vault.sql builds on (the `orgs` table + the
-- `current_user_org_ids()` predicate), so vault.sql applies and test/keys.test.ts
-- runs standalone against a fresh Supabase project. Each real app brings its own
-- tenancy (see the HOST SCHEMA CONTRACT header in sql/vault.sql).

create type org_type as enum ('direct', 'agency', 'client');
create type org_role as enum ('owner', 'admin', 'member', 'viewer', 'guardian');

create table orgs (
  id uuid primary key default gen_random_uuid(),
  type org_type not null,
  name text not null,
  parent_org_id uuid references orgs(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table org_memberships (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  user_id uuid not null,
  role org_role not null default 'member',
  unique (org_id, user_id)
);

-- Orgs the current user may access (own orgs + child orgs they own/admin).
create or replace function current_user_org_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.org_id from org_memberships m where m.user_id = auth.uid()
  union
  select o.id from orgs o
    join org_memberships m on m.org_id = o.parent_org_id
   where m.user_id = auth.uid() and m.role in ('owner', 'admin')
$$;
