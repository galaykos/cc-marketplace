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

## plugins/secret-scanning/hooks/redact.ts

### The Higgsfield signed upload URL (0.16.0, 2026-11-09)

Session retro 2026-11-05, issue 16. In sessions `5df215ae`/`64de927c` (cowork) and `5d6230d0`/`b1c33fa3` (little-sprito), Higgsfield's
MCP `media_upload` result came back with its `X-Amz-Security-Token` value masked as "an assigned secret literal". The tool was
`mcp__91037719-f36d-439c-a49c-805a84b65a0d__media_upload`, a claude.ai connector named by UUID. The assigned-row mask runs to the
next quote, so it also swallowed `X-Amz-Signature`. The model then said "The upload link came back redacted, so I can't send the
file". It regenerated reference views for about 6 more credits in one session and dropped a planned inpainting fix in the other.
Since 0.15.7 the AWS row also matches the `ASIA…` key ID in `X-Amz-Credential`, so today both values would be masked.

The shape, read from the 2026-10-29 transcript line (`5df215ae`, line 6119) on 2026-11-09:
`https://upload.higgsfield.ai/user_<id>/<uuid>.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=<ASIA…>%2F<date>%2Feu-north-1%2Fs3%2Faws4_request&X-Amz-Date=…&X-Amz-Expires=86400&X-Amz-SignedHeaders=content-type%3Bhost%3Bif-none-match&X-Amz-Security-Token=…`.
It is an S3 SigV4 presigned PUT under STS session credentials. The result holds it twice: as `upload_url` in a JSON text block,
and quoted in the `curl -X PUT` line the tool tells the model to run. Higgsfield's public API docs
(https://docs.higgsfield.ai/docs/concepts/file-uploads.md, read 2026-11-09) describe the same flow, an `upload_url` to PUT to that
"expires after one hour", but name no host. So `upload.higgsfield.ai` rests on that one transcript and is not in the docs. The
same docs name the API credentials `HF_API_KEY_ID`/`HF_API_KEY_SECRET` and the legacy `hf-api-key`/`hf-secret` headers
(…/authentication.md); the key format itself is not documented.

The exception: in the successful result of a tool named `mcp__<server>__media_upload`, an `https://upload.higgsfield.ai/…?…` URL
keeps two matches. One is the AWS row's match on the `ASIA…` key ID that leads `X-Amz-Credential`; the other is the assigned row's
match on the `X-Amz-Security-Token` value, judged on its matched run, not on the span to the quote its mask would cover. Each must
lie wholly inside its value. The URL's path and query and each value end at the first character outside the SigV4 query alphabet
`[A-Za-z0-9%._~-]` (plus `/` in the path, `=` and `&` in the query). Every other match in the same result is masked as before: a
Higgsfield key beside the URL, or one carried by another parameter of the same URL. So is that URL in any other tool's result,
Bash and Read included, so it stays masked in a log or in a commit's echoed message. So is an S3, R2 or any other host's presigned URL, and an errored `media_upload`. Nothing changed for writes: `scan.sh` still denies the
URL in a Write or a Bash write (the `ASIA…` key ID), and the mod never rewrites tool input. `tests/redact.test.ts`, "Higgsfield
upload URL", replays the firing and runs each must-still-mask case; `scan-hook.test.sh` pins the write deny and the `curl -X PUT`
that passes.

The first cut (commit 92daeb35) kept any match that began inside any `X-Amz-*` value and ended by the URL's end, with the URL and
each value running to the next `&`, quote, whitespace or `#`. Review the same day found four ways through it. A JSON-escaped `\n` (two
characters) ended nothing, so `HF_API_KEY_SECRET=…` after the URL stayed unmasked. A userinfo URL in `X-Amz-Date` ran across `&db=`
and kept its password. `X-Amz-Meta-*` kept a GitHub token, and `X-Amz-Credential` kept a long-term `AKIA…` key ID. Each now has a
must-still-mask case in "Higgsfield upload URL", and each check fails at least one of them when reverted alone (2026-11-09, `claude
plugin test` on a patched copy).

LIMITATION: the transcript now keeps the signed URL as returned. Its credentials can PUT one object path until `X-Amz-Expires` runs
out (86400 s in the replayed firing, one hour per the docs). The match is on the tool's name and the host, not on the server: any
MCP server with a `media_upload` tool returning an `upload.higgsfield.ai` URL gets it. The policy lives in `redact.ts`, and
`redact-core.ts` only takes the ranges (`Kept`). `scan.sh` has no counterpart, so `pattern-parity.test.sh` runs the core without
ranges. A range names its row by label, so relabelling the AWS or assigned row in `patterns.tsv` silently ends the keep and the URL
is masked again; the test copies the rows and does not read that file. A path or value holding a character outside the alphabet
masks the same way.

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

### --tracked and --outgoing (0.17.0, 2026-11-10)

Added for `hooks/commit-scan.sh`. `--tracked` is what `git commit -a` records: `git diff <HEAD>` over the index's paths, so untracked files stay out; an unborn HEAD diffs against the empty tree (`git hash-object -t tree /dev/null`, so a SHA-256 repository gets its own). `--outgoing` reads `git log -p --no-merges`, one patch per commit, not one tree diff over the range: a secret one outgoing commit added and a later one deleted is absent from the tree diff but still sent. Merges are skipped because `log -p` prints no patch for them by default and `--first-parent` style diffs would re-read what the merged branch already pushed. With no revision it takes HEAD and excludes `@{upstream}`; every form excludes `--remotes`, so a commit another remote-tracking branch already holds is not reported (the roadmap row asked for `@{upstream}..HEAD`; that range alone re-reads commits a merge from `origin/main` brought in, which are already public). A `-`-led revision exits 2 because the revisions reach `git log` as arguments and `--output=<file>` would write a file. Measured: 1,040 commits of this repository's history, 362,013 added lines, 0.99 s.

### Review fixes (0.17.0, 2026-11-12)

- **`--outgoing=<remote>`.** `commit-scan.sh` must judge a push against its destination, not every remote: with `--not --remotes`, `git push public main` read nothing when `origin/main` held the history. `--outgoing=<remote>` excludes `--remotes=<remote>` only, after `git check-ref-format "refs/remotes/<remote>/x"` accepts the name; a URL or path fails that check (a `:`, a leading `/`, a `..`) and excludes nothing, as it has no tracking refs. A valid name cannot hold `*`, `?` or `[`, so it is never read as a glob. The `@{upstream}` default is dropped in this form: the upstream may sit on another remote, which is the same mistake.
- **`--no-show-signature`.** `git log` honours `log.showSignature`; with it set in a repository's config and `gpg.program` pointing at a script, a signed outgoing commit ran the script (probed 2026-11-12 on git 2.53 with a hand-built `gpgsig` header: the script left its marker; with the flag it did not). A global `log.showSignature` would also spend a gpg run per signed commit inside the hook's 10 s.
- **`--ignore-submodules=all` on `--tracked`.** `git diff <HEAD>` runs `git status` inside each submodule, and a stat-dirty file there runs the submodule's own clean filter, which the hook's filter blanking (it reads the superproject's config) cannot name. Probed: a `touch`ed submodule file ran the filter under plain `diff HEAD` and not with the flag. A commit records a submodule only as a gitlink, whose `Subproject commit <sha>` line can match no pattern, so nothing scannable is lost.

## plugins/secret-scanning/hooks/commit-scan.sh

### Why it exists

Roadmap Track 7, row S2 (`taskmaster-docs/integration-roadmap-2026-11-07.md`, from the 2026-10-31 cluster's rank 5): no hook ran `scan-range.sh --cached`. The write guard (`scan.sh`) reads Write/Edit text and Bash heredoc or echo writes; the PostToolUse lane only warns after an interpreter or `cp` write. A secret that reached the index any other way went into a commit and out with a push unread. A Stop-time model review of the diff (G2) was rejected in the same roadmap; this is the commit layer it pointed to.

### Decisions

- **Deny, not ask.** The safety brief prefers an ask unless the action is irreversible. A push is irreversible once it lands. A commit is not, but the dispatch for S2 said deny on a hit, and a committed secret is one push from public. The reason names the off switch, and under `claude -p` an ask would have been a deny anyway.
- **Its own switch.** `CC_SECRET_COMMIT_SCAN` / `cc_secret_commit_scan`, not `CC_SECRET_SCAN`: the plugin gives each layer its own (`cc_secret_scan`, `cc_secret_redact`, `cc_secret_prompt`, `cc_unicode_scan`), and the write guard's off switch exists for a fixture write, which should not also open the commit.
- **No value in the reason.** `scan-range.sh` prints the first four characters of each value; the hook drops that part, because the reason lands in the transcript and four characters of an assigned password are most of a short one. `file:line` and the label are enough to find it.
- **Reading through `git add`.** The model's usual commit is `git add <files> && git commit -m …` in one Bash call. PreToolUse fires before the add runs, so `--cached` alone saw none of those files. An earlier `git add`/`git stage` for the same repository switches the commit to `--tracked` and adds the untracked files `git ls-files -o` lists for that add's pathspecs (whole repository for `-A` with none; none for `-u`, `-n`, `-p` or `-e`; whole repository for `-i`, a pathspec file or a `$` word since the 2026-11-12 review), read whole in path mode. `git add --dry-run` would list them exactly, but it runs the model's arguments as options; `ls-files` takes them only after `--`, as pathspecs.
- **A tokenizer of its own.** No shared block splits a command (`templates/blocks/` has none). git-workflow's `no-ai-trailer.sh` `segments()` lowercases each segment and blanks quoted text, so a `-C "My Dir"` path is lost. command-guard's `split_segments` keeps heredoc body lines as segments and cuts on `{`/`}` inside `${HOME}`. debugging's `probe-guard.sh` regex (copied from no-ai-trailer) finds a commit but never resolves `cd dir &&` or `git -C dir`, which this row requires. So the awk walk here keeps case, drops quotes, heredoc bodies (top level and inside `$( )`, the `-m "$(cat <<'EOF' … EOF)"` shape Claude Code's commit instructions use), comments and redirection targets, marks a word holding `$` or a backtick as unknown, and follows `cd`/`pushd` to the end of the command.
- **Caps.** A first push of a long history reads every commit. On this repository 1,040 commits took 0.99 s; `MAX_PUSH_COMMITS=1000` keeps the worst case near one second under the 10 s timeout, and past it the push is not scanned. `MAX_ADDED_FILES=1000` bounds `git add -A` in a tree with an unignored dependency directory. Both pass silently, stated in the header and README. What the host does with a hook it kills at the timeout was not measured here.
- **Timeout 10 s**, the value `authoring-hooks` gives git work and the one the plugin's other hooks use.
- **`core.fsmonitor` off for every git call** (`GIT_CONFIG_COUNT` in the environment, so `scan-range.sh`'s worktree diff inherits it). The hook runs before the permission prompt, in whatever directory the command names. A repository's `core.fsmonitor` command ran on a plain `git diff HEAD` there and did not run under the hook (probed 2026-11-10; the harness pins it, and the case fails without the override). debugging's `probe-guard.sh` passes `-c core.fsmonitor=false` for the same reason. Clean filters a worktree diff may run were at first left on, on the reasoning that `git commit -a` runs them itself; that reasoning missed that the hook runs them before the prompt, so they are now blanked too (below).

### Measurements, 2026-11-10

Interleaved runs on this machine (bash 5.3, git 2.53, mawk 1.3.4), median (max):

| case | runs | ms |
|---|---|---|
| an empty `bash -c 'cat >/dev/null'`, for scale | 25 | 3.0 (3.4) |
| a Bash call naming neither `commit` nor `push` (`ls -la && npm test`) | 25 | 2.3 (2.6) |
| `git log --grep commit --oneline` (parsed, no action) | 25 | 5.0 (5.7) |
| `git commit`, 1 staged file of 40 lines | 25 | 45.0 (47.0) |
| `git commit`, 200 staged files, 8,000 lines | 25 | 53.0 (59.0) |
| `git add -A && git commit`, 200 files already staged | 25 | 57.7 (61.0) |
| `git add -A && git commit`, 200 untracked files, 8,000 lines | 15 | 88.1 (89.8) |
| `git push`, 20 outgoing commits | 15 | 53.2 (55.1) |
| `git push -u origin HEAD`, 1,040 outgoing commits, cap raised | 3 | ~1,000 |

Before 0.17.0 no hook ran on these calls, so each figure is the added cost. The hot path stays under an empty bash process because the hook reads stdin with `read`, not `cat`, and exits on a `case` before `jq`.

### Harness

`scripts/__tests__/commit-scan.test.sh`, against real PreToolUse payloads in a scratch repository with a bare remote. First written with 41 cases, of which 17 failed against a stub hook that prints nothing; the first CHANGELOG entry said 18, but the never-prints-the-value assertion passed on an empty reason. It now fails on one. After the 2026-11-12 review: 71 cases, 33 failing against that stub (every deny and every reason assertion), 16 failing against the first 0.17.0 hook. Required pairs: a staged secret denies, a clean commit is silent; `-a` with an unstaged tracked secret denies, a plain commit beside it is silent; a secret an earlier outgoing commit added (a later one deleted it) denies `git push`, the same after `git push` is silent; a placeholder value is silent. Silent neighbours named by the row: `git log`, `git commit --dry-run`, `echo "git commit"`, `git push --dry-run`.

### Review fixes (2026-11-12)

A review of the first 0.17.0 hook found ten gaps; each behavioural one has a harness case that fails against that hook (run from a copy of the b80faf31 layout) and passes now.

- **The index beside the working tree.** `--tracked` replaced the index read, so with a secret staged and its file rewritten clean, `git add notes.md && git commit` (or `git commit -i a.txt`) recorded the secret unread, and the push scan cannot see a commit not yet made. The hook now also runs `--cached`, but only when `git diff --cached --quiet` says the index differs from HEAD: `load_patterns` costs about 19 ms of each `scan-range.sh` run, and the common `git add x && git commit` fires with nothing staged. With `-a` or `-o` this over-reads a staged line the working tree has since replaced (stated in the README).
- **Filters, before the prompt.** A `.gitattributes` `filter=<name>` with a configured `filter.<name>.clean` ran on `git diff <HEAD>` for a stat-dirty file, and `git diff --name-only HEAD` ran it too (probed: both left the marker), so listing paths first and reading files raw would not have avoided it. Two ways were weighed: blanking the drivers the attribute files name, or blanking every driver git config names. The config is the only place a driver's command can come from, while attribute files sit in every directory, in `info/attributes`, in `core.attributesFile` and in macros. So `nofilter` reads `git config -z --name-only --get-regexp '^filter\..+\.(clean|process)$'` and sets `clean` and `process` empty and `required` false for each name through `GIT_CONFIG_KEY_<n>`, which git reads last. Probed: an empty command runs nothing, but with `required` still true git dies (`clean filter 'mk' failed`, exit 128) and the scan would fail open; with `required` false the diff reads the raw file and runs nothing. The cost is one `git config` call per `--tracked` scan. A git-lfs or git-crypt file then diffs as its working-tree bytes, which are usually binary and so unread.
- **What a push sends.** With no source named the hook read HEAD, though `push.default=matching`, a `remote.<name>.push` refspec or `remote.<name>.mirror` sends more; a `$` source read HEAD, and a glob source failed `rev-parse` and was dropped. The reviewer offered reading every local branch whenever no source is named. That would deny a plain `git push` of a clean branch over a local-only branch holding a secret, so the hook asks git's own config instead (one `git config --get-regexp` read, parsed in bash because macOS ships bash 3.2 without associative arrays). Matching reads only the branches the destination also has under `refs/remotes/<remote>/`. A `$` source, a glob or an unresolvable source reads every branch, the reviewer's rule.
- **Where a push sends.** `--not --remotes` counted a commit on any remote as sent. Now the destination is the named remote, `--repo`, or git's own choice: `branch.<b>.pushRemote`, `remote.pushDefault`, `branch.<b>.remote`, `origin`. Only its refs count. A remote with no tracking refs, a URL or a path makes all reachable history outgoing, so the count runs first (`rev-list --count`, milliseconds even on long history). Past `MAX_PUSH_COMMITS` the hook falls back to the earlier rule, the commits no remote holds, so a fork far behind its upstream still has its own commits read. Past the cap again it reads nothing, a stated miss. A remote in a variable cannot be resolved and keeps the earlier rule.
- **`$` pathspecs.** A `git add` word holding `$` listed no untracked file. It now lists every one, as `-A` does, within `MAX_ADDED_FILES`. `-p` and `-e` were in the same unknown bucket but stage tracked hunks only, so they moved to the tracked-only flag: treating them like `-A` would have denied `git add -p && git commit` over an unrelated untracked file.
- **Byte cap.** `MAX_FILE_BYTES=1048576`, the PostToolUse lane's per-file cap. Untracked files are filtered with one `find … -prune -type f -size -1048577c` (POSIX, GNU and BSD alike), which also drops symlinks, whose commit records a path, not content. Diff modes get `core.bigFileThreshold` at the same value: git's `diff_populate_filespec` marks a blob or working-tree file over the threshold binary before reading it. Probed: a 1.1 MB staged file printed `Binary files … differ` and a 1.0 MB one diffed in full. A `.gitattributes` `diff` attribute set on the path overrides that and reads the file anyway. What the host does with a hook it kills at 10 s is still not measured; the hook prints no deny in that case.
- **Doc-only.** The commit message is never read (`-m`, `-F`, a heredoc; `--format='commit %h'` drops it in `--outgoing`), now named in the header and README.
- **Harness.** The `git push --dry-run` case sat in the commit block, before any commit was outgoing, so it passed against a mutant hook that ignores `--dry-run`. Beside `git push -n` it fails against that mutant.

Measured 2026-11-12, same machine, 25 interleaved runs each, before = the first 0.17.0 hook, after = this one, median ms:

| case | before | after |
|---|---|---|
| `ls` | 2.4 | 2.5 |
| `git commit -m x`, 1 staged file of 40 lines | 46.5 | 46.8 |
| `git push`, 5 outgoing commits | 47.5 | 50.7 |
| `git add b.txt && git commit -m x`, nothing else staged | 82.8 | 85.7 |
| the same with another file staged | 84.7 | 124.1 |
| `git commit -am x`, nothing staged | 47.7 | 49.2 |
| the same with a file staged | 46.1 | 84.2 |
