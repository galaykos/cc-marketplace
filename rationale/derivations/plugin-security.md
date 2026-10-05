# security: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-security.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/security/hooks/write-scan.sh

### Header: the shebang

```text
Absolute-path shebang, same reasoning as secret-scanning's guard: the fail-open
guarantee must hold even under a stripped PATH.
```

### Header: warn, not deny

```text
PostToolUse WARN (never deny) on the mechanically detectable subset of the
security-review skill — the Laravel/Vite shapes that used to be review-time only,
plus the stack-agnostic sinks (eval, shell-string exec, unsafe deserialization,
XXE, TLS-off, ECB, script-without-SRI) ported from Anthropic's security-guidance
pattern set, each gated to the file extensions where the token IS the sink. Warn, not deny, on purpose: each has a legitimate
form (a fixture, an admin-only Blade page, an already-sanitized sink), and a
deny that fires on ambiguous cases is a deny that gets turned off.
```

### Header: dedup, fail-open and the off switch

```text
One warning per (session, file, finding) — repeat edits stay quiet. Fail-open:
any error, or missing jq, exits 0 silently. CC_SECURITY_SCAN=off disables.
```

### Header: residual

```text
Residual (stated, per the has-teeth convention): shape-only matching on the
text being written, single-line — a multi-line yaml.load(...) call with SafeLoader
on the next line still warns, and a sink reached through an alias never does.
Cross-file flows, authz logic, injection via query builders other than whereRaw —
still review-time judgment (/security:review). GitHub Actions expression injection
is deliberately NOT here: devops/hooks/workflow-guard.sh denies it pre-write.
Three LLM sinks (prompt-interpolation, llm-output-exec, tool-result-unfenced) are
ported from llm-app's prompt-injection prose rule and carry the same single-line
residual: a system prompt assembled across lines, or a completion executed two
statements later, never fires — and no regex detects injection IN the data.
```

### Header: BASH WRITES

The "at most 8" and "the 9th target on" below are the constant `MAX_BASH_TARGETS`.

```text
BASH WRITES (0.11.4). On `Bash` the hook reads each file the command wrote from disk,
after the call: targets come from cc_bash_write_targets (shared block below), at most 8,
a relative one resolved against the payload `cwd` (a `~/` one against $HOME) and
normalized, and only the first 256 KiB of each is scanned. The whole file is scanned, so
the FIRST Bash write to an existing or downloaded file (`>>`, `sed -i`, `curl … > x.js`)
warns on its pre-existing content too; after that the per-(context, file, slug) dedup
keeps an already-warned finding quiet. A Bash call that writes nothing exits before the
lock sweep. NOT caught: interpreter writes (python open(), php file_put_contents),
cp/mv/install destinations, `{ …; } > f` groups, a path held in a variable, a relative
target in a command holding a `cd`/`pushd` (skipped, not misattributed), a quoted string
or `\` continuation spanning lines, a second heredoc on one line, the 9th target on, and
bytes past 256 KiB.
```

### The CC_REMIND switch

```text
Also honour the marketplace-wide advisory switch other plugins' READMEs advertise.
This hook is warn-only, so there is no deny lane to protect from it.
```

### The in-command cd

```text
A relative target after an in-command `cd` names a file in another directory: skip
it rather than warn about the payload cwd's same-named file. Heredoc bodies ignored.
```

### Context key and the marker tree

The "older than a day" sweep below is the constant `MARKER_TTL_MIN`. The sibling line cited as `ask-ledger/hooks/ledger.sh:53` is that hook's `key=` assignment: the `cksum` of `ctx`, read from `.transcript_path // .session_id`.

```text
CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
subagents at all, and a subagent shares its parent's session_id while getting its
own transcript. Keying a one-shot on session_id therefore dedups the worker against
nudges only the PARENT ever saw, so the context where most fan-out code is written
is the one context this never speaks in. Pattern and rationale: code-review/hooks/conventions.sh (context-key one-shot).
The context value is usually an ABSOLUTE transcript path. Used raw as a directory
component it mirrored the whole path under $TMPDIR — seven nested dirs per session —
and nothing ever removed them. Hash it, the way every sibling one-shot does
(ask-ledger/hooks/ledger.sh:53), so the marker tree is one flat dir per context, and
sweep keys older than a day. Does NOT catch: a machine where this hook never fires
again keeps its last day of markers — the sweep only runs when the hook runs.
```

