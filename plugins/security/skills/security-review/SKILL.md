---
name: security-review
description: Use when security-reviewing web application code for vulnerabilities to fix — authorization vs authentication (policies, IDOR), injection (SQL/command), XSS (Blade escaping, v-html), mass assignment, file uploads, CSRF boundaries, secrets handling, session/cookie transport, dependency audit, and error/log hygiene — mapped to PHP/Laravel and JS/Vue specifics with exploitability-first severity triage.
---

## Severity is exploitability times impact

Rank findings by who can trigger them and what they get — an unauthenticated
attacker reading other users' data outranks an admin-only theoretical injection:

- **Critical** — unauthenticated or any-user exploitation yielding data theft,
  account takeover, or code execution (IDOR on mutations, SQLi, unrestricted upload).
- **High** — authenticated exploitation crossing a tenant/user boundary; stored XSS.
- **Medium** — needs preconditions (MITM, an existing XSS) or leaks recon material.
- **Low** — hardening gaps: missing headers, verbose errors, dependency lag with no
  known exploit path. Report them, but never above a reachable exploit.

Severity requires proving reachability: name the route, the guard that is missing,
and the input that flows through. "Could be dangerous" is not a finding.

## Authorization is not authentication

Logged-in is not allowed-to. Every mutating route needs an explicit authz check,
not just `auth` middleware:

- Laravel: `$this->authorize()`, policy classes, `Gate::allows`, or a FormRequest
  `authorize()` — in the controller layer, where the request is decided.
- IDOR is the classic: never trust a route or body ID without an ownership check.
  `Post::findOrFail($id)` fetches ANY post; `$request->user()->posts()->findOrFail($id)`
  scopes it. Route model binding does not scope by itself — `scopeBindings()` or a policy does.
- Hiding a button is not authorization — `v-if="isAdmin"` and `@can` in Blade gate
  pixels, not requests; anyone with curl skips the frontend. Authorize server-side, always.
- Check the whole object graph: updating a comment must verify the comment's owner,
  not merely the parent post's visibility.

## Injection

- Eloquent and query-builder bindings are safe by default; the red flags are
  `whereRaw`, `DB::raw`, `orderByRaw`, `havingRaw` with interpolated input.
  `whereRaw("name = '$name'")` is SQLi; `whereRaw('name = ?', [$name])` is fine.
- `ORDER BY` and column names cannot be bound — allowlist them
  (`in_array($col, ['name','created_at'], true)`), never pass through.
- Command injection: user input reaching `exec`, `shell_exec`, backticks, or
  `Process::run` with a string command. Use `Process` array syntax or
  `escapeshellarg` — or a library instead of shelling out at all.
- Same family: `eval`, dynamic `include`/`require` paths, and `unserialize` on
  user input (object injection) — use JSON for untrusted data.

## XSS

- Blade `{{ }}` escapes; `{!! !!}` does not — every `{!! !!}` is a finding unless
  the content is provably not user-influenced or sanitized (HTMLPurifier) at render time.
- Vue: text interpolation escapes; `v-html` is the `{!! !!}` of Vue — flag it
  unless the value passes through DOMPurify first. Sanitizing on input is not
  enough; data changes shape between write and render.
- JSON in script tags: `<script>var d = {!! $json !!}</script>` breaks on
  `</script>` inside a string — use `@json($data)` / `Js::from($data)`.
- href/src built from user data: `javascript:` URLs survive HTML escaping —
  allowlist schemes.
- CSP is defense in depth, not a fix — it caps blast radius after an escaping bug ships.

## Mass assignment

- `$request->all()` into `create()`/`update()` is the classic: any extra field the
  attacker posts (`is_admin`, `role_id`, `user_id`) lands on the model.
- `$request->validated()` only helps when the rules list exactly the writable
  fields — a permissive catch-all rule rebuilds the hole.
