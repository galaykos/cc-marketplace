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

## Boundary with Claude Code's built-in `/security-review`

Claude Code ships its own `security-review` skill, which reviews the pending
changes on the current branch. Since 0.8.0 `/security:review` **wraps** it: when the
session lists the bare host skill (this plugin's own skill lists as
`security:security-review`, which is not the same thing) and the scope is the
branch diff, the generic OWASP pass is delegated to the built-in, report-only, and
this command adds what the built-in lacks — the pin against the installed framework
version, `composer audit` / `npm audit` folding, the secret-scanning fold, the
threat-model disposition audit, the data-privacy and api-auth lenses, the coverage
inventory and the self-refute pass. A path or file-set scope, or a session without
the built-in, runs the whole review inline. Standing: recorded — nothing checks
which branch ran; the `Checked:` line says.

## Commands

| Command | What it does |
|---------|--------------|
| `/security:review [files-or-diff]` | Security-review a diff or path; severity-ordered findings with exploitability notes and concrete fixes; runs `composer audit` / `npm audit` alongside; wraps the host's built-in `security-review` on a branch-diff scope (see Boundary above) |

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
empty `$guarded`, unescaped `{!! $ !!}` Blade output, secrets carrying any
public-bundle env prefix (`VITE_`, `NEXT_PUBLIC_`, `NUXT_PUBLIC_`, `EXPO_PUBLIC_`,
`PUBLIC_`, `REACT_APP_`, `GATSBY_`, `VUE_APP_`), variables inside `whereRaw` SQL, and
raw HTML sinks (`dangerouslySetInnerHTML`, `v-html`, Svelte `{@html }`, Astro
`set:html=`, `innerHTML`/`outerHTML`/`insertAdjacentHTML`, `document.write`). Since 0.7.0
it also carries the stack-agnostic sinks ported from Anthropic's `security-guidance`
pattern set, each gated to the file types where the token IS the sink: `eval` / `new
Function`, shell-string execution (`child_process.exec`, `execSync`, PHP `exec` /
`shell_exec` / `system` / `passthru`, `os.system`, `subprocess(..., shell=True)`),
unsafe deserialization (`pickle` and its wrappers, PHP `unserialize($…)`), `yaml.load`
without `SafeLoader`, `torch.load` without `weights_only`, XML parsed with entities on,
TLS verification switched off (`verify=False`, `rejectUnauthorized: false`, Guzzle
`'verify' => false`, `CURLOPT_SSL_VERIFYPEER`), ECB / `createCipher`, and an external
`<script>` without `integrity=`. Since 0.9.0 three LLM sinks ported from the llm-app plugin's prose rule (that plugin was removed 2026-09-14; the sinks stay here) — from its
prompt-injection rule, gated to JS/TS/Python/PHP: `prompt-interpolation` (a `system` /
`role: "system"` string built by interpolation or concatenation), `llm-output-exec` (a
completion / `choices[0]` / `.content` value on the same line as `eval`, `exec`,
`new Function`, `child_process`, `subprocess` or a PHP shell call) and
`tool-result-unfenced` (a `tool_result` / `retrieved*` / `chunks` / `documents` name
interpolated into a `prompt` / `messages` string with no delimiter token on that
line). Since 0.11.4 it warns on files a Bash command writes as well (a `>`/`>>` redirect,
`tee`, `sed -i`), read from disk after the call, at most 8 files and 256 KiB of each; it
does not see a path held in a variable, or a relative target in
a command holding a `cd`/`pushd` (skipped). The whole file is read, so
the first Bash write to an existing or downloaded file also warns on what was already
there. Since 0.12.4, after a python, node, php, ruby, perl, deno, bun, cp,
mv, install or patch run it also reads up to 8 files git reports changed since the
hook's previous call, judged on what each added: the whole file when HEAD lacks it, else its
`+` lines against HEAD (so a line any uncommitted edit added warns again; what HEAD already
held does not). A command that exits non-zero fires `PostToolUseFailure`, registered for Bash
too, and is read the same way. It misses a writer it does not name (`npx prettier --write`,
`make`), gitignored files, a repo with no git, a submodule's files, anything under `.claude/`, a
file written then reverted, a `mv` or `cp -p` destination that keeps an older mtime and the first
such run of each session (the marker holds the session's cksum; another session's reads as
none); a `$HOME` root or a repo with `status.showUntrackedFiles=no` reads nothing. It reads
anything else that changed a file since its previous call (an IDE, a parallel agent) as this
run's write. Its marker lives in the plugin's data dir, else under `<repo>/.claude/security/`
behind a `*` `.gitignore`. `write-scan.test.sh` runs a python write, the first call, a run that
wrote nothing, an Edit between two runs, a tracked file's added line, a failed run's
`PostToolUseFailure` envelope and another session's marker. A non-matching Bash call costs
11.9 ms median and a matching one that wrote nothing 21.3 ms on a synthetic 2,786-file repo
(10.4 and 16.5 ms before the session key, the failure event and the one-`find` read). Also since 0.12.4, a target outside the project root (the session cwd's git toplevel,
else `CLAUDE_PROJECT_DIR` when the cwd is under it, else the cwd), or under `$TMPDIR`
(`/tmp`) while the project is not, is skipped on every tool: a scratch probe is not the
project. A sibling worktree written by absolute path from another checkout is skipped
too. Warn — never deny — because each has a legitimate form; `CC_SECURITY_SCAN=off`
disables it, and `CC_REMIND=off` silences it along with
every other advisory nudge in this marketplace. Single-line matching only: a `SafeLoader` on
the next line still warns, a system prompt assembled across lines never does. GitHub Actions expression injection is deliberately not
here — `devops` denies it pre-write. Everything else (authz logic, cross-file flows,
dependency audit) stays review-time via `/security:review`.

## Pairs well with

- **testing** — turn each confirmed finding into a regression test
- **laravel** — general code-quality review; security:review goes deeper on the attack surface
