# The four laws — derivation

Read on demand. The body of `SKILL.md` states each law in one actionable line;
this file records where each came from and what it costs to get wrong.

Every law here was **found, not invented**. Each was independently re-derived
across this marketplace under a different subject heading, by authors who did
not know the others had written it. That is the evidence they are real, and the
reason they now live in one place: a principle with no home gets rewritten every
time it is needed.

Counts below are from a verified sweep (2026-07-27). Each is scoped per law —
they cover different plugin sets and do not sum.

---

## 1. Proportionality

**Size the ceremony to the blast radius. Counts are ceilings, not quotas.**

Re-derived at **18 sites across 5 plugins** — taskmaster 8, orchestration 5,
craft-layer 3, task-runner 1, code-architecture 1 — each with its own threshold and
own vocabulary — "scaled to blast radius", "earns", "trigger threshold", "not
padded", "sized to", "CEILING". A literal search for "proportional" finds two
hits, one of them about typefaces; the law was invisible to its own name.

Best-stated: `taskmaster/skills/grill/SKILL.md` —

> Scale to blast radius: a one-file bugfix earns zero to two questions; a feature that…

Its corollary was, as of the sweep, written **verbatim at three unlifted
sites**:
*"counts are ceilings, not quotas"* — `taskmaster/skills/spec-redteam/SKILL.md`,
`taskmaster/skills/ultra/references/dispatch-tiers.md`,
`orchestration/commands/review.md`.

The local numbers stay local. Proportionality is the law; the thresholds in
grill, spec-redteam, erd, experience-walkthrough and parallel-planning are each
that law applied to one decision. Collapsing them into a single number would be
the opposite of the law. (An earlier draft said "eleven-ish" and listed
task-cards — a count that was refuted and a file that carries no blast-radius
rule. Both are corrected here rather than quietly dropped.)

**Cost of getting it wrong, in both directions:** a five-agent panel on a typo
fix, and a one-question interrogation of a twelve-file migration.

## 2. Honest limitation

**A gate states what it converts from silent to blocking, and what stays a
prose obligation.**

Re-derived at **11 sites** (the frozen table's count, which includes
`task-runner/hooks/completion-gate.sh` and `agents/task-executor.md` and excludes
the teeth table's own two copies), in three mutually unaware vocabularies:

- the declarative teeth table (`CLAUDE.md`, and the body of this skill);
- an operational gate-script header, whose exact wording varies —
  `LIMITATION (honest scope, …)` in `taskmaster/scripts/spec-ledger-lint.sh`,
  bare `LIMITATION:` in `goal-ledger-check.sh`,
  `LIMITATION (this is a DENYLIST…)` in `verify-teeth-lint.sh`, and
  `COVERAGE LIMIT (honest scope)` in `task-runner/hooks/scope.sh`;
- a named-residual heading — `Residual (named)` in
  `task-runner/skills/task-execution/references/negative-control.md`,
  "The residual is named, not hidden" in `task-runner/skills/behavioral-gate/`
  `SKILL.md`, `Residual —` in
  `orchestration/skills/delegation-contracts/references/role-floors.md`.

Best-stated, and the sharpest sentence in the repo on the subject —
`taskmaster/scripts/goal-ledger-check.sh`:

> …from silent to blocking; entry completeness stays a prose obligation.

That is the whole idea: a gate rarely proves the thing you want proved. It
narrows the ways to fail silently. Say which ways, and say what is left.

craft-layer states the same rule as a **declared blind spot**
(`skills/asset-sourcing/references/component-sourcing.md`,
`references/licence-discipline.md`) — a fourth vocabulary for one law.

**Cost of getting it wrong:** a check trusted as a guarantee for months while
nothing enforces it. The teeth table in the body is the taxonomy; this law is
the obligation to apply it to your own gate, including when the answer is
unflattering.

## 3. The theater test

**Ceremony whose mechanism is absent is waste, however thorough it looks.**

Named 16 times across 13 files, always with the same meaning. Best-stated,
`orchestration/skills/verification-panels/SKILL.md`:

> …five-agent panel voting on a typo fix is theater: it costs real tokens,

Related namings: *"variant theater spends the user's attention on a
non-decision"* (`taskmaster/skills/erd`), *"No status theater"*
(`task-runner/skills/task-execution`), *"Verification is proportional, not
theatrical"* (`code-architecture/skills/work-verification`).

The test is mechanical: **name what the ceremony would catch that nothing else
catches.** If there is no answer, it is theater — including when it is your own.
A check that cannot fail is the commonest form: a fixture above the threshold it
guards, an assertion on the wrong channel, a `SKIP` that reads as a pass.

**Cost of getting it wrong:** a green suite that proves nothing, which is worse
than no suite, because it is trusted.

## 4. Admission

**An artifact earns existence by carrying a rule nothing else carries.**

Already stated in `authoring-plugins/SKILL.md`, which this law generalises:

`:20` — "An empty scaffold directory is clutter, not foresight."

`:96-99` — "Prefer the smallest artifact… A plugin whose every feature is a hook
is usually a skill wearing armor; a plugin with one command and no knowledge is
usually a shell alias."

`:145-146` — "Kitchen-sink plugins… split by audience."

(Three separate passages, not one.)

The deletion half has a precedent rather than a sentence — `CHANGELOG.md`
v0.86.0 retired three plugins with **no deprecation window** ("HARD DELETE, and
it will break installs"), re-homing the two surviving capabilities as skills in
the plugin that already owned the adjacent seam.

There is deliberately **no number** — no cap on plugin count, no ceiling on the
`everything` bundle's always-on tokens. The mechanism is the per-plugin ratchet
in `scripts/context-budget.sh`, which makes growth visible and deliberate.
A number nobody chose on evidence would be theater by law 3.

Applying law 2 to that mechanism, since it is the one place this file leans on a
gate: the ratchet allows 2 tokens per leaf (`2 * members` for a bundle) before it
fails, and the script declares its own residual — it "does NOT bound aggregate
drift — every leaf drifting its full +2 is ~150 tokens across the marketplace
that no run reports". So growth is visible **per plugin, above a threshold**, and
invisible in aggregate below it.

**Cost of getting it wrong:** 76 plugins, four of which you remember installing.

---

## What has no law here

Deliberate omissions, so their absence is not read as an oversight:

- **How much a skill should explain.** Judgment; the 200-line ceiling is the
  only mechanical part, and it bounds size, not quality.
- **When to split a plugin versus a skill.** `authoring-plugins` covers it
  better as concrete heuristics than a law would as an abstraction.
- **Anything about model tiers.** Boost contracts own that, and it changes
  faster than a law should.
