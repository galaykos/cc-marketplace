# security

Security review for web apps: OWASP-aligned checks for injection, XSS, CSRF,
authorization vs authentication, mass assignment, file uploads, secrets handling,
and dependency audit — mapped to PHP/Laravel and JS/Vue specifics. Also ships the
threat-modeling skill (design-phase STRIDE, trust boundaries, abuse cases), the
data-privacy skill (GDPR/CCPA regulatory layer: PII mapping, data-subject rights,
consent, retention/deletion) and the api-auth skill (token model choice, OAuth2 +
PKCE, scopes, refresh-token rotation) — the latter two applied as review lenses
when the diff touches their surface.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install security@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/security:review [files-or-diff]` | Security-review a diff or path; severity-ordered findings with exploitability notes and concrete fixes; runs `composer audit` / `npm audit` alongside |

## Example

```bash
/security:review app/Http/Controllers/UploadController.php
/security:review           # reviews the current diff before merge
```

Findings are triaged by exploitability × impact, not theoretical purity — a
`$request->all()` into `update()` on an admin-only route ranks below the same
pattern on a public endpoint.

## Pairs well with

- **testing** — turn each confirmed finding into a regression test
- **php / laravel** — general code-quality review; security:review goes deeper on the attack surface
