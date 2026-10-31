# secret-scanning hooks and harnesses: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

`scripts/scan-range.sh` moved on 2026-10-28: its header as it stood, with the `# ` leader and the indentation before it removed; the file kept a header of three lines.

## plugins/secret-scanning/hooks/scan.sh

### Header: the shebang

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.
```

### Header: what it denies

```text
PreToolUse secret guard. DENIES a Write/Edit/MultiEdit/NotebookEdit, an MCP file
write, or (0.9.0) a Bash command whose heredoc or echo/printf lands text in a file,
when that text introduces a high-confidence secret, before it reaches disk.
Fail-open: any error, or a missing jq, exits 0 (allow) and never blocks legitimate
work. Only high-confidence provider patterns deny — matching is shape-only: a fixture
that still matches a pattern's shape (an AKIA-shaped fake) is denied; non-matching
shapes (sk_live_placeholder, short values) pass.
```

### Header: PLACEHOLDER EXEMPTION (0.5.0)

```text
PLACEHOLDER EXEMPTION (0.5.0), the one departure from shape-only. The deny has no
bound and no allow-file, so a write it refuses is refused on every retry, and the
reason text's own advice — "use an obviously-fake value" — was unfollowable for
the two shapes that came up: AWS's documented example key `AKIAIOSFODNN7EXAMPLE`
matches the AKIA shape by construction (every AWS doc key ends in EXAMPLE), and
an `.env.example` line `STRIPE_SECRET=<test-key prefix + a run of x's>` matches
the assigned-literal shape (the literal is not spelled out here: GitHub's own push
protection flags the x-run form as a Stripe test key, which is the point). The only
exits were a Bash heredoc around the guard (a route 0.9.0 closed, below) or
uninstalling it. So a matched VALUE is released when it is a placeholder by
its own text: it ends in EXAMPLE (the AWS convention), it is one character
repeated (xxxx…, 0000…), or it carries a placeholder word (example, placeholder,
changeme, your-/your_, dummy, redacted, sample, fake, todo). A real secret that
happens to contain one of those words passes — that residual is stated, small,
and smaller than a deny that cannot be satisfied. The check is applied to the
VALUE only, never to the variable name, so `EXAMPLE_TOKEN=<real>` still denies.
```

### Header: BASH WRITES (0.9.0)

```text
BASH WRITES (0.9.0). Until 0.9.0 this guard matched the host write tools only, and the
header above named the heredoc as the way around it. Measured 2026-09-25
(rationale/2026-09-25-session-plugin-usage-review.md, finding 1): the host steers file
writes through Bash (auto mode `bashFirst`), one session's main thread wrote 233 files
through Bash against 5 through Edit/Write, and in that session the one deny guard on
the default write path never ran. On `Bash`, when cc_bash_write_targets (shared block
below) finds at least one write target, the guard scans the text that will land in a
file — heredoc bodies and echo/printf arguments whose pipeline writes a file, read by
cc_bash_write_chunks (shared block below) — with the SAME patterns and placeholder exemption as the
Write path, through one scanner (scan_for_secret). The deny names the file the
offending chunk writes. Every target counts, inside the project or not: the Write
path never filtered by location, and a key in /tmp/deploy.env is a key on disk. No
per-call cap either — the scan reads command text, never a file, and a cap would let
the ninth heredoc through; a pathological command can still outrun the timeout, which
fails open, like every other error here.
```

### Header: NOT caught on Bash

```text
NOT caught on Bash, stated: a command with no write target (a live key in a
`curl -H` header is a different problem — it leaves the machine, not lands on disk);
interpreter writes (python open(), php file_put_contents); `cp`/`mv` of a file that
already holds a secret; sed/perl -i replacement text; and the gaps
cc_bash_write_chunks lists. command-guard owns DESTROYING a live `.env` (truncation,
overwrite); this guard owns a secret ENTERING any file, `.env.example` included, and
never asks whether the target exists.
```

### The off-switch

```text
OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
uninstalling the plugin. Every other guard in the marketplace ships one,
and a global install makes "turn it off here" a real need.
```

### The MCP arm: apply_patch and create_new_file

```text
An MCP server that writes files bypasses the four host tool names entirely, and
a session driving the IDE writes every file through one. Keys verified against
the shipped tool schemas on 2026-09-14 (JetBrains MCP): create_new_file takes
`pathInProject` + `text`; apply_patch takes `input` (alias `patch`) carrying the
whole patch, whose added lines are what a secret would ride in on, and no single
path — hence the empty `file` below, which only affects the message, not the deny.
Residual, stated: this covers the servers whose key names are listed here. A
server using different keys writes past this guard, as every non-listed tool did
before. The matcher in hooks.json and this case must widen together.
```

### placeholder and detect

```text
`--` is load-bearing: the private-key pattern starts with dashes, and without
it grep parses the pattern as options and the pattern never matches.
one character repeated for the whole value
detect <label> <ERE>: the first pattern whose match survives the placeholder
test sets the hit. Every match of a pattern is checked, not just the first — a
file can carry a placeholder AND a real value.
```

### detect_i

```text
Case-INSENSITIVE twin, for the generic assigned-literal rule only. The provider
patterns below must stay case-sensitive: `AKIA`, `AIza`, `sk_live_` and the PEM
header are literal provider prefixes, and -i would loosen them toward noise
(`aiza`+35 chars matches far more prose than the real key shape does).
the VALUE is the run of value characters at the end of the match; the
placeholder test must not see the variable name
```

### scan_for_secret

```text
scan_for_secret <text> — THE scanner, one for both paths: resets `hit`, then sets it
to the label of the first pattern whose match survives the placeholder test.
```

### The assigned-literal rule: two widenings

```text
Two widenings, both forced by where assigned literals actually live: .env,
compose `environment:`, Actions `env:`, k8s manifests, Dockerfile ENV.

