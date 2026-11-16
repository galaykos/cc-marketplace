# Verify-side reviewer routing

Which reviewer(s) a card gets after its verify passes: a tag-routed reviewer ADDED to the
baseline pass, never removing one. Tags as in `references/routing.md`; serial only (§ Tracks).

## The baseline reviewer pass

Four baseline reviewers, each condition-gated:

1. `code-review:code-reviewer` — **always**, on the diff (baseline correctness + smells).
2. `ui-ux:ui-ux-reviewer` — **diff-content gate:** when the diff touches UI files.
3. `code-architecture:architecture-reviewer` — **diff-content gate:** structural diffs.
4. `security:security-engineer` under a review-only contract — **diff-content gate:** auth /
   input / dependency diffs. Probes and scratch only under `$TMPDIR`, no write in the repo,
   findings in the return format below, `security:security-review` primed. Not code-reviewer
   told to "also do security": its probes found SSRF and XSS bypasses a read-only review
   missed. No security-engineer: that skill, inline.

The diff-content gates fire on their **file conditions regardless of the `Agent:` tag** —
so a `backend` card that adds an auth check still gets the security gate. A markdown-only or
test-only card diff gets `code-reviewer` alone, at `effort: high` where the dispatch can set
effort (`Workflow`), and no architecture or ui-ux pass.

## Resolution map

Tag → the domain reviewer the card's `Agent:` tag ADDS. The vocab-sync parser reads only
the **tag key** (the field before `->`); the RHS is descriptive.

```
frontend      -> web-dev:frontend-reviewer + prime {card Skills-to-apply}
ui-ux         -> ui-ux:ui-ux-reviewer + prime {card Skills-to-apply}
devops        -> devops:devops-reviewer + prime {card Skills-to-apply} + devops:devops-practices
generic       -> code-review:code-reviewer
database      -> code-review:code-reviewer + prime {card Skills-to-apply} + database:sql-best-practices
backend       -> code-review:code-reviewer + prime {card Skills-to-apply} + resilience:resilience-design
api           -> code-review:code-reviewer + prime {card Skills-to-apply} + api-design:api-design + resilience:resilience-design
security      -> security:security-engineer (review-only) + prime {card Skills-to-apply} + security:security-review
testing       -> code-review:code-reviewer + prime {card Skills-to-apply} + testing:testing-best-practices
performance   -> code-review:code-reviewer + prime {card Skills-to-apply} + resilience:performance-tuning
observability -> code-review:code-reviewer + prime {card Skills-to-apply} + resilience:observability-design
asset         -> code-review:code-reviewer + prime {card Skills-to-apply}
```

`ui-ux:a11y-audit` is preloaded by those two agents (ui-ux ≥0.26.3, web-dev ≥0.9.3); prime it
only for other reviewers — a `frontend`/`ui-ux` card falling back to `code-reviewer`, or an older install.

## Priming (the orchestrator primes every routed reviewer)

Reviewer agents have no Skill tool and cannot self-load a rubric, so the **orchestrator**
injects it. For each named skill, Read its installed `SKILL.md` and paste a
**reviewer-phrased** inject into the dispatch prompt:

> "Read `<abs-path>` before reviewing; treat it as the authoritative review rubric for
> this dispatch."

For a gap-tag `code-reviewer` dispatch, also inject:

> "For this dispatch you ARE the domain reviewer — apply the primed rubric; do not defer
> framework detail to a per-stack review."

**Coverage marker** — every reviewer dispatch prompt opens with one line naming the card:

> `RV-CARD: <card id>`

`hooks/rv-observe.sh` records each dispatch carrying it; the completion gate counts those
records against done cards. A dispatch omitting it is uncounted, so the run blocks at
completion rather than passing silently — deliberately.

