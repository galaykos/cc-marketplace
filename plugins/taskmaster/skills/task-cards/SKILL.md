---
name: task-cards
description: Use after a spec exists, or to "break this down into tasks" / "split the spec into cards" — one-sitting single-prompt cards, self-contained for a fresh session with zero context, in a dependency-ordered index with parallel groups.
---

## What a card is

A card is the smallest unit of work that is independently verifiable AND passes the
**fresh-session test**: a new Claude session, given only the card text, can execute
it without this conversation, the spec open in another tab, or tribal knowledge.
If a card needs "as discussed" or "like we said earlier", it fails the test —
inline the discussion's conclusion instead.

## Card template

Role tags inside a `.md` file: the H1 is for humans, the tags name what the author
decided about each sentence, attributes carry the evidence. Standing of every rule:
`references/card-shape.md`.

```markdown
# NN — <imperative title, no "and">

<card id="NN">
<goal>one line tying this card to the spec's goal</goal>

<facts>
<file path="src/billing/invoice.ts" line="88" mode="edit">totals computed inline</file>
<file path="src/billing/__tests__/invoice.test.ts" mode="create"/>
<current>quote what exists today</current>
<target>what exists after this card</target>
<convention>service classes live in `app/Services`</convention>
</facts>

<must>
<change>exact edits at file level — create X, extract Y into Z, wire A to B</change>
<interface consumer="04">the signature or data shape card 04 reads</interface>
<contract section="Data Model"/>
<skill name="laravel-best-practices"/>
</must>

<must-not>
<file path="src/billing/discounts.ts" reason="card 05 owns it; the tempting fix is not this card's"/>
<rule reason="card 04 imports this signature">rename or add parameters</rule>
</must-not>

<proof>
<criterion>observable behaviour, binary checkable</criterion>
<verify>npm test -- invoice → all pass, including new test <name></verify>
</proof>

<depends-on>02, 03</depends-on>
<agent>backend</agent>
</card>
```

One `<skill>` per skill, `name="none"` when none; the executing session MUST Read each
before implementing. `<agent>`: one tag from `references/agent-tags.md`, `generic` when
files span >1 domain. `<contract>` only when the spec has that binding section.

## Sizing rules

- One card = one prompt = one sitting. When in doubt, split.
- Split when: more than ~5 files touched, more than ~300 changed lines expected,
  or the title needs "and". Exception: purely mechanical sweeps (a rename across
  40 files) stay one card — mechanical breadth is not complexity.
- Every card ends verifiable. "Part 1: types only" is valid ONLY if something
  checks it (compiles, tests pass); a split whose first half cannot be verified
  is one card pretending to be two.
- Size every card S/M/L/XL against an anchor — the anchor is a card the same person
  shipped in one sitting, which is M. Anything L+ is split or spiked before it enters
  the index.

## Context rules

- Every `<file>` names its `mode`; an edited file names its `line`. The shape lint
  refuses a bare path — the executor trusts the card, not its memory of the repo.
- Quote current behavior rather than describing it from memory.
- Signatures and data shapes crossing card boundaries go in `<interface>`, with the
  reading card in `consumer`; two cards that each "know" half will disagree.
- A card touching a binding spec section — `## Data Model`, `## Visual contract` —
  carries `<contract section="…"/>` and conforms; deviation needs re-approval.
- Cards implement the spec's chosen approach and respect its kill-trigger; a card that
  silently picks another shape reopens a settled decision.
- Repo conventions go in `<convention>` — the fresh session has not read the scout report.
- Every `<must-not>` entry carries a `reason`. "Out of scope" with no why is the line an
  eager implementer argues past.
- `<skill>`: stamp the stack skills relevant to each card from the stack-scan inventory
  taken at pipeline step 1 (read manifests when stack-scan is absent). delegation-contracts
  § Skill priming injects a Read-by-path into the dispatch — a delegate cannot self-load.
