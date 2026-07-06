---
name: task-cards
description: Use after requirements are clarified into a spec — splits the work into single-prompt task cards, each small enough for one sitting and self-contained enough to execute in a fresh session with zero conversation context. Produces an ordered, dependency-aware index with parallel groups.
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

**Skills to apply:** <stack skills for this card from the stack-scan inventory,
e.g. laravel-best-practices, postgresql-best-practices — or "none detected">
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
- Cards that touch persistence must reference the spec's approved `## Data Model`
  section (the `erd` skill's output); deviation requires model re-approval, not drift.
- Name the conventions to follow ("service classes live in `app/Services`, one
  public method") — the fresh session has not read the scout report.
- Skills to apply: stamp the stack/framework skills relevant to each card from
  the stack-scan inventory taken at pipeline step 1 (fall back to reading
  manifests when stack-scan is absent). The executing session loads the named
  skills deterministically instead of relying on description matching.

## Acceptance criteria rules

- Criteria describe observable behavior, never the change itself. "Deleting a
  project soft-deletes its tasks" — not "code for soft-delete is added".
- Each criterion is binary: passes or fails, no "works well".
- The Verify line is an exact command plus expected output shape. If no such
  command can exist, the card is not yet a task — sharpen it.

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
- Parallel groups stay within a milestone; cards from different milestones
  never interleave.

## Output layout

```
taskmaster-docs/tasks/YYYY-MM-DD-<slug>/
  00-INDEX.md
  01-extract-invoice-totals.md
  02-add-soft-delete-migration.md
  ...
```

`00-INDEX.md` holds: the spec path, a table (card / title / depends-on / parallel
group / status), and the run note — each card is executed by pasting it into a
fresh session or `claude "$(cat 01-*.md)"`. Update the status column as cards
land; the index is the only file that mutates during execution.

When cards are executed by subagents, the dispatch-prompt and return-format
contract is the orchestration plugin's delegation-contracts skill.

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