**Diff delivery** — reviewers hold Read, Grep and Glob: never tell one to run git. Before each
`RV-CARD` dispatch run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/review-diff.sh" --card <id> --base
<HEAD before the card> <card files>`; it writes `.cc-artifacts/task-runner/rv/diff-<id>.patch` (diff,
untracked files, blame of the changed lines). Name that path in the prompt, with "cite line
numbers from the working file, not the patch". Standing: agent-graded.

**Compressed-return contract** — every reviewer dispatch prompt ALSO demands a compressed
return (delegation-contracts § Compressed returns), injected verbatim:

> "Return findings most severe first, ONE line each:
> `file:line — severity(critical|high|medium|low) — problem — fix`. List every critical
> and high; medium/low past the tenth may collapse into one final `+N more (medium/low)` line.
> A medium that is duplicated code or drift from the repo's conventions opens its problem
> with `[duplication]` or `[convention]`.
> No prose introductions, no summary of the summary. Your final message is data for the
> orchestrator, not prose for a human."

**Card-criteria inject** — every reviewer dispatch ALSO carries the card's own bar,
right after `RV-CARD`: paste the card's success criteria (or, when the card has none,
its `Verify:` line) plus this instruction, verbatim:

> "Judge the diff against THESE criteria, not just general quality. Your return must
> open with one line per criterion — `criterion — met | not met | not checkable from
> the diff — <one-line reason>` — before any findings. A return of 'no findings'
> without the per-criterion lines is an unfinished review and will be re-dispatched."

This is what makes a silent reviewer distinguishable from a clean diff: "no findings"
now asserts "each criterion checked", not "nothing jumped out".

**Card-contract inject (contract first)** — when the card carries `<invariant>`, `<reuse>` or
`<interface>` lines (taskmaster 0.63.0 cards), paste them verbatim after the criteria with this
instruction, verbatim:

> "Check the card's contract before anything else. One line per `<invariant>`:
> `<id> — kept | broken — <path:line>`. A broken invariant is high. A new symbol written
> beside a `<reuse>` symbol instead of extending it, or a helper that repeats one you can
> find by grep, is a `[duplication]` medium. An `<interface>` whose shape the diff changed
> is high. Then review the rest of the diff as usual."

Reviews of two real runs found the largest share of bugs in contracts between cards and in
code rewritten beside a sibling's helper; a free hunt reached them late or not at all.
**Blocking mediums:** a `[duplication]` or `[convention]` medium goes back into the card's fix
loop like a high, on the same three-cycle ceiling; other mediums and lows go to the backlog.
A card without contract lines gets the criteria inject alone. Standing: agent-graded.

**Bound:** inject the card's `<skill>` names (deduped) + at most one agnostic domain
skill from the map. The sentinel `<skill name="none"/>` (or an absent element)
resolves to **zero** priming skills — no log. A named skill that is absent is omitted and
**logged in the run report**. If a reviewer ends with **zero** domain grounding (every
priming skill missed, or a real reviewer agent whose rubric is absent), flag
*"review had no domain grounding"* in the run report — do not pass silently.

## The augmented pass (per card, after ANY successful verification)

Runs after the card's verification passes — a command OR a recorded manual check
(`SKILL.md`'s manual-check rule), so UI/visual cards without a runnable command are still reviewed.

1. **Baseline pass:** `code-reviewer` + whichever diff-content gates match the
   diff (ui-ux / architecture / security).
2. **Tag route:** add the card's tag reviewer (map above), primed per § Priming.
3. **Dedup over (agent + rubric):** never run the same review twice.
   - A real reviewer agent is never dispatched twice (e.g. a `ui-ux` card whose diff also
     trips the ui-ux gate → one `ui-ux-reviewer`).
   - A `security` card's tag route IS the security gate: one review-only `security-engineer`.
4. **Fallback:** a mapped agent/skill that is absent → plain `code-reviewer`; logged in
   the run report (matching `routing.md`'s downgrade log).
5. **Concurrent dispatch — BASELINE, not `--crew`-gated:** the deduped read-only reviewer
   set is dispatched as **one concurrent batch** over the card diff (reads parallelize
   freely). A reviewer holding `Bash` (e.g. `devops:devops-reviewer`: `Read, Grep, Bash`)
   is **excluded from the batch and run serially** — it can write build artifacts into
   the shared tree, so it never runs concurrently; that includes `security-engineer`.
   The `security:security-review` skill, when it stands in, runs inline in the
   orchestrator after the batch joins.
6. **Severity** (one scale, code-review's): **critical/high** → re-enter the existing
   **3-cycle fix loop** (`SKILL.md`'s fix-loop rule);
   **medium/low** → the backlog, except accessibility findings and deferrals
   to `/ui-ux:audit`, which close in the run (§ UI diffs). In the fix loop the runner applies fixes
   (or re-dispatches the builder), re-runs verify, then re-reviews. A finding that names a
   mechanism (a middleware, a cache-key rule) first greps the run's diff for siblings.
7. **Ultra:** routed reviewers inherit the `Ultra:` marker model override (`SKILL.md` § Extreme Boost).

A card whose `<agent>` tag and `<skill>` names imply different stacks is **not** a
conflict — inject both the tag's agnostic domain skill and the card's stack skills; they
are complementary.

## Milestone review: one cross-card pass

When a milestone's full suite is green (task-execution § Milestone close), the orchestrator runs
ONE `/code-review:review <milestone base>..HEAD` (Skill tool) before the next milestone starts,
with the spec's `## Shared state & invariants` table pasted and this lens: each invariant held
across every card that touches it, a state with no exit, a second writer, a helper duplicated
between cards, an `<interface>` its consumer reads differently. Per-card passes cannot see
these. Its critical/high findings, and its `[duplication]`/`[convention]` mediums, go through
the bounded fix loop on the card that owns the code; the fixes' verify commands re-run, and
there is no second hunting pass. Other mediums go to the backlog. A skip needs the user's
approval and `scripts/review-skip.sh --card milestone-<n> --reason "<why>"`. An index without
milestones gets none: the run-close range review (`commands/run.md` step 4) is its one
cross-card pass. Standing: agent-graded; no record counts milestone reviews.

