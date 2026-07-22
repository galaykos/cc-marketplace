---
name: task-cards
description: Use after requirements are clarified into a spec — splits the work into single-prompt task cards, one-sitting sized, self-contained for a fresh session with zero context, in an ordered dependency-aware index with parallel groups.
---

## What a card is

A card is the smallest unit of work that is independently verifiable AND passes the
**fresh-session test**: a new Claude session, given only the card text, can execute
it without this conversation, the spec open in another tab, or tribal knowledge.
If a card needs "as discussed" or "like we said earlier", it fails the test —
inline the discussion's conclusion instead.

## Card template

```markdown
# NN — <imperative title, no "and">

**Why:** one line tying this card to the spec's goal.

**Context:**
- Files: `src/billing/invoice.ts:88` (current: totals computed inline),
  `src/billing/__tests__/invoice.test.ts`
- Current behavior: <quote or describe what exists today>
- Target behavior: <what exists after this card>
- Interfaces crossed: <signatures/data shapes this card must respect>

**Change:** exact edits at file level — create X, extract Y into Z, wire A to B.

**Acceptance criteria:**
- [ ] <observable behavior, binary checkable>
- [ ] <second criterion if needed>

**Verify:** `npm test -- invoice` → all pass, including new test <name>.

**Out of scope:** what an eager implementer might also touch, but must not.

**Depends on:** 02, 03 — or "none".

**Skills to apply:** <stack skills for this card; the executing session MUST Read each
named SKILL.md before implementing — e.g. laravel-best-practices; or "none detected">

**Agent:** <capability tag per `references/agent-tags.md` — always emit; `generic` when files span >1 domain or no tag matches>
```

## Sizing rules

- One card = one prompt = one sitting. When in doubt, split.
- Split when: more than ~5 files touched, more than ~300 changed lines expected,
  or the title needs "and". Exception: purely mechanical sweeps (a rename across
  40 files) stay one card — mechanical breadth is not complexity.
- Every card ends verifiable. "Part 1: types only" is valid ONLY if something
  checks it (compiles, tests pass); a split whose first half cannot be verified
  is one card pretending to be two.
- If the estimation plugin is installed, size each card per its anchored
  S/M/L/XL scale; anything L+ is split or spiked before it enters the index.
  Skip when not installed.

## Context rules

- Repo-relative paths with line numbers for every file mentioned.
- Quote current behavior rather than describing it from memory — the executing
  session will trust the card verbatim.
- Spell out data shapes and signatures crossing card boundaries; two cards that
  each "know" half an interface will disagree.
- Cards that touch a binding contract section — `## Data Model` for persistence,
  `## Visual contract` for a staged visual/creative surface — must reference it and
  conform; deviation requires re-approval, not drift.
- Cards implement the spec's chosen approach and respect its kill-trigger. A card
  that silently picks a different shape reopens a decision the persona round settled.
