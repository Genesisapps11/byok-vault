# BYOK trust cards

Drop-in trust cards for any app built on
[`@skyhighmedia/byok-vault`](https://www.npmjs.com/package/@skyhighmedia/byok-vault).
Copy the one that fits the surface. The badges are **live** — they track the published
package + CI, so the card stays honest as the vault evolves.

Two surfaces:
- **Card A — settings / key-entry** (the modal where users actually paste a key).
- **Card B — landing / marketing** (earning trust before signup).

Each comes as **Markdown** (renders on GitHub/docs/MDX) and a **drop-in HTML/JSX** snippet
(for real product pages). Keep the wording honest — see [Keep it honest](#keep-it-honest).

---

## Card A — Settings / key-entry

Put this **right next to the key input**, at the moment of trust.

### Markdown

```md
> **Before you paste your key — here's exactly what happens to it.**
>
> - 🔒 **Encrypted at rest** in Supabase Vault. A database dump is useless on its own.
> - 🖥️ **Decrypted server-side only**, at the moment we place your call — never shown back
>   in the app, never written to logs.
> - 🔁 **You hold the off switch.** Revoke it anytime from your own provider dashboard and
>   we instantly have nothing.
>
> This is **BYOK** — the guarantee is structural, not a promise. The exact vault module is
> open and provenance-signed: **[read the code](https://github.com/Genesisapps11/byok-vault)**.
```

### Drop-in HTML

```html
<aside class="byok-card">
  <strong>Before you paste your key — here's exactly what happens to it.</strong>
  <ul>
    <li>🔒 <b>Encrypted at rest</b> in Supabase Vault. A database dump is useless on its own.</li>
    <li>🖥️ <b>Decrypted server-side only</b>, at the moment we place your call — never shown
        back in the app, never written to logs.</li>
    <li>🔁 <b>You hold the off switch.</b> Revoke it anytime from your provider dashboard.</li>
  </ul>
  <p>This is <b>BYOK</b> — structural, not a promise. The vault module is open &amp;
     provenance-signed: <a href="https://github.com/Genesisapps11/byok-vault">read the code</a>.</p>
</aside>
```

### Live per-user status (after a key is saved)

Once a key exists, show its status. Feed this from the `org_keys` metadata row
(`provider`, `key_last4`, `updated_at`) — **only `last4` is ever sent to the client; never
the key itself.**

```tsx
// props come from your server (the org_keys metadata row), not the vault plaintext.
function ByokStatus({ provider, last4, savedAgo, onRevoke }: {
  provider: string; last4: string; savedAgo: string; onRevoke: () => void
}) {
  return (
    <div className="byok-status" role="status">
      🔒 <b>{provider}</b> key ending <b>••••{last4}</b> — Active
      <button onClick={onRevoke}>Revoke</button>
      <small>Saved {savedAgo}. Cross-check usage in your {provider} dashboard.</small>
    </div>
  )
}
```

---

## Card B — Landing / marketing

Use where you're earning trust before signup.

### Markdown

```md
### 🔐 Your API key, your control — verifiably

[![byok-vault on npm](https://img.shields.io/npm/v/@skyhighmedia/byok-vault?label=byok-vault&color=2ea44f)](https://www.npmjs.com/package/@skyhighmedia/byok-vault)
[![CI](https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml)
[![npm provenance](https://img.shields.io/badge/npm-provenance%20signed-8957e5)](https://www.npmjs.com/package/@skyhighmedia/byok-vault)
[![MIT](https://img.shields.io/npm/l/@skyhighmedia/byok-vault)](https://github.com/Genesisapps11/byok-vault/blob/main/LICENSE)

You **bring your own key**. It's encrypted at rest, decrypted only server-side at the
moment of a call, and **you can revoke it in one click** from your own provider dashboard.

Don't take our word for it — the vault module is **open and provenance-signed**:
**[read the code](https://github.com/Genesisapps11/byok-vault)** ·
**[the signed package](https://www.npmjs.com/package/@skyhighmedia/byok-vault)**.
```

### Drop-in HTML

```html
<section class="byok-card byok-card--landing">
  <h3>🔐 Your API key, your control — verifiably</h3>
  <p class="byok-badges">
    <a href="https://www.npmjs.com/package/@skyhighmedia/byok-vault"><img alt="byok-vault on npm" src="https://img.shields.io/npm/v/@skyhighmedia/byok-vault?label=byok-vault&color=2ea44f"></a>
    <a href="https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/Genesisapps11/byok-vault/actions/workflows/ci.yml/badge.svg"></a>
    <a href="https://www.npmjs.com/package/@skyhighmedia/byok-vault"><img alt="npm provenance signed" src="https://img.shields.io/badge/npm-provenance%20signed-8957e5"></a>
  </p>
  <p>You <b>bring your own key</b>. It's encrypted at rest, decrypted only server-side at the
     moment of a call, and <b>you can revoke it in one click</b> from your own provider dashboard.</p>
  <p>Don't take our word for it — the vault module is open &amp; provenance-signed:
     <a href="https://github.com/Genesisapps11/byok-vault">read the code</a> ·
     <a href="https://www.npmjs.com/package/@skyhighmedia/byok-vault">the signed package</a>.</p>
</section>
```

---

## Optional styling

Framework-agnostic; tweak to your design system.

```css
.byok-card { border: 1px solid color-mix(in oklab, currentColor 14%, transparent);
  border-radius: 12px; padding: 1rem 1.25rem; line-height: 1.5; max-width: 46rem; }
.byok-card ul { margin: .5rem 0; padding-left: 1.1rem; }
.byok-card li { margin: .25rem 0; }
.byok-badges img { height: 20px; margin-right: .35rem; vertical-align: middle; }
.byok-status { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap;
  font-size: .95rem; }
.byok-status button { margin-left: auto; }
.byok-status small { flex-basis: 100%; opacity: .7; }
```

---

## Keep it honest

The whole point of this card is a claim people can trust, so don't let the copy drift past
what's true ([the vault README's "honest part"](../README.md#the-honest-part-read-this) is
the source of truth):

- **Lead with BYOK.** The structural guarantee is that *you own the account, see your own
  billing, and can revoke the key.* Open code shows intent; it doesn't prove a server runs it.
- Say **"decrypted server-side at point of use,"** never "your key is never decrypted/exported."
- Say **"open & verifiable,"** never **"audited"** (unless an independent audit actually happened).
- **Provenance** proves the *package* was built from this repo at a signed commit — it does
  **not** prove a given app runs it. Don't imply otherwise.
- The real boundary is **custody of the `service_role` key + the SQL grants**; a holder of
  that key can read plaintext. BYOK is what makes that boundary one you can audit and revoke,
  not just trust.
