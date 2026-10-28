# ui-ux: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-ui-ux.md § <heading>`. taskmaster's `plugins/taskmaster/hooks/preview-guard.sh` is the twin of the first file, identical save its TWIN line, and points at the same heading. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/ui-ux/hooks/preview-guard.sh

### Header: the failure it exists for

```text
PreToolUse guard on the Artifact tool.

The failure this exists for: a visual decision gets published as a remote
artifact instead of served from the local preview server. The skills that
route to that server (visual-decisions, ui-ux:theme) load by JUDGMENT, so a
run where they never load never sees their rule — that is exactly how it goes
wrong. This fires on the tool call instead.
```

### Header: the tiers

```text
TIERED, because the strong signal is absent in precisely the population that
needs guarding. An earlier version keyed solely on taskmaster-docs/mockups/
existing; that directory is only ever created by the flows whose non-loading
IS the root cause, so the guard was silent exactly when it mattered and noisy
afterwards (one server start arms it for the life of the checkout).

  STRONG — a per-purpose preview basename, or a path under a mockups docroot,
           or a mockups docroot present in this project: ask EVERY time, with
           the mockup rule.
  WEAK   — any other .html artifact: ask ONCE PER SESSION to confirm the remote
           publish is intended — a note proved ignorable, and a for-you page
           must not slip out.
  NONE   — not .html (a markdown report is not a mockup): silent.
```

### Header: why the weak tier is bounded and the strong tier is not

```text
WHY WEAK IS BOUNDED AND STRONG IS NOT. Every Artifact .html is a remote
publish, so the weak signal never clears: the tier asked on every HTML
artifact for the life of the session, which is a standing veto in the name of
a CONVENTION (render it on the local preview server) rather than a blast
radius. One deliberate answer is what a convention is worth; the rest is noise
the user learns to click through, which costs the STRONG asks their weight
too. Bound pattern: comment-discipline/hooks/scan.sh and
taskmaster/hooks/clarify-gate.sh, once-per-session for the same reason.
STRONG stays unbounded — unreleased design work leaving the machine is blast
radius, not convention.
```

### Header: honest limitation

```text
HONEST LIMITATION. After the session's first plain-.html publish, the next one
goes unasked: a different for-you page, or a retry of the one just denied. The
tier buys one deliberate answer per session and is not a standing veto; the
population the guard exists for (STRONG) is unaffected. With no session_id in
the hook input the bound cannot be recorded, so the tier falls back to asking
every time — an ask can never wedge a session, so failing toward the question
is safe here, the mirror of a deny gate, which must fail toward allowing.
```

### Header: fail-open

```text
Fails open on any error: a broken guard degrades to a no-op, never to a
blocked tool call.
```

### Header: the twin and the off-switch

The first line is the ui-ux copy's TWIN line as it stood; the file keeps it cut after "save this line.", which is all `pc_twin_files` reads.

```text
TWIN: plugins/taskmaster/hooks/preview-guard.sh is an identical copy save this line. ui-ux
ships the theme flow but declares no taskmaster dependency, and a user may
install ui-ux without taskmaster — without its own copy that path would have
no mechanical guard at all. ${CLAUDE_PLUGIN_ROOT} is per-plugin so the file
cannot be shared; change one, change both. With BOTH plugins installed the
guard fires twice on the same call — an extra line in one prompt, which is
the cheap side of the trade against leaving ui-ux unguarded. On the WEAK tier
not even that: both copies hash the same session_id to the same marker, so the
mkdir race leaves exactly one asker.
OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
uninstalling the plugin. With BOTH twins installed it asks twice on a strong
signal (see TWIN above), which makes "turn it off here" a real need.
```

### The docroot walk

```text
Walk UP looking for the docroot. A git worktree or a session started in a
subdirectory would otherwise miss it — taskmaster-docs is untracked wherever the
project ignores it (as this marketplace does), so a worktree may not carry one
even while the shared server is live. The walk does not depend on that either way.
```

### Strong signal: the artifact first

```text
The artifact itself is the more reliable signal than project state.
```

### The weak tier's one ask per session