- Name the conventions to follow ("service classes live in `app/Services`, one
  public method") — the fresh session has not read the scout report.
- Skills to apply: stamp the stack/framework skills relevant to each card from
  the stack-scan inventory taken at pipeline step 1 (fall back to reading
  manifests when stack-scan is absent). delegation-contracts § Skill priming
  resolves each named skill's installed SKILL.md and injects a Read-by-path into
  the implementer dispatch — a delegate cannot self-load skills.

## Acceptance criteria rules

- Criteria describe observable behavior, never the change itself. "Deleting a
  project soft-deletes its tasks" — not "code for soft-delete is added".
- Each criterion is binary: passes or fails, no "works well".
- The Verify line is an exact command with **teeth**: a named assertion that fails if the
  feature is absent — verify-teeth blocks compile/existence/require-only, `|| true`, bare "suite passes".

## Ordering and parallelism

- Topologically order by `Depends on`; number cards in that order.
- Mark parallel groups — cards with no mutual dependency that touch disjoint
  files. Within a group, put the riskiest card first so failures surface early.
- Cards coupled through shared work-in-progress state are ordering bugs: merge
  them or move the shared piece into its own earlier card.

## Milestones for big runs

Past ~10 cards, a flat list hides the shape of the work. Group cards into
milestones — each one independently shippable and verifiable:

- A milestone ends at a state worth having even if work stops there: "landing
  page live without signup", "export works for admins only".
- The index gains a milestone grouping; each milestone closes with its own
  full-suite verify, not just per-card checks — milestone boundaries are where
  integration bugs surface.
- Order milestones by risk and value, not by architectural layer: "walking
  skeleton first" beats "all migrations, then all endpoints, then all UI".
- Parallel groups stay within a milestone; different-milestone cards never interleave (serial mode).
- Each milestone's index entry carries a normalized `Files:` set (see `references/milestone-file-sets.md`) for `--tracks`.

## Output layout

```
taskmaster-docs/tasks/YYYY-MM-DD-<slug>/
  00-INDEX.md
  01-extract-invoice-totals.md
  02-add-soft-delete-migration.md
  ...
```

`00-INDEX.md` holds: the spec path, a table (card / title / depends-on / agent /
parallel group / status), and the run note — each card is executed by pasting it into a
fresh session or `claude "$(cat 01-*.md)"`. Update the status column as cards
land; the index is the only file that mutates during execution. Under `ULTRA-TASK ACTIVE` (see the `ultra` skill), also write an exact `Ultra: true (model=<model>, effort=<effort>)` line near the top of `00-INDEX.md` — copy the directive's `model`/`effort` VERBATIM (defaults auto/xhigh; `auto` stays the literal `auto` so execution re-resolves it in its own session) — so a fresh-session execution run inherits the boost at the same tier. Under `ULTRA-GOAL ACTIVE` (see the `ultra-goal` skill), ALSO write an exact `Goal: true (model=<model>, effort=<effort>) — requires task-runner ≥0.11.0; older runners fall back to interactive execution` line with the resolved tier (ultra-task tier when both tokens are present); when only goal is active, write BOTH lines — the `Ultra:` line carries the resolved tier because goal implies the boost. Also copy the spec header's `**Upgraded statement:**` verbatim into a `## Upgraded statement` section of `00-INDEX.md` — a single Markdown blockquote (every line `> `-prefixed, at most ~8 lines) placed near these `Ultra:`/`Goal:` markers; the `> ` prefix guarantees no statement line can start with `Ultra:` or `Goal:`, so exact-prefix marker parsing stays safe. When the spec header has no labeled `**Upgraded statement:**` pair (older or hand-written spec), SKIP the section entirely — never derive a statement at card time.

When cards are executed by subagents, the dispatch-prompt and return-format
contract is the orchestration plugin's delegation-contracts skill.

## After the index — verify coverage, then suggest a skill

Once `00-INDEX.md` is written, before the task-runner handoff, in order:

1. **Verify coverage.** Invoke coverage-check: it cross-checks success criteria ↔ cards
   both ways, blocks on any gap/orphan/drift, and writes `## Coverage` into `00-INDEX.md`.
2. **Lint each card.** Per card run `verify-teeth-lint.sh --card <file>` (blocks a weak
   Verify line) and `skills-stamp-lint.sh --card <file>` (blocks a framework card stamped "none").
3. **Suggest a project skill.** If claude-authoring is installed, its project-skill-suggester
   scans the card set (three+ cards on the same uncaptured repo knowledge → offer a skill);
   skip silently when absent, never blocks.

## Anti-patterns

- Cards that only make sense in sequence-of-conversation order — the fresh-session
  test exists precisely to kill these.
- Hidden dependencies: card 04 quietly assumes card 02's helper exists. If it is
  needed, it goes in `Depends on`.
- Criteria that restate the diff ("function X exists") instead of behavior.
- A "misc cleanup" card — scope leftovers either become real cards or non-goals.
- Splitting below verifiability to make cards look small: ten unverifiable
  micro-cards are worse than three honest ones.
- Duplicating the whole spec into every card. Context is task-scoped: what THIS
  card needs, not everything anyone decided.
- Tracking status inside cards — status lives only in `00-INDEX.md`, so cards
  stay immutable prompts that can be re-run verbatim.
