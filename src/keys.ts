import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// ─────────────────────────────────────────────────────────────────────────────
// THE single chokepoint for provider-key plaintext.
// Keys are encrypted in Supabase Vault and only ever read here, server-side,
// via service_role-only SQL functions. Errors NEVER include key material.
//
// SERVER-ONLY: SUPABASE_SERVICE_ROLE_KEY bypasses RLS — never ship it to a
// browser. This module is framework-agnostic (no hard `import 'server-only'`);
// re-add that guard in your app's wrapper if your framework supports it.
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_PROVIDER = 'vapi'

function adminClient(): SupabaseClient {
  // SUPABASE_URL is the canonical name; NEXT_PUBLIC_SUPABASE_URL is accepted as a
  // fallback so Next.js apps don't need to duplicate the (non-secret) URL.
  const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !serviceRoleKey) {
    throw new Error('vault: missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY')
  }
  return createClient(url, serviceRoleKey, { auth: { persistSession: false } })
}

export async function storeProviderKey(
  orgId: string,
  key: string,
  provider: string = DEFAULT_PROVIDER,
): Promise<void> {
  const { error } = await adminClient().rpc('store_org_key', {
    p_org_id: orgId,
    p_provider: provider,
    p_key: key,
  })
  if (error) throw new Error(`vault: store failed (${error.code ?? 'unknown'})`)
}

export async function getProviderKey(
  orgId: string,
  provider: string = DEFAULT_PROVIDER,
): Promise<string | null> {
  const { data, error } = await adminClient().rpc('get_org_key', {
    p_org_id: orgId,
    p_provider: provider,
  })
  if (error) throw new Error(`vault: read failed (${error.code ?? 'unknown'})`)
  return (data as string | null) ?? null
}
