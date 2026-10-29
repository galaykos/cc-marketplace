# scripts/*.sh: the comment text moved out of the code (2026-10-27)

The text below was moved verbatim on 2026-10-27 from the top-level maintainer scripts named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed. Each `###` block is a comment block, or a contiguous part of a header, as it stood; the file kept a short summary in its place (a header of at most three lines, a one-line why), or nothing where the code already says it. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/scripts.md § <path>`. Standing: `recorded` — no gate reads this file, and its dates, measurements, line citations and file names are as they stood on the day it moved.

## scripts/authoring-guard.sh

### Header

```text
Repo-level PostToolUse authoring guard. Advisory (post-write) and fail-open:
any error, missing jq, or out-of-scope path exits 0 silently and never blocks.
On an over-budget SKILL.md or a stray non-functional .md inside this repo's own
plugins/, emits a model-visible additionalContext warning so the author (human
or Claude) fixes it in-session instead of at CI. Shares check logic with
validate.sh via scripts/lib/plugin-checks.sh — no drift.
```

## scripts/check-doc-staleness.sh

### Header

```text
Warn-only staleness check for vendored doc digests (hybrid digest +
fetch-verify strategy). Scans */references/*.md under a root for the
machine-parsable stamp, expected within the first 6 lines of a digest:

  > Last verified: YYYY-MM-DD — <root doc URL>[ — npm:<package>@<major>[.<minor>]]

and prints a warning for any digest whose stamp is older than the threshold.
Scans BOTH */references/*.md and skills/*/SKILL.md: a version-leverage claim is
usually inline in the SKILL body, not in a reference file. Files with no stamp
are hand-written skill material, not doc-derived — silently ignored here.
validate.sh separately REQUIRES a stamp from any plugin whose own description
claims version leverage; that is the blocking half of this pair. NEVER blocks: exits 0 on every path,
including after warnings (warn-only by contract, spec A2); the CI step adds
continue-on-error as belt and braces. Runnable locally:
  bash scripts/check-doc-staleness.sh [--days N] [--path DIR] [--live] [--inventory]
    --days N    staleness threshold in days (default 90)
    --path DIR  scan root (default plugins/)
    --live      also compare npm:<pkg>@<ver> stamps against the live npm
                version and HEAD every stamped URL; npm/network errors print
                an info line, never warn
    --inventory print one tab-separated row per stamp (age, date, stamped npm,
                live npm, URL status, file) instead of only the warnings — the
                table the digest-refresh project skill walks

What the age check does NOT catch, measured: the Astryx digest was 49 days
old on 2026-09-09 — inside the 90-day window — and already wrong on the
package layout, the theme API and a category name, because a 0.x package
had gone 0.3 → 0.5. Age is a proxy; the `npm:` tail is the real signal, and
for a 0.x package the MINOR is the breaking unit, so the tail may carry
`@<major>.<minor>` and --live then compares both. A stamp with no npm tail
is invisible to --live: stamp the package, or accept that only the date is
read back. Residual: a URL that still answers 200 with rewritten content is
reported as reachable; only a human or model diff catches that, which is
what the digest-refresh skill is for.

Three more gaps, recorded 2026-10-05 and not built:
  - --live runs only by hand. CI runs the age check alone (validate.yml's
    "doc staleness" step), so motion 14 (npm, published 2026-10-02) sat
    behind two npm:motion@13 stamps until someone ran --live by hand.
  - npm: is the only tail read. A composer:/Packagist tail is ignored, so a
    Laravel or other PHP major surfaces only through the age warning, even
    though validate.sh's pc_version_stamp_tail accepts a composer: tail.
  - A versioned docs URL (laravel.com/docs/13.x/...) is HEADed, never probed
    for the next version (docs/14.x answering 200), so a new major with no
    package tail stays invisible to --live.
