---
name: secret-scanning
description: Use when a secret may be entering the codebase — writing config/.env, wiring an API client, pasting a key, or reviewing a diff for leaked credentials — and to understand the PreToolUse guard hook this plugin ships. Covers the high-confidence secret patterns, why a hook and not advice, remediation, and false-positive handling.
---

# Secret scanning

A leaked secret is the one class of mistake advice cannot prevent — by the time the
model "should have known better", the token is on disk, in a commit, and effectively
public. Detection has to be **mechanical and pre-write**, which is why this plugin's
core is a hook, not a skill you must remember to invoke.

## Why a hook, not a rule

Rules in a CLAUDE.md or a skill fire only when the model recalls and applies them. A
secret written during a routine edit — a `.env` filled in, a client wired with a
pasted key — happens in exactly the moment no one is thinking about secret hygiene.
The PreToolUse hook has no such gap: it inspects every Write/Edit/MultiEdit and denies
the ones carrying a high-confidence secret before the bytes land. Missing even one
firing is unacceptable, which is the precise test for choosing a hook over a skill.

## What the guard blocks

The hook denies a write when the incoming text matches a **high-confidence** provider
pattern — chosen so real secrets trip it and placeholders do not:

- **AWS access key ID** — `AKIA` + 16 base32 chars.
- **Private key block** — `-----BEGIN … PRIVATE KEY-----`.
- **GitHub token** — `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_` + 36+ chars.
- **Slack token** — `xoxb-`/`xoxp-`/`xoxa-`/`xoxr-`/`xoxs-` + body.
- **Google API key** — `AIza` + 35 chars.
- **Stripe live secret** — `sk_live_` + 24+ chars.
- **Assigned secret literal** — `api_key`/`secret`/`token`/`password` set to a 24+
  char base64-ish value.

It deliberately does **not** flag short values, obvious placeholders
(`sk_live_xxx`, `your-token-here`), or values already in the file — only new secrets
of a shape that is almost never a false positive.

## When the guard fires

You get a denial with the secret type and the file. The fix is never "force it
through":

1. **Move the value out.** Reference an environment variable or a secret store
   (`process.env.X`, `config('services.x.key')`, a mounted secret) — never the literal.
2. **If it is genuinely a fixture or example**, make it obviously fake (`AKIA` +
   `EXAMPLE…`, `sk_live_placeholder`) or place it outside a committed path. The guard
   passes obviously-fake values.
3. **If a real secret already leaked** (committed before the guard, or found in a
   review), rotate it first — removal from history is secondary and does not un-expose
   a key that was pushed. Flag its location; do not quietly rewrite history someone
   may be relying on.

## On-demand scanning

The hook guards *new* writes. To sweep what is **already** in the tree — a path, a
staged diff, a whole repo before first commit — run `/secret-scanning:scan`. Use it
in a security review, before an initial push, or when adopting the plugin on an
existing codebase the hook never saw being written.

## Reviewing a diff for secrets

When auditing a change (not writing one), scan beyond the provider patterns — the hook
is tuned for precision, a human review can afford suspicion:

- **`.env`, `.env.*`, config, and CI files** — the highest-yield targets; a filled-in
  `.env` committed instead of `.env.example` is the classic leak.
- **Connection strings** — `postgres://USER:PASSWORD@host`, `redis://:PASS@host` — the
  password sits inline in a URL the provider patterns may not catch.
- **Base64 blobs** — a long opaque string assigned to a credential-shaped name.
- **Private keys and certs** — `.pem`, `.key`, `id_rsa`, keystore files added to the
  tree at all.
- **Hardcoded fallbacks** — `token || "sk_live_…"`, a "temporary" real key left as a
  default.

> Worked remediation: a diff adds `STRIPE_KEY = "sk_live_51H…"` in `config/services.php`.
> Fix — replace with `env('STRIPE_SECRET')`, add `STRIPE_SECRET=` (empty) to
> `.env.example`, put the real value in the untracked `.env`, and **rotate** the
> exposed key in the Stripe dashboard because it was on a developer's disk in cleartext.

## Defer rule

- Broader application-security review (authz, input validation, OWASP) →
  `/security:review`; this plugin is scoped to credential leakage only.
- Infra-level secret *handling* (injection, secret stores, least privilege in
  manifests) → `/devops:review`. This plugin stops the leak; devops designs the
  storage.

## Limits (state them, do not oversell)

- **Regex, not entropy** — a novel token format the patterns do not cover slips
  through. The guard is a high-value backstop, not a proof of absence.
- **Write-time only** — it cannot catch a secret introduced outside the Write/Edit
  tools (a shell heredoc, a downloaded file). The on-demand scan and a real pre-commit
  scanner (gitleaks, trufflehog) complement it; the hook does not replace them.
- **High-confidence by design** — tuned to avoid false denials, so it under-flags
  rather than over-blocks. Pair with a full scanner in CI for coverage.

## Anti-patterns

- **Disabling the guard to "just commit it"** — the one time you override is the one
  time it mattered.
- **Weakening a placeholder to pass** by making it look real — defeats the point.
- **Treating a pass as proof of no secrets** — it is a backstop, not a guarantee.
