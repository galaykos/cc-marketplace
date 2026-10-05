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
