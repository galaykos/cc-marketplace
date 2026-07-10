---
name: api-auth
description: Use when building or reviewing API authentication and authorization — token types (session, opaque, JWT), Laravel Sanctum vs Passport, OAuth2/OIDC flows, scopes, refresh-token rotation, secure token storage and transport, revocation, and expiry. Covers the day-one token-secured-API decisions and the top OWASP auth failures.
---

# API authentication & authorization

Auth is the control plane for everything else — get it wrong and every other control
is moot. Two questions frame every design: **what is the token** (and can you revoke
it), and **where does it live** (and who can steal it). Answer those deliberately; most
auth breaches are a default answered by accident.

## Pick the token model

- **Server session (opaque cookie)** — the simplest safe default for a first-party web
  app. State lives server-side; revocation is deleting the session. Pair with a
  same-site, httpOnly, secure cookie and CSRF protection.
- **Opaque API token** (Sanctum personal-access tokens) — a random string mapped to a
  DB row. Revocable instantly (delete the row), no crypto to misconfigure. The right
  default for first-party SPAs and mobile talking to your own API.
- **JWT** — self-contained, signed, stateless. Buys horizontal scale (no lookup) at the
  cost of **revocation** — a valid JWT is valid until it expires, full stop. Only reach
  for it when statelessness is a real requirement, and then keep access-token lifetimes
  short (minutes) and pair with revocable refresh tokens.

The revocation question decides it: if "log out everywhere now" must be instant, do not
choose a bare JWT.

## Laravel: Sanctum vs Passport

- **Sanctum** — first-party SPAs, mobile apps, simple API tokens. Cookie-based session
  auth for same-domain SPAs, opaque tokens for the rest. The default; reach for it first.
- **Passport** — a full OAuth2 server. Only when you are issuing tokens to **third-party**
  clients you do not control (a public API with external app developers). Using Passport
  for your own SPA is carrying an OAuth server you do not need.

## OAuth2 / OIDC — use the right flow

- **Authorization Code + PKCE** — the only correct flow for SPAs and mobile/native apps.
  PKCE is mandatory, not optional; it defends the public client that cannot hold a secret.
- **Client Credentials** — machine-to-machine, no user.
- **Never Implicit or Password grant** — both are deprecated; Implicit leaks tokens in
  URLs, Password hands your credentials to the client. If a review finds them, flag it.
- Validate the `state` parameter (CSRF on the callback) and the `nonce`/`aud`/`iss`/`exp`
  on any ID token you accept.

## Scopes and least privilege

A token carries the minimum scope its job needs — a read-only integration gets read
scope, not `*`. Check scope at the endpoint, not just at issuance; a broadly-scoped
token used on a narrow endpoint is privilege waiting to be abused. Authorization
(what this identity may do) is enforced per request; authentication (who they are) is
not authorization.

## Refresh-token rotation

- **Rotate on every use** — issue a new refresh token and invalidate the old one each
  refresh. A stolen refresh token then works at most once before detection.
- **Reuse detection** — if an already-rotated (invalidated) refresh token is presented,
  a theft has occurred; revoke the whole token family and force re-auth.
- Refresh tokens are long-lived and powerful — store them like passwords (hashed at
  rest), never in a place JS can read.

## Storage and transport

- **Browser: httpOnly, secure, same-site cookie** — not `localStorage`. A token in
  `localStorage` is readable by any XSS; httpOnly cookies are not. Accept the CSRF
  trade-off and defend it (same-site + CSRF token), rather than the XSS exposure.
- **Always TLS**; a token on plain HTTP is a token shared with the network.
- **Hash tokens at rest** — store a hash of the API/refresh token, compare hashes; a DB
  leak then exposes no usable credential.
- **Expiry is mandatory** — every token has a TTL; "never expires" is a permanent key.

## Decide fast

| Situation | Use |
|---|---|
| First-party web app, same domain | server session cookie (httpOnly, same-site) |
| First-party SPA / mobile → your API | Sanctum opaque tokens |
| Third-party developers on a public API | Passport / an OAuth2 server, Auth Code + PKCE |
| Machine-to-machine, no user | Client Credentials |
| Genuinely stateless at scale | short-lived JWT + rotating refresh token |

## Reviewing an auth integration

- Token model fits the need; JWT only where statelessness is real and revocation is handled.
- Browser tokens in httpOnly same-site cookies, never `localStorage`; always TLS.
- Tokens hashed at rest; every token has an expiry.
- OAuth uses Authorization Code + PKCE; no Implicit/Password grant; `state`/`nonce`
  validated on callback.
- Refresh tokens rotate on use with reuse-detection revoking the family.
- Scope is least-privilege and checked at the endpoint, not only at issuance.

## Defer rule

- OWASP code-level review beyond auth (injection, XSS, CSRF mechanics) → `/security:review`.
- In-app authorization gates/policies (Laravel Gate/Policy usage) → the laravel plugin.
- Secret storage for signing keys and client secrets → `secret-scanning` / devops.

## Anti-patterns

- **JWT because it's modern** — statelessness you don't need, revocation you now lack.
- **Token in `localStorage`** — one XSS from full account takeover.
- **Passport for your own SPA** — an OAuth server carried for no third party.
- **Implicit / Password grant** — deprecated flows that leak or over-trust.
- **Non-rotating, non-expiring refresh token** — a permanent credential one leak from disaster.
- **Scope checked only at issuance** — a broad token abused on a narrow endpoint.