```text
WEAK only: one ask per session (see header). Keyed by session and NOT by
path — the convention is answered once, not once per page. Recording it is
what makes this the session's one weak ask, so the mkdir comes first; a
marker that cannot be recorded at all leaves the old unbounded behaviour.
```

### PREVIEW_PORT validation

```text
Never interpolate an unvalidated env value into text shown at a permission
decision: jq keeps the JSON well-formed, but a crafted PREVIEW_PORT would
still read as prose in the guard's own authoritative voice.
```

### The payload cwd

```text
.cwd is the session root; $PWD is only this script's cwd, so prefer it.
```
Editor's note (2026-10-04): false as moved — the payload cwd follows the model's cd.

## plugins/ui-ux/hooks/palette-default.sh

### Header: the shebang

```text
Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
stripped or broken PATH, where `env bash` itself exits 127.
```

### Header: what it names

```text
PostToolUse on a written UI file. Names the category-default accent — the indigo/violet/
purple band — when it arrives through Tailwind utility classes or a literal default
swatch, i.e. through the channel a stylesheet-reading check cannot see.
```

### Header: why this exists and why here

```text
WHY THIS EXISTS AND WHY HERE. craft-layer's `divergence.mjs` already grades this, and
grades it harder: `utility-palette` there is a GATE with a waiver lane. But that file is
invoked only by `/craft-layer:audit` step 4 — a `/craft-layer:craft` run reaches it only
because craft step 7 calls that command, which is one call site, not two. A plain
"build me an app" turn runs neither. Measured, not assumed: in a control/treatment run
on 2026-08-17, a Laravel build shipped 23 indigo utilities across 5 Blade views with
every gate green, because none of them was on that path. The reach asymmetry:
craft-layer NEEDS ui-ux — a README notice and a plugin-scout companion line, not a
manifest key, since no plugin may declare `dependencies` (retired with the suites,
2026-09-26) — so a craft-layer install that followed its README carries this hook,
while ui-ux is routinely installed where craft-layer is not.
PostToolUse fires on any write, so this is the reach half of a rule craft-layer
already owns the depth of.
```

### Header: standing

```text
STANDING: advisory. `additionalContext` is not a blocking key and this exits 0 on every
path. It is deliberately NOT a gate: a violet brand is a legitimate answer, and the only
thing separating "chose it" from "reached for the default" is intent, which no script
reads. craft-layer's gate can demand a written waiver because a craft run has a contract
to write it in; a bare edit has nowhere to record consent, so blocking here would punish
the legitimate case with no way to say so.
```

### Header: limitation

```text
LIMITATION (honest scope — the four laws, see
.claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
  - It counts a hue, never a composition. Three equal cards, a ribbon on the middle one
    and a centred hero are the rest of the fingerprint and are not detected here.
  - Literal class strings only. A palette assembled in a variable, behind `cn(...)`, or
    arriving through a component prop is invisible.
  - The hex list is the DEFAULT swatches by value, not a hue range. Reading hue from hex
    would be wrong at this band: sRGB puts indigo-500 (#6366f1) at 238.7 degrees, far
    below the 275-315 band those same swatches occupy in oklch — the mismatch recorded
    in craft-layer's CHANGELOG 0.47.0. A short literal list is honest; hue math here
    would silently miss the exact colours it names.
  - PostToolUse: the file is on disk already. This informs the NEXT edit.
  - Its cost is unmetered by construction — context-budget.sh measures the dynamic
    channel with one synthetic Edit that is not a UI file, so this scores 0 while
    emitting ~70 tokens on a real hit. The one-shot below is what stands in for a meter.
```

### Header: off switches

```text
Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
CC_PALETTE=off silences only this one.
```

### Header: fail-open

```text
FAIL-OPEN: missing jq, unreadable file, unwritable state dir, or any error exits 0.
```

### Header: state at the project root

```text
STATE AT THE PROJECT ROOT (state-root block below), not the payload cwd. The cwd
follows the model's `cd` — measured 2026-09-25 (finding 2,
rationale/2026-09-25-session-plugin-usage-review.md): one session's cwd moved through
app/Enums, app/Models and the root, so a per-cwd state dir is a new one-shot in every
directory and "says so once per session" became once per directory.
```

### The cwd test