1. CASE-INSENSITIVE (detect_i). Those surfaces name variables in UPPERCASE by
   convention. Matched case-sensitively, this catch-all tier — the one that
   exists precisely to cover what the provider patterns miss — let `SECRET=`,
   `API_KEY=`, `TOKEN=` and `PASSWORD=` through while denying their lowercase
   twins on identical values.
2. SEPARATOR TAIL `([_-][A-Za-z0-9]+)*`. The trigger word used to have to sit
   immediately before the operator, so the canonical `AWS_SECRET_ACCESS_KEY=`
   missed: after `SECRET` comes `_ACCESS_KEY`, not `=`. The tail is restricted
   to `_`/`-` separated segments on purpose — that is the env-var naming shape.
   It deliberately does NOT match camelCase, so `tokenizerConfig = "<long>"`
   stays clean while `AWS_SECRET_ACCESS_KEY=<long>` denies.

The old harness only exercised `api_key = "..."` — lowercase, no tail — so a
green run never showed either hole.
```

### The URL-credential rule

```text
A credential that lives in a URL rather than in an assignment. `DATABASE_URL=
postgres://admin:<pw>@db/app` in a .env, a tfvars connection string, a compose
`POSTGRES_*` DSN, a Helm values DSN — none of them is a provider key and none of
them has 24 characters after a `secret=`-shaped operator, so the whole file passed.
The password run is bounded at 6+ so `redis://localhost:6379` (no password) and
`https://user:@host` do not match; it excludes `/?#` because RFC 3986 userinfo
cannot contain them, which is what keeps `https://host:8080/mail?to=a@b.com` out;
and it refuses a leading `$`/`{` so the CORRECT shape, `postgres://u:${DB_PASS}@db`,
is not denied on every retry (measured — the first draft denied it). NOT caught,
stated: a real password that itself begins with `$` or `{`, one under 6 characters,
and any credential in a URL whose scheme is not in the list.
```

### The Slack webhook rule

```text
A Slack incoming-webhook URL is a bearer credential in URL clothing: anyone holding
it posts as the app, forever, and it matches no `secrets.`-shaped assignment. NOT
caught: any other vendor's webhook URL — each has its own shape and this is the one
that came up.
```

### The Bash branch

```text
Cheap exit for the common case — a Bash call that writes no file — before any
chunk is read.
Keep the chunks whose writer names a file; remember that file for the message.
```

### The Write branch

```text
Collect the text being written across the tool shapes.
```

### The reason text: the off-switch named

```text
Name the escape in the message that blocks you: an off-switch documented only in a
CHANGELOG is not reachable by the person it exists for.
```

### Moved 2026-10-28

The comments below left the file on 2026-10-28, verbatim with only the `# ` leader and its indentation removed; each is introduced by the code line it sat above, as that line read on the day it moved.

