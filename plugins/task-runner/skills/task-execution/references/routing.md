# Card agent routing (main-runner only)

Only the main `/task-runner:run` orchestrator routes: it can spawn subagents and can
see the available-agent-types list in its own context. A resolved worker is a **leaf**
that executes and never re-routes. Keep the tag keys below in sync with the vocabulary
in `taskmaster/skills/task-cards/references/agent-tags.md` — `scripts/validate.sh`
fails on drift.

## Resolution map (ordered preference — first reachable wins, else `task-executor`)

```
database      → [database:database-engineer]
frontend      → [web-dev:web-developer]
ui-ux         → [ui-ux:ui-ux-engineer]
security      → [security:security-engineer]
testing       → [testing:test-engineer]
devops        → [devops:devops-engineer]
performance   → [performance:performance-engineer]
observability → [observability:observability-engineer]
backend       → [laravel:backend-engineer, web-dev:web-developer]
api           → [web-dev:web-developer]
generic       → [task-runner:task-executor]
```

A tag's list may gain more-specific specialists over time; the runner walks it in order
and picks the first present in its available-agent-types list.

## Per-card dispatch procedure

1. **Read the tag.** Take the card's `**Agent:**` value. Missing or not in the closed
   vocabulary → treat as `generic` and log the normalization.
2. **Resolve the worker.** Walk the tag's preference list; pick the first agent present
   in the runner's available-agent-types list. If none is reachable, use
   `task-runner:task-executor`. Log any downgrade (requested tag → actual worker) in
   the run report.
