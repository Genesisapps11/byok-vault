# @skyhighmedia/byok-vault

[![CI](https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml)

**The BYOK vault module SkyHighMedia apps use to keep your provider API key safe — the actual code that does it.**

These apps are BYOK: you bring your own provider API key (e.g. your voice-AI key for
[SpeakOS](https://speakos.ai)). That key is powerful, so here is *exactly* how it is stored
and used. This is the real vault module from the products — open so anyone can verify the
claims below.

**Used by:** [SpeakOS](https://speakos.ai) _(and other SkyHighMedia apps)_.

---

## In plain English

- Your key is **locked in a vault** (encrypted). What sits in the database is scrambled
  text — the unlock key is held by the database provider, **outside** the data, so a stolen
  database dump is useless on its own.
- It is **only ever unlocked on the server, for the moment it is needed**, and never
  shown to anyone — not other customers, not even to you through the app.
- It is **never logged by the vault**, which also ships a redaction helper to scrub
  key-shaped tokens from the app's other logging paths.
- **You hold the off switch.** It's *your* account — revoke the key anytime from your own
  provider dashboard and the app instantly has nothing.

## The honest part (read this)

Open-sourcing this code proves our **design and intent**. It does **not** cryptographically
prove our servers run exactly this code — no amount of publishing can prove that. Concretely,
the real boundary is **custody of the server-side `service_role` key plus the SQL grants**:
whoever holds that key can decrypt a stored key server-side, so the guarantee can't rest on any
single line of app code. That's why the real, structural guarantee isn't our promise: it's
**BYOK**. You own the account, you see your own billing, and you can kill the key in one click.
The code below shows we built the careful version; BYOK means you never have to take our word for it.

---

## How it works (technical)

1. **Encrypted at rest — Supabase Vault.** Keys are stored as Vault secrets (`sql/vault.sql`).
   The ciphertext lives in `vault.secrets`; the encryption key is managed by Supabase outside
   the database. A `pg_dump` yields ciphertext only.
2. **Plaintext is `service_role`-only.** Two `SECURITY DEFINER` functions (`store_org_key`,
   `get_org_key`) are the *only* way to reach a key. `EXECUTE` is **revoked from
   `anon`/`authenticated`** and granted to `service_role` alone — so a logged-in customer
   literally cannot call them, and the `vault` schema is never granted to tenant roles.
3. **Row-Level Security.** A customer can read only their own metadata row — provider +
   **last 4 characters**, never the key, never another tenant's.
4. **No-log redaction** (`src/redact.ts`) scrubs key-shaped tokens from values the app
   passes through it; the vault's own errors carry codes, never key material.
5. **One chokepoint.** All *app-side* key handling lives in `src/keys.ts`. The boundary that
   actually *enforces* this is the `service_role`-only SQL functions (#2) plus custody of the
   service-role key — the TS file is the convention; the SQL grants are the enforcement.

## Install

```bash
pnpm add @skyhighmedia/byok-vault
# or: npm install @skyhighmedia/byok-vault
```

```ts
import { storeProviderKey, getProviderKey } from '@skyhighmedia/byok-vault'
import { redactSecrets } from '@skyhighmedia/byok-vault/redact'
```

> **ESM-only** (Node 18+). Import via ESM; there is no CommonJS `require()` build.

The chokepoint reads `SUPABASE_URL` (or `NEXT_PUBLIC_SUPABASE_URL`) and
`SUPABASE_SERVICE_ROLE_KEY` from the environment. **Server-only:** the service-role key
bypasses RLS — never bundle it to a browser. In Next.js, re-export from a module that begins
with `import 'server-only'`.

## What's in here

| Path | What |
|---|---|
| `src/keys.ts` | the store / decrypt-at-call chokepoint |
| `src/redact.ts` | the no-log redaction layer |
| `sql/vault.sql` | the vault schema: `org_keys`, the `service_role`-only functions, grants, RLS |
| `sql/context.sql` | minimal tenancy fixture `vault.sql` builds on (test-only; apps bring their own) |
| `test/keys.test.ts` | proves: round-trip, ciphertext-only storage, tenant role denied |

## Adopting it in your own schema

`sql/vault.sql` ships with the SpeakOS tenancy as the default. It is parameterised by two
**HOST SCHEMA CONTRACT** points (documented at the top of the file): the tenant table the key
rows reference, and the metadata-read RLS predicate. Substitute your own (e.g. `tenants` + a
JWT-claim predicate) in your app's migration. **Keep the function names and param names
(`store_org_key` / `get_org_key`, `p_org_id`) unchanged** — the shared `src/keys.ts` calls
them by name, so keeping them is what lets every app use this package's chokepoint as-is.

## Verify it yourself

```bash
# 1. create a Supabase project, then apply the schema:
psql "$DATABASE_URL" -f sql/context.sql -f sql/vault.sql
# 2. set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, DATABASE_URL in .env
pnpm install && pnpm test
```

The tests are the proof — and they run in CI on every push (see the badge above).

## License

MIT — see [LICENSE](./LICENSE). Part of the SkyHighMedia ecosystem · [speakos.ai](https://speakos.ai)
