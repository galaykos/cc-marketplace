# Skill priming — provenance, self-rescue, and why the orchestrator still resolves

Companion to `SKILL.md` § Skill priming. That section states the contract; this one
states the evidence behind it, and the one case where a delegate can rescue itself.

## What a delegate can and cannot do

| Tool it holds | Can it locate its own rubric? |
|---|---|
| `Glob` only | **No.** `Glob` is scoped to the user's project CWD; skills live under `~/.claude/plugins/…`, so a project-CWD pattern matches nothing. |
| `Bash` | **Yes** — `find ~/.claude/plugins -path '*/skills/<name>/SKILL.md'` returns hits. Verified against a live spawned agent, not assumed. |
| Neither | No. Say so; do not proceed on recall. |

The older doctrine said flatly that a delegate "cannot self-locate an installed skill."
That was true of the `Glob` path it had in mind and false for every `Bash`-holding
worker this marketplace ships — 10 of the 12 that declare a rubric. It is corrected here
rather than quietly: a limitation that is wider than reality gets designed around, and
the design that resulted was 4 dispatch paths that all named a rubric and injected
nothing.

## Why self-location is still not enough

A real `find` on a working install returns **five or more** hits for one skill name,
across three provenance classes:

```
~/.claude/plugins/marketplaces/<mp>/plugins/<pl>/skills/<name>/SKILL.md      live checkout
~/.claude/plugins/marketplaces/<mp>.bak/plugins/<pl>/skills/<name>/SKILL.md  stale mirror
~/.claude/plugins/cache/<mp>/<pl>/<version>/skills/<name>/SKILL.md           version-pinned, many
```

Nothing in the layout says which one you meant. Picking wrong is silent — an older cache
copy is a valid, readable, confidently-wrong rubric. In one observed case the live copy
carried a `> Last verified:` stamp naming a current framework major while a cached `0.3.7`
predated it entirely.

So: **self-location solves availability, not authority.** The orchestrator resolves
because it is the only party that can rank provenance.

## Resolution ladder (first hit wins)

1. `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` — same plugin, unambiguous.
2. `"${CLAUDE_PLUGIN_ROOT}"/../*/skills/<name>/SKILL.md` — sibling plugin in the SAME
   marketplace. This rung matters: a cross-plugin token (`sql-best-practices` cited by a
   Laravel worker) resolves here without ever leaving the marketplace the dispatching
   plugin was installed from. `taskmaster/scripts/skills-stamp-lint.sh:72` already uses
   exactly this glob.
3. `find ~/.claude/plugins/marketplaces -path '*/skills/<name>/SKILL.md' | grep -v '\.bak' | head -1`
4. `find ~/.claude/plugins/cache -path '*/skills/<name>/SKILL.md' | sort -V | tail -1`
5. `plugins/*/skills/<name>/SKILL.md` — repo-relative, development only.

Rungs 1–2 are exact; 3–4 are heuristics and are ordered last on purpose. A machine can
carry several marketplaces at once (six on the box this was verified against, one of them
a `.bak`), so a bare `find … | head -1` picks arbitrarily among them — fine as a fallback,
wrong as a first choice. Marketplaces outrank cache because the checkout is what the user
installed; `.bak` is excluded because it is by definition superseded. A name that resolves
nowhere is skipped, never an error — but **name the miss**, or a rubric that silently
shrank reads identically to one that applied in full.

## Self-rescue (delegate side)

A `Bash`-holding delegate that receives NO injected path runs steps 2–3 itself and states
which path it used. This is a backstop, not the design: it covers direct `Agent` spawns
and any dispatch site that skipped its step, neither of which the orchestrator can reach.
A delegate without `Bash`, or with nothing resolved, opens its return with
`dispatched unprimed — rubric not loaded` and works only from what its own body inlines.

## Standing

**Agent-graded.** `scripts/validate.sh` gates that every dispatching command *carries* a
priming instruction (`pc_dispatch_priming` in `scripts/lib/plugin-checks.sh`), and
`scripts/smoke/chassis-template-tests.sh` gates that the generated apply-lane and worker
bodies carry theirs. Neither can verify that a given run actually injected the paths —
that remains unmeasurable from inside the repo, and saying so is the point.
