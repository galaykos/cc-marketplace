# Audit: `web-dev` and `brain` — the two nominated deletion candidates

The 2026-08-02 coverage review's cost-and-scope refuter closed with "not one item
cuts anything" and nominated these two as the concrete answers, on the grounds
that both ship **zero skills** and were therefore invisible to every skill-shaped
lens in that review. The completeness critic repeated the nomination.

This audit checks the nomination against the dependency graph rather than the
skill count. **Neither survives as a deletion candidate, and one of them is load-
bearing infrastructure.** Recording that is the point: the nomination was made
from shape, and shape was the wrong instrument.

---

## `web-dev` — keep. It is not a candidate; it is a hub.

**Ships:** 2 agents (`web-developer`, `frontend-reviewer`), 0 skills, 0 commands.
**Cost:** 115 always-on tokens, 0 dynamic.
**Bundles:** `everything`, `frontend-suite`, `php-suite`, `taskmaster-suite`.

**Inbound references: 12, from 10 distinct plugins.** Measured, not estimated:

| Referrer | Edge |
|---|---|
| `task-runner/.../references/routing.md` | `frontend → [web-dev:web-developer, …]` — the implement-side worker for the `frontend` tag |
| `task-runner/.../references/routing.md` | `api → [web-dev:web-developer, …]` |
| `task-runner/.../references/reviewer-routing.md` | `frontend → web-dev:frontend-reviewer` — the verify-side reviewer for the same tag |
| `api-design`, `i18n`, `inertia`, `nextjs`, `node-backend`, `nuxt`, `react-native`, `threejs`, `vite`, `vue3` — commands/review.md | each names `web-dev:web-developer` as the head of its apply chain |

Nine chassis review commands route their fix list through it, and the closed
11-tag routing vocabulary resolves two of its tags to it. `scripts/generate.sh`
hard-errors when a stamped worker has no agent file, so deleting this plugin does
not degrade those chains — it **breaks the generator**.

The critique that survives is about the NAME, not the function. `web-dev` reads as
a claim on the whole of web development while what it actually is, and what every
one of those twelve edges uses it as, is *the generalist worker pair for work no
framework plugin owns*. Its own README says so. That is a rename argument at most,
and a rename costs twelve edits and every downstream user's muscle memory to buy
a better noun. **Recommendation: keep, unchanged.**

Zero skills is the correct shape for it. A plugin whose entire job is to be a
dispatch target does not need a description competing for a trigger.

---

## `brain` — keep, with one honest weakness. Not a deletion.

**Ships:** 1 agent (`indexer`), 1 command (`/brain`), a SessionStart hook, 0
skills, plus a README and a ROADMAP.
**Cost:** 89 always-on tokens — the fourth-cheapest leaf in the marketplace.
Its SessionStart hook emits **0 bytes** in a sandbox and ~60 bytes in a real repo
with no map (`ℹ brain: no map for this project yet — run /brain index to create
one.`), so it is close to free in both metered channels.
**Bundles:** `everything`, `taskmaster-suite`.

**Inbound references: 2, and neither is a real dependency.** One is
`orchestration/skills/delegation-contracts/SKILL.md:73`, where "brain" is the
English word in a sentence about model tiers. The other is a `role-floors.md` row
pinning `brain:indexer` to a tier — a config entry, not a caller.

So the connectivity critique is TRUE for `brain` and false for `web-dev`. It is
genuinely a leaf nothing routes to. What that does not establish:

- **It is not redundant with the host `init`.** `init` produces `CLAUDE.md` —
  instructions. `brain` produces `brain/INDEX.md` plus per-area maps — an
  orientation artifact for a fresh session, committed to the repo. Different file,
  different lifecycle, different consumer. Neither reads the other, and that IS a
  gap worth a sentence in both, but not a duplication.
- **It is not redundant with `hindsight`.** Hindsight mines transcripts for
  friction and proposes rules; brain maps code structure. They share only the
  property of writing something a future session reads.
- **89 tokens is not where a token argument gets made.** `terse` is 886,
  `craft-layer` 1,025, `taskmaster` 931. Cutting brain would save 0.7% of the
  always-on floor and remove the only codebase-map capability in the marketplace.

**Recommendation: keep.** The honest residual is that nothing routes to it, so it
is reachable only if the user already knows `/brain` exists — the same
discoverability problem the review found for 102 of 126 skills. That is a routing
fix, not a removal.

---

## What this audit actually found

The nomination came from a skill-count heuristic applied without checking the
graph. For `web-dev` it inverted the truth: the plugin with zero skills is the one
that ten other plugins depend on, precisely BECAUSE agents, not skills, are what a
dispatch chain consumes. A lens that counts skills cannot see an agent-only plugin
at all, which is the same blind spot that hid all three skill-less plugins
(`web-dev`, `brain`, `registry-source`) from the review's forty-domain taxonomy.

**The deletion question therefore remains open and is unanswered by this audit.**
`scripts/retirement-queue.sh` and the two usage ledgers exist now; four plugins
hold 3,423 tokens between them (`terse` 886, `craft-layer` 1,025, `taskmaster`
931, `approaches` 581) and none has ever been through the baseline loop. That is
where a cut argument can be made from evidence. It cannot be made from here.

**Standing: recorded.** Nothing enforces any of this. It exists so the next reader
does not re-derive the nomination from the same wrong instrument.
