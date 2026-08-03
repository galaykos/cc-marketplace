---
description: Review a diff, branch, or path for correctness bugs, code smells, and convention drift — severity-sorted one-line findings; loads every installed matching stack skill in one pass.
---

Review the code change in $ARGUMENTS. Resolve scope in this order:

1. If $ARGUMENTS names a path, PR number, or branch — review that.
2. Else if staged changes exist (`git diff --cached --stat`) — review staged.
3. Else review the working tree against the default branch
   (`git diff $(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD~1)`).
4. Nothing to review — say so and stop.

**Debt lane** (`/code-review:review --debt`, or on request): instead of the diff
review, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/debt-scan.sh --dir . --age` and
report the table it prints. Five categories — suppressions, skipped tests, bare
markers, deprecated-symbol references, feature flags — counted, compared against
`.claude/debt-baseline.json`, with `--age` resolving first-seen dates by git
pickaxe. Two things to say and neither is the count: which categories GREW, and
which markers are oldest. "340 TODOs" is a number nobody acts on; "11 older than
two years, 3 of them in payments" is a decision. If no baseline exists, say that
`--update-baseline` starts the ratchet and that the first run only establishes a
line to hold — do not present the initial numbers as findings.

Triage before the deep read: a trivial, single-file, or purely mechanical change
earns a one-line verdict — state it and stop. Take the full pass below when the change
touches correctness-sensitive code (auth, data, migrations, concurrency), OR spans
more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
changed).

Stack fan-in — one pass, no duplicate reviews: from the changed files' types and
manifests, list every matching best-practice skill (`.ts`/`.tsx` → no language
plugin, the baseline covers language-level review; `.tsx`/`.jsx` with react in
the manifest → react (server-state only); markup/utility classes touched → the
matching ui-ux stack skill + a11y-audit; `.php`/`.blade.php` → php, plus
laravel/livewire per composer.json; `.vue` → vue3; `.sql`/migrations → sql + the
engine skill). Load each skill whose plugin IS installed and apply it inside the
single pass below — never tell the user to run the per-stack review commands
separately; this command is the fan-in for the overlapping review surfaces. Name
relevant-but-uninstalled plugins in one closing line instead.

Then:

1. Read every changed hunk plus enough surrounding code to judge behavior —
   never review a hunk in isolation when it calls or is called by nearby code.
2. Correctness pass: logic errors, off-by-one, null/undefined paths, error
   handling gaps, race conditions, resource leaks, wrong boundary conditions.
3. Smell pass: apply the code-smells skill catalog to the changed code only —
   pre-existing smells outside the diff get one summary note, not findings.
4. Convention pass: naming, structure, and idiom drift versus the surrounding
   file and the project's stated conventions (CLAUDE.md, linters, existing code).

Output rules:

- One line per finding: `path:line — severity — problem — fix`.
  Severities: `critical` (wrong behavior/data loss), `high` (bug-prone or
  misleading), `medium` (smell/convention), `low` (nit). Sort by severity,
  critical first — the marketplace-wide scale the chassis reviews use, so
  fan-in output merges with theirs without translation.
- No praise, no restating the diff, no findings on unchanged lines.
- Defer instead of duplicating. The fan-in covers two axes:
  - **Stack axis** — idiom detail is already loaded inline when the plugin is
    installed; when absent, name the plugin in the closing line rather than
    guessing its idioms.
  - **Concern axis** — three plugins claim things step 2 also claims. When one is
    installed, IT owns that finding and this review does not duplicate it:
    `resilience` (missing timeouts, unsafe retries, absent degradation paths;
    empty/over-broad catches, swallowed exceptions, missing cause chains;
    check-then-act races, retry idempotency, unguarded parallel writes),
    `observability` (silent catch blocks, correlation IDs, secrets in logs),
    `comment-discipline` (comment volume and placement).
    Report the finding once and name the owner; when none is installed, this
    review keeps it. The swallowed catch alone had four claimants.
  - Structural/YAGNI → `/code-architecture:yagni` or the architecture-reviewer
    agent; security-deep issues → `/security:review`.

Before the verdict, state the coverage: `Checked: …` and `Not checked: … (why)` so it
is explicit what was covered, what was clean, and what was skipped — not only what
broke. Then run one adversarial self-refute pass over every `critical` finding; if a
finding does not survive it, drop or downgrade it with a note.

Close with a one-line verdict: merge-ready, merge-after-criticals, or rework.

After the verdict, if findings exist, offer the next step as a selectable choice
(AskUserQuestion): "Fix all findings" / "Apply critical+high only" / "Report only". On an
apply pick, dispatch the finding list down the static chain
`task-runner:task-executor if installed → inline` — never leave the user to retype
findings, and never apply a list of this size inline when a scope-locked executor
with its own verify-fix loop is available. This plugin ships a REVIEWER, not a
worker, so `task-executor` is the head of the chain rather than its second rung.

Prime that dispatch. `task-executor` has no `Skill` tool AND declares no
`bestpractices-skill:` frontmatter, so unlike a stack worker it has nothing to resolve —
and a fix list is not a task card, so nothing else names its rubric either. You already
loaded the matching stack skills to produce these findings: inject one
`Read <abs-path> — supplementary` line per skill you actually loaded, so the executor
applies the same rubric the review was judged against rather than recalled convention.
The label is not optional: each names a skill outside the head's (empty) frontmatter, and
a worker carrying a refusal clause discards an unlabelled outside path unread. Name any skill you
loaded whose file you could not resolve. Doctrine:
`orchestration:delegation-contracts` § Skill priming.
Headless: verdict only.