Stale on the day it moved: `cc_state_root` also returns 1 for a cwd that no longer exists, so the `-d` test is no longer the only guard, and the state dir sits under `CLAUDE_PLUGIN_DATA` when the host sets it.

```text
-d, not just -n: the state-dir `mkdir -p` below RECREATES a project directory the
session deleted, three levels deep, from a payload field nobody validated
(overseer/hooks/track-read.sh:30-31 is the shape this copies).
```
Editor's note (2026-10-28): the `track-read.sh:30-31` line number above is stale; the shape is the line in `plugins/overseer/hooks/track-read.sh` holding `[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0`.

### The context key

```text
CONTEXT KEY, hashed before it becomes a filename. The key is normally an absolute
path; interpolated raw it names a file whose parents never existed, every write fails,
and the one-shot below silently stops bounding anything. See the authoring-hooks skill,
references/one-shot-state.md. Gated by pc_context_key and pc_marker_key.
```

### The three families

```text
The three families whose oklch hues sit inside craft-layer's 275-315 default band:
indigo ~277.1, violet ~292.7, purple ~303.9. Neighbours are outside it — blue ~259.8,
fuchsia ~322.1 — so the list is derived from that band rather than from taste. If the
band moves, re-derive; never extend by feel.
```

### Default swatch values

```text
Default swatch VALUES, matched literally — see the limitation note on hue vs hex.
```

### Unwritable state

```text
A bound that cannot be recorded is not a bound: unwritable state means silence rather
than the same nudge on every edit for the rest of the run.
```

### The state dir's .gitignore

```text
the state dir ignores itself
```

## plugins/ui-ux/scripts/__tests__/palette-default.test.sh

### Header

```text
Fixture tests for hooks/palette-default.sh. Picked up by the shared CI step globbing
plugins/*/scripts/__tests__/*.test.sh.

The FIRST fixture is the real regression this hook was written for: on 2026-08-17 a
control/treatment run shipped 23 indigo utilities across 5 Blade views of a Laravel
build, with every gate in this marketplace green, because craft-layer's equivalent gate
runs only inside a craft run. If that fixture ever stops firing, the hook has lost the
only failure it is known to catch.

The silence cases carry equal weight. An advisory that fires on a deliberate palette is
noise, and a reader who learns to skip it has lost the signal too.
```

### fire(): a fresh cwd and the real payload shape

```text
Each call gets a fresh cwd so the one-shot never masks an unrelated case. The payload
carries a path-shaped transcript_path — the shape the host actually sends, which is what
pc_harness_payload exists to require after three hooks shipped broken without it.
```

### Case 4: neighbouring hues

```text
Flagging them would make the family list taste rather than a derivation.
```

### Case 8: a deleted cwd

Stale on the day it moved: the hook no longer builds `$cwd/.claude/ui-ux`; it resolves the state dir through `cc_state_root` and `cc_plugin_state`.

```text
The hook `mkdir -p "$cwd/.claude/ui-ux"`. With only `-n` on the payload field, a session
whose project directory was deleted got it resurrected three levels deep — the live
repro in the 2026-09-22 panel (architecture finding 1).
```

### Case 9: a subdirectory cwd

```text
The payload cwd follows the model's `cd` (measured 2026-09-25, finding 2 of
rationale/2026-09-25-session-plugin-usage-review.md). State must land at the repo root,
never under the subdirectory, and a later edit from the root must see the same one-shot.
```

## plugins/ui-ux/hooks/ui-check.sh

Written 2026-10-27 when the hook shipped (ui-ux 0.32.0), not moved from the code. Standing: `recorded`.

### Why it exists

`rationale/2026-09-25-session-plugin-usage-review.md` (P1): 34 UI worker subagents made 0 browser calls, and the one 2-minute browser check found two defects the review cycles had missed (two nav items highlighted at once; Generate enabled with no provider configured). Playwright was available throughout; what stopped the walk was access (a password the model correctly would not type, data and API keys that did not exist). So the hook asks for the walk, and the reason it sends lets the model answer in one line why it cannot, rather than demanding a render it may be unable to do.

It is a ui-ux Stop hook, not a candor clause (decision 2026-10-27, `.claude/overseer/decisions.md`): ui-ux is installed by people doing UI and already declares the UI file shapes in its lane, and candor's Stop gate stays about honesty.