```

### Stamp grammar

```text
Binding stamp grammar: within the first 6 lines, first match wins. The bold form
(`> **Last verified: …**`) is accepted because seven shipped craft-layer references
used it and were invisible to this script for weeks — a staleness checker that
silently skips files is worse than one that reports them, and the marker is for
humans, who bold things. Both forms are canonical; neither is preferred.
```

### npm tail

```text
Optional npm tail of the stamp: " — npm:<package>@<major>[.<minor>]"
(package may be scoped, e.g. npm:@scope/pkg@3 — greedy [^ ]+ keeps the
scope's @). A minor is meaningful on its own for 0.x packages, where the
minor is the breaking unit; on >=1.x a stamped minor is compared too.
```

### SKILL.md in the scan

```text
WIDENED 2026-08-02 to include skills/*/SKILL.md. The scan was references-only,
and every one of the ~15 version-leverage stack plugins — nextjs, nuxt, vue3,
laravel, php, vite, threejs, node-backend, react-native, livewire, inertia,
mysql, mariadb, postgresql, sql — ships ZERO files under any references/
directory. All ten stamped files in the tree sit in ui-ux and craft-layer.
Their version claims live inline in SKILL.md bodies, which this check had never
been able to see. Those plugins are exempt from the baseline-redundancy loop
precisely BECAUSE they encode version leverage, so a stale leverage map turns
the marketplace's one durable advantage over a blind model into confidently
wrong advice that decays silently rather than on any edit.
WIDENED 2026-09-09 to .claude/skills when --path names it; the default root
stays plugins/ so the CI step's output is unchanged.
```

## scripts/check-version-bumps.sh

### Header

```text
Fail if a plugin's files changed vs a base ref but its plugin.json version did
NOT strictly INCREASE (sort -V) — rejects both a missing bump (version equal to
base) and a downgrade (version below base). Complements scripts/validate.sh
(which is static/structural and does not look at history). Runs in CI on pull
requests; also runnable locally before
pushing:  bash scripts/check-version-bumps.sh [base-ref]   (default: origin/master)

New plugins (no manifest at base) are exempt — a first release needs no bump.

DOC-ONLY changes are exempt too: a typo fix in a plugin's root README.md,
CHANGELOG.md or ROADMAP.md does not force a semver bump. Before this filter,
correcting one character in plugins/i18n/README.md failed the gate.
The exclusions use :(glob) so `*` does NOT cross a directory separator —
plugins/x/template/README.md is shipped code and still forces a bump.

LIMITATION (honest scope): this converts "a doc typo silently demands a
version bump" into "only functional changes demand one". It cannot tell a
substantive README rewrite from a typo — a real documentation change now ships
without a bump unless the author bumps deliberately.
```

### CHANGELOG coverage

```text
CHANGELOG COVERAGE (added 2026-08-02). A bump the consumer cannot read is a
version number, not a release. Verified before this landed: 0 git tags across
the repository and 0 of 58 leaves shipping a CHANGELOG.md, while validate.sh
has always ALLOWED one and this script already excludes it from triggering a
bump. So a user upgrading `laravel` 0.3.1 -> 0.4.0 had no artifact anywhere
naming what changed.

Deliberately WARN, not FAIL, and the reason is the same one that kept the
version-stamp gate a warning until its verification pass ran: making it hard
today would demand 58 backfilled changelogs describing releases nobody
recorded at the time, i.e. invented history in the file whose whole job is
history. It hardens per plugin: once a plugin HAS a CHANGELOG.md, an entry
for the new version is required, so adopting the file opts that plugin in.
```

### CHANGELOG entry anchored to a heading

```text
Anchored to a `##` heading, not a substring: a plugin that inherited its
predecessor's changelog (two bundles did, both retired 2026-09-26) carries the OLD
numbering below a seam, so `grep -F 0.6.0` matched history — and prose
such as "against taskmaster-suite 0.19.0" — and passed six unreleased
versions vacuously (measured 2026-09-22).
```

## scripts/comment-stats.sh

### Header pointer

```text
Why, limits, history: rationale/improvement-plan-2026-10-26.md § Before values (m2, 2026-10-26)
```

## scripts/context-budget.sh

### Header

```text
Blocking per-plugin context-budget gate (D3/A5). TWO metered channels, each
with its own committed baseline and its own ratchet:

  ALWAYS-ON (scripts/context-budget-baseline.json) — surface every session
  pays before a single file is read: the frontmatter `description:` byte
  length of skills/*/SKILL.md, commands/*.md, agents/*.md, PLUS the stdout of
  its SessionStart hooks, PLUS
  the `tools/list` payload of any local MCP server the plugin declares.

  ACTIVATED (scripts/context-budget-activated-baseline.json) — the always-on
  surface again, but with the state its hooks are WAITING FOR. Added
  2026-08-20 because the always-on pass runs against an empty HOME and no env,
  which meters the OFF state: candor's terse-mode SessionStart hook emits ~5 kB once a
  level is set and 0 in the sandbox (recount: `CC_TERSE=full CLAUDE_PLUGIN_ROOT=plugins/candor
  bash plugins/candor/hooks/activate.sh </dev/null | wc -c`), brain's emits ~2 kB once
  brain/INDEX.md exists and 75 B without it. That is ~1.7k tokens a real user pays and no
  baseline saw. This channel is a SEPARATE column, not folded into always-on,
  because "installed and idle" and "installed and switched on" are two honest
  numbers and averaging them would describe neither.

  DYNAMIC (scripts/context-budget-dynamic-baseline.json) — surface injected
  per prompt and per tool call: the stdout of UserPromptSubmit and
  Pre/PostToolUse hooks. This channel was UNMETERED until 2026-08-02 and the
  omission was load-bearing: skill-router's UserPromptSubmit hook alone emits
  ~9.4 kB (~2.4k tokens) of a second command catalog on any work-shaped
  prompt, against an always-on baseline entry of 0. "Zero always-on tokens"
  was true and irrelevant for every hook-bearing plugin. Measuring it does not
  make it always-on — a per-tool hook fires per Edit, not once — so it is
  reported and ratcheted SEPARATELY rather than folded into the always-on sum.

All hook and MCP measurement runs sandboxed against an empty project with an
empty HOME (a deterministic, repo-neutral LOWER bound; real output can grow
with the user's project) and is fail-open per hook. chars/4. A plugin more
than its tolerance over EITHER baseline fails (exit 1); --update-baseline, a
missing jq, and a missing baseline file stay exit 0.

STILL NOT METERED, by nature rather than by omission: skill BODIES loaded when
a routing rule fires (a routed a11y-audit is ~1.8k tokens on top of its
description), and remote MCP servers, whose tool surface cannot be read
offline. Both are named in the run's closing notes rather than silently
scored as zero. Unmetered by OMISSION, latent while no plugin ships an MCP
server: a server's `instructions` string, which `initialize` returns and this
gate never reads (it keeps the `tools/list` reply), so a LOCAL server's is
missed. `/context` counts it as its own row since CLI 2.1.283 (cut at 4,096
chars by default since 2.1.296). No closing note names it.
```

### --reconcile

```text
Reconciliation against `claude plugin details`, the host's OWN meter.
LOCAL ONLY, WARN ONLY, and not a CI step: `details` resolves a plugin by
INSTALLED NAME (it rejects a path, and its own `--plugin-dir` hint is not
an option of that subcommand), so a checkout with nothing installed cannot
run it. Claiming it as a gate would be claiming a check CI can never
execute.
```

### plugin_desc_bytes

```text
Sum of frontmatter description-value bytes (plus `when_to_use:` when present, joined by
the 3-char " - " the CLI renders between them — the host shows the pair as one string,
so all three are charged) across a plugin dir's
skills/*/SKILL.md, commands/*.md, agents/*.md (tolerates missing dirs). The fields
come from pc_listing_fields (scripts/lib/plugin-checks.sh, sourced below), the one
frontmatter walk every listing meter and linter shares.
```

### Chars versus bytes, and the listing entry cost

```text
Same walk, counting CHARACTERS instead of bytes (`wc -m`). The listing channel
needs this and the token channels do not: a token estimate is bytes/4, but the
listing cap is documented in CHARS and this corpus is em-dash heavy, so the two
diverge by ~3%. Measured 2026-08-31 on taskmaster-suite: 15,016 bytes against
14,581 chars — 435 bytes of multi-byte punctuation, enough to report a bundle
OVER a cap it is 419 chars UNDER. That is the whole reason this function exists.

HONEST LIMITATION, and it is the important half: nobody here has verified which
unit the HOST counts. Chars is the unit its documentation states, so chars is
what this compares — but an install within ~3% of the cap cannot be called under
or over with confidence on either measure, and the channel says so when it lands
in that band rather than printing a verdict it has not earned.
Listing entry cost: delegated to pc_listing_entry_cost in scripts/lib/plugin-checks.sh
— the SINGLE implementation (shared with the pc_listing_declaration gate until that
went with the bundles, 2026-09-26), after the two by-value copies were measured disagreeing by their separator models (9 chars on
taskmaster-suite) while every bundle README told readers to reconcile one against the
other. This wrapper returns chars-without-separators and stashes the entry count in
The call sites read "chars entries" via `set --` and add the CLI's n-1
separator term once per install (a $()-wrapper cannot return the count: the
subshell drops any variable it sets).
Unit note (inherited from the helper): LC_ALL=C bytes — a deterministic ~1% overcount
of the chars the CLI counts, conservative for a floor warning. Agents excluded: they
render in a separate system-prompt section (unverified whether it shares this budget).
```

### plugin_sessionstart_bytes

```text
Stdout bytes a plugin's SessionStart hooks inject each session, measured by
executing them in a throwaway sandbox (empty CLAUDE_PROJECT_DIR/HOME, minimal
SessionStart JSON on stdin, fail-open per hook). Deterministic lower bound.
```

### EDIT_SANDBOX

```text
File-shape fixtures for the per-tool probe live in their OWN sandbox, never in
HOOK_SANDBOX. The always-on channel measures SessionStart stdout against an
EMPTY project — put a src/ and a migrations/ next to it and the stack-sniffing
SessionStart hooks find a project to describe, which moves the always-on figure
for a reason that has nothing to do with always-on cost. First attempt did
exactly that: +36 tokens on four bundles, pure fixture contamination.
```

### Fixture content

```text
The fixture CONTENT trips the hooks on purpose. A clean file measures a hook
that fired and found nothing, which is not what a real edit costs — the point
of the channel is what an edit that DOES trip a guard pays. Clean fixtures
under-report by construction: `testing` read 0 on a well-formed test and 509
bytes on one asserting internals, and both are "the hook ran".
```

### plugin_sessionstart_activated_bytes

```text
Stdout bytes a plugin's SessionStart hooks inject in the ACTIVATED state — the
same hooks, run against a sandbox carrying the state they wait for. The fixture
turns on everything this repo knows how to turn on; a hook waiting for some
OTHER state still measures its OFF value here, and that residual is the reason
this is a floor and not a ceiling.

Fixture contents, each with the hook it exists for:
  CC_TERSE=full            → candor/hooks/activate.sh (env beats its state file)
  brain/INDEX.md           → brain/hooks/inject.sh (clamped at 2048 B by its `head -c 2048`)
  package.json + composer.json + a src tree
                           → skill-router/hooks/prime.sh, which sniffs manifests
```

### plugin_dynamic_hook_bytes

```text
Stdout bytes a plugin's per-prompt / per-tool hooks inject, measured the same
sandboxed way as SessionStart. UserPromptSubmit gets a work-shaped prompt
because several hooks gate on exactly that (skill-router's route-prompt.sh
matches build|create|fix|review|refactor|... — a neutral prompt measures zero
and would understate the channel by ~2.4k tokens). Pre/PostToolUse get a
synthetic Edit payload, the hottest path in the product.
```

### A fresh session id and TMPDIR

```text
A FRESH session id and a FRESH TMPDIR per measurement. Several hooks are
once-per-session, keyed on a marker directory under $TMPDIR — reuse a session
id and the second run measures 0, which would make this gate order-dependent
and silently report a plugin's cost as zero on every run after the first.
Uniqueness comes from mktemp, not a counter: this function is called inside
command substitution, so a shell variable incremented here never survives.
```

### A real transcript file

```text
A real transcript file, not just a path: hooks split two ways on this field —
most hash it as a context key, but some OPEN it — task-runner/hooks/drift.sh
(:61 readability guard, :73 `tail`) and comment-discipline/hooks/verbosity.sh.
An unreadable path would meter the second kind on its error branch, which is
the same defect one level down from the one sending the field at all fixes.
```

### UserPromptSubmit corpus

```text
UserPromptSubmit is measured against a CORPUS, scored MAX, not one string.

WHY. This used to send exactly one prompt — "refactor the auth module, add
tests and review the diff". api-design's remind.sh (the docs-first reminder) gates on
(sdk|endpoint|integrat\w*|webhook|oauth|graphql); none of those words is in
that sentence, so the hook baselined at 0 while emitting 206 bytes (~52 tok)
on a real integration prompt. A hook whose trigger vocabulary misses the one
probe is unmetered forever, and its growth with it. MAX rather than SUM
because a user sends one prompt, not five; the corpus asks "what is the worst
single prompt", which is the number the budget is about.

LIMITATION: a hook whose trigger appears in no corpus entry still reads 0,
and that 0 is indistinguishable from "never fires". Extend the corpus when a
new trigger vocabulary ships; nothing here can detect that for you.
```

### Fresh sid per corpus entry

```text
Fresh sid + TMPDIR per corpus entry: several prompt hooks are once-per
session behind a marker, so a reused id would score every entry after the
first at 0 and turn the corpus back into the single probe it replaces.
```

### transcript_path is sent

```text
transcript_path IS SENT, and that is load-bearing. Every context-keyed hook
in this marketplace reads `.transcript_path // .session_id` (a subagent
shares its parent's session_id, so keying on it dedups the worker against
nudges it never saw). A payload carrying only session_id therefore meters
every one of those hooks on its FALLBACK branch — the same
grade-the-branch-the-host-never-takes shape `pc_harness_payload` closes for
test harnesses, which scans only scripts/smoke/ and plugins/*/scripts/
__tests__/ and so never saw this meter.

NO BASELINE MOVED when this landed, and that is the honest result: this
fixes WHICH BRANCH is metered, not any number. Hooks that merely hash the
field emit the same bytes either way; the ones this re-branches are the two
the probe runs that OPEN the transcript — comment-discipline's verbosity.sh
and task-runner's drift.sh, both of which exited at a no-transcript guard
under the old payload and now read the file. Both emit 0 bytes either way,
which is why no number moved. (NOT hindsight/hooks/collect.sh, which two
earlier drafts of this comment named: it is wired to SessionEnd, and this
meter executes only SessionStart, UserPromptSubmit and Pre/PostToolUse — so
it is not metered on any branch, error or otherwise.) An earlier version
of this comment also cited
testing/hooks/test-shape.sh's 0 as the evidence — wrong cause: that hook's
path gate (:81-84) exits before it ever reads a context key at :95, so it
reads 0 on `src/example.ts` with or without this field. That is the FILE
SHAPE gap, named separately in the closing notes at the bottom of this file.
```

### File-shape corpus

```text
FILE-SHAPE CORPUS. One synthetic Edit at one path used to be the whole probe,
and the closing notes named the consequence: a hook gated on any other path
shape read 0 "regardless of what it would emit". Six of the nine per-edit
hooks in this marketplace scored 0 for exactly that reason, not for silence —
testing's matcher wants a test file, comment-discipline has a CSS branch,
ui-ux's palette hook wants a stylesheet, database's guard wants a migration.
A channel that cannot see a hook fire cannot be reduced on purpose.

Aggregation mirrors the prompt corpus deliberately: SUM across a plugin's
hooks for one shape (an edit that trips two of them pays both), MAX across
shapes (report the worst single edit, not a fictional session that edits
five files at once). The figure is what ONE edit can cost.
```

### plugin_mcp_bytes

```text
Bytes of the tools/list result a plugin's LOCAL MCP servers put in context at
session start. Always-on by nature: tool definitions are loaded once and stay.
Remote servers (type http/sse) cannot be read offline — they are counted as 0
here and enumerated separately in the closing notes, so the run reports the
blind spot instead of scoring it as free.
```

### MCP_UNMEASURABLE

```text
A stdio MCP server needs its runtime to answer tools/list. On a machine
without that runtime the measurement is 0, which against a non-zero baseline
would read as "this plugin shrank by 475 tokens" and fail the build for a
missing binary. Exempt those plugins from the always-on delta this run and say
so — a gate that fires on the checker's toolchain rather than on the surface
under test is worse than no gate.
```

### LISTING CAP

```text
LISTING CAP. Claude Code allocates a budget for the skill listing and drops
descriptions past it, least-invoked-first, names surviving. One source
documents the default as ~15,000 chars; the eviction was observed live on
2026-08-26 (rationale/marketplace-necessity-review-2026-08-26.md:262-287),
where ~31 marketplace descriptions arrived stripped and the stripped set was
nondeterministic at the margin across identical reloads.

THE CAP IS NOT A CONSTANT AND NOT 15,000. This channel asserted `LISTING_CAP=15000`
from its creation until 2026-08-31, sourced from a doc paraphrase nobody checked.
Read out of the shipped CLI (2.1.251) the rule is:

    budget_chars = contextWindowTokens * bytesPerToken * skillListingBudgetFraction

  * `skillListingBudgetFraction` defaults to **0.01** and is a settings.json key.
  * `bytesPerToken` is **4** for the older tokenizer set (through opus-4-6 /
    sonnet-4-6 / haiku-4-5) and **3** for everything newer, opus-5 included.
  * A SECOND, independent cap applies per skill: `skillListingMaxDescChars`,
    default **1536**. Longer descriptions are truncated individually, always,
    budget or not. This repo's own description linter caps at 500, so it never binds.

So the real budget spans a 6.7x range depending on where you run:

    opus-5    @200k = 6,000 chars     opus-5    @1M = 30,000 chars
    opus-4-6  @200k = 8,000 chars     opus-4-6  @1M = 40,000 chars

AND THE UNIT IS NOT DESCRIPTION TEXT. The CLI costs each entry as
`name + 4 + min(description + " - " + when_to_use, 1536)`, joined by one separator each — so
the artifact NAME and a 4-char delimiter are charged per artifact. Artifact COUNT is
in the measure directly, which is the mechanical reason "fewer artifacts" beats
"shorter descriptions" and not merely an empirical one.

Over budget, the CLI does not drop the tail: it reduces every non-protected entry
to name-only, then buys descriptions back in PRIORITY order until the budget is
spent (bundled-prompt skills are protected outright). So the survivors are the
high-priority ones, and "least-invoked first" is the right intuition.

SHORT-CIRCUIT, unmodelled: the CLI reads `process.env.SLASH_COMMAND_TOOL_CHAR_BUDGET`
FIRST and returns it verbatim when set, so a user who exports it has no formula at all
and every number below is wrong for them. Nothing here detects that.

WHAT THIS CHANNEL REPORTS: the worst realistic case, opus-5 at 200k = 6,000 chars,
overridable with LISTING_CTX_TOKENS / LISTING_BYTES_PER_TOKEN / LISTING_FRACTION.
A 1M-context session gets 5x that, so an install flagged here may be entirely fine
where you personally run it — the row prints both. Report-only, never fails a build.
```

### LISTING_FRACTION

```text
LISTING_FRACTION takes the same unit as the CLI's skillListingBudgetFraction
(0.01, 0.02, ...) — the unit all-plugins' README and script teach. awk, not $(( )): the
first version read an undocumented integer-percent variable and crashed on
exactly the values the READMEs recommend.
```

### One dir per plugin

```text
Every plugin is measured from its own dir. A `dependencies` branch summed a bundle's
members (plus its own uninstall command) until 2026-09-26, when the suites were
retired and pc_plugin_dependencies started failing any plugin.json that declares one;
a branch for a shape validate.sh rejects would be dead code with a vote.
```

### Listing channel row and the NEAR band

```text
LISTING CHANNEL (report-only). Descriptions ONLY — deliberately not the
always-on sum. The host's skill listing is built from description text; a
SessionStart hook's stdout and an MCP tools/list are injected by other
means and survive the listing budget, which is the whole distinction this
channel exists to draw. Hooks are eviction-proof; descriptions are not.
NEAR band: within 3% of the cap EITHER WAY — [97%, 103%]. The unit the host
counts is unverified (this measures LC_ALL=C bytes, a ~1% overcount of chars),
so inside that band neither "under" nor "over" is a claim this channel has
earned. The first version checked `-gt cap` before the band, so 100-103%
printed a confident OVER — the exact unearned verdict the band was added to
avoid. The order below is the fix: band first, OVER only past 103%.
```

### UNION

```text
UNION (every plugin). Every row above answers "if you installed only this one
thing", which is the question nobody asks of a marketplace they install whole. The
all-plugins-installed figure appeared in NO tooling here until 2026-09-15, so two
independent audits each had to recompute it by hand. The number is deliberately NOT
written down here or in any README: this line is the one place that computes it.
```

### Activated rows

```text
Activated channel: only reported when the state actually changes what a
plugin emits. A plugin whose activated figure equals its always-on figure has
no waiting-for-state surface and would add a row saying nothing.
```

### Tolerance

```text
Tolerance: 2 tokens per plugin. (A bundle got 2 x member-count while bundles
existed; they were retired 2026-09-26 and the scaling went with them.)

BASIS (a number with no stated basis is theater). The metric is bytes/4,
so 2 tokens is an 8-byte edit — one short word. Every meaningful
description change is larger: adding a trigger phrase costs 15+ bytes.
At zero tolerance, fixing a 4-character typo in one description took
i18n from 116 to 117 tokens and exited 1, freezing every description in
the marketplace at its current byte length.

LIMITATION (honest scope): this converts "any typo is a blocking budget
failure" into "only real surface growth is". It does NOT bound aggregate
drift — every leaf drifting its full +2 is ~150 tokens across the
marketplace that no run reports. Accepted, not covered; the ratchet is
per-plugin, and that is exactly what it means.
```

### Emit the listing channel

```text
Emit the listing channel. Report-only by construction: no `fail=1`, no ceiling
comparison that can red a build. It answers a question the token table cannot —
not "what does the catalogue weigh" but "what will the host actually load".

AN `OVER` STATUS IS A REACHABILITY WARNING AND NEVER A COST WARNING, and the
channel now says so on every run because the number looks exactly like a bill.
The host DROPS description text past the cap, so that text is never sent and
never charged: an over-cap install pays the same description cost as any install
sitting at the cap. Trimming descriptions above the cap therefore saves ~nothing
(measured twice: 2.8% catalogue-wide at distillation-2026-08-23.md:206-214, 1.8%
for taskmaster-suite specifically). What overflow was ASSUMED to cost is DISPATCH — the
dropped descriptions arrive name-only and the surviving set is nondeterministic
across reloads (observed live, marketplace-necessity-review-2026-08-26.md:262-287).

THAT ASSUMPTION WAS MEASURED ON 2026-09-15 AND DID NOT HOLD. Stripping a skill's
description changed how often it fired by nothing: 47/50 with descriptions against
47/50 name-only, across five conditions from one installed skill up to 226, and in
the hardest condition the name-only arm scored HIGHER. Method, per-condition table
and — importantly — what it does NOT establish: rationale/2026-09-15-listing-eviction-probe.md;
re-runnable via scripts/smoke/listing-eviction-probe.sh. What DID cost firing was
OVERLAP: eight skills contesting one territory took BOTH arms from 100% to ~75%.

So this row is still worth printing — it is the honest measure of what the host
will load — but it is not evidence that anything became unreachable, and nobody
should trim a description or raise skillListingBudgetFraction on the strength of
it. The membership argument that retired the `everything` bundle on 2026-08-31
survives, on the overlap finding rather than the eviction one: fewer artifacts,
because adjacent artifacts compete. Full cost derivation:
rationale/2026-08-31-token-cost-review.md.
```

### ceil3

```text
ceil3: round the recommendation UP to the precision it is PRINTED at. The old margin
was a flat x1.02, which is smaller than one ulp of %.3f at the 1M tier — so the printed
fraction could round DOWN to a value that does not fit, and the margin meant to prevent
exactly that was invisible at the only tier where it mattered. The ceiling IS the margin.
```

### ALWAYS_ON_CEILING

```text
AGGREGATE CEILING. The per-plugin ratchet above says of itself, at :127-131, that
it "does NOT bound aggregate drift" — every leaf may drift its full +2 and no run
reports the sum, while --update-baseline accepts any growth on request. So the one
number the README advertises to users as the cost of `everything` had nothing
holding it anywhere. This does: a declared ceiling that fails the build, so a new
leaf has to be paid for by a deletion or by an explicit, reviewable decision to
raise the number in this file. That is the only version of the marketplace's own
"new surfaces name their funding deletion" rule with teeth.

Raising it is legitimate and deliberately visible: edit the line below in a commit
someone reviews. --update-baseline does NOT move it, which is the point — the
per-plugin ratchet is a convenience, this is a budget.
Raised 12600 -> 12800 on 2026-08-15 for the `lean` plugin (73 tokens: one skill
description, no command, no agent). The funding question was asked the other way
first, and the answer is worth recording: the marketplace's fattest frontmatter
description is 435 bytes against a 500-byte cap, so paying for `lean` by deletion
meant trimming trigger phrasing out of five or six unrelated skills to buy 0.5% of
this budget. Degrading dispatch quality across the catalogue to avoid a 200-token
line edit is precisely the ratio-chasing `lean:cost-model` and testing's
proportionality.md both reject — the cheaper artifact would have been the more
expensive decision. Spending it deliberately and saying so is the honest form.
```

### DYNAMIC_CEILING

```text
Raised 2600 -> 2800 on 2026-08-11 with the delivery-channel fixes: the
skill-router inline nudges moved to the metered additionalContext envelope
(previously unmetered dead stdout), plain-source routing rows were added,
and taskmaster's clarify directive widened. Those are deliberate spends the
owner chose; the old ceiling would have sat 1 token from failure. The
ceiling still exists to make the NEXT unplanned growth a conversation.
Raised 2800 -> 2900 on 2026-08-15. `lean`'s PostToolUse budget hook measures 85
tokens and PASSES the old ceiling — at 2798 of 2800. It is raised anyway, on this
block's own stated reasoning: the 2026-08-11 raise was justified partly because
"the old ceiling would have sat 1 token from failure", and 2 tokens is that case
again. Left alone, the next person to touch ANY hook in this marketplace gets a red
build naming a plugin they did not edit. Note what is NOT being bought: skill-router
alone is 2663 of the 2798 (95%), so this channel remains one plugin's command
catalog plus rounding. That is the number worth attacking next, not this ceiling.
```

### RECONCILIATION

```text
RECONCILIATION against `claude plugin details` — the host's own meter.

WHY. This script estimates always-on cost as description bytes / 4. The host
charges a per-component floor on top of that (~60-130 tok even for a one-line
description) and counts commands as skills, so our number reads LOW: measured
2026-08-20, summing `claude plugin details` over the 61 leaves gave 19,667
tokens against our 12,789 — a factor of 1.54, and the gap scales with COMPONENT
COUNT, which is exactly what a distillation is supposed to reduce. A meter that
under-reads in proportion to the thing it exists to control is worth
reconciling against.

THAT SNAPSHOT'S POPULATION IS STALE AND THE RATIO INHERITS IT. The 61 leaves it
sums were measured before `cfef9c1`, and include nine plugins since deleted
(i18n, livewire, mysql, node-backend, nuxt, php, postgresql, react, vue3) and
none of the bundles. Today's tree is 52 leaves. Re-measuring needs an install,
because `details` resolves by installed name — so 1.54 is carried forward as a
HISTORICAL figure, not a current one. Treat it as an order-of-magnitude
correction, never as a coefficient to multiply today's numbers by. (This
paragraph lived in CLAUDE.md until 2026-08-31 and was deleted there on the
premise that this header carried it. It did not. Verifying that claim per fact,
rather than per file, is the only reason it is here.)

