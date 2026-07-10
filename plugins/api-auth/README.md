# api-auth

The auth control plane — get it wrong and every other control is moot.

- **`api-auth` skill** — pick the token model (session vs opaque vs JWT, decided by the
  revocation question), Laravel Sanctum vs Passport, OAuth2/OIDC with Authorization Code
  + PKCE, scopes and least privilege, refresh-token rotation with reuse detection, and
  secure storage (httpOnly cookies not localStorage, hashed at rest, mandatory expiry).
- **`/api-auth:review`** — audit an auth integration for the failures that end in
  account takeover: tokens in localStorage, un-revocable JWTs, deprecated OAuth flows,
  non-rotating refresh tokens, scopes checked only at issuance.

Defers broader OWASP review to security, in-app Gate/Policy usage to laravel, and
signing-key storage to secret-scanning/devops.