### Extension gate

```text
Extension gate: a pattern that only means something in one language (eval in a
README, innerHTML in a Python docstring) is a warning that gets turned off.
Groups are ERE alternations over the lowercased basename's suffix.
any extension; the doc exclusion below still applies
```

### client-bundle-secret: the public-bundle prefixes

```text
Every bundler that exposes env to the client does it by PREFIX, and each picked its
own: Vite `VITE_`, Next `NEXT_PUBLIC_`, Nuxt `NUXT_PUBLIC_`, Expo `EXPO_PUBLIC_`,
SvelteKit/Astro `PUBLIC_`, CRA `REACT_APP_`, Gatsby `GATSBY_`, Vue CLI `VUE_APP_`.
The slug is prefix-neutral for the same reason. Does NOT catch: a secret exposed
without a prefix (an explicit `define:`/`envPrefix` override), or a name whose
secret-ness is not in the identifier (`NEXT_PUBLIC_FOO`).
```

### The stack-agnostic sinks

```text
---- stack-agnostic sinks, ported from Anthropic's security-guidance pattern set ----
(claude-plugins-official, 2026-09-03). Same warn tier, same one-per-finding dedup.
Each is gated to the language where the token IS the sink, so a README that
mentions eval() stays quiet.
```

### The LLM sinks

```text
---- LLM sinks, ported from llm-app's prompt-injection rule (2026-09-10) ----------
Each ERE is composed from named pieces so the shape stays readable; every piece is
still one line and the match is still one line. A `system`/`role: "system"` key
whose value is built by interpolation or concatenation; a completion/message value
on the same line as an exec sink; a tool-result/retrieved-chunk name interpolated
into a prompt/messages string with no delimiter token on that line.
```

## plugins/security/scripts/__tests__/write-scan.test.sh

### Header

```text
Fixture tests for hooks/write-scan.sh — each warn pattern proven to warn once,
dedup proven, clean/off/malformed inputs proven silent.
```

### client-bundle-secret cases

```text
One public-bundle prefix per bundler: the rule used to know VITE_ only, so a Next,
Nuxt, Expo, SvelteKit/Astro, CRA, Gatsby or Vue-CLI secret was written in silence.
A server-side name with no public prefix must stay silent, or the widening has
turned the rule into "any variable whose name contains SECRET".
```

### Section banners

```text
---- ported stack-agnostic sinks, each gated to its language --------------------------
---- LLM sinks, ported from llm-app's prompt-injection rule; JS/TS/PY/PHP gated ------
```

### notslug

```text
notslug <name> <file_path> <content> <slug-that-must-NOT-fire> — a sibling may
```

### Dedup and the off-switch control

```text
Dedup: same session + file + finding warns once.
Same payload with the switch ON must warn — proves the off test tested the switch.
```

### The transcript_path cases

The first block describes the marker shape before the hook hashed the key: the `mkdir -p "$(dirname "$lock")"` it names is gone, and the lock path's context component is now `cksum` of the key, one flat directory under `cc-security-scan`.

```text
---- the payload the host actually sends ---------------------------------------------
Every case above sends session_id only, so they graded the FALLBACK branch of
`.transcript_path // .session_id`. This hook puts that value in the lock path as a
DIRECTORY component, and an absolute transcript path is only survivable there because
of the `mkdir -p "$(dirname "$lock")"` on the next line. That one line is the whole
safety margin and nothing exercised it. Three sibling hooks that lacked the equivalent
shipped broken behind a green suite. Gated by pc_harness_payload.
Scoped to THIS run's key, not any lock dir: the marker dir is the cksum of the
transcript path, ONE level under cc-security-scan. Assert both directions — the keyed
dir exists AND the absolute path's own segments do not — because the old shape mirrored
`/Users/x/.claude/projects/...` into $TMPDIR, seven dirs per session, swept by nothing.
```

### Bash writes

```text
---- Bash writes: PostToolUse fires AFTER the command, so each case plants the file the
command would have written and the hook reads it back from disk. ---------------------
```