### What it decides, and why that way

Every rule errs toward silence: a wrong block costs the person a turn, a wrong "checked" costs one missed reminder. Two reviewer lenses (correctness, false-block adversary, about 150 fixture cases) set that order on 2026-10-27, a re-check found two more false blocks and nine misses the same day, and the rules below are those findings as decided.

- **The window.** A browser call clears every edit before it. A turn opener clears only the session's own edits: the person's prompt (text, or content that starts with an image), and a `<task-notification>`. Not a turn opener: `isMeta` records, compact summaries (`isCompactSummary`), and other frames (`<system-reminder>`, `[SYSTEM NOTIFICATION`, `Stop hook feedback:`, `<local-command-`). So an edit made during the hook's own continuation is not raised at the end of a later, unrelated turn, while a background subagent's edits survive the notification that reports its completion.
- **Once per edit.** The per-session state file holds the newest edit's timestamp, what was done (`blocked`, `declined`, `noticed`) and, while declined, the blocked edit's timestamp. The check acts again only on a strictly newer edit. Keying on the newest edit's id let the eight-command Bash window shift which edit read as newest, and the same edits blocked twice.
- **Declined.** After a block, a later decision that finds no browser call after the blocked edit prints instead. The decline ends with a browser call, the person's second prompt since the block, or a Bash dev-server start (`npm|pnpm|yarn run dev|serve|start`, `vite`, `next dev`, `php artisan serve`). It stands down on `stop_hook_active`, which every Stop hook shares, so another hook's block also defers it.
- **Availability.** A `deferred_tools_delta` in the session transcript decides alone: added and re-added names minus removed ones, pending servers ignored, matched on `playwright`, `browser_`, `chrome`, `puppeteer`. A screenshot tool is evidence of a call, not of a browser. Without a delta, settings decide: `enabledPlugins` local over project over user; user and local MCP servers minus `disabledMcpServers`; `.mcp.json` servers only once approved (`enableAllProjectMcpServers` or `enabledMcpjsonServers`) and not in `disabledMcpjsonServers`. Unsure prints "no browser check was seen", since a browser tool it does not recognise may exist.
- **Subagents.** Finished ones (`.meta.json` says `"finished": true`, the join `scripts/turn-cost.sh --workflow` uses) are read, and every call is ordered by its record `timestamp`. The check stands down, recording nothing, only for a running background agent (`"requestShape": "background"`) whose transcript changed in the last 30 minutes and holds UI or browser words, matched in any case. Any other running subagent is skipped and the stop is judged now. A line that does not parse drops only its subagent; in the session transcript it silences the check, since it could be the browser call. A record with no timestamp takes the previous timestamped record's in the same file.
- **Paths.** Judged root-relative, the root being `cc_state_root` of `CLAUDE_PROJECT_DIR`, else of the cwd. A leading `.claude/worktrees/<name>/` is set aside first, so an isolated-worktree subagent's edits count. Never counted:
  - dot-directories and `taskmaster-docs/` at the top;
  - `dist`, `build`, `out`, `coverage`, `storybook-static`, `node_modules`, `.next`, `.nuxt` and `.svelte-kit` at any depth;
  - tests, mocks, e2e, specs, stories and `setupTests.*`.

  A relative Bash target is skipped when the command, heredoc bodies aside, holds `cd ` or `pushd `, and is otherwise resolved against the record's `cwd`. A redirect that only moves file descriptors (`2>&1`, `>&2`) or goes to `/dev/null` is not a write and does not use up the eight-command window. An Edit, Write or MultiEdit whose `tool_result` has `is_error: true` is not an edit; an edit later reverted still counts.