- `$fillable` is the model-side seatbelt: explicit and short. `$guarded = []`
  disables it and is a finding on any model reachable from user input.
- Prefer explicit allowlists: FormRequest rules that ARE the field list, or
  `$request->only([...])`/`safe()->only([...])` at the call site.

## File uploads

- Validate by content, not name: extension and client `Content-Type` are attacker-
  controlled. Laravel `File::types()` / `mimes:` sniff actual bytes — use them,
  plus a `max:` size rule on every upload field.
- Store outside the webroot (`storage/app`) or in object storage — an uploaded
  `shell.php` under `public/` is remote code execution on most PHP hosts.
- Randomize stored names (`hashName()`); user filenames enable `../` traversal and
  overwrites. Keep the original name as metadata only.
- Re-encode images (resize through GD/Intervention) — strips polyglot payloads and EXIF.
- Serve user files with `Content-Disposition: attachment` or from a cookie-less
  domain; never let the browser execute what users uploaded.

## CSRF

- Laravel's `web` group covers forms by default — findings live in the escape
  hatches: routes in the CSRF `except` list, and session-authenticated endpoints
  moved to `routes/api.php` to "fix" token errors.
- Stateless `api` routes skip CSRF by design — safe only if actually bearer-token
  authenticated (Sanctum tokens), not riding the session cookie.
- Webhooks cannot carry CSRF tokens — verify provider signatures
  (`Stripe-Signature`, `X-Hub-Signature-256`) with `hash_equals`; reject unsigned payloads.

## Secrets

- `.env` never committed — check git history, not just the working tree; a
  rotated-out secret in history is still leaked. `.env.example` carries keys, never values.
- Anything `VITE_`-prefixed compiles into the public JS bundle — server tokens and
  API secrets must never carry the prefix. Grep the built assets when unsure.
- Code reads `config()`, never `env()` outside config files — `config:cache` turns
  stray `env()` calls into nulls, which teams "fix" by disabling the cache.
- Rotation must be possible: secrets in one place, out of logs, with an `APP_KEY`
  plan for anything encrypted under it.

## Sessions and transport

- Cookies: `secure`, `httpOnly`, `SameSite=lax` minimum (`strict` where UX allows);
  `SESSION_SECURE_COOKIE=true` in production, HTTPS everywhere, HSTS as depth.
- Password change invalidates other sessions and remember-tokens
  (`Auth::logoutOtherDevices`); a stolen session must not survive the reset.
- Rate limit login, password reset, and expensive endpoints (`RateLimiter::for`) —
  credential stuffing is the default assumption, not an edge case.
- `hash_equals` for any token comparison outside the framework's own.

## Dependencies and runtime

- `composer audit` and `npm audit` in CI, failing the build — an advisory nobody
  sees is an advisory nobody fixes.
- Lockfiles committed and deployed from (`composer install`, `npm ci`); unpinned
  deploys are supply-chain roulette.
- EOL runtimes are vulnerabilities, not tech debt: PHP or Node past security
  support gets no patch for the next CVE. Verify against endoflife.date, then flag.

## Errors and logs

- `APP_DEBUG=false` in production — debug pages leak env vars, credentials, and
  paths; same for exposed Ignition/Whoops and reachable `phpinfo()`.
- No secrets or PII in logs: redact passwords, tokens, card data before logging;
  `#[SensitiveParameter]` keeps them out of stack traces.
- Generic messages to users, detail to logs — "invalid credentials", not "no user
  with that email" (enumeration).

## Anti-patterns

- Findings without a path and line — a checklist recital is not a review.
- Ranking theoretical issues above reachable ones — severity is exploitability,
  not category prestige.
- "Sanitize on input, trust forever" — escape at output, per context.
- Treating frontend enforcement (disabled buttons, `v-if`, client validation) as
  any part of the security story.
- Prescribing WAF/CSP/headers as the fix for an injection or authz bug — those
  are depth layers, not repairs.
