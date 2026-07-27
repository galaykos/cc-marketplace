# Agent naming and PROACTIVE-trigger arbitration

Read on demand from `../SKILL.md`. Was the `orchestration:agent-conventions` skill
until 2026-07-27: it fired on the same moments as `authoring-agents` (both matched
"write me a new reviewer agent"), restated the same tool lists, the same hybrid-agent
ban and the same PROACTIVELY rule, and neither body referenced the other. The seam
existed only in `orchestration/README.md`, which is not loaded when either skill fires
— the coin-flip dispatch `../SKILL.md` warns about, committed by the two skills that
warn about it.

Merged here because writing an agent file is an authoring act. What stayed in
`orchestration` is the runtime side: which fleet gaps exist, how to retrofit
delegation onto a review-only plugin, and the shared apply-fixes contract.

---

## The two roles — a naming taxonomy

Every agent is a **worker** or a **reviewer**. Encode it in the suffix:

- **`<domain>-engineer`** — the worker. Writes, edits, runs commands, produces a
  diff. Tools: `Read, Write, Edit, Bash, Grep, Glob`.
- **`<domain>-reviewer`** — read-only. Inspects and reports findings; never edits,
  never runs mutating commands. Tools: `Read, Grep, Glob`.

One domain owns at most one of each. The pair — engineer + reviewer — is the unit;
`ui-ux` is the reference (`ui-ux-engineer` builds, `ui-ux-reviewer` audits). A lone
half is fine when only half the work is delegatable, but name it for the half it is:
a read-only agent is never `-engineer`.

Exceptions that keep their established names (do not rename): `code-reviewer`,
`test-engineer`, `security-engineer`, `database-engineer`, `context-scout`,
`spec-adversary`, `transcript-miner`. New agents follow the suffix rule.

## Proactive-trigger arbitration

`description: Use PROACTIVELY …` means the main thread may dispatch the agent
without being asked. That is a loaded gun when N agents all say "after editing
code": one `.tsx` save nominally wakes ui-ux-reviewer, a11y, the frontend reviewer,
code-reviewer. The fix is at authoring time, in the description:

- **Name one surface.** A PROACTIVELY trigger must state the specific surface —
  a file kind, a pipeline phase, an artifact — not "after any change". "after
  editing a migration or schema", not "after writing code".
- **One surface, one owner.** Two agents that would fire on the same surface must
  differentiate by specificity: the more specific claim wins, the general one steps
  back. `a11y` owns accessibility on markup; `ui-ux-reviewer` owns everything else
  on the same file — the descriptions say so, so both know when to defer.
- **Most-specific-wins at dispatch.** When surfaces still overlap, the main thread
  runs the single most-specific reviewer for that edit, not the whole set. Breadth
  comes from one review pass with several lenses (see verification-panels), not from
  several agents racing on one file.

An agent whose trigger cannot name its surface in one clause is not ready to be
PROACTIVE — ship it as an on-demand `/command` instead.
