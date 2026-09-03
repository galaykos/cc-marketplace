---
description: Review any diff for bugs and smells, fanning in every installed stack review — severity-sorted one-line findings; never run the per-stack commands separately.
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

Standing of the ratchet: `unenforceable` as a gate against the model itself —
`--update-baseline` is runnable by any session, so the line can be reset by the
same session that crossed it. Never run `--update-baseline` to make a red debt
report green; growth is accepted by the user, not by the reviewer that caused it.

Triage before the deep read: a trivial, single-file, or purely mechanical change
earns a one-line verdict — state it and stop. Take the full pass below when the change
touches correctness-sensitive code (auth, data, migrations, concurrency), OR spans
more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
changed).

Stack fan-in — one pass, no duplicate reviews: from the changed files' types and
manifests, list every matching best-practice skill (`.ts`/`.tsx`/`.jsx`/`.vue` →
no language plugin, the baseline covers language-level review; web-dev's
react-native and vite skills per their manifest markers; markup/utility classes touched → the matching ui-ux stack
skill + a11y-audit; `.php`/`.blade.php` → laravel per composer.json;
`next.config.*`/`app/` routes → web-dev's nextjs skill; `.sql`/migrations → database's sql skill, plus its
mariadb skill when that engine is detected). Load each skill whose plugin IS installed and apply it inside the
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
5. History pass, when the change edits or removes existing lines: `git log -L` or
   `git blame` on the touched hunks. A line added by a commit whose subject names a
   bug, a workaround, or an incident is a line the diff must not undo without saying
   why — report the reversal with the commit it reverts. Skip this pass for
   additions-only diffs.

Output rules:

- One line per finding: `path:line — severity — problem — fix`.
  Severities: `critical` (wrong behavior/data loss), `high` (bug-prone or
  misleading), `medium` (smell/convention), `low` (nit). Sort by severity,
  critical first — the marketplace-wide scale the chassis reviews use, so
  fan-in output merges with theirs without translation.
- No praise, no restating the diff, no findings on unchanged lines.
- **Also emit through `ReportFindings` when that tool is available.** This command
  is the active code-review instruction the tool's own usage rule waits for, so
  the condition is met here. Emit once, after the self-refute pass, with the
  surviving findings ranked most-severe first (an empty array when none survived),
  and keep the prose lines as well — the prose is what the stack fan-in merges on,
  and dropping it would break every plugin that reads this format. Map the
  marketplace scale onto the tool's fields: `category` takes the kebab-case kind
  (`correctness`, `simplification`, `efficiency`, `test-coverage`), `verdict` is
  `CONFIRMED` for anything re-read or re-run and `PLAUSIBLE` for the rest, and
  `failure_scenario` carries the concrete inputs-to-wrong-output line rather than a
  restatement of the summary. When the tool is absent, prose only — nothing else
  about this command changes.
- Defer instead of duplicating. The fan-in covers two axes:
  - **Stack axis** — idiom detail is already loaded inline when the plugin is
    installed; when absent, name the plugin in the closing line rather than
    guessing its idioms.
  - **Concern axis** — three plugins claim things step 2 also claims. When one is
    installed, IT owns that finding and this review does not duplicate it:
    `resilience` (missing timeouts, unsafe retries, absent degradation paths;
    empty/over-broad catches, swallowed exceptions, missing cause chains;
    check-then-act races, retry idempotency, unguarded parallel writes),
    `resilience` also owns observability (silent catch blocks, correlation IDs, secrets in logs) and performance,
    this plugin's own `comment-discipline` skill (comment volume and placement).
    Report the finding once and name the owner; when none is installed, this
    review keeps it. The swallowed catch alone had four claimants.
  - Structural/YAGNI → `/code-architecture:yagni` or the architecture-reviewer
    agent; security-deep issues → `/security:review`.

Before the verdict, state the coverage: `Checked: …` and `Not checked: … (why)` so it
is explicit what was covered, what was clean, and what was skipped — not only what
broke. Then run one adversarial self-refute pass over every `critical` and `high`
finding; if a finding does not survive it, drop or downgrade it with a note. The
refutation checklist is the false-positive taxonomy — a finding matching any row is
dropped, not downgraded:

- pre-existing: the problem is on a line the diff did not touch, or existed before it
- silenced: the code carries a lint-ignore / suppression comment for exactly this
- tooling-caught: a linter, type-checker, compiler, or the test suite would report it
  (missing import, type error, formatting) — CI runs those; this review does not
- intentional: a behaviour change that is the point of the diff, not a side effect
- a nit a senior reviewer would not raise, or a general-quality wish (more tests,
  more docs) that no project rule asks for
- a stylistic call not stated in CLAUDE.md or the surrounding file — a preference,
  not a convention

Close with a one-line verdict: merge-ready, merge-after-criticals, or rework.

After the verdict, if findings exist, offer the next step as a selectable choice
(AskUserQuestion): "Fix all findings" / "Apply critical+high only" / "Report only". On an
apply pick, dispatch the finding list down the static chain
`task-runner:task-executor if installed → inline` — never leave the user to retype
findings, and never apply a list of this size inline when a scope-locked executor
with its own verify-fix loop is available. This plugin ships a REVIEWER, not a
worker, so `task-executor` is the head of the chain rather than its second rung.
Headless: verdict only.