3. **Arm scope.** Record the card's declared allowed-files to a per-card artifact,
   e.g. `<cwd>/.claude/task-runner/scope-<cardId>.json` (the runner's own — NOT the
   legacy fixed `scope.json`, which stays the inline path's soft tripwire).
4. **Inject discipline + prime stack skills.** Read
   `orchestration/skills/delegation-contracts/references/discipline-preamble.md` and
   paste its text **verbatim** into the dispatch prompt, together with the card, its
   allowed-files, and the index's `## Upgraded statement` block when one is present.
   The preamble overrides the worker's own default procedure. THEN, for
   every skill named in the card's `Skills to apply`, resolve its installed `SKILL.md`
   and inject a `Read <abs-path>` line into the same prompt (delegation-contracts
   § Skill priming) — a delegate cannot self-load skills. Do this **unconditionally, not
   only under ultra**: a framework card must reach its worker with the framework skill
   primed, or the code is written framework-blind and only caught (if at all) at review.
5. **Dispatch** the resolved worker with that prompt.
6. **Enforce + verify on return.** Run a **diff-vs-declared-files check** (git diff of
   the paths the worker touched vs the declared allowed-files); reclaim/reject a card
   that touched out-of-set files. Then re-run the card's exact verify command yourself
   (§ Delegating parallel groups) — this holds whether or not a PostToolUse hook fired
   inside the subagent. On a green re-verify, run the **negative-control** before the
   card closes — the same gate the inline inner loop runs (`references/negative-control.md`,
   `task-execution/SKILL.md` inner-loop step 3): `negative-control.sh --verify "<the card's
   exact verify>" --target <impl-file> --auto`, with `--target` set to the CARD's declared
   primary implementation file — an authoring property the worker cannot arrange around; a
   multi-file return still runs the control against that declared file (the copy carries
   the other files along). Only a card that declares no single implementation file falls to
   the unresolvable-target exemption (negative-control.md exemption 2).
   `discriminating` closes the card; `vacuous`/`invalid-control` counts as a failed
   re-verification under the two-strike rule (§ Delegating parallel groups): one
   re-dispatch, then reclaim the card for inline execution where the inner-loop 3-cycle
   ceiling applies; `isolation-halt` halts. The standard exemptions apply (manual/visual
   lines → the recorded why-non-automatable note; an unresolvable `--target` → record
   control-not-applicable (`references/negative-control.md`) — never a silent pass.
   This runs on every delegated return, so a delegated/parallel-group card gets the teeth
   check the inline path already had.

## Batch dispatch (bundled same-worker S-cards)

`parallel-planning` may return a **BATCH** verdict: a level's file-disjoint **same-worker**
S-cards (≥3, ≤8), fired only when the batch runs concurrently with a sibling dispatch (the
concurrency gate — `parallel-planning/references/dispatch-selection.md`). A batch is ONE
dispatch of several cards to a single worker; it is otherwise the per-card procedure above,
applied per member. Differences:

1. **Membership is homogeneous.** Every card in a batch resolves (step 2) to the SAME
   worker and its file-set is disjoint from every sibling in the batch. Mixed-tag S-cards
   are never co-batched — they form their own same-worker batch or stay inline.
2. **Arm scope per card**, not per batch: one `scope-<cardId>.json` for each member (step 3
   unchanged), so each card keeps its own declared-files boundary.
3. **Dispatch once — down-tiered.** All member cards inline in the prompt, the discipline
   preamble verbatim, and the instruction to run the members **sequentially**, committing
   **one commit per card** (message `card <id>`) so the main runner can attribute per-card
   diffs on return. Because a batch is mechanical work (bundled S-cards, scaffolds, renames),
   the orchestrator passes an **explicit tier override IN THE DISPATCH CALL**: the Agent tool
   `model:` param (`haiku` for pure-mechanical sweeps, `sonnet` otherwise) and/or
   `opts.effort: 'low'` on the `Workflow` path — delegation-contracts § Model and effort
   tiering (mechanical stages get low effort and cheaper models; tiering is per-stage, not
   per-run). The worker's pinned frontmatter tier is a default the call may override downward,
   never a floor; verify and judge dispatches are never down-tiered. A batch worker is a
   leaf: it never re-routes or writes `00-INDEX.md`.
4. **Mid-batch failure is park-one-continue-rest.** A member hitting its 3-cycle halt or a
   park is parked; the worker continues the remaining disjoint members and returns
   **per-card statuses** (done + commit sha, or parked + reason). Members are disjoint, so
   a parked member never blocks a sibling.
5. **Per-card teeth on return** (step 6, run per member against that member's commit — never
   the union): the diff-vs-declared check (that card's commit vs that card's declared
   files, so a member writing into a sibling's file IS caught), the exact verify command,
   and the negative-control with `--target` = that card's declared impl file. A member
   failing re-verification twice is reclaimed for **inline** execution (the two-strike rule
   applies per member, not to the whole batch).
6. **Reviewer pass is kept.** A returned batch is NOT a live parallel-group/track leaf (see
   `references/reviewer-routing.md` carve-out): the main runner runs the per-card reviewer
   pass on each member's diff, exactly as an inline S-card would have received it. Batching
   changes *where the code is written*, never the quality gates a card passes.

## Blast-radius detection — breakage in unlisted files halts, not follow-up

The scope lock's follow-up-and-continue rule (`task-execution/SKILL.md` § Scope lock) is for
*improving* an unlisted file. Evidence that the current change *breaks* an unlisted file is a
different signal — mis-scoped card / blast radius — and must halt-with-evidence or flag the
orchestrator, never become a silent follow-up. Three detection points:

1. Any compile/type/test error naming an unlisted file.
2. A call-site grep of a symbol being changed reveals callers in unlisted files.
3. A completion full-suite failure attributable to the card → reopen the card, don't hot-patch.

## Notes

- Every mapped agent is equally privileged (Read/Write/Edit/Bash on the same repo); the
  tag selects **aptitude, not authority**. A mis-tag routes to a competent-but-suboptimal
  worker, still scope-bounded by step 6.
- Verify-side routing (matching domain reviewer) is out of scope here — deferred to
  the reviewer pass; the runner's generic re-verify remains the gate.
