-- BYOK key vault. Provider keys are stored in Supabase Vault — ciphertext in
-- vault.secrets, the encryption key held by Supabase outside the DB, so a DB
-- dump alone is useless. Plaintext is reachable ONLY via the two security-
-- definer functions below, which are granted to service_role alone.
--
-- ┌─ HOST SCHEMA CONTRACT ──────────────────────────────────────────────────┐
-- │ This template is shown with a reference tenancy. Each host app           │
-- │ applies its own migration substituting TWO contract points:             │
-- │                                                                          │
-- │  1. TENANT TABLE the key rows reference.                                 │
-- │       default:  org_id uuid references orgs(id)                          │
-- │       e.g.:     tenant_id uuid references tenants(id)                    │
-- │                                                                          │
-- │  2. METADATA-READ PREDICATE for the SELECT RLS policy — the tenant rows  │
-- │     the current user may see (provider + last4 only; never the key).     │
-- │       default:  org_id in (select current_user_org_ids())               │
-- │       e.g.:     tenant_id = (select (auth.jwt() -> 'app_metadata'        │
-- │                              ->> 'tenant_id')::uuid)                     │
-- │                                                                          │
-- │ FIXED RPC CONTRACT (do NOT rename): the shared TS chokepoint             │
-- │ (src/keys.ts) calls these functions BY NAME with these param names:      │
-- │   store_org_key(p_org_id uuid, p_provider text, p_key text)              │
-- │   get_org_key(p_org_id uuid, p_provider text)                            │
-- │ Even if your tenant column is named differently, keep the function and   │
-- │ param names and pass your tenant id as p_org_id — that is what keeps the │
-- │ published package's keys.ts usable unchanged across apps.                │
-- └──────────────────────────────────────────────────────────────────────────┘

create table org_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,   -- contract point 1
  provider text not null default 'vapi',
  vault_secret_id uuid not null,     -- points at vault.secrets; NOT the plaintext
  key_last4 text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, provider)
);

alter table org_keys enable row level security;
-- Supabase's default public-table ACL grants anon/authenticated full DML. Revoke it
-- EXPLICITLY so tenant roles cannot write key metadata (e.g. repoint vault_secret_id
-- at another tenant's secret, or spoof key_last4). RLS already blocks writes (no
-- permissive write policy exists), but this makes the lockdown explicit rather than
-- "one accidental policy away".
revoke all on org_keys from anon, authenticated;
grant select on org_keys to authenticated;  -- metadata only (provider + last4); no plaintext lives here
create policy org_keys_select on org_keys for select
  using (org_id in (select current_user_org_ids()));           -- contract point 2
-- writes go ONLY through store_org_key (security definer, service_role): no write policy + revoked DML

-- Store or replace a provider key: upserts the Vault secret + the metadata row.
create or replace function store_org_key(p_org_id uuid, p_provider text, p_key text)
returns void language plpgsql security definer set search_path = public, vault as $$
declare v_existing uuid; v_id uuid;
begin
  if p_key is null or p_key = '' then
    raise exception 'vault: empty key';
  end if;
  -- Serialize concurrent writes for the same (org, provider) so two racing first-time
  -- creates can't each call vault.create_secret and leave one secret orphaned. The
  -- lock is transaction-scoped (released on commit/rollback).
  perform pg_advisory_xact_lock(hashtextextended(p_org_id::text || ':' || p_provider, 0));
  select vault_secret_id into v_existing from org_keys where org_id = p_org_id and provider = p_provider;
  if v_existing is not null then
    perform vault.update_secret(v_existing, p_key);
    v_id := v_existing;
  else
    v_id := vault.create_secret(p_key, 'provider_key:' || p_org_id || ':' || p_provider, 'BYOK provider key');
  end if;
  insert into org_keys (org_id, provider, vault_secret_id, key_last4)
    values (p_org_id, p_provider, v_id, right(p_key, 4))
    on conflict (org_id, provider)
    do update set vault_secret_id = excluded.vault_secret_id, key_last4 = excluded.key_last4, updated_at = now();
end $$;

-- Fetch the decrypted provider key (service_role only).
create or replace function get_org_key(p_org_id uuid, p_provider text)
returns text language plpgsql security definer set search_path = public, vault as $$
declare v_id uuid; v_secret text;
begin
  select vault_secret_id into v_id from org_keys where org_id = p_org_id and provider = p_provider;
  if v_id is null then return null; end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets where id = v_id;
  return v_secret;
end $$;

revoke all on function store_org_key(uuid, text, text) from public, anon, authenticated;
revoke all on function get_org_key(uuid, text) from public, anon, authenticated;
grant execute on function store_org_key(uuid, text, text) to service_role;
grant execute on function get_org_key(uuid, text) to service_role;

notify pgrst, 'reload schema';
