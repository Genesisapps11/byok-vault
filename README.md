# byok-vault

**How [SpeakOS](https://speakos.ai) keeps your API key safe — the actual code that does it.**

SpeakOS is BYOK: you bring your own voice-AI (Vapi) API key. That key is powerful, so
here is *exactly* how we store and use it. This repo is the real vault module from the
product — open so anyone can verify the claims below.

---

## In plain English

- Your key is **locked in a vault** (encrypted). What sits in our database is scrambled
  text — the unlock key is held by our database provider, **outside** the data, so a stolen
  database dump is useless on its own.
- It is **only ever unlocked on our server, for the moment we place your call**, and never
  shown to anyone — not other customers, not even to you through the app.
- It is **never written to logs.**
- **You hold the off switch.** It's *your* account — revoke the key anytime from your own
  Vapi dashboard and we instantly have nothing.

## The honest part (read this)

Open-sourcing this code proves our **design and intent**. It does **not** cryptographically
prove our servers run exactly this code — no amount of publishing can prove that. So the real,
structural guarantee isn't our promise: it's **BYOK**. You own the account, you see your own
billing, and you can kill the key in one click. The code below shows we built the careful
version; BYOK means you never have to take our word for it.

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
4. **No-log redaction** (`src/redact.ts`) scrubs key-shaped tokens from anything logged;
   errors carry codes, never key material.
5. **One chokepoint.** All key handling lives in `src/keys.ts`. Nothing else in the app
   touches plaintext.

## What's in here

| Path | What |
|---|---|
| `src/keys.ts` | the store / decrypt-at-call chokepoint |
| `src/redact.ts` | the no-log redaction layer |
| `sql/vault.sql` | the vault schema: `org_keys`, the `service_role`-only functions, grants, RLS |
| `sql/context.sql` | minimal tenancy schema `vault.sql` builds on (so it applies + tests run) |
| `test/keys.test.ts` | proves: round-trip, ciphertext-only storage, tenant role denied |

## Verify it yourself

```bash
# 1. create a Supabase project, then apply the schema:
psql "$DATABASE_URL" -f sql/context.sql -f sql/vault.sql
# 2. set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, DATABASE_URL in .env
npm install && npm test
```

## License

MIT — see [LICENSE](./LICENSE). Part of the SkyHighMedia ecosystem · [speakos.ai](https://speakos.ai)
