// Proves the vault's guarantees against a real Supabase project.
// Apply sql/context.sql + sql/vault.sql first, then set env and `npm test`.
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { fileURLToPath } from 'node:url'
import dotenv from 'dotenv'
import pg from 'pg'
import { storeProviderKey, getProviderKey } from '../src/keys'
import { redactSecrets } from '../src/redact'

dotenv.config({ path: fileURLToPath(new URL('../.env', import.meta.url)) })

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 3 })
const SAMPLE = 'vk_live_DEMOkey_445566'
let orgId = ''
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

beforeAll(async () => {
  const c = await pool.connect()
  try {
    orgId = (
      await c.query<{ id: string }>(
        `insert into orgs (type, name) values ('direct', 'byok-vault test') returning id`,
      )
    ).rows[0].id
  } finally {
    c.release()
  }
  // PostgREST may need a moment to expose the new RPCs
  for (let i = 0; i < 15; i++) {
    try {
      await getProviderKey(orgId)
      return
    } catch {
      await sleep(1000)
    }
  }
})

afterAll(async () => {
  const c = await pool.connect()
  try {
    const k = await c.query<{ vault_secret_id: string }>(
      `select vault_secret_id from org_keys where org_id = $1`,
      [orgId],
    )
    for (const row of k.rows) await c.query('delete from vault.secrets where id = $1', [row.vault_secret_id])
    await c.query('delete from orgs where id = $1', [orgId]) // cascades org_keys
  } finally {
    c.release()
  }
  await pool.end()
})

describe('byok-vault', () => {
  it('encrypts then decrypts the key (round-trip)', async () => {
    await storeProviderKey(orgId, SAMPLE)
    expect(await getProviderKey(orgId)).toBe(SAMPLE)
  })

  it('stores only ciphertext + last4 — never the plaintext', async () => {
    const c = await pool.connect()
    try {
      const meta = await c.query<{ key_last4: string; vault_secret_id: string }>(
        `select key_last4, vault_secret_id from org_keys where org_id = $1`,
        [orgId],
      )
      expect(meta.rows[0].key_last4).toBe('5566')
      const raw = await c.query<{ secret: string }>(`select secret from vault.secrets where id = $1`, [
        meta.rows[0].vault_secret_id,
      ])
      expect(raw.rows[0].secret).not.toContain(SAMPLE)
    } finally {
      c.release()
    }
  })

  it('a logged-in (authenticated) user cannot read the key', async () => {
    const c = await pool.connect()
    try {
      await c.query('begin')
      await c.query('set local role authenticated')
      await expect(c.query(`select get_org_key($1, 'vapi')`, [orgId])).rejects.toThrow()
    } finally {
      await c.query('rollback').catch(() => {})
      c.release()
    }
  })

  it('redactSecrets scrubs keys from anything logged', () => {
    expect(redactSecrets(`key=${SAMPLE}`)).not.toContain(SAMPLE)
    expect(redactSecrets({ apiKey: SAMPLE })).not.toContain(SAMPLE)
  })
})
