-- BYOK key vault. Provider keys are stored in Supabase Vault — ciphertext in
-- vault.secrets, the encryption key held by Supabase outside the DB, so a DB
-- dump alone is useless. Plaintext is reachable ONLY via the two security-
-- definer functions below, which are granted to service_role alone.

create table org_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(id) on delete cascade,
  provider text not null default 'vapi',
  vault_secret_id uuid not null,     -- points at vault.secrets; NOT the plaintext
  key_last4 text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, provider)
);

alter table org_keys enable row level security;
grant select on org_keys to authenticated;  -- metadata only; no plaintext lives here
create policy org_keys_select on org_keys for select
  using (org_id in (select current_user_org_ids()));
-- no authenticated insert/update/delete: writes go through store_org_key (service_role)

-- Store or replace a provider key: upserts the Vault secret + the metadata row.
create or replace function store_org_key(p_org_id uuid, p_provider text, p_key text)
returns void language plpgsql security definer set search_path = public, vault as $$
declare v_existing uuid; v_id uuid;
begin
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
