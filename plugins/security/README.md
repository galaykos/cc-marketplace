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

## What has teeth

Since 0.6.0 a PostToolUse hook (`hooks/write-scan.sh`, fixture harness in CI) WARNS at
write time on the mechanically detectable shapes from the security-review skill:
empty `$guarded`, unescaped `{!! $ !!}` Blade output, `VITE_`-prefixed secrets,
variables inside `whereRaw` SQL, and raw HTML sinks (`dangerouslySetInnerHTML`,
`v-html`, `innerHTML`/`outerHTML`/`insertAdjacentHTML`, `document.write`). Since 0.7.0
it also carries the stack-agnostic sinks ported from Anthropic's `security-guidance`
pattern set, each gated to the file types where the token IS the sink: `eval` / `new
Function`, shell-string execution (`child_process.exec`, `execSync`, PHP `exec` /
`shell_exec` / `system` / `passthru`, `os.system`, `subprocess(..., shell=True)`),
unsafe deserialization (`pickle` and its wrappers, PHP `unserialize($…)`), `yaml.load`
without `SafeLoader`, `torch.load` without `weights_only`, XML parsed with entities on,
TLS verification switched off (`verify=False`, `rejectUnauthorized: false`, Guzzle
`'verify' => false`, `CURLOPT_SSL_VERIFYPEER`), ECB / `createCipher`, and an external
`<script>` without `integrity=`. Warn — never deny — because each has a legitimate
form; `CC_SECURITY_SCAN=off` disables. Single-line matching only: a `SafeLoader` on
the next line still warns. GitHub Actions expression injection is deliberately not
here — `devops` denies it pre-write. Everything else (authz logic, cross-file flows,
dependency audit) stays review-time via `/security:review`.

## Pairs well with

- **testing** — turn each confirmed finding into a regression test
- **php / laravel** — general code-quality review; security:review goes deeper on the attack surface
