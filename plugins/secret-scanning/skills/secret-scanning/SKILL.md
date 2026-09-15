---
name: secret-scanning
description: Use when a secret may be entering the codebase — writing config or .env, wiring an API client, pasting an API key, token or hardcoded credential, reviewing a diff for leaked credentials — or when this plugin's write guard denied a write and the fixture escape is needed.
---

# Secret scanning

## What the guard blocks

The hook denies a write when the incoming text matches a **high-confidence** provider
pattern — chosen so real secrets trip it and placeholders do not:

- **AWS access key ID** — `AKIA` + 16 base32 chars.
- **Private key block** — `-----BEGIN … PRIVATE KEY-----`.
- **GitHub token** — `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_` + 36+ chars.
- **Slack token** — `xoxb-`/`xoxp-`/`xoxa-`/`xoxr-`/`xoxs-` + body.
- **Google API key** — `AIza` + 35 chars.
- **Stripe live secret** — `sk_live_` + 24+ chars.
- **Assigned secret literal** — `api_key`/`secret`/`token`/`passwd`/`password` set
  to a 24+ char base64-ish value. Matched **case-insensitively**, and the key name
  may carry `_`- or `-`-separated suffixes: `AWS_SECRET_ACCESS_KEY=…` matches on
  `SECRET`, even though `SECRET` is not the word adjacent to the `=`.

It deliberately does **not** flag values below the length floor, which is what
carries most placeholders (`sk_live_xxx`, `your-token-here` — too short to match).
Two things that sentence does not cover, both verified by running the hook:

- **A matched value that announces itself as fake is RELEASED.** The test reads the
  VALUE, never the variable name: it ends in `EXAMPLE` (so AWS's own documentation key
  `AKIAIOSFODNN7EXAMPLE` passes — it is *not* denied), or it carries `example`,
  `placeholder`, `changeme`, `your-`, `dummy`, `redacted`, `sample`, `fake`, `todo`,
  `xxxx`. A whole value of one repeated character also passes, but only where the match
  carries no literal prefix: measured, `SECRET=` plus 26 zeros passes, while `AKIA` plus
  sixteen zeros **denies** — the prefix breaks the repetition. For a provider shape use
  a word, not a run of zeros. Every match in a write is tested, so a placeholder beside
  a real key still denies, and `EXAMPLE_TOKEN=<real value>` still denies. Residual: a
  real secret containing one of those words passes.
- **"Already in the file" holds for `Edit`/`MultiEdit` only.** Those pass just
  `new_string`, so untouched lines are never seen. A `Write` passes the WHOLE file
  as `content`, so re-emitting a file that already contains a secret **is** denied.

## When the guard fires

You get a denial with the secret type and the file. The fix is never "force it
through":

1. **Move the value out.** Reference an environment variable or a secret store
   (`process.env.X`, `config('services.x.key')`, a mounted secret) — never the literal.
2. **If it is genuinely a fixture or example**, make the value announce itself and
   the guard releases it: end it in `EXAMPLE`, use a placeholder word (`example`,
   `placeholder`, `changeme`, `dummy`, `xxxx`), or use a value too short to match
   (`sk_live_placeholder`). The deny message names this escape. **Do not split the
   literal** across concatenated strings so the written text never carries the full
   pattern — that smuggles a real value past the pattern instead of writing a fake
   one, and it is the move this guard exists to catch. `CC_SECRET_SCAN=off`
   disables the guard for a session — for a fixture that genuinely cannot announce
   itself, never to land a real value (see the anti-patterns below).
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
- **Dressing a real value in a placeholder word** so the exemption releases it —
  `API_KEY=<real value>_sample`. The exemption exists for fixtures; spent on a live
  credential it is the one bypass this guard cannot see, and it is deliberate, not
  an accident the hook can forgive.
- **Treating a pass as proof of no secrets** — it is a backstop, not a guarantee.