IT IS NOT GROUND TRUTH, measured 2026-08-21. `details` is a static estimate over
the FILES: it charged a `disable-model-invocation: true` skill ~60 always-on
tokens for a description the session listing provably does not contain (probes
in rationale/host-lever-probes-2026-08-21.md). Read the gap it reports as a
better model of the host's per-component floor, not as a measurement of what
the harness actually loads.

STANDING: local, WARN-only, NOT a CI step, and this comment is the reason.
`claude plugin details` resolves a plugin by INSTALLED NAME — it rejects a path
and its own `--plugin-dir` hint is not an option of that subcommand — so a
fresh checkout with nothing installed cannot run it. Wiring it into CI would
ship a check that can never execute there.

--reconcile        compare live against the committed snapshot, WARN on drift
--update-official  re-take the snapshot (records the date it was taken)
```

### Drift against the snapshot

```text
Drift against the last snapshot: >15% on any plugin is a WARN, because a
jump means either the host changed how it charges or we changed the
plugin without noticing what it costs a user.
```

### Remote MCP servers

```text
Remote MCP servers cannot be read offline. Naming them is the whole point:
a plugin shipping one is an always-on context cost AND an outbound runtime
dependency, and scoring it zero would say the opposite.
```

### EVENT AND TOOL SHAPE

```text
EVENT AND TOOL SHAPE. The dynamic channel executes UserPromptSubmit and
Pre/PostToolUse-as-Edit, and nothing else. Two whole categories therefore read
0, and a 0 here is indistinguishable from "emits nothing" — the same failure
the corpus comment above names for prompt vocabulary, one level up:
  - Stop hooks. Three plugins ship one (candor, code-architecture, task-runner)
    and their block reasons are model-visible text, measured at roughly
    211 / 127 / 742 tokens upper bound across branches. Never executed here.
  - PreToolUse matched on Bash. command-guard's deny reason is ~175 tokens per
    denied call and its dynamic baseline reads 0.
Naming it is the honest floor; metering it means teaching this loop the other
event and tool shapes, which is a real change and not one this note makes.
```

### FILE SHAPE

```text
FILE SHAPE. The synthetic Edit targets src/example.ts, so a hook gated on a
path pattern it does not match scores 0 for a reason that has nothing to do
with its size — testing/hooks/test-shape.sh emits ~146 tokens on a real test
file and baselines 0 here.
```

### --update-baseline and an unmeasurable MCP plugin

```text
Updating IS the remedy — suppress the FAIL/remedy lines on this path.
But an unmeasurable MCP plugin must not have its zero WRITTEN: the delta
check above exempts it, so a baseline zeroed here passes locally and then
fails CI by the full tool-surface amount (+475 on registry-source,
2026-08-26, written by an --update-baseline run on a node-less machine).
Preserve the old value for the plugin. (The deficit was also added back into every
bundle that summed it, in both channels, until the bundles were retired 2026-09-26.)
```

## scripts/done-gate.sh

### Header

```text
done-gate — a Stop hook that refuses to let a turn end quietly on a red gate.

WHY: CLAUDE.md is advisory. Across a long session an agent reliably verifies
the axes it was last burned on and quietly skips the rest. The checks below are
the fast per-plugin slice of CI's blocking steps — passing them is necessary, not
sufficient. Only CLAUDE.md ("Every enforcement surface, by tier") carries the
step COUNT; two files carrying one number is how they drift apart.

TRIGGER — all THREE must hold:
  1. a plugins/<name> dir has a modified, staged or untracked file, and
  2. the turn did NOT acknowledge a failing/in-progress state, and
  3. a check genuinely fails.

The original version asked "did the turn claim completion?" and matched a
completion-phrasing regex. That penalised clear reporting and was evaded by
saying nothing: end the turn without the word "done" and a red gate shipped
silently. The test is inverted — saying "validate.sh is failing", "still in
progress", "halting with evidence", "blocked on X" passes; ending on a red gate
having said none of it does not.

The prose comes from the TRANSCRIPT on purpose. The Stop payload does carry
`last_assistant_message` (ask-ledger and candor read it), but that is the final
message only; the tail of every assistant text block lets an acknowledgment said
earlier in the turn count.

WHAT RUNS: `generate.sh --check`, then for each changed plugin validate.sh's
FAIL-tier per-file checks — plugin.json JSON validity (`jq empty`), frontmatter
(pc_frontmatter), skill budget, doc location, jargon (not for
taskmaster/task-runner), removed refs, hook executability (pc_hook_exec), hook
shebangs, hook timeouts (pc_hook_timeout), the no-dependencies rule
(pc_plugin_dependencies) — plus check-version-bumps.sh when committed history
differs from the base. No WARN-tier check runs. validate.sh and
context-budget.sh are NOT invoked: measured 2026-09-29, the gate that ran them
took 93 s against the 60 s Stop timeout, so the host killed it before it blocked.

WHAT IT NO LONGER CATCHES — every cross-plugin and repo-level check, left to CI
and CLAUDE.md's pre-push loop: lanes (territory, coverage, deference, phase
guard), skill-router rules (resolution, overlap, reachability, co-fire), README
counts and the plugin table, marketplace.json parity, CHANGELOG/metadata parity,
the role-floor registry, the context budget, the host's official validator, the
smoke harnesses, and validate.sh's per-file checks not named above (plugin.json
fields, command argument hints, host overlap, handoff refs, dispatch binding, the
hook-state checks, the command/skill shadow check, the renames ledger). A change
confined to templates/, scripts/ or .claude/skills/ never triggers it.

RESIDUAL: the doc allow-list, the jargon exemption, the jargon/removed-refs file
set, the symlinked-skill budget skip and the plugin.json validity test (one label
here for a missing and an invalid file) are COPIES of validate.sh's inline logic;
frontmatter and hook-exec are not — both scripts call pc_frontmatter and pc_hook_exec.
validate.sh stays the authority; the allow_md copy is asserted byte-identical by
scripts/smoke/done-gate-tests.sh. pc_plugin_dependencies prints the manifest's
`.name`, so a changed plugin whose name differs from its directory is not matched.

LIMITATION (honest scope). This converts "stop silently while a gate is red"
into "stop having said so, or be blocked". Residuals, all accepted:
  - It does not prove the acknowledgment is truthful; prose mentioning failure
    for another reason satisfies the escape.
  - It cannot tell a mid-work pause from a final claim. A Stop hook sees one
    turn, not intent; the acknowledgment escape is what keeps ordinary work
    unblocked, and an honest turn always carries it.
  - The trigger reads the working tree, index and untracked files; only the
    version-bump gate consults committed history.
  - It fires on "plugins are dirty", not "this turn dirtied plugins", so the
    first stop in an already-dirty session is judged even if the turn was
    read-only. The state marker below means it says so once, not repeatedly.

FAIL-OPEN on every missing tool or unreadable input, matching the sibling hooks
(candor/hooks/gate.sh, hindsight/hooks/collect.sh) — with one exception:
pc_removed_refs fails CLOSED on a missing or malformed scripts/removed-plugins.tsv,
so a broken ledger blocks every changed plugin .md until it is restored.

A Stop hook can reach the model two ways: stdout {"decision":"block",…} with
exit 0, or exit 2 with the reason on stderr. This uses exit 2. Exit 0 with no
JSON prints into a turn that has already ended and cannot prevent anything.

DISABLE: remove the Stop entry from .claude/settings.json, or
         export CRAFT_DONE_GATE=off
```

Editor's note (2026-10-28): that CLAUDE.md text now lives in CLAUDE.md § CI step count (the count) and `.claude/skills/repo-gates/references/enforcement-tiers.md` (the tier tour) (m13).

### 2. ACKNOWLEDGMENT

```text
2. ACKNOWLEDGMENT (cheap, and evaluated BEFORE the checks so an honest turn
never pays generate.sh --check plus the per-plugin scans).
Whole-word matching via grep -w: BSD grep has no \b, and an unanchored `red`
matches the tail of required/registered/triggered/covered — 1390 occurrences
under plugins/ in this repo, which would reopen the evasion in new spelling.
```

### check-version-bumps.sh only on committed history

```text
check-version-bumps.sh reads COMMITTED history while this hook fires on an
UNCOMMITTED tree — different questions. Run it only when there IS committed
history to judge, against the same base ref that script would pick itself;
otherwise it reports OK regardless and adds a gate that cannot report.
```

### 4. LOOP GUARD

```text
4. LOOP GUARD. stop_hook_active is not trusted alone — the sibling Stop hook
refuses to assume it too. The old trigger was prose the next turn could simply
not repeat; this one is repo state a mid-work turn cannot clear, so an unset
flag would mean an unbreakable stop-loop. Block once per distinct state.
```

## scripts/eval-cases.sh

### Header

```text
BLOCKING gate: every shipped eval suite must LOAD.