## UI diffs: nothing deferred leaves the run

On a UI diff (why: `rationale/2026-09-26-task-runner-prose-derivations.md`):

- **An accessibility deferral closes IN the run, whatever its severity.** At group close,
  send the group's deferrals to ONE `ui-ux:a11y-engineer` dispatch (else the card's
  worker), routed per `routing.md`, before the UI walk (`ui-walk.md`). The alternative is
  `review-skip.sh --card <id> --reason "a11y deferred: <item> — <why>"`. A card holds one
  record, and a second call replaces the first.
- **`ui-ux-reviewer` is on every directly-dispatched UI card** (gate 2). No other reviewer
  stands in for it. A UI card reviewed without it gets `--exempt no-reviewer-installed` or
  `--reason "<why>"`.

Standing: the ui-ux-reviewer rule is a **gate** with candor installed. `rv-observe.sh` records
each `RV-CARD` dispatch's agent type, and clause 4 blocks the close while a card whose
`diff-<card>.patch` names a `.tsx`, `.jsx`, `.vue`, `.svelte`, stylesheet or `.blade.php` file
has neither that record nor a skip. A card with no patch file is not seen. The a11y rule is
**recorded**.

## Tracks

Reviewer routing applies to serial `/task-runner:run` and to the **serial non-eligible
milestones** of a `--tracks` run. A card executed **inside a parallel-group/track leaf gets no
reviewer pass** (routed or baseline) — a track-worker is a leaf and cannot dispatch
reviewers.

**Record every such card**: `scripts/review-skip.sh --card <id> --exempt leaf`. The
completion gate counts reviewer records against done cards, so a leaf card with neither a
dispatch nor an exemption blocks the stop.

## Batch carve-out

A **batch** (`references/routing.md` § Batch dispatch, item 6) is **exempt from the leaf
rule above**: it *returns* to the main runner, which runs the full augmented reviewer pass on
**each batched card's diff** — exactly the review its inline counterpart would get.

## Role-tier floor

**Role-tier floor — applies boosted or NOT:** an agent with a row in delegation-contracts
`references/role-floors.md` dispatches at `max(marker tier if present ELSE the session model,
its floor)` — never below the session model; a floor is a MINIMUM, so an agent already above
it keeps its tier. Agents with no row are unfloored and unchanged (omit `model:`). A registry
miss → omit `model:` and log `role-floors.md unresolved — floors not applied` in the run report.
