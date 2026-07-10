---
description: Review API authentication/authorization for token model, storage, OAuth flow, rotation, and scope gaps against api-auth
argument-hint: [path-or-diff]
---

Review the target's API auth — the failure class is account takeover and un-revocable
tokens.

1. Determine scope from $ARGUMENTS — auth middleware, token issuance/refresh, OAuth
   callbacks, guard config, or a diff. If empty, locate the auth layer in the repo
   (guards, middleware, token models, SDK config) and review it.

2. Invoke the `api-auth` skill from this plugin and apply its checklist: token model
   fits the need (JWT only where statelessness is real and revocation is handled);
   browser tokens in httpOnly same-site cookies not `localStorage`; TLS everywhere;
   tokens hashed at rest with a mandatory expiry; OAuth using Authorization Code + PKCE
   (no Implicit/Password grant) with `state`/`nonce` validated; refresh tokens rotating
   with reuse-detection; least-privilege scopes checked at the endpoint.

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity. A token in `localStorage`, an unverified OAuth callback, a
   non-expiring token, or a missing scope check is always critical.

4. Defer, do not duplicate: broader OWASP code review → `/security:review`; in-app
   Gate/Policy authorization usage → the laravel plugin; signing-key/secret storage →
   `/secret-scanning:scan` and devops.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor` (or the backend-engineer for stack idioms). In
   headless or non-interactive runs, report only.