WHY THIS EXISTS. On 2026-09-14 two of the three shipped eval suites were found to have
never run — `resilience` and `web-dev` loaded 0 cases on CLI 2.1.270 (`invalid
case.yaml: graders: Required`). They sat dead for weeks. Nothing noticed, because
nothing runs an eval in CI, and a dead suite is indistinguishable from a passing one
when nobody executes it: the files are present, `validate.sh` is happy, the directory
looks maintained.

THE ROOT CAUSE WAS MISNAMED for two days. Both suites used the `prompt.md` +
`graders/*.md` shape, and this script's first revision failed that SHAPE as dead. It is
not: the runner's own usage line reads `case.yaml or prompt.md + graders/*.md`, and a
`prompt.md` beside a `graders/says-hello.md` carrying `type: regex` frontmatter loaded
and scored 1.00 on 2.1.273 (measured 2026-09-16,
rationale/marketplace-trend-audit-2026-09-16.md A1). What the two suites shipped was a
grader with NO frontmatter at all — prose from line 1
(`git show 4878150702^:plugins/resilience/evals/timeout-and-retry/graders/retry-idempotency.md`)
— so the runner had no `type:` to build a grader from. That is the same defect as a
`case.yaml` grader entry with no `type`, reached through a different file.

Running the evals in CI is the expensive fix — a full resilience matrix measured
$10.13 and 12 minutes on 2026-09-15, it needs a live model and a credential, and its
result is a score rather than a verdict. LOADING them is nearly free and catches the
failure that actually happened. That is the whole claim of this script.

WHAT IT CATCHES:
  - an `evals/` directory that resolves to ZERO cases (the 2026-09-14 bug)
  - a case directory holding neither `case.yaml` nor `prompt.md`
  - a `case.yaml` that is not valid YAML, or is not a mapping
  - a missing `name`, `execution.prompt`, or `graders`
  - a `schema_version` that is absent, or unquoted (a YAML float, not a string), or
    whose major does not parseInt — each of which loads ZERO cases
  - `graders` present but empty, or a grader with no `type` (the exact rejection above)
  - a `prompt.md` with no `graders/*.md`, or a `graders/*.md` whose frontmatter carries
    no `type:` (or none at all). The NAME is not checked: until 2026-09-17 this branch
    held graders to a six-name allowlist while the case.yaml branch asked only for
    presence, so one grader shape was gated by a list the runner never published and
    the other was not. The runner is the authority on which types exist; both branches
    now ask the same question — is there a non-empty `type`.
  - a non-numeric or non-positive `runs` / `max_turns`
  - a `context.scaffold_script` naming a file that is not in the case directory. The
    runner reports nothing for it without `--scaffold`, so the broken path only shows
    up on a paid run of a suite somebody trusted enough to pass the flag to.
  - (WARN) a suite with a scaffolded case whose plugin README never names `--scaffold`.
    `--scaffold` is OFF by default; on 2026-09-22 five of fourteen cases declared a
    scaffold and only `overseer`'s README said so, so candor's three ran against
    whatever happened to be in the operator's unstaged workspace and scored it.
  - `runs` below 3, or no `runs` key at all, on a case carrying an `llm` grader, in
    either shape — a prompt.md case reads `runs` from its own frontmatter first and a
    sibling case.yaml second (a directory holding BOTH files is judged on the yaml's
    `runs` alone in the case.yaml branch). CLAUDE.md's own rule: three runs cannot separate a
    regression from a flake — fewer cannot even try. A WARN until 2026-09-30, under
    which four shipped cases sat at `runs: 1`. A case with no `llm` grader is exempt.
  - (FREE LOAD) per suite, the documented zero-cost invocation
    `claude plugin eval ./plugins/<p> --max-cost-usd 0 --no-publish --trust-plugin`,
    failing on the runner's `not granted` and `cannot pass with the granted tools`
    lines. Those are operator-grant facts, not file facts: a case that legitimately
    declares Write/Edit/Bash in `execution.allowed_tools` draws them under the bare
    command no matter what it contains. So the FAIL is discharged by DOCUMENTING the
    grant — the plugin's own README naming `--allow-tools` — which is the defect the
    2026-09-22 panel actually found (candor's grant lived in CHANGELOG:26 and nowhere
    an installer reads). Measured that day: `ran-a-command` in
    candor/limitation-checked-before-stated cannot pass under the bare command, and
    ask-ledger/named-things-accounted reports Write, Edit not granted.

WHAT IT DOES NOT CATCH, stated because this repo tiers its claims:
  - whether a case MEASURES anything. A case whose control arm passes is a regression
    guard with no headroom, and it loads exactly like a case that measures a skill.
    That distinction is `CLAUDE.md`'s ceiling rule and it is `recorded`, not gated.
  - whether a grader's criteria are any good, or whether the prompt elicits the
    behaviour the grader scores. Both are agent-graded at best.
  - whether the suite would PASS. This never runs a model and never spends a cent.
  - the run count a suite actually gets. `claude plugin eval --runs <n>` overrides every
    case's `runs` on the command line, so the three this gate demands can still be
    lowered at run time; it reads the files, not the invocation.
  - drift between the runner's schema and this checker's idea of it. The runner is the
    authority; this asserts the subset whose absence has actually broken a suite here.
  - a `schema_version` MAJOR the installed CLI is too old for. The runner rejects one
    above its own ceiling (`1` on 2.1.273); that constant lives in the binary and moves
    with it, so this gate checks the shape and leaves the ceiling to the runner —
    copying the number here is how CLAUDE.md's stale-count rule gets broken again.
  - how the runner merges a case that ships BOTH files. The runner's own usage line
    admits the combination, so a `case.yaml` beside a `prompt.md` is held to `name`
    only: the prompt.md body is the prompt and graders/*.md are the graders, and
    demanding `execution.prompt` there (as this did until 2026-09-17) failed a shape
    the runner loads. A key that IS present is still shape-checked; whether the runner
    prefers the yaml's `graders:` list or the directory when both exist is unmeasured.
  - which grader KEYS the runner accepts. Only `type` is asserted; on 2026-09-18 this
    loaded a case whose grader carried a `target:` key the runner rejected at run time
    (rationale/fable-distillation-2026-09-18.md). The key set is the runner's, not this
    script's — see the schema-drift bullet above.
  - anything INSIDE a case. A case dir is the first directory on a branch holding a
    `case.yaml` or a `prompt.md`; the walk stops there, so a `prompt.md` under its
    `resources/` or `mocks/` is a fixture the case reads, neither counted nor failed.
    Cases NEST: the runner's own usage line globs `<eval dir>/**/case.yaml or
    prompt.md + graders/*.md` (`claude plugin eval --help`, 2.1.273), so a case may
    sit at any depth. Until 2026-09-17 this walked `evals/*/` only and FAILED the
    PARENT of a nested case as "not a case" — a gate rejecting a layout the runner
    loads, and a regression against the recursive `find` it replaced.
  - whether a scaffold_script that EXISTS builds the workspace the prompt assumes, or
    whether the README's documented grant is the RIGHT grant. Both are agent-graded:
    this checks that the file is there and that the flag is named, nothing more.
  - anything at all when `claude` is not on PATH — the free load check then prints a
    WARN and is skipped, exactly as `official-validate.sh` does. A gate that skips is
    not a gate, so the skip is printed by name rather than swallowed.
  - a suite under a directory with no `.claude-plugin/plugin.json`. The runner resolves
    a plugin from the target path; with no manifest there is nothing to resolve, so the
    free load check is skipped there (which is also what keeps the synthetic fixtures in
    scripts/smoke/eval-case-tests.sh from invoking the binary).
```

### case_dirs

```text
A case dir is the first directory on a branch carrying a case definition; the walk
does not descend into one, so its fixtures are never mistaken for cases. A branch
that bottoms out with no case definition anywhere on it is `dead` — the scratch dir
that looks like a suite and loads nothing. results/ is the runner's output dir,
mocks/ its MCP stand-ins, and graders/ belongs to the case above it.
```

### free_load_check

```text
The documented zero-cost invocation. `--max-cost-usd 0` aborts before the first run
launches (exit 2, "partial"), so no model is called and no credential is needed — but
the runner has already resolved the plugin, read every case and printed the grant
diagnostics by then. That is the whole of what this reads.
```

### --output-dir and --report

```text
--output-dir AND --report: the first redirects aggregate-result.json, the second the
HTML report, and only both together keep the runner out of `plugins/<p>/evals/results/`
(gitignored, so this litters rather than dirties — measured 2026-09-22). HOME is
throwaway so the check cannot depend on, or write to, the operator's config.
```

### Discharged by documenting the grant

```text
Discharged by documenting the grant: the lines are a property of the bare command,
not of the files, so the fix an author can make is to name `--allow-tools` where an
installer reads it. A CHANGELOG entry is not that place (candor, 2026-09-22).
```

## scripts/gate-coverage.sh

### Header

```text
Which author-time checks has anyone actually watched FAIL?

MAINTAINER PATH, NOT A GATE. Always exits 0 and never fails a build. It reports; the
judgment about whether an uncovered check deserves a fixture stays with a person,
because some checks are structural enough that a fixture would be ceremony.

WHY IT EXISTS: a check nobody has seen fail is indistinguishable from `return 0`. That
is not hypothetical here — `pc_context_key` passed all three hooks that shipped the
2026-08-17 marker-key regression, because it tests for a string's presence and every
offender contained the string.

WHY IT IS A SCRIPT AND NOT A NUMBER IN A DOC: the first version of that day's review
said "20 checks, 2 have harnesses, so ~14 have never been watched fail" — arrived at by
counting harness FILES rather than tracing which checks each file exercises. The true
figure was 3, because one harness covers six checks. A recorded count in prose is a
measurement someone will trust and nobody will recompute. Run this instead.

HONEST LIMITATION: coverage here means "a harness mentions this function by name". It
cannot tell an assertion that watches the check fail from one that merely calls it, and
it cannot see a harness that exercises a check through validate.sh without naming it.
So this over-reports coverage; treat a NONE as certain and a hit as probable. WIRED
counts mentions in validate.sh, context-budget.sh and official-validate.sh only;
done-gate.sh and authoring-guard.sh also source the lib and are not counted. A mention
is likewise not proof of a call.
```

## scripts/generate.sh

### Header

```text
scripts/generate.sh — deterministic chassis stamper.

Discovers every plugins/*/.chassis.json (each holds ONE chassis object or an ARRAY
of them) and renders it through templates/ via the card-01 template engine
(scripts/lib/template-engine.sh, overridable with TEMPLATE_ENGINE). Var derivation:
booleans lang/concern come from the manifest `variant` string, applyExtraBlock from
the `applyExtra` array, worker-agent vars are the six frontmatter fields verbatim
plus an optional `floor` frontmatter slot, an optional `preloadSkills` slot (renders a
`skills: [...]` frontmatter line — Claude Code preloads those bodies at spawn; set only
where the cost per spawn is earned, see ui-ux's .chassis.json), and three optional
domain-content slots —
operatingProcedure, domainChecklist, deferRule (each a markdown string or an array of
lines, joined with "\n"; absent fields default to "" so the template's {{#if}} guards
render nothing — so a chassis agent that pins a non-`inherit` model can emit its own
`floor: none`/floor row exemption, and existing agents re-render byte-identical).

RETIRED 2026-09-22: the `stack-review` kind and templates/review-command.md.tmpl.
It rendered ONE file in the whole marketplace (code-review/commands/comment-review.md)
behind a 24-line template, four partials and nine opt-out justifications — more prose
in the machinery than in the artifact (panel finding #64,
rationale/specialist-panel-2026-09-22.md). That output is inlined and hand-maintained
now; the `optout` kind stays, as the plain note it always was. The build-time worker
routing through task-execution/references/routing.md went with it — nothing else read
that map from here.

  --write : byte-compare rendered vs tree; on a delta write the file (chmod +x for
            .sh) and patch-bump that plugin's plugin.json ONCE per run. Idempotent.
  --check : render to a temp file, byte-diff vs tree (incl. the mode bit on hooks),
            print the opt-out + worker-override report, exit non-zero on any drift.
            NEVER writes.

hooks.json is never generated. Roots are overridable for fixtures via CHASSIS_ROOT
(plugins tree to scan/stamp) and CHASSIS_TEMPLATES (templates dir).
Spec: taskmaster-docs/specs/2026-07-13-fable-review-engine.md §generate.sh contract, D6, D7.
```

### emit: preserve blocks

```text
Preserve blocks: transplant the tree's version of each
<!-- preserve:NAME --> body into the render before ANY comparison, so a
sanctioned local divergence is not drift in --check and is not clobbered by
--write. Everything outside those markers still refreshes from the template.
Both modes go through here, so they cannot disagree about what "the render"
is. Runs for every render carrying a marker — today the worker agents'
rubric-source block — and is a no-op for the rest; recount with
`grep -rl '^<!--[[:space:]]*preserve:' plugins templates`.
```

### Lane rows