Header:

```text
scan.sh (PreToolUse on Write, Edit, MultiEdit, NotebookEdit, MCP apply_patch/create_new_file and Bash; payload on stdin) — denies a write whose new text
  (for apply_patch, the whole patch), Bash heredoc body or echo/printf argument landing in a file carries a high-confidence, non-placeholder secret,
  and a Bash write of redact.ts's [REDACTED: marker unless CC_SECRET_REDACT is off (Write/Edit carrying it are redact.ts's to refuse).
  PostToolUse on the same tools, and PostToolUseFailure on a Bash call that exited non-zero (hook_event_name), warning only: after a python,
  node, php, ruby, perl, deno, bun, cp, mv, install or patch run,
  on the same patterns in what each file git reports changed since this lane's previous call added (the whole file when HEAD lacks it, else its
  `+` lines against HEAD, so a line any uncommitted edit added is judged again). State: that lane's marker in the plugin's data dir
  (CLAUDE_PLUGIN_DATA), else <root>/.claude/secret-scanning/ behind a `*` .gitignore.
Off: CC_SECRET_SCAN=off. Fails open: a timeout, a missing jq or any error but a bad pattern file allows the write.
Fails closed: a missing or malformed hooks/patterns.tsv, the pattern source, or a missing hooks/patterns.sh, its reader, denies every write with
  text to scan (the PostToolUse lane stays silent).
CC_SECRET_SCAN unset: the /config option cc_secret_scan decides.
Misses: a URL password under 6 characters or led by `$` or `{`, a URL scheme not listed, a webhook URL other than Slack's; a real value holding a
  placeholder word; an MCP write tool with other key names; on Bash, a command with no write target, interpreter writes and cp/mv before they
  land, sed/perl -i text and what cc_bash_write_chunks misses; a command that outruns the hook timeout (no per-call cap). After the fact: changed
  files past the eighth (MAX_BASH_EFFECTS), text past 1 MiB per file, the redaction marker, and the bash-write-effects block's misses; a file
  anything else changed since the lane's previous call (an IDE, a parallel agent) is read as that run's write.
```

Above `detect() {`:

```text
detect <kind> <label> <flags> <ERE> — sets hit to <label> when a match of <ERE> in $text is no placeholder; a no-op once hit is set.
grep needs `--`: the private-key pattern starts with dashes, which grep would read as options.
```

Above `scan_for_secret() {`:

```text
scan_for_secret <text> — the one scanner for both paths: resets hit, then sets it to the first label whose match is no placeholder.
The first non-empty text loads $pat_file; an unusable one ends the run with a deny.
```

Above `if [ "$event" = PostToolUse ] || [ "$event" = PostToolUseFailure ]; then`:

```text
The PostToolUse lane: the write has landed, so it warns and never denies. It reads what an interpreter, cp, mv, install or
patch run changed (the bash-write-effects block), each file judged on what it added: the whole file when HEAD lacks it, else
its `+` lines against HEAD. The effects are read with the old marker, then the marker is dated, on EVERY call this lane sees,
a failed Bash call's PostToolUseFailure included.
```

Above `redact=$(cc_option CC_SECRET_REDACT on | tr '[:upper:]' '[:lower:]')`:

```text
redact.ts masks a secret in tool output as [REDACTED:<label>] and refuses Write/Edit carrying it; through Bash, the
same write-back would replace the real value on disk. With redaction off no mask is ever shown, so the text is quoted.
off, 0 and false in any case, as redact.ts's switchOn reads the same variable.
```

## plugins/secret-scanning/hooks/unicode-scan.sh

### Header: the shebang

```text
Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
even under a stripped PATH where `env bash` exits 127.
```

### Header: what it scans

```text
PostToolUse scan for INVISIBLE characters in text the model just wrote or read.
Warns — never blocks — naming the codepoint and the line, on:

  U+200B-U+200D  zero-width space / non-joiner / joiner
  U+2060         word joiner
  U+FEFF         zero-width no-break space (BOM), mid-file only; since 0.15.0 not a
                 lone one leading a *.log line or tab-separated field, where GitHub
                 starts each step's output (gh run view --log puts it after the job
                 and step fields; a saved CI log drew the warning for it)
  U+202A-U+202E  bidirectional overrides (the "Trojan Source" class, CVE-2021-42574)
  U+2066-U+2069  bidi isolates
  U+00AD         soft hyphen
  U+E0000-U+E007F  Unicode tag block — the "invisible instruction" carrier
```

### Header: WHY A SCRIPT AND NOT PROSE

```text
WHY A SCRIPT AND NOT PROSE. The model cannot see these characters. They do not render,
they survive copy-paste, and in the bidi class they make source code display in an
order different from the order it executes — a reviewer reads one program and the
compiler reads another. No amount of instruction helps with a byte that is not shown;
only a scanner reports it. This is the one rule in this plugin whose subject is
invisible by definition.
```

### Header: WHY PostToolUse AND WARN, NOT PreToolUse AND DENY

```text
WHY PostToolUse AND WARN, NOT PreToolUse AND DENY. Two reasons, both measured rather
than assumed: legitimate zero-width joiners appear in emoji sequences and in Arabic,
Persian and Indic text, so a deny would break writing those languages; and the
interesting case is usually a file being READ — content arriving from outside the
session, where blocking the read helps nobody and knowing what is in it does.
```

### Header: WHAT IT DOES NOT CATCH

```text
WHAT IT DOES NOT CATCH, stated because the README tiers it:
  - Homoglyphs (Cyrillic а in an ASCII word). Those are visible, just not distinct;
    a different check with a different false-positive profile.
  - Anything in a file the session never touched, and a file Bash wrote in a way
    cc_bash_write_targets cannot see (see BASH WRITES below).
  - The hostile case specifically: it reports presence, not intent. A zero-width run
    inside a prompt-shaped sentence and one inside a CJK string look identical here.
```

### Header: BASH WRITES (0.9.0)

```text
BASH WRITES (0.9.0). The host steers file writes through Bash heredocs, and in one
measured session the main thread wrote 233 files through Bash against 5 through
Edit/Write (rationale/2026-09-25-session-plugin-usage-review.md, finding 1), so a file
written that way was never scanned. On `Bash` the hook takes the command's write
targets from cc_bash_write_targets (shared block below), resolves a relative one
against the payload `cwd` — the Bash tool's own cwd, which is what the shell resolved
it against — keeps those under the project root (cc_state_root) that now exist as
regular files, and scans each exactly as a Write. Cheap by construction: a Bash call
with no write target costs one awk pass and exits before any root lookup, and at most
8 targets are handled per call, so a mass-write command cannot make one call slow.
Residual, stated: the 9th target on, cp/mv destinations, interpreter writes, and a
path held in a variable are not scanned.
```

### Header: STATE and the off-switch

```text
STATE. None under the project: the one-shot marker lives in $TMPDIR, so the
state-root conversion has nothing to move; cc_state_root is here only to bound WHICH
Bash targets count.

CC_UNICODE_SCAN=off disables it. Fail-open on every error path.
```

### report_file

```text
report_file <path> — prints this file's warning (lead sentence, then one line per
hit), or nothing when the file is clean, too big, unreadable or already reported.
Bound the read: a scanner that stalls on a 2 GB file is a latency bug, not a guard.
`tr -d` is load-bearing: BSD wc pads its output ("      26"), and the numeric
guard below would reject that as non-numeric and silently disable the whole hook.
```

### report_file: the one-shot marker

```text
One-shot per file per session: the same file is read and written repeatedly, and a
warning repeated on every touch is a warning nobody reads. The shot is SPENT only
by a warning (below, after the scan found something). Until 0.9.1 the marker was
claimed before the scan, so a clean first touch used up the file's one warning and
invisible characters written into it later went unreported — "warns once" read as
"checks once". Bash-written files made that the common path: a file is created by
one heredoc and appended by the next.
Claim the shot now. mkdir is atomic: of two concurrent hooks on the same file,
exactly one reports.

0.15.0: the key was the transcript path (else the session id) and the file, so the
same mockup HTML warned once in each of three read-only reviewer subagents in one
measured session. It is now the date, the project root (cc_state_root of the payload
cwd), the file and the codepoints the scan found with their positions dropped: one
warning per project, file and day, and again that day only when the set of invisible
characters changes, so a reflowed file stays quiet and an added character speaks.
Accepted cost: a new session the same day is not told about an unchanged file it
reads, and the day turns at local midnight.

0.15.0, review round (2026-10-15): that per-day key was reverted. The warning exists for
the model context that ingests the hidden text, and a subagent or a later session that
Read a file with tag characters was never told. The key is now the session_id plus the
payload's agent_id (the transcript path when there is no session_id), the file, and a
sha1 of every hidden codepoint in order. Premise checked before keying on session_id:
the 2026-09-29/10-01 candor probes show SubagentStart, SubagentStop and Stop carrying one
session_id and a PostToolUse inside the subagent carrying an agent_id, and a subagent
transcript's own sessionId field reads the parent's session (checked on a local
transcript, 2026-10-15) — so session_id alone dedups subagents, and agent_id is what
tells them apart. The digest covers codepoints past the six the report names: the old
key was built from the report, so six U+200B and a seventh turned into U+202E stayed
silent. Cost: a file with hits is read whole, as a clean one always was (1.87 MB with
110k hits, 31 -> 208 ms; clean, 200 ms).
```

### The Bash branch: resolving a target

```text
Logical `cd && pwd` folds `..` without resolving symlinks, so the result keeps
the spelling cc_state_root used and the prefix test compares like with like.
A relative target resolves against the payload cwd: that IS the shell's cwd.
```

### Moved 2026-10-28

The comments below left the file on 2026-10-28, verbatim with only the `# ` leader and its indentation removed; each is introduced by the code line it sat above, as that line read on the day it moved.

Header:

```text
unicode-scan.sh (PostToolUse on file writes and reads, Bash included, and PostToolUseFailure on Bash; payload on stdin) — warns once per model
  context (a session's main thread, each subagent) and file, again only when the file's invisible characters change, never blocks,
  naming line and codepoint, when a file the call wrote or read holds a zero-width, bidi, soft-hyphen, mid-file BOM or Unicode tag character
  (a lone BOM leading a `*.log` line, or a tab-separated field of one, is a CI step's encoding and skipped);
  after a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run, also each file git reports changed since this hook's previous call.
Off: CC_UNICODE_SCAN=off or CC_REMIND=off. Fails open on every error path; its one-shot markers live in $TMPDIR, its one bash-effects marker in
  the plugin's data dir (CLAUDE_PLUGIN_DATA), else <root>/.claude/secret-scanning/ behind a `*` .gitignore.
CC_UNICODE_SCAN / CC_REMIND unset: the /config options cc_unicode_scan / cc_remind decide.
Misses: homoglyphs; intent (presence only); a file over 2 MB or not valid UTF-8; naming hits past the sixth in a file (they still pick the
  message and the one-shot); a file the session never touched; a character stored as a JSON backslash-u escape (a .ipynb or .json
  the session only read); an MCP apply_patch (no single path); on Bash, a
  target past the eighth, outside the project root, not an existing regular file or relative after an in-command cd, and cc_bash_write_targets' misses;
  after an interpreter run, changed files past the eighth (MAX_BASH_EFFECTS) and the bash-write-effects block's misses. Reads too much: a file
  anything else changed since this hook's previous call (an IDE, a parallel agent) is read as that run's write.
```

Above `{ IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; IFS= read -r ctx; } < <(printf '%s' "$input" \`:

```text
Interpreter writes: read the effects with the old marker, then date it, on EVERY call this hook sees (a Read too), so a
file an Edit changed or a command that wrote nothing is never read as the next run's write. A failed Bash call fires
PostToolUseFailure, whose envelope must name that event.
```

Above `key=$(printf '%s|%s|%s' "$ctx" "$file" "$digest" | cksum 2>/dev/null | cut -d' ' -f1)`:

```text
One warning per model context and file while the file holds the same invisible characters: each context that ingests the
text is told once. Claimed only after a hit, so a clean touch keeps the file's one warning; mkdir is atomic, so one of two
racing hooks reports.
```

## plugins/secret-scanning/hooks/patterns.sh

```text
Moved out of scan.sh on 2026-10-15 (0.15.0, review round): scripts/scan-range.sh had
re-implemented the loader, the placeholder rule and the assigned-value extraction, and
checked less — no edge-space, dialect, escape, empty-match or placeholder-probe check —
so a row scan.sh refused was applied by the sweep. One sourced file, as candor's
hooks/cite.sh is for its gate and /candor:check. scan.sh keeps its fail-closed contract:
a missing patterns.sh defines a load_patterns that fails, so every write with text is
refused as for a bad patterns.tsv; scan-range.sh exits 2. pat_value sets a variable
rather than printing, so a secret-row match costs no subshell in the hook.
```

### Moved 2026-10-28

The comments below left the file on 2026-10-28, verbatim with only the `# ` leader and its indentation removed; each is introduced by the code line it sat above, as that line read on the day it moved.

Header:

```text
patterns.sh — sourced, never run, by hooks/scan.sh (the write guard) and scripts/scan-range.sh (/secret-scanning:scan): one reader of
  hooks/patterns.tsv, so the guard and the sweep cannot disagree on what a row means, what is a placeholder, or which value is judged.
load_patterns <file>: reads <file> into pat_kind/pat_label/pat_flags/pat_re (secret and assigned rows, in file order) and the
  ph_i/ph_c placeholder alternations; returns 1 with pat_bad set when it is missing or malformed.
placeholder <value>: 0 when the value announces itself as fake. pat_value <kind> <match>: sets pat_v to the value a match is judged on.
```

## plugins/secret-scanning/hooks/patterns.tsv

### The provider rows adapted from gitleaks (0.15.7)

Written 2026-10-31. Unlike the sections above, it was not moved out of code.

What shipped: before this release, a Write into `app.ts` passed `hooks/scan.sh` when it held any of these: `const key = "sk-ant-api03-…AA";`, the same key in an `Authorization: "Bearer …"` header, `GH_PAT=github_pat_…`, or `const t = "github_pat_…";`. Only `apiKey: "sk-ant…"` and `ANTHROPIC_API_KEY=…` were denied, on the generic assigned row. A researcher reported more that passed: OpenAI `sk-proj-`/`sk-svcacct-`/`sk-admin-` keys holding `T3BlbkFJ`, GitLab `glpat-`, Hugging Face `hf_`, AWS `ASIA`/`ABIA`/`ACCA` key IDs, Stripe `rk_live_`, SendGrid `SG.`, npm `npm_` and PyPI `pypi-AgEI…`. The provider rows were written before those formats existed. The redaction mod and `scripts/scan-range.sh` read the same file, so they missed the same values.

Source: gitleaks' default config, `config/gitleaks.toml`, fetched 2026-10-31 at commit `5f6ec56cfa6f8c67648d863582c7ae2f206d5c1c` (master, committed 2026-10-23). gitleaks is MIT-licensed, "Copyright (c) 2019 Zachary Rice" (its `LICENSE` at that commit). Rules used: `anthropic-api-key`, `anthropic-admin-api-key`, `openai-api-key`, `github-fine-grained-pat`, `gitlab-pat`, `huggingface-access-token`, `aws-access-token` (its prefix set only), `stripe-access-token` (`rk_live_` only), `sendgrid-api-token`, `npm-access-token`, `pypi-upload-token`.

How each rule was translated into this file's dialect:

- `\w` became `[A-Za-z0-9_]`, and `\-` inside brackets moved to the bracket's end. `(?i:[a-z]{34})` and `(?i)[a-z0-9=_\-\.]` now list both letter cases. `(?:` became `(`.
- Dropped: the leading `\b`, the trailing `(?:[\x60'"\s;]|\\[nr]|$)` group, every `entropy` filter and every keyword prefilter. Without lookaround, a boundary has to consume a character. That shifts the redaction mask, and it swallows the separator the next key's match needs. So a row also matches a prefix inside a longer word (`xhf_` + 34 letters), and the first N characters of a longer run. Only the provider prefix and the length carry the confidence.
- Some runs are open-ended where gitleaks gives a range: Stripe `{10,99}` and PyPI `{50,1000}` are capped above only so the trailing boundary can fire, and GitLab's `{20}` has no boundary at all. Here they are `{10,}`, `{50,}` and `{20,}`. The same texts match, and the mask covers the whole run instead of leaving its tail readable. Fixed-length formats keep the exact count: `{93}AA`, `{82}`, `{34}`, `{36}`, `{66}`.
- npm keeps its `npm_` prefix case-sensitive. gitleaks' `(?i)` covers the prefix as well, and this file keeps `i` off provider rows.
- AWS: the existing row gained `A3T[A-Z0-9]`, `ASIA`, `ABIA` and `ACCA`. Its `[0-9A-Z]{16}` body stays, rather than gitleaks' base32 `[A-Z2-7]{16}`, so no `AKIA` value that denied before passes now.

Not taken:

- Stripe `test` and `prod` keys, for both `sk_` and `rk_`. Test-mode keys reach no live data, and `.env.example` files carry them (`scan-hook.test.sh`, `.env.example x-run`).
- `huggingface-organization-api-token`. Its `api_org_` prefix reads like a snake_case identifier, and nothing in the report named it.
- `gitlab-pat-routable`. Its prefix is `glpat-`, which the open-ended row already matches.
- Every other gitleaks rule.

Order: the new rows sit after the Stripe live row, ahead of the URL and assigned rows. A key under a key-like name (`apiKey: "sk-ant-…"`) is now denied under its provider's label. The assigned row still matches it, so the mod's mask names both labels (`pattern-parity.test.sh` pins the text). Measured 2026-10-31: each row takes about 10 ms under `grep -oE` on a 1 MB line. The parity harness's redact timings stayed under its 500 ms bound (12 ms on the 300 kB `token-` line).

Residual:

- A real key holding a placeholder word (`todo`, `fake`, `xxxx`) is released, as on every row.
- `hf_` and `SG.` match inside a longer word.
- Any token format newer than that commit is missed.
- So is an OpenAI key whose halves are neither 58 nor 74 characters.

## plugins/secret-scanning/scripts/__tests__/scan-hook.test.sh

### Header

```text
Fixture tests for hooks/scan.sh — the deny path of the marketplace's only
secret guard finally gets a harness: every deny pattern proven to deny, clean
and out-of-scope inputs proven to pass, fail-open proven to stay open.

Trigger strings are ASSEMBLED AT RUNTIME (concatenation / printf) so this file
never contains a secret-shaped literal — the guard denies shape-matching
writes even in fixtures, by design, including a write of this very file.
Runtime-assembled shapes (split so no source literal matches any pattern).
```

### The uppercase twins

```text
UPPERCASE twins. Env-var names are uppercase by convention, so these are the
COMMON real shapes for an assigned literal, not edge cases — and every one of
them passed the guard until the rule was made case-insensitive. Lowercase-only
coverage is what hid that: the rule denied, in the one casing anyone tested.
```

### The allow cases: lowercased provider prefixes and camelCase

```text
The -i applies to the generic rule ONLY; a lowercased provider prefix must still
pass, or the loosening this fix introduces has leaked into the provider tier.
The separator tail must not swallow camelCase: a trigger word that merely PREFIXES
a longer identifier is not an assignment of that secret. Guards the widening.
```

### The placeholder cases

```text
0.5.0 PLACEHOLDER EXEMPTION. A matched VALUE that announces itself as fake is
released; the deny is unbounded and has no allow-file, so before this the AWS
documentation key and an .env.example line were refused on every retry.
The exemption reads the VALUE, never the name, and every match is checked.
```

### The URL-embedded credential cases

```text
0.8.0 URL-EMBEDDED CREDENTIALS. A DSN in a .env, tfvars, compose or Helm values file
is neither a provider key nor an `assigned secret literal` — the trigger word is the
scheme, not a `password=` operator — so every shape below was written to disk silently.
Assembled at runtime, same reason as every other trigger in this file.
The shapes that must stay allowed, or the rule denies correct code on every retry.
The runtime-substitution one is the CORRECT way to write a DSN; a deny there has no
satisfiable fix. `/?#` exclusion is what keeps an ordinary URL with a mailto-ish query
out; the placeholder escape still applies to the whole match.
```

### Fail-open and the Edit shape

```text
Fail-open: malformed JSON must not deny (and must exit 0).
Edit tool shape (new_string) must also be scanned.
```

### The Bash write cases

```text
0.9.0 BASH WRITES. The host steers file writes through Bash heredocs; in the measured
session 233 of 238 main-thread writes went that way and never met this guard
(rationale/2026-09-25-session-plugin-usage-review.md, finding 1). The Bash path scans
heredoc bodies and echo/printf arguments whose pipeline writes a file, with the Write
path's patterns and placeholder exemption. Payloads carry a real `cwd` inside a temp
git repo so the last case can prove the hook leaves no state behind.
Routes the extractor claims beyond the brief's list, each pinned once.
The guard writes no state: nothing may appear under the payload's cwd or the repo root.
```

## plugins/secret-scanning/scripts/__tests__/unicode-scan.test.sh

### Header

```text
Fixture tests for hooks/unicode-scan.sh — the invisible-character scanner.
Bytes are written with printf escapes, never with literal invisible characters in
this file: a fixture whose point is an unreadable byte must not depend on that byte
surviving an editor, a copy-paste, or this repo's own review.
```

### Case notes

```text
the bidi class gets its own message, because the consequence is different
the report names a location, not just a fact
one-shot per project, file and day (0.15.0; per session before)
a clean touch does NOT spend the file's one warning (0.9.1): created clean, then an
invisible character appended — the second touch must still warn.
off switches
fail-open
```

### The Bash write cases

```text
0.9.0 BASH WRITES. A file written by a heredoc never reached this hook
(rationale/2026-09-25-session-plugin-usage-review.md, finding 1). The hook runs AFTER the
command, so each fixture file is created first and the payload carries the command that
wrote it. The cwd is a SUBDIRECTORY of a temp git repo, as after the model's `cd`.
```

## plugins/secret-scanning/scripts/scan-range.sh

### Header

```text
scan-range.sh <base>..<head> | --cached | <path>… — applies hooks/patterns.tsv, the file the write guard and the redaction mod read, to the
  lines a git range or the index ADDED, or to whole files: a file path as given, a directory's git-tracked files (every file under it
  outside git). Prints one `<file>:<line> <label> (<first 4 characters>****, <n> chars)` per matching line, never a whole value; a count
  to stderr. A range or the index names files from the repo root, from any directory. A name holding a tab, newline, `"` or `\` prints
  in git's escapes (`\t`, `\n`, `\"`, `\\`), unquoted, in every mode.
Exit: 0 nothing matched · 1 a match · 2 nothing was scanned (no argument, a missing path, a range or index git cannot diff, an unusable
  patterns.tsv as scan.sh judges it, or no hooks/patterns.sh).
Matching is scan.sh's, through hooks/patterns.sh: secret and assigned rows in file order, the first non-placeholder match names the line.
Misses: a secret split across lines (each line is matched alone), a shape patterns.tsv does not list, a real value holding a placeholder
  word, binary files, a line a range removed (the secret is still in history), history outside the range, untracked files under a
  directory in git; in path mode a name's other control characters print raw.
```