- **Browser evidence.** A tool name holding `playwright`, `browser_`, `chrome`, `puppeteer` or `screenshot`, in any case. Or a Bash command segment holding `playwright`, `puppeteer`, `cypress`, `dusk`, `browser`, `test-storybook`, `wdio`, `lighthouse`, `lhci`, `pa11y`, `e2e`, `chrom`, `--screenshot`, `--headless`, `backstop` or `axe`. That segment must not be run by a reader, writer, VCS or `cd` command (`cat`, `grep`, `git`, `echo`, `tee`, `cp`, …), nor be a package install (`npm i`, `pnpm add`, `npx playwright install`, …); quoted text is masked first. A command holding a heredoc is judged on `cc_strip_heredoc_bodies inert` output: a body a shell runs is kept, one written to a file is not. Only the newest eight such commands are judged; older ones count as checks. A write and a check in one command count in that order.
- **No `declare -A`.** The fix list asked for one to dedupe file names; `/bin/bash` on macOS is 3.2, which has none, so the dedupe runs in the awk pass instead, with no per-event process either way.
- **State it cannot save** prints instead of blocking: an unrecorded block would repeat on every stop.

### What it misses

- SubagentStop is not hooked: a subagent ends its own turn unchecked, and only its parent is sent back.
- The live host's display of `systemMessage` on a Stop block was probed for candor's gate on CLI 2.1.310, not for this hook.
- Browsers it does not recognise: a tool or command holding none of the words above (a node script driving Playwright under another name, `curl`, `npm test` wrapping Playwright), or a browser run hidden in quotes (`bash -c '…'`).
- It reads too much as a check: the words are substrings, so `npx eslint e2e/`, `taxes` or a `chrome-ext` path count. That costs a missed reminder, never a wrong block. A task notification hides the session's own edits made before it.
- Writes it cannot see: interpreter, `cp` and `mv` writes, and the rest `cc_bash_write_targets` lists in its header; past the eight newest Bash commands that could write a UI file, none is read.
- A CLI that writes no `finished` flag reads every subagent as unfinished: a recent background one doing UI work stops the check, any other is skipped. Subagents nested below `subagents/` are not read.
- Only lines that can hold an event are parsed: a tool call naming a UI extension, a browser or dev-server word, a tool list, an error result, or a prompt. A truncated line holding none of those is not seen.
- Timestamps compare as strings in the CLI's ISO form; an edit whose file has no timestamp before it stands the check down. A file reached both by an Edit and by a Bash write can be counted twice in "and N more".

### Cost

Median over 5 runs (2026-10-27, Linux, jq 1.8.1), first stop then the repeat stop that finds its state file: 31.0 ms on a 2 MB transcript that ends in a block; 66.8 / 63.5 ms with 1,000 UI edits; 286.8 / 283.1 ms with 6,000; 227.6 / 225.4 ms on a 50 MB transcript beside 100 finished 0.5 MB subagent files, 20 of them with UI edits (105 MB in all); 7.6 ms when no UI file appears. The repeat stop saves little because reading dominates, not the walk. jq compiles a regex on every `test()` call, so per-record checks are `contains`/`endswith`, and awk passes on only the lines that can hold an event: the same 105 MB took 1,131.8 ms when every tool-call line was parsed.

### Comments moved from the code (2026-10-28)

Moved verbatim on 2026-10-28, with only each comment's `# ` leader and indentation removed; the file keeps a one-line form of each.

The event lines:

```text
One line per event: time (inherited within a source when a record has none), source (m session, s<n> subagent), then U UI edit,
  C Bash command that may write one, B browser call, W browser word in a command holding a heredoc, S dev-server start,
  P the person's prompt, N another turn opener, F failed tool call, D0/D+/D- tool list, X bad line.
Only lines that can hold one are parsed; jq compiles a regex on every test() call, so per-record checks are string checks first.
```

The summary pass:

```text
Calls interleave by time. A bad session line silences the check (it could be the browser call); a bad subagent line drops that subagent.
A browser call clears every edit before it; a turn opener clears only the session's own. Printed: availability from the tool list
  (unknown without one), the last browser call, unique UI files, prompts and a dev-server start since the decline anchor, then edits newest first.
```

The decline:

```text
After a block with no browser call since, the session declined: print, until a browser call, the person's second prompt since the
  block, or a dev-server start.
```

## plugins/ui-ux/scripts/contrast.mjs

The twin of `plugins/craft-layer/template/craft-gates/contrast.mjs`, identical save its TWIN line (`pc_twin_files`). Its header points at that file's heading, `rationale/derivations/plugin-craft-layer.md` § `plugins/craft-layer/template/craft-gates/contrast.mjs`, where the comment text both copies carried until 2026-10-28 was moved verbatim. Standing: `recorded`.