```text
--- lane rows: the generated block in <plugin>/lane.tsv ---------------------------
Every chassis object that renders an ARTIFACT (reminder hook, boost hook, worker
agent) also declares its lane in a `lane` key —
  {"owns": "<territory>", "trigger": "<definite trigger>", "yieldsTo": "a:b,c:d" | "-",
   "phase": "<optional override>"}
— and generate.sh renders one six-field lane.tsv row per artifact into a block
between `# generated:start` and `# generated:end`. --check byte-diffs that block
like any other generated file; --write rewrites it and patch-bumps the plugin.

WHY. Until 2026-09-03 the rows for generated artifacts were typed by hand
(every generated worker agent, chassis command and reminder hook — recount with
`grep -l 'generated from templates' plugins/*/agents/*.md plugins/*/commands/*.md
plugins/*/hooks/*.sh`), so one property was split across a generator and a
hand-edited file — exactly the drift the chassis exists to prevent
(collective-taskforce-backlog #8). A missing `lane` key is a hard error in both
modes: every manifest has carried one since the 2026-09-03 sweep.
Phase: no surviving renderer supplies a default — the two command kinds that did
(review command → review, suite uninstall → ship) were retired 2026-09-22 and
2026-09-26 — so hooks and agents MUST declare `lane.phase` explicitly — a hook's phase is what
pc_phase_guard reads (`any` exempts it from the sentinel), and the shipped rows
disagree with any default (api-design:remind build, taskmaster:remind shape,
testing:test-engineer verify), so a default there would silently disarm a gate.
owns/trigger/yieldsTo carry the SAME values the hand rows carried, lifted verbatim.
A hand row for an artifact the block now owns is a hard error: two rows for one
artifact only trip pc_lanes_schema when their `owns` match verbatim.
RESIDUAL (named): a deleted `lane` KEY strips its block on the next run, but a
deleted MANIFEST is never visited, so its plugin's generated block would rot with
--check silent. Delete the block by hand with the manifest; nothing checks it.
```

### lane_row: a missing lane key

```text
Every manifest carries a lane key since the 2026-09-03 sweep; a new chassis
object without one is a hard error — the generator owns the artifact, so it
owns the row, and pc_lanes_coverage would fail the build on a row nobody writes.
```

### render_reminder_hook

```text
budgetShared/budgetExempt are GONE. They were derived complements standing in
for a two-branch template: one branch ran a first-come mkdir lottery, the other
was a privileged directive exempt from it. Both are replaced by a single ranked
path — a hook declares `arcRank` and yields to any better rank sharing its phase,
so no plugin is privileged and the protocol still works when the old exempt
plugin is not installed (approaches alone ships two reminder hooks and no taskmaster).
armsClarifyGate replaces budgetExempt's SIDE EFFECT only: dropping the
cross-plugin cc-workprompt marker. Defaults keep a bare manifest renderable.
`file` (optional, default hooks/remind.sh) names the target the way boost-hook's
does: a plugin carrying TWO reminder hooks with different phases renders each
to its own file (approaches: remind.sh for build-vs-buy at `decide`,
consult-remind.sh for the irreversible-command guard at `any`, since fresh-take
merged in on 2026-09-14). hooks.json must list both by hand.
```

### render_boost_hook

```text
Boost injectors (taskmaster ultra.sh, task-runner ultra-assess.sh, craft-layer
ultra-craft.sh) shared one hand-copied 35-line skeleton — off switch, fence
scrub, 200-char head, negation guard, enumerated self-echo guard — and differed
only in env var, token regex and directive text. The self-echo guard had been
fixed in three files once already (hook-guard-tests.sh pins the regression), so
the skeleton is one template now and the manifest carries the data. `file`
names the target (hooks/<name>.sh — the three shipped names differ); `regex2`/
`message2` render an elif branch when non-empty (taskmaster's ultra-goal) and
nothing otherwise. The directive goes out through a quoted heredoc, so the
manifest text is the wire text — no bash escaping in the manifest.
```

### render_worker_agent: optional slots

```text
Optional slots (operatingProcedure, domainChecklist, deferRule, floor): each may be
a markdown string or an array of lines (joined with "\n"); absent -> "" so the
template's {{#if}} guards render nothing and existing agents (which carry none of
these fields) re-render byte-identical. `floor` is a scalar frontmatter value
("none" for a breadth/mechanical exemption) — same absent->"" defaulting.
```

### render_catalog

```text
Renders plugins/stack-scan/skills/plugin-scout/references/catalog.md (the scout
lived in its own plugin until 2026-09-14): one deterministic row per marketplace
plugin — `name — [keywords] — description`. Description comes from
marketplace.json, keywords from each plugin.json. Always regenerated on --write
(byte-compared, written on delta); byte-diffed on --check via the shared DRIFT
flag. Does NOT bump stack-scan — the catalog rides the plugin's own change
set, so version ownership stays with its manifest/skill edits.
```

### readme_apply

```text
One README region is generated now: the off-switch table. The bundle-table and
no-suite-leaves blocks went with the suites on 2026-09-26 (no plugin may declare
`dependencies`, so there is no bundle to tabulate and no leaf outside one). The
helper stays a helper: each block owns a marker pair and rewrites only its own
region, and a second block needs nothing but a second call.

A fixture root (CHASSIS_ROOT pointed at a smoke harness tree) has no root README —
every caller returns early rather than dying, or each harness that overrides
CHASSIS_ROOT would read this step's abort as chassis drift.
```

### render_offswitch_table

```text
Every guard in this marketplace fails open and every one of them can be switched off —
and on 2026-09-22 the root README named ZERO of the switches (UX 1,
rationale/specialist-panel-2026-09-22.md #5). A user whose turn was just refused had
no list to read. Generated rather than typed because the set moves with every hook.

THE SOURCE is each plugin's userConfig in plugins/*/.claude-plugin/plugin.json: one
row per distinct upper-cased key, which is the environment variable overriding that
option. It is not the hooks, because a hook reading its switch through cc_option
(templates/blocks/option-resolver.md) leaves no `${NAME:-` for a grep to find. A
switch a hook still reads — `${NAME:-`, `cc_option NAME` on a non-comment line, or the
boost chassis' `plugin_switch=NAME` — that no plugin declares gets a row as well, so
the deliberately undeclared CLAUDE_AI_TRAILER keeps its name in front of a refused
user. The host-supplied CLAUDE_* path, session and data variables are not switches.
Hooks modules under plugins/*/hooks/ count as hooks, cc-kit.ts excepted: pc_switch_reads
credits CC_SUGGEST, which only the kit reads, to the plugins whose modules suggest.

THE COLUMNS: Variable, the env override; Plugins, every plugin declaring it, sorted;
Default, the declared default with true/false shown as on/off — plugins that disagree
are all listed, and an undeclared read shows `—`; What it does, the description's first
sentence, or for an undeclared read the first hook comment line writing `NAME=` ("see
hook header" when none does; CC_SUGGEST's is fixed here, as the kit that reads it is never
scanned). Cut at 104 characters with ` …`, `|` escaped.

WHAT THIS TABLE DOES NOT ESTABLISH: that a switch works, that any hook reads a declared
key, that the hook's cc_option default equals the Default column, or that the hook
names the variable when it refuses you — that last one is pc_offswitch_named's job and
it is a WARN. Nor is a module read exact: a `registerSuggestion(` inside a string literal
or after a trailing `//` still credits CC_SUGGEST, and an `$.env.get` with backticks, inner
spaces or a receiver other than `$` is not read at all.
```

## scripts/host-constants.sh

### Header

```text
scripts/host-constants.sh — the four Claude Code skill-listing constants, in ONE place.

WHAT THEY ARE. The host budgets its skill listing at
  budget_chars = contextWindowTokens x bytesPerToken x skillListingBudgetFraction
and truncates any single entry's description at skillListingMaxDescChars. Read out of
the shipped CLI binary (2.1.278, 2026-09-22) the four defaults sit in one minified
declaration:  var <a>=0.01,<b>=4,<c>=200000;var <d>=1536;

WHY THIS FILE EXISTS. Until 2026-09-22 `1536` was a bare literal in three places —
scripts/context-budget.sh, scripts/lib/plugin-checks.sh and the SHIPPED
plugins/all-plugins/scripts/all-plugins.sh — and `0.01` / `200000` in two more, with
nothing anywhere re-reading the binary they claim to mirror. The 2026-09-22 panel
(AR 8, rationale/specialist-panel-2026-09-22.md #59) found them all still correct and
entirely unverifiable: a host release that moved one would leave every gate, README
paragraph and fraction recommendation in this repo quietly wrong. One definition plus a
re-read is the smallest thing that makes the claim falsifiable.

TWO USES:
  sourced  — defines HOST_LISTING_* and runs nothing else.
  --check  — greps the PINNED CLI binary (pin read from scripts/official-validate.sh)
             for those four literals in their declaration window and reports a diff.

STANDING: WARN. Wired into CI as a `continue-on-error: true` step beside
check-doc-staleness.sh — it reports a host change, it never fails a build on one,
because the repo cannot be red for something upstream did between releases.

WHAT IT DOES NOT CATCH:
  - a host that keeps the literals and changes the FORMULA around them. The window is
    anchored on `skillListingMaxDescChars??`, so the constants are read where the
    listing code reads them, but arithmetic elsewhere is invisible here.
  - any machine without the pinned build on disk: that path is a WARN-skip, and a
    WARN-skip is the normal case on a fresh checkout and in CI.
  - `bytesPerToken`. The host default is 4 and this file records it, but
    context-budget.sh deliberately reports the 3-byte worst case (opus-5), so the two
    numbers differ ON PURPOSE and no check can tell that apart from drift.
  - the `SLASH_COMMAND_TOOL_CHAR_BUDGET` env short-circuit, which bypasses the formula
    entirely when set (the binary returns it before any of these are read). Nothing
    here or in context-budget.sh models a user who exports it.
```

### decl=: the declaration read

```text
The declaration, anchored on the accessor that names the cap — one forward scan, no
leading `.{N}` window (that form backtracks for minutes on a 200 MB binary).
```

## scripts/mod-outcomes.sh

### Header

```text
mod-outcomes.sh — prints the outcome counts this marketplace's mods keep in each plugin's $.store (key `outcomes`).
Catches: suggestions shown, accepted or passed over; prompt-coach judgments, flags and buttons; spawn-floor raises.
Does not: say which project a count came from, see a session with mods off, or show that anything helped. Always exits 0.
```

## scripts/mod-tests.sh

### Header

```text
mod-tests.sh — run `claude plugin test` on every mod: each plugins/*/ whose
hooks/hooks.json has `modules`, plus templates/mods/kit-harness (the shared kit's tests).

WHAT IT CATCHES: a failing mod test; a mod with no *.test.ts or *.test.tsx (the CLI exits
1); a host with hooks modules turned off (disableAllHooks exits 1, measured on 2.1.291) —
the "hooks modules are turned off" text is matched too, so an off run that exits 0 still
FAILs instead of passing on zero tests.
WHAT IT DOES NOT: it runs tests; it proves nothing a test does not assert — a module branch
no test reaches passes. No typecheck (tsc is a spec non-goal). Whether each `modules` entry
exists and exports register is validate.sh's (pc_mod_modules); kit copies, pc_mod_kit.

Standing: gate (a named, fail-capable CI step after the CLI install) — and a local pre-push check.
```

## scripts/official-validate.sh

### Header

```text
official-validate.sh — run the host's own plugin validator, strict, over every
plugin and the marketplace manifest. The local twin of the CI step
"Official plugin validator (--strict)" in .github/workflows/validate.yml, so a
contributor green on the four repo gates is not red only in CI.

WHAT IT CATCHES that validate.sh does not — each probed with a crafted plugin on
CLI 2.1.300, 2026-10-15; the release that added it in brackets:
  - plugin.json / marketplace.json SCHEMA errors — unrecognized fields, wrong
    types — because validate.sh models named fields only;
  - a shell-form hooks.json command leaving `${CLAUDE_PLUGIN_ROOT}` unquoted [2.1.281];
  - an .mcp.json entry the loader would silently drop, a `${user_config.*}`
    reference plugin.json does not declare, an http:// URL to a non-loopback host [2.1.281];
  - a marketplace.json plugin name Claude Code cannot install [2.1.283];
  - an outputStyles / themes / monitors / lspServers path that is missing or
    leaves the plugin directory [2.1.283];
  - a hooks module the host refuses (an `on()` event name that is not a literal).
`--strict` promotes the CLI's warnings to errors.
GATING HOOKS. The CLI LISTS every mod hook at a gating site with whether its
registration carries a `.catch` (`gatingHooks` under --json) [2.1.290], as a note:
--strict passes a missing `.catch`. A gating hook that throws is skipped and the
action runs — the guard fails open — so this script fails `hasCatch: false` itself
(pc_gating_catch). It reads PRESENCE, not policy: a `.catch` that answers `next(e)`
fails open too, and passes here. Below 2.1.290 (reachable only with
OFFICIAL_VALIDATE_ANY_VERSION=1) the key is absent and that half passes vacuously.
WHAT IT DOES NOT: SKILL.md frontmatter typos (measured 2026-08-20 accepting an
invented `bogusfield:` key — rationale/distillation-strategy-2026-08-20.md:37;
still accepted on 2.1.300); that remains validate.sh's job. Nor an unquoted
`${CLAUDE_PLUGIN_ROOT}` in a command or skill — the host reads hooks.json only
(validate.sh's pc_plugin_root_quoting, FAIL).

PIN. The CLI version is asserted, not assumed: `--strict` semantics drift with
releases, so a run on any other version is reported and fails unless
OFFICIAL_VALIDATE_ANY_VERSION=1. CI installs the pinned npm package; locally you
run whatever `claude` is on PATH and this script tells you if it differs.

EGRESS. HOME is a throwaway dir, the auto-updater and non-essential traffic are
disabled, stdin is closed — the verdict cannot depend on network or a prompt.
Measured 2026-09-03 (darwin arm64 native binary): unauthenticated, no prompt,
44/44 + manifest in ~25 s. Linux x64 native, 2.1.300, 2026-10-15: 33 plugins + manifest in
3.0 s with one --json run per plugin, 5.6 s with the old human + --json pair.

Standing: gate (a named, fail-capable CI step) — and a local pre-push check.
```

### The --json run per plugin

```text
One --json run per plugin carries the verdict, the findings printed on failure and
gatingHooks; a human-mode run repeats the whole validation for the same findings.
```

## scripts/readability.sh

### Header pointer

```text
Why, limits, history: rationale/improvement-plan-2026-10-26.md § Before values (m2, 2026-10-26)
```

## scripts/remove-plugin.sh

### Header

```text
Remove a plugin (or fold its skills into a host plugin). Edits: the plugin dir, its
marketplace.json entry, the plugin's key in all three context-budget baselines, its
README table row and leaf counts, and — through one full generate.sh --write run —
the plugin-scout catalog and the README off-switch table. Under --merge-into it moves
the skill dirs to the host and drops the rest. It appends a scripts/removed-plugins.tsv
row and a marketplace.json renames entry; the successor is the host only under
--merge-into and only when the host registers no blocking hook (as that TSV's header
defines it) the removed plugin lacked, else null — a renames successor is installed
without asking. Command hooks compare by event, script basename and content hash, so
only an identical script cancels; prompt/agent hooks by event and definition; matchers
are ignored. A PreToolUse script counts when it contains permissionDecision or `exit 2`,
so a deny emitted only from a file it sources is missed; a command that does not resolve
to a readable file after quote-stripping and ${CLAUDE_PLUGIN_ROOT} substitution (a
`bash …` wrapper, unbraced $CLAUDE_PLUGIN_ROOT, an inline command, an empty one) counts
as blocking. The row's removed column is the run date (UTC): correct it to the deleting
commit's date if they differ. Its prose_match is `no`: flipping it to plug/moved/both,
which makes pc_removed_refs flag the name in prose, is a reviewed edit of the TSV.
Existing renames entries are append-only history and never edited; any that target the
removed plugin are printed. marketplace.json is validated and its new content built
before anything is deleted.
Does NOT edit skill-router's rules.tsv, other plugins' lane.tsv edges or smoke fixtures
(the report prints the first 40 word-match lines, which may name them), bump stack-scan's
plugin.json and CHANGELOG for the regenerated catalog, or, under --merge-into, bump the
host's plugin.json and CHANGELOG or re-baseline its context budget. Dry-run by default;
edits only with --apply. validate.sh is the recovery gate after a partial failure.

No bundle branches. The all-in bundle went 2026-08-31 and the four themed suites
2026-09-26, the day pc_plugin_dependencies started failing any plugin.json that
declares `dependencies` — so every plugin is a leaf and there is no bundle's dep
list, README row or member count left for this script to maintain.

  bash scripts/remove-plugin.sh <name> [--merge-into <host>] [--apply]
```

### blocking_hooks

```text
Prints one key per blocking hook registration, sorted: <Event>:<basename>:<hash> for a
command resolving to a readable file, <Event>:unresolved:<command> for any other
command, <Event>:<type>:<hash of the hook definition> for prompt/agent hooks.
```

### 4. baseline keys

```text
4. context-budget baseline keys — all three channels. Only the always-on file was
edited until 2026-09-26; the suite retirement had to strip the dynamic and activated
baselines by hand, and a stale key there is dead weight --update-baseline would
silently drop anyway.
```

### Leaf-count regex

```text
Same regex shape as scripts/validate.sh's leaf-count gate — both must see "all N
plugins", "all N leaf plugins" AND "N leaf plugins", or this script stops maintaining
the very lines that gate checks. The bare "all N plugins" expression cannot match the
leaf wording (" plugins" must follow the digits), which is the exact miss that once let
the count go stale under a gate written to catch it.
```

### Residual report filter

```text
Filter the plugin's own dir by full path, not --exclude-dir basename — after
--merge-into, the moved skill dir plugins/<host>/skills/<name>/ must still be
scanned or real residuals inside the merged skill body stay hidden. The ledger row and
the renames entries naming the plugin are dropped: this list is what a person rewrites,
and those are append-only history.
```

## scripts/run-evals.sh

### Header

```text
Maintainer command: run ONE plugin's eval suite against a no-plugin control arm under a
hard cost cap, and write a summary that is safe to commit under rationale/evals/.

  RUN_EVALS=1 bash scripts/run-evals.sh <plugin> [extra `claude plugin eval` args…]

WHY THIS EXISTS. Nothing in the repo ran `claude plugin eval` for real: scripts/eval-cases.sh
only LOADS suites. A hand run leaves its result under the gitignored plugins/<p>/evals/results/,
in a document full of prompts and absolute paths, so no run left a committable record, and
CLAUDE.md forbids stating a delta without its run count and vote spread. This fixes the
flags (control arm, cap, local report, output kept out of the plugin) and writes those
counts to a file that can be committed.

WHAT IT DOES. Refuses (exit 3, before any `claude` call) unless RUN_EVALS=1. Refuses (exit
64, also before any call) a missing plugin, one with no plugins/<p>/evals/, a non-numeric
cap, python3 without yaml, a suite with any case.yaml declaring `context.scaffold_script`
or not readable as a YAML mapping, and any extra argument off an ALLOW-list: `--runs`,
`--case`, `--model`, `--judge-model`, `--threshold` (one value each) and `--tag`,
`--allow-tools` (one or more values), each as `--flag v…` or `--flag=v`; a bare token is
accepted only as the value of the allowed flag before it. An allow-list because the CLI
keeps the last value of a repeated flag: a new or aliased flag would otherwise override a
fixed one (`--max-cost-usd`, `--json`…) or run code outside the sandbox (`--scaffold`,
`--allow-real-servers`, `--mocks off`) while the summary recorded the fixed value. Runs
  claude plugin eval ./plugins/<p> --ablation with-without --max-cost-usd <cap>
    --no-publish --trust-plugin --output-dir <tmp> --report <tmp>/report.html
    --json <tmp>/aggregate.json <extra…>
with cap = RUN_EVALS_MAX_COST_USD (default 5). Then writes
rationale/evals/<YYYY-MM-DD>-<HHMMSS>-<p>.json (UTC; dir overridable by RUN_EVALS_OUT_DIR)
and exits with the CLI's exit code — 0 pass, 1 below threshold or load error, 2 partial
(cost ceiling or auth), 130 interrupted. A serialized summary matching a home path or a
UUID (session-id shape) is refused: exit 65, nothing written. No result document from the
CLI means no summary. When the summariser fails after the CLI wrote a document, the temp
dir is kept, its document path is printed, and the script exits with the summariser's code.

FIELDS IT RELIES ON, as observed rather than documented: a `--max-cost-usd 0` load of
candor on CLI 2.1.285 (2026-09-30) wrote `cases: []` with no per-case run count anywhere,
`partial: true`, `partialReason: "cost_ceiling"`; completed documents from CLI 2.1.283
carry `cases[].runsPerCase` and a numeric `cases[].arms.{with,without}[].score`, neither
in the docs' field table. Read: `claudeVersion`, `costUsd`, `partial`, `partialReason`,
`cases[].name`, `cases[].runsPerCase`, `cases[].arms.*[].score`, `cases[].arms.*[].error`,
`cases[].aggregates.delta`. A run whose `error` is non-empty (the docs' field table: "why a
run ended abnormally, such as `timed out after 300s`") is counted in `errors` and
`completed` and left out of `scores` and `spread`; its numeric score, when it has one, is
kept apart in `erroredScores`. The spread's denominator is every run with no error, scored
or not; its numerator is the runs scoring 1 or more, whatever `--threshold` or `passed`
say, so an unscored run counts against the arm and shows as `scores` shorter than the
denominator. No document holding an errored run has been read: that shape is the docs', assumed.
Case files (plugins/<p>/evals/**/case.yaml: `name`, else the directory; `runs`; `tags`) are
read with PyYAML before the paid call. The summary's cases are the document's `cases[]`;
only a partial document, or one listing no cases, gains the case files it omits, 0
completed, and only those the `--case`/`--tag` filters select. The filters are applied as
CLI 2.1.285 applies them, measured by zero-cost loads 2026-09-30: `--case` (last one wins)
against the whole `name`, case-sensitive, `*` any run and `?` one character, every other
character literal (NOT fnmatch: `[n]amed-one` selects nothing); `--tag` accumulates across
repeats and selects a case carrying ANY of them; both together are ANDed. Planned runs per
arm: `--runs`, else the document's `runsPerCase`, else the case file's `runs`, else 3.
Nothing else is copied: no prompt, grader text, `error` string, path or trace id.

WHAT IT DOES NOT:
  - show a skill helped. A case whose `without` spread is n/n has no headroom: it is a
    regression guard and can never measure the skill (CLAUDE.md's ceiling rule).
  - separate a regression from a flake at fewer than three runs per arm. The summary
    carries the counts and per-arm spread so a delta quoted from it can carry them too.
  - tell an infrastructure error from one the plugin caused. The docs grade an errored run
    on what it produced and record a `max_turns` overrun as an error, so a run dropped from
    the spread may have earned its score: `erroredScores` holds it, and a reader who wants
    the spread over every graded run recomputes it from `scores` plus `erroredScores`.
    `delta` is the CLI's own figure, copied as written, so it can cover runs the spread
    beside it leaves out.
  - meter spend. `costUsd` is the CLI's list-price estimate, not plan usage, and the cap
    is checked before each run launches, so runs already in flight can pass it.
  - keep the HTML report or the full document after a summary is written; both leave with
    the temp dir, because they hold prompts, grader evidence and paths.
  - track a later CLI's filter rules; the ones above are one version's. A case.yaml the
    runner rejects on load is still planned in a partial record, and a prompt.md-shaped
    case (no case.yaml) is counted only if the document lists it.
  - run a suite that needs `--scaffold`. Without it a scaffolded case is paid for while
    scoring the repo root, so the suite is refused, whatever the filters select; the
    plugin README carries the manual command. A prompt.md case's frontmatter is not read.
  - catch a leak the regex does not match; the field whitelist is the real defence.

Standing: `recorded` — nothing runs it in CI. scripts/smoke/run-evals-tests.sh proves the
plumbing (refusal, flags, summary shape, a zero-cost real load), never a score.
```

## scripts/turn-cost.sh

### Header: WHY THIS EXISTS

```text
WHY THIS EXISTS. Every cost instrument in this repo meters BYTES:
context-budget.sh's three channels, pc_skill_budget, pc_budget_crowding, the
description linter, the listing channel. rationale/2026-08-31-token-cost-review.md
measured what those bytes are worth against real spend and found the whole
always-on surface is ~1% of a session, while 61.8% of the bill is cache reads —
context re-read every request. The term that actually moves that is how many
model requests a piece of work takes, and NOTHING here measures it. Same run:
task-runner-attributed context cost 19% of all measured spend across 464
requests, against a shipped byte surface worth ~$2.80 a session. A ~40:1 gap
between what a plugin ships and what its workflow costs, in the channel with no
instrument.
```

### Header: what the numbers mean, the limitation, the default scope

```text
WHAT THE NUMBERS DO AND DO NOT MEAN — read before quoting any of them:
  - This measures COST, NEVER VALUE. A plugin that turns one instruction into
    200 requests may be buying 200 requests of work you would otherwise have
    driven by hand. Nothing here can tell those apart, and this repo's one real
    ablation (rationale/eval-ablation-2026-08-20.md) measured zero delta in
    every arm. This is a denominator. It is not a verdict, and a high number is
    not a finding.
  - Attribution is INCOMPLETE and the script measures its own coverage on every
    run — see the coverage table it prints. On the machine this was written for,
    one Claude Code version accounted for 48.6% of all requests and emitted no
    attribution records at all. Unattributed cost is reported as its own row,
    never silently spread over the plugins.
  - Attribution also carries FORWARD, and turn blocks are delimited by user
    prompts, so a plugin keeps being charged across a block boundary into an
    instruction about something else. Per-plugin figures are UPPER BOUNDS, and
    the two errors compound.
  - SUBAGENT TURNS ARE INVISIBLE. No `isSidechain` record appeared in any
    transcript measured; subagent requests are billed and do not show up here.
    This systematically UNDER-counts exactly the orchestration-heavy plugins the
    instrument was built to look at. That is the biggest known hole in it.
  - Cost is ESTIMATED from a static price table (below), not read from a bill.
    Cache reads are priced per model (Sonnet 5.5 reads at 0.05x of input, not
    0.1x); writes are 1h 2x, 5m 1.25x. The TTL split is read per request from
    usage.cache_creation, because assuming the 1.25x default under-states a
    1h-TTL session's write channel by 60%.

HONEST LIMITATION, stated the way this repo's convention asks. It cannot see:
subagents (above); anything on another machine; sessions whose transcripts have
been deleted; and whether a turn was useful. It reports a per-plugin ratio only
once that plugin has --min-blocks turn blocks (default 10), because a $/block
figure at n=3 is noise wearing a table — the failure the retirement queue's
doctrine (now the --skills mode below) warns about. Below the threshold it prints the raw count and withholds
the ratio.

WHY IT DEFAULTS TO ALL PROJECTS: a plugin's turn cost appears where the plugin
is USED, which is essentially never this repo. (retirement-queue.sh, folded into
--skills here on 2026-08-31, defaulted to the current project and answered with
an empty table on every machine anyone ran it on.)
Scoped to the marketplace checkout it would measure authoring sessions and
report nothing about any plugin. Use --project to narrow.
```

### Value-taking flags

```text
Value-taking flags demand their value: `shift 2` with $#=1 does NOT shift in
bash — the loop re-read the same flag forever (100% CPU) when a flag was the
last argument. Checked, reported, exit 0: this script never fails a build,
and a hang is worse than either.
```

## scripts/validate.sh

### Header

```text
Validates cc-plugins-marketplace structure. Exits non-zero on first category of failure.
```

### Stray directories

```text
Scratch under plugins/ (plugins/design-studio/ once held only a hook's marker files and
drew three FAILs about a plugin that never existed): one message, and the listing,
README and plugin-table checks below skip it. Rule and misses: pc_stray_dirs' header.
A heredoc, not a pipe, so fail=1 and STRAY_DIRS survive.
```

### fm_structural and fm_linter

```text
The frontmatter checks in the next three loops are pc_frontmatter's, the same
function done-gate.sh runs per file. It prints a file's structural lines, then its
description-linter lines; validate.sh prints every file's structural lines before
any file's linter lines, so the structural loops park linter lines in FM_LINT for
the linter loop rather than calling it twice per file. A line fm_is_linter does not
recognise counts as structural: a reworded linter message moves earlier, never drops.
The skill budget skip also keys on the exact "missing frontmatter opener" and
"frontmatter not terminated" wording; rewording either re-enables the budget check.
```

### SKILL.md loop

```text
Every skills/<name>/ directory must contain SKILL.md with terminated frontmatter,
name: + description:, and a body within the 200-line ceiling (no floor).
`.claude/skills/*/` — the repo's tracked PROJECT skills, where the authoring
doctrine has lived since 2026-09-03 — is held to the same rules: a doctrine home
outside every gate would be the "recorded" tier pretending to be "gate".
Why trigger phrasing skips a `disable-model-invocation: true` skill: pc_frontmatter's header.
```

### Symlinked project skills

```text
A symlinked project skill is somebody else's file mounted here, not authored
in this repo; its budget and phrasing are theirs to keep. Only skills whose
bytes live here are gated. None is symlinked today: the last one, a vendored
476-line plugin-structure skill, duplicated authoring-plugins and was removed.
```

### plugin.json description linter

```text
plugin.json description linter (WARN, not err): the frontmatter cap above never
covered plugin manifests, which is how a 1039-char description shipped unseen
(craft-layer, trimmed 2026-08-11). Always-on cost is already metered by
context-budget.sh, so this warns on the CLARITY smell only — a description too
long to be an install decision. Promote to err only after the tail is clean.
```

### Jargon-leak and removed-artifact guards

```text
Jargon-leak guard (HARD): internal taskmaster process vocabulary — "card NN" /
"cards NN", "Finding #N", "smoke-test #N", "the backlog" — must not leak into
shipped plugin prose (today's craft-layer review scrubbed 8 such leaks no gate
saw). Scans every functional .md per plugin (SKILL.md, references/*.md, commands,
agents) via find — NOT a `**` glob (globstar is off in scripts/) — with
references/ INCLUDED (the 8 leaks lived there), PLUS the plugin-root docs
(README/CHANGELOG/ROADMAP) via shell glob, which never crosses `/` — root docs
previously escaped the scan entirely. Excludes the taskmaster + task-runner
plugins, where these are legitimate domain vocab. The `taskmaster-docs` PATH is a
legitimate working-dir ref in ~6 plugins and is deliberately NOT a pattern.

Removed-artifact guard (HARD), same file set: references to plugins/skills
removed or merged away in the W6.5 baseline sweep (typescript, vue2,
react-best-practices, the css-family skills, …) are dangling pointers the
/plugin:command check cannot see — ~10 plugins carried them undetected.
claude-api must be described as Claude Code's built-in/external skill, never as
a marketplace artifact.

The patterns themselves, the rescue lists, the <!-- jargon-ok --> /
<!-- removed-ok --> escapes and the honest-scope notes all live in
scripts/lib/plugin-checks.sh (pc_jargon, pc_removed_refs) — one source shared by
these gates and their smoke fixtures. Do not restate them here; two copies of a
matcher is a guarantee one goes stale.
```

### The jargon exemption

```text
The jargon exemption is theirs alone. Until 2026-09-17 this `continue` sat before
every check, so the two plugins that fan out the most were never walked by the
removed-ref, host-overlap or handoff gates — task-runner/commands/run.md carried a
<!-- host-ok --> nothing had read.
```

### Dispatch-binding gate

```text
Dispatch-binding gate (HARD). A shipped `agent(<args>)` sample that spawns an agent
this marketplace ships must bind it with `agentType`; without it `Workflow` spawns the
generic subagent and the agent's contract silently does not apply. Detector, guards and
honest scope live in pc_dispatch_binding (scripts/lib/plugin-checks.sh).

Its own loop, NOT the one above. When this was written that loop skipped taskmaster and
task-runner outright — the two plugins that fan out the most — and inheriting the skip
would have blinded this gate to its likeliest offender. The skip is jargon-only since
2026-09-17; the loop stays separate for its narrower file set (no plugin-root docs, no
project skills).
```

### /plugin:name resolves to a command or a skill

```text
A `/plugin:name` reference resolves to a command file OR a same-named
skill. Claude Code merged custom commands into skills — "A file at
.claude/commands/deploy.md and a skill at .claude/skills/deploy/SKILL.md
both create /deploy and work the same way"
(https://code.claude.com/docs/en/skills) — so a plugin that ships only the
skill still answers the slash command. Before 2026-08-20 this gate knew
only about commands/, which is why deleting three commands that merely
restated their identically-named skill produced 12 FAILs about references
that had never stopped working.
```

### /preserve:<name>

```text
/preserve:<name> is the template engine's preserve-block closer
(<!-- /preserve:NAME -->), not a plugin reference — see
scripts/lib/template-engine.sh merge_preserve_blocks.
```

### Doc location

```text
Plugins ship ONLY functional files. Task documentation, specs, and design/task
history live in taskmaster-docs/ (or a repo-level location outside plugins/) —
never inside a plugin. Allowed .md: README/CHANGELOG/ROADMAP at a plugin root,
a skill's SKILL.md and its references/, commands/, and agents/ — plus evals/,
which is functional despite being prose: `claude plugin eval` reads
`<plugin>/evals/**/prompt.md` and `graders/*.md` as the case definition, the same
way a skill reads references/. Added 2026-08-20 with the first four suites; a
design doc parked under evals/ is still a doc-location violation in spirit, and
nothing here can tell the two apart.
```

### README leaf-count honesty

```text
README leaf-count honesty. This USED TO ride on the `everything` bundle: the
check walked that bundle's dependencies, and the count check lived inside
`if [ -f "$EV" ]`. When `everything` was removed (2026-08-31 — 224
description-bearing artifacts against the host's ~15k-char skill listing meant
two thirds of it arrived name-only, nondeterministically; see
rationale/2026-08-31-token-cost-review.md), the count check would have died
with it, silently. It did not, because it was rehomed here first. Deleting an
artifact can delete a gate riding on it, and nothing warns you.

Every plugin is a leaf since 2026-09-26: the themed suites were retired and no
plugin may declare `dependencies` (pc_plugin_dependencies, below), so the count is
every plugin.json. It used to skip any manifest with a `dependencies` key — the
bundles — and that skip is gone rather than kept as dead code, because a skip for a
shape the build now rejects would be a second place to disagree about what a leaf is.
```

### Every leaf-count claim

```text
Matches "all N plugins" AND "all N leaf plugins". The optional-word form is
the point: the narrow original regex could not see README.md's actual wording
("all 72 leaf plugins"), so rc came back empty and the check passed vacuously
— shipping the exact 72-vs-69 drift it was written to catch. A missing count
is now an error too, not a silent pass.
Widened again 2026-09-15, same lesson one layer down: this checked only the
FIRST match and only the `all N …` wording, so README.md's opening line
("**27 leaf plugins**") was never covered. It carried 27 while the gated line
carried 26 — one file disagreeing with itself, and the gate reporting green.
Every leaf-count claim is now checked, not just the first one that parses.
```

### Stack-authoring-gap guard

```text
Stack-authoring-gap guard: a worker agent declaring `bestpractices-skill: <dir[,dir]>`
must name skill dirs that exist, and the delegation-contracts doctrine that
resolves+injects them must be present.
```

### Agent-routing

```text
Agent-routing: the tag vocabulary (task-cards), the implement-side map keys
(routing.md), and the verify-side map keys (reviewer-routing.md) must stay in sync,
and every reviewer-map RHS reference must resolve — drift/typos break routing silently.
```

### Crew reference check

```text
Crew reference check: crew.md (the --crew contract) must exist, be linked from the
task-execution SKILL, and every plugin:name it names must resolve — a dangling ref or a
lost link breaks the crew wiring silently. Mirrors the reviewer-routing RHS check; the
`-d plugins/$pl` guard skips line-number tokens (crew.md:44) and prose (model:opus).
```

### Chassis generated-header gate

```text
Chassis generated-header gate: every chassis-shaped file — commands/review.md,
commands/uninstall.md, commands/check.md, hooks/remind.sh — must EITHER carry the
generate.sh header OR be named by an optout entry in its plugin's .chassis.json
(object OR array form). Neither means the deterministic stamper never ran or was
bypassed — drift the regenerate-and-diff gate must catch.

The optout must name the file it exempts. The earlier test was
`any(.chassis=="optout")` over the WHOLE manifest, so ONE opt-out entry exempted
all four chassis-shaped kinds at once: api-design (docs-first) and build-vs-buy each hand-
maintain commands/check.md while generating hooks/remind.sh, and a hand-edit that
stripped the header off remind.sh would have been silently covered by check.md's
exemption. An unscoped optout is now an error, not a blanket.
```

### Chassis agent-file header gate

```text
Chassis agent-file header gate: every plugins/*/.chassis.json worker-agent object
that declares an agentFile must have that EXACT file carry the generated header —
keyed on the declared path only, never a plugins/*/agents/*.md glob, so hand-shaped
reviewer agents next to migrated engineers (web-dev, ui-ux, devops) are untouched.
```

### Banner over the description-parity gate (milestone ID dropped)

```text
---- W2-M2 governance gates ------------------------------------------------
```

### Description-parity gate

```text
Description-parity gate (hard): a plugin's marketplace.json .description must be
byte-identical to its plugin.json .description — a discovery listing that lies
about what a plugin does is a silent rot the chassis system cannot catch.
```

### rules.tsv resolution gate

```text
rules.tsv resolution gate (hard): every skill token the skill-router references —
rules.tsv column 3, prime.sh `add <skill> <plugin>` lines, and any literal skill
name in route.sh — must resolve to a real plugins/*/skills/<skill>/SKILL.md.
route.sh sources its skills from rules.tsv at runtime and carries no literals
post-W2-M1; the grep catches any that get re-introduced. Locks A1's phantom fix.
```

### rules.tsv overlap gate

```text
rules.tsv overlap gate (hard): two high-confidence glob rows sharing one
pattern must be stack_marker-discriminated or declared complementary via a
pairwise "# co-fire-ok:" directive — stack-exclusive pairs (vue2/vue3,
php/laravel) must never co-fire on a detectable stack.
```

### Reachability gate

```text
Reachability gate (hard): a row that CANNOT fire is worse than a missing row —
it reads as coverage. `**/routes/api.php` shipped for months matching nothing,
because route.sh basename-matches every pattern except the `**/dir/**` form.
The overlap and marker harnesses cannot see this class: a dead row collides
with nothing and reaches no marker.
```

### Col-4 owner

```text
Col-4 owner must be a plugin directory. rules.tsv:124 named a plugin folded
away weeks earlier; route.sh's installed-plugin filter suppressed the row and
nothing at author time read the column. Derivation: pc_rules_owner's header.
```

### Content-row co-firing

```text
Content-row co-firing, against a corpus of representative snippets. Content rows
never share a literal pattern, so the glob-axis equality test above is vacuous for
them; two different regexes matching one file is the real collision.
```

### Tool-fit check gate

```text
Tool-fit check gate (hard). route-prompt.sh injects a catalog it builds at runtime
from the installed plugins' command frontmatter, and hands the ROUTING JUDGMENT to
the model. Two properties are mechanically checkable and both are load-bearing:

  1. No literal command token in the hook. A hardcoded `/plugin:command` is a route
     the catalog never shows and nobody can audit — the same rule route.sh carries.
  2. No per-tool routing patterns. At most four prompt-matching greps (three
     narrowing refusals + the work-shaped gate); a fifth is a routing table growing
     back in shell, the mechanism this deliberately replaced.

What is NOT gated, stated plainly: which command the model picks. That is a
judgment with real variance — agent-graded, not gated. See the has-teeth
convention in CLAUDE.md; do not describe this check as guaranteeing a route.
Created by 7fc492d0; rule and misses: the pc_route_prompt_literals/_greps headers.
```

### No plugin may declare dependencies

```text
No plugin may declare `dependencies` (hard). Replaces the all-bundle dependency gate,
which proved every bundle's deps resolved: an update that ADDS a dependency does not
install it, and the plugin then fails to load — measured on CLI 2.1.283, 2026-09-26.
The measurement and the residuals are in pc_plugin_dependencies' header.
```

### CHANGELOG-parity gate

```text
CHANGELOG-parity gate (hard): the first `## [X.Y.Z]` heading in CHANGELOG.md must
equal the marketplace metadata.version — a released version with no matching
changelog top entry (or vice versa) is undocumented drift.
```

### Banner over the keywords gate (milestone ID dropped)

```text
---- W2-M5 keywords[] taxonomy gate --------------------------------------------
```

### keywords gate

```text
keywords gate (hard): scripts/taxonomy.txt is the controlled discovery vocabulary.
Every plugin.json must carry a non-empty keywords[] whose every element is a
taxonomy term. A missing/empty keywords[] or an off-vocab term fails the build —
the generated scout catalog (stack-scan's plugin-scout skill) and keyword-driven discovery rely on it.
Orphan taxonomy terms (declared but used by no plugin) are WARN only.
```

### Version-leverage stamp coverage

```text
Version-leverage stamp coverage (HARD, promoted from WARN on 2026-08-02).
rationale/stack-skill-baselines.md exempts ~20 stack plugins from the
baseline-redundancy loop on the promise that they encode version leverage rather
than idioms; check-doc-staleness.sh can only see that leverage decay where a
`> Last verified: YYYY-MM-DD — <url>` stamp exists, and until this morning not
one of those plugins carried one.

It shipped as a WARN because promoting it first would have forced a fabricated
provenance record onto nine plugins — a stamp asserts that someone checked the
content against that URL on that date, and writing nine unchecked ones would be
a lie in the one file whose entire purpose is provenance. The verification pass
has now run: every claimant's load-bearing version claim was checked against
upstream and stamped with the URL actually consulted, so the gate has teeth
without anyone having to trust it on faith.
```

### README-listing

```text
README-listing (HARD): every plugin must also be LISTED in the top-level
README.md plugin tables — a bolded `**name**` or `**[name](...)` row. Presence
of a per-plugin README is not discoverability; 9 plugins shipped invisible to
the catalog before this gate (2026-07-23).

TIGHTENED 2026-08-02: the previous form accepted the bolded name ANYWHERE in
the file, so a plugin mentioned once in a prose paragraph counted as catalogued
while appearing in no table a reader browses. The row must now actually be a
table row — a line starting `| **name**` or `| **[name](`.
```

### Empty-section gate

```text
Empty-section gate (HARD): a `###` heading followed by a table header and its
separator with ZERO data rows is a section that claims a category and lists
nothing. `### Automation & browser` sat empty from 2026-07-06 until this gate
landed, and every structural check in this repo passed it — an empty table is
well-formed markdown.
```

### Boost-preamble parity

```text
Boost-preamble parity (HARD): the four full taskmaster commands carry one
byte-identical boost preamble between the `boost-preamble:start/end` markers,
and every trigger token the ultra hook greps for is named inside that block —
the trigger logic exists twice (bash regex in hooks/ultra.sh + command prose)
and this gate keeps the two implementations from diverging silently.
taskmaster.md is NOT in the list: it is a thin alias of task.md (checked
below), which is how it stays in parity — by carrying nothing to drift.
```

### Alias-shape gate

```text
Alias-shape gate (HARD): taskmaster.md must stay a thin delegation to task.md.
It was a 105-line byte-copy kept in sync by the parity gate above; parity by
duplication was the bug, not the fix. Thin = delegates with $ARGUMENTS, names
commands/task.md, carries no preamble block of its own, stays under 25 lines.
```

### Lane declarations

```text
Every plugin declares, in its own plugins/<name>/lane.tsv, which territory each
of its artifacts owns, at which phase of the arc it may speak, the condition
that fires it, and who outranks it. The pc_lanes_* family reads those files by
glob (recount: `grep -c '^pc_lanes_[a-z_]*() {' scripts/lib/plugin-checks.sh`)
— there is deliberately no generated aggregate, because a concatenation would carry no
rule this glob does not and would add a chassis-drift surface for nothing.

THE ONE THAT CARRIES THE MISSION is pc_lanes_territory: it is the only
mechanical statement in this marketplace that two artifacts must not silently
claim the same job. The 8 reviewer-class agents live in 8 different plugins
with 8 distinct filenames, so every other gate here sees eight unrelated files
while the model picks between them from descriptions alone.

TIERS, per the has-teeth convention: agents and UserPromptSubmit/Stop hooks are
`gate`; commands and skills are `WARN` this run and are reported as a count,
not 200 lines. The format, the blessing shape, and the honest-scope residuals
all live in scripts/lib/plugin-checks.sh above pc_lanes_schema — one source
shared with scripts/smoke/lanes-tests.sh, which asserts these FAIL strings.
```

### Lane adjacency

```text
The territory gate above fires only on an exact `owns` collision, and the live
vocabulary is 1:1 with the claimed nouns, so it has never had a pair. Crowding is
the defect the probe actually priced (eight rivals on one territory: firing
100% → ~75%), and it is invisible to a string compare. WARN tier deliberately —
the derivation, the six live clusters and the FAIL flip are in the function's
header in scripts/lib/plugin-checks.sh.
```

### Deference edges

```text
A description that promises "defers X to <plugin>" must be backed by a
yields_to edge in the plugin's own lane.tsv; host-built-in and plugin-class
targets are skipped by design. Derivation: pc_deference_edges' header.
```

### Marker key

```text
Reading the context key is half the job; the value is normally an absolute PATH, so a
hook that pastes it into a filename writes to parents that do not exist and loses the
bound it claims to keep. pc_context_key cannot see the difference — both hooks mention
transcript_path. This is the half that can.
```

### Source of truth

```text
A SKILL that names a reference as SOURCE OF TRUTH for its figures must not carry
a figure that reference lacks. Converts a mirror the skill itself declared
"recorded — no gate checks the two agree" into one that is checked. Scope and
limits are stated ONCE, in pc_source_of_truth's own header, and pinned by
scripts/smoke/source-of-truth-tests.sh.
```

### Agent tool fit

```text
An agent told to do what its own tools: cannot (run git, hash, write a file) improvises:
creative-director invented its seed in three of three runs. What it reads, what it misses
and why it FAILs: pc_agent_tool_fit's header.
```

### Harness payload

```text
And the condition that let pc_marker_key's defect hide for a release: a harness
that only ever sends session_id grades the fallback branch, so the branch the host
actually takes is never executed. pc_marker_key gates the hook; this gates the
test that would have caught it.
```

### Prime coverage

```text
The SessionStart index must not claim a skill the documented manifest map never
sanctioned — that is how prime.sh came to assert tailwind on any React dependency.
...and, since 2026-09-22, the reverse: the map must not declare a repository signal
the probe never emits. WARN TIER for that direction only — the two it found are in
skill-router's hook, another hand than the one adding the check, and the forward
direction stays a FAIL. Derivation and the matcher blind spot: pc_prime_coverage's header.
```

### Hook timeout

```text
A hook runs inside the user's turn, so the plugin must say how long it may hold
it. Gates that a number EXISTS, not that it is right, and says nothing about
what a killed hook does — both residuals are stated in pc_hook_timeout's header.
```

### Command argument hint

```text
The slash-command menu shows `argument-hint` as the user types; without it a
command that reads $ARGUMENTS asks for input it never names. Derivation and
residuals: pc_command_arg_hint's header.
```

### Hook shebang

```text
The fail-open guarantee six hook headers assert in their own words, read back. FAIL
TIER as of 2026-09-22: all 11 offenders counted that day are fixed — eight were chassis
output and went with one line each in templates/reminder-hook.sh.tmpl and
templates/boost-hook.sh.tmpl, three (ui-ux and taskmaster preview-guard.sh, design-kit
unread-pick.sh) by hand. The check shipped at WARN for exactly as long as the tree
disagreed with it. `# env-shebang-ok: <reason>` is the escape for a host with no
/bin/bash; the residuals are in pc_hook_shebang's header.
```

### cwd validated

```text
A hook may not `mkdir -p` a path built from the payload's cwd without first proving
that directory still exists — the shape that rebuilt a deleted three-level project
tree to hold a state dir. FAIL tier: the live tree passes it as it lands. What it
cannot see (a cwd that exists but is not this project) is in pc_cwd_validated's header.
```

### State root

```text
A hook may not build state from `$cwd/.claude`: the payload cwd follows the model's
`cd`, so per-project state split into one `.claude/` dir per subdirectory, one-shots
re-fired, and task-runner's scope-lock read an empty directory (2026-09-25 session
review, finding 2). State goes through the shared cc_state_root block. FAIL tier.
```

### Off switch named

```text
The person who needs to know a guard has an off switch is the person it just refused.
WARN TIER THIS RUN — five hooks in four plugins fail it the moment it ships, and they
are other hands than the one adding the check. Per-message attribution is out of reach
for a static reader; that half is agent-graded, and pc_offswitch_named's header says so.
```

### Version stamp tail

```text
A skill that promises version pinning must leave check-doc-staleness.sh --live
something to compare: an npm:/composer:/pypi: tail on its stamp. WARN TIER THIS RUN
(two offenders, both other plugins'). It gates the TAIL, never its truth —
pc_version_stamp_tail's header.
```

### Plugin-root quoting

```text
A command or skill line that runs `${CLAUDE_PLUGIN_ROOT}/…` unquoted, by path or through an
interpreter, splits on a space in the install path; the host checks hooks.json for this, never
a command or skill. One FAIL per plugin.
```

### Budget crowding

```text
Corpus-level companion to the per-file SKILL budget: a ceiling authors write TO
stops being a ceiling, and no per-file check can see that. Ratchet, not
threshold — the reasoning is in pc_budget_crowding's header.
```

### Plugin corpus

```text
The third budget instrument: pc_skill_budget bounds one FILE, pc_budget_crowding
bounds the distribution of file lengths, and NEITHER can see a plugin that stays
under both while shipping a 100k-token prose corpus across a dozen skills. That
channel is unmetered everywhere else — context-budget.sh gates three channels and
CLAUDE.md says bodies loaded by a routing rule are "unmetered by nature". Prose
only (.md, generated files excluded): counting runtime assets read taskmaster at
70,664 against a real 36,037. Ratchet, not ceiling — reasoning in the header.
```

Editor's note (2026-10-28): that CLAUDE.md text now lives in `.claude/skills/repo-gates/SKILL.md` § `scripts/context-budget.sh` (m13).

### Lane vocabulary

```text
An `owns` noun must be declared in scripts/lane-vocabulary.txt, so inventing one is a
reviewed act rather than the invisible default. pc_lanes_vocabulary's header is candid
that the catch is social; the gate is only on the bookkeeping.
```

### Scout names

```text
The plugin-scout skill's suggestion tables are hand-written and feed `--yes`, which
INSTALLS what they name — so a name that outlived its plugin is an install command
against nothing. Repo root, not `plugins`: the live set comes from marketplace.json.
Column-scoped and liveness-only; both residuals are in pc_scout_names' header.
```

### Handoff resolution over plugin.json descriptions

```text
Handoff resolution over plugin.json DESCRIPTIONS. Ten of them carry "Defers X to Y"
claims — the densest ownership statements the marketplace ships, and the only ones a
USER reads before installing. They were the one surface pc_handoff_refs never scanned,
so a rename could orphan a user-facing deference claim silently.
Only this check, not the three siblings in the loop above: pc_removed_refs and
pc_host_overlap read prose intent and would misfire on a description that legitimately
names a removed plugin or a host skill.
```

### Role-floor registry gate

```text
role-floors.md rows must agree with agent frontmatter, and every agent pinning a
real tier must be CLASSIFIED: either a registry row (floored) or `floor: none`
plus a `floor-reason:` (deliberately unfloored). The nine FAIL strings pc_role_floors
emits are frozen — scripts/smoke/validate-fixtures/role-floors-check.sh asserts each one.
err() only, never exit ($fail governs the tail); a heredoc, not a pipe, so fail=1
survives the loop. Parse rules live in pc_role_floors' header.
```

### No session tooling state inside a plugin

```text
A plugin ships to users, so anything tracked under it is distributed. Local
Claude Code state under a `.claude/` dir is per-session
and per-machine and must never be part of that. The root .gitignore rule is
anchored to the repo root, so nested `.claude/` dirs slipped through unnoticed
until they were already committed; this is the check that would have caught it.
```

### One severity vocabulary

```text
Every finding-emitting command and reviewer agent sorts on ONE scale —
critical/high/medium/low — so fan-in output merges without translation. Four
scales coexisted (blocker/major/minor, moderate, blockers-then-minors, none),
which made "Apply critical+high only" and "Fix blockers only" non-interoperable
on the same diff. This bans the divergent FORMAT-DEFINITION shapes, not the
words: prose like "a wrong mental model is the real blocker" stays legal.
taskmaster's spec-adversary is exempt — its blocker/major/minor grades SPEC
HOLES inside a closed pipeline, never code findings a fan-in merges.
```

### Dated-fact staleness report

```text
Files that assert an observed fact about the world carry `Last verified: <date>`.
A date nothing reads is a convention that dies quietly, so this reads them.
WARN-ONLY BY DESIGN: a fact does not become wrong on a schedule, and a
time-based failure would break CI on a quiet repo with no defect to fix.
```
