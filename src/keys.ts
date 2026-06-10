import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// ─────────────────────────────────────────────────────────────────────────────
// THE single chokepoint for provider-key plaintext.
// Keys are encrypted in Supabase Vault and only ever read here, server-side,
// via service_role-only SQL functions. Errors NEVER include key material.
//
// SERVER-ONLY: SUPABASE_SERVICE_ROLE_KEY bypasses RLS — never ship it to a browser.
// (In the SpeakOS app this file additionally imports `server-only` for a
//  build-time guarantee; omitted here so the module is framework-agnostic.)
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_PROVIDER = 'vapi'

function adminClient(): SupabaseClient {
  return createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  })
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