- A card that CREATES a unit (module, class, service, boundary) also stamps
  `approaches:pattern-selection`, so the shape pick is deliberate and reviewable. Not on
  edit-in-place cards — it is a decision aid, not a checklist.

## Acceptance criteria rules

- Criteria describe observable behavior, never the change itself. "Deleting a
  project soft-deletes its tasks" — not "code for soft-delete is added".
- Each criterion is binary: passes or fails, no "works well".
- `<verify>` is ONE line, an exact command with **teeth**: a named assertion that fails if the
  feature is absent — verify-teeth blocks compile/existence/require-only, `|| true`, bare "suite passes".

## Ordering and parallelism

- Topologically order by `<depends-on>`; number cards in that order.
- Mark parallel groups — cards with no mutual dependency that touch disjoint
  files. Within a group, put the riskiest card first so failures surface early.
- Cards coupled through shared work-in-progress state are ordering bugs: merge
  them or move the shared piece into its own earlier card. (Proportionality law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository) "The four laws".)

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
land; the index is the only file that mutates during execution.

**Upgraded statement — every run, boosted or not.** When the spec header carries the
labeled `**Upgraded statement:**` pair, copy it VERBATIM into a `## Upgraded statement`
section of `00-INDEX.md`: one Markdown blockquote, every line `> `-prefixed, ~8 lines at
most. task-execution reads that section on every run, so an index that omits it hands the
executor nothing where it looks. The `> ` prefix is load-bearing: marker parsing is exact-prefix,
so an unprefixed statement line beginning `Ultra:` or `Goal:` would be read as a tier
declaration. No labeled pair in the spec header (older or hand-written spec) → skip the
section entirely; never derive a statement at card time. Boosted runs stamp `Ultra:`/`Goal:`
markers beside it — `references/index-markers.md`.

When cards are executed by subagents, the dispatch-prompt and return-format
contract is the task-runner plugin's delegation-contracts skill.

## After the index — verify coverage, then suggest a skill

Once `00-INDEX.md` is written, before the task-runner handoff, in order:

1. **Verify coverage.** Invoke coverage-check: it cross-checks success criteria ↔ cards
   both ways, blocks on any gap/orphan/drift, and writes `## Coverage` into `00-INDEX.md`.
2. **Lint each card.** All four live in `${CLAUDE_PLUGIN_ROOT}/scripts/` — a bare name
   resolves nowhere in the user's project. Per card run `card-shape-lint.sh --card <file>`
   (blocks a missing section, a `<file>` without `mode`/`line`, a `<must-not>` without
   `reason`, an `<interface>` without `consumer`, a `<verify>` count other than one),
   `verify-teeth-lint.sh --card <file>` (blocks a weak `<verify>`) and
   `skills-stamp-lint.sh --card <file>` (blocks a framework card stamped "none").
   Plus `spec-ledger-lint.sh --spec <spec>` once — an unconverged spec (open UNKNOWN, missing/empty ledger) never becomes cards; route holes back to grill.
3. **Suggest a project skill.** If a `project-skill-suggester` skill is available (the
   marketplace repository keeps one under `.claude/skills/`), it scans the card set (three+ cards on the same uncaptured repo knowledge → offer a skill);
   skip silently when absent, never blocks.

## Anti-patterns

- Cards that only make sense in conversation order — the fresh-session test kills these.
- Hidden dependencies: card 04 quietly assumes card 02's helper. Needed → `<depends-on>`.
- Criteria that restate the diff ("function X exists") instead of behavior.
- A `<must-not>` whose `reason` restates the prohibition ("do not touch: out of scope").
  The lint sees a non-empty attribute; only a reader sees an empty one.
- A "misc cleanup" card — leftovers become real cards or non-goals.
- Splitting below verifiability: ten unverifiable micro-cards are worse than three honest ones.
- Duplicating the whole spec into every card. Context is what THIS card needs.
- Status inside a card — it lives only in `00-INDEX.md`, so cards stay re-runnable verbatim.
