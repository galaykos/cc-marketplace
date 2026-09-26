# taskmaster prose derivations moved out of skills (2026-09-26)

taskmaster's on-invoke prose corpus sat at 159,837 B against `pc_plugin_corpus`'s
160,000 B cap when the visual contract gained its *Interaction contract* field (a
composite widget, a drag or a live region binds its keyboard model, non-drag route and
live-update behaviour into the spec). The field and its grill pointer added 480 B. The
rules stayed in the skills; the derivations below (what was measured, where a rule came
from) moved here verbatim so the plugin stays under the cap. Each heading names the file
the text came from; a pointer to this file was left in place.

## plugins/taskmaster/skills/grill/references/visual-contract.md

§ Walk access, why the row exists:

> Measured 2026-09-25: a run with no walk access shipped UI unwalked; one that
> self-registered caught a 375 overflow six reviews missed.

## plugins/taskmaster/skills/task-cards/references/card-shape.md

Why the card shape earns its place at authoring time only:

> Measured before shipping (8 fresh-model runs, 4 per shape;
> `rationale/card-shape-ablation-2026-09-23.md` in the marketplace repository): the
> READING side showed zero delta. The shape earns its place at authoring time only, and
> only because the **gate** rows below are a script.

## plugins/taskmaster/skills/ultra/references/dispatch-tiers.md

Where the boost tier's per-stage rule comes from:

> This is not a new policy — it is `task-runner:delegation-contracts`' own rule:
> tiering is *per-stage, not per-run* (one pipeline dispatches a cheap scout,
> mid workers, an expensive judge), and one of its named anti-patterns is
> "**Uniform model for every stage.** Judge-tier for a rename sweep, or
> scout-tier on the final review." Flat-escalating every ultra subagent to
> `fable` is the first half of that; declining to raise a reasoning role is
> the second, which is why the ladder below is a FLOOR in one direction and a
> refusal in the other. Ultra defers to it.

Where the mechanical/breadth treatment comes from:

> Mechanical/breadth roles are handled exactly the way `opinion-lens` already was
> — given **no** model override, so they run at their shipped frontmatter tier.
> Lever 1 just widens that existing treatment from one agent to a class.
