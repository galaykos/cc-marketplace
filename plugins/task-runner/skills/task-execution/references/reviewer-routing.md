# Verify-side reviewer routing

How the runner picks the reviewer(s) for a card after its verification passes. This
**augments** the existing reviewer pass — it never removes a reviewer. Mirror of the
implement-side `references/routing.md`; reuses the same closed 10-tag vocabulary
(`taskmaster/skills/task-cards/references/agent-tags.md`). Applies to **serial**
execution only (see § Tracks).

## The existing reviewer pass (preserved)

Four reviewers already run, each condition-gated — all kept:

1. `code-review:code-reviewer` — **always**, on the diff (baseline correctness + smells).
2. `ui-ux:ui-ux-reviewer` — **diff-content gate:** when the diff touches UI files.
3. `code-architecture:architecture-reviewer` — **diff-content gate:** structural diffs.
4. `security:security-review` — **diff-content gate:** auth / input / dependency diffs
   (a skill, no agent).

The diff-content gates fire on their **file conditions regardless of the `Agent:` tag** —
so a `backend` card that adds an auth check still gets the security gate.

## Resolution map

Tag → the domain reviewer the card's `Agent:` tag ADDS. The vocab-sync parser reads only
the **tag key** (the field before `->`); the RHS is descriptive.

```
frontend      -> web-dev:frontend-reviewer + prime {card Skills-to-apply}
ui-ux         -> ui-ux:ui-ux-reviewer + prime {card Skills-to-apply}
devops        -> devops:devops-reviewer + prime {card Skills-to-apply} + devops:devops-practices
generic       -> code-review:code-reviewer
database      -> code-review:code-reviewer + prime {card Skills-to-apply} + database:database-design
backend       -> code-review:code-reviewer + prime {card Skills-to-apply}
api           -> code-review:code-reviewer + prime {card Skills-to-apply} + api-design:api-design
security      -> code-review:code-reviewer + prime {card Skills-to-apply} + security:security-review
testing       -> code-review:code-reviewer + prime {card Skills-to-apply} + testing:testing-best-practices
performance   -> code-review:code-reviewer + prime {card Skills-to-apply} + performance:performance-tuning
observability -> code-review:code-reviewer + prime {card Skills-to-apply} + observability:observability-design
```

## Priming (the orchestrator primes every routed reviewer)

Reviewer agents have no Skill tool and cannot self-load a rubric, so the **orchestrator**
injects it. For each named skill, Read its installed `SKILL.md` and paste a
**reviewer-phrased** inject into the dispatch prompt:

> "Read `<abs-path>` before reviewing; treat it as the authoritative review rubric for
> this dispatch."

For a gap-tag `code-reviewer` dispatch, also inject:

> "For this dispatch you ARE the domain reviewer — apply the primed rubric; do not defer
> framework detail to a per-stack review."

**Compressed-return contract** — every reviewer dispatch prompt ALSO demands a compressed
return (delegation-contracts § Compressed returns), injected verbatim:

> "Return AT MOST 10 findings, most severe first, ONE line each:
> `file:line — severity(blocker|major|minor) — problem — fix`. No prose introductions, no
> summary of the summary; findings past the cap collapse into one final `+N more (minor)`
> line. Your final message is data for the orchestrator, not prose for a human."

**Bound:** inject the card's `Skills to apply` (deduped) + at most one agnostic domain
skill from the map. The sentinel `none detected` (or an absent `Skills to apply` line)
resolves to **zero** priming skills — no log. A named skill that is absent is omitted and
**logged in the run report**. If a reviewer ends with **zero** domain grounding (every
priming skill missed, or a real reviewer agent whose rubric is absent), flag
*"review had no domain grounding"* in the run report — do not pass silently.

## The augmented pass (per card, after ANY successful verification)

Runs after the card's verification passes — a command OR a recorded manual check
(`SKILL.md:139`), so UI/visual cards without a runnable command are still reviewed.

1. **Existing pass:** baseline `code-reviewer` + whichever diff-content gates match the
   diff (ui-ux / architecture / security).
2. **Tag route:** add the card's tag reviewer (map above), primed per § Priming.
3. **Dedup over (agent + rubric):** never run the same review twice.
   - A real reviewer agent is never dispatched twice (e.g. a `ui-ux` card whose diff also
     trips the ui-ux gate → one `ui-ux-reviewer`).
   - When the `security` tag primes `security:security-review`, **suppress** the baseline
     security gate (the tag route subsumes it).
4. **Fallback:** a mapped agent/skill that is absent → plain `code-reviewer`; logged in
   the run report (matching `routing.md`'s downgrade log).
5. **Concurrent dispatch — BASELINE, not `--crew`-gated:** the deduped read-only reviewer
   set is dispatched as **one concurrent batch** over the card diff (reads parallelize
   freely). Any reviewer that holds the `Bash` tool (e.g. `devops:devops-reviewer`, tools
   `Read, Grep, Bash`) is **excluded from the batch and run serially** — a Bash reviewer
   can write build artifacts into the shared tree, so it must not run concurrently with
   anything. The `security:security-review` **skill** (no agent) runs inline in the
   orchestrator after the batch joins.
6. **Severity normalization** (routed reviewers use varying scales): **critical/high** or
   **blocker/major** → re-enter the existing **3-cycle fix loop** (`SKILL.md:82-84`);
   **medium/low** or **minor** → the backlog. The fix loop itself is unchanged: the
   runner applies fixes (or re-dispatches the builder), re-runs verify, then re-reviews.
7. **Ultra:** routed reviewers inherit the `Ultra:` marker model override (`SKILL.md:64-70`).

A card whose `Agent:` tag and `Skills to apply` imply different stacks is **not** a
conflict — inject both the tag's agnostic domain skill and the card's stack skills; they
are complementary.

## Tracks

Reviewer routing applies to serial `/task-runner:run` and to the **serial non-eligible
milestones** of a `--tracks` run. A card executed **inside a parallel-group/track leaf gets no
reviewer pass** (routed or baseline) — a track-worker is a leaf and cannot dispatch
reviewers. Accepted MVP limitation, consistent with implement-side routing being off in
tracks.

## Batch carve-out

A **batch** (bundled same-worker S-cards, `references/routing.md` § Batch dispatch) is
**exempt from the leaf rule above**: unlike a live track leaf, a batch *returns* to the
main runner, which then processes each member per-card. So the main runner runs the full
augmented reviewer pass (baseline `code-reviewer` + diff-content gates + tag route) on
**each batched card's diff** on return — a batched S-card receives exactly the review its
inline counterpart would. Batching moves where the code is written, never the review it gets.
