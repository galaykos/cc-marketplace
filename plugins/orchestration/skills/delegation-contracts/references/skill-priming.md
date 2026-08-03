# Skill priming — provenance, self-rescue, and why the orchestrator still resolves

Companion to `SKILL.md` § Skill priming. That section states the contract; this one
states the evidence behind it, and the one case where a delegate can rescue itself.

## What a delegate can and cannot do

| Tool it holds | Can it locate its own rubric? |
|---|---|
| `Glob` only | **Yes, with an explicit `path`.** Only the UNPATHED form is confined to the project. Verified: a `Read/Grep/Glob` agent resolved a skill under `~/.claude/plugins` in one call. It cannot FILTER or version-sort the results, and Glob returned the `.bak` mirror FIRST — the probe read the stale copy. |
| `Bash` | **Yes** — `find ~/.claude/plugins -path '*/skills/<name>/SKILL.md'` returns hits. Verified against a live spawned agent, not assumed. |
| Neither | No. Say so; do not proceed on recall. |

The older doctrine said flatly that a delegate "cannot self-locate an installed skill."
That is false for every agent here, in two separate ways, and both were found by probing
rather than by reasoning: `Bash` holders can `find`, and `Glob` holders can pass an
explicit `path`. A limitation stated wider than reality gets designed around, and the
design that resulted was 4 dispatch paths that all named a rubric and injected nothing.
What is genuinely true is narrower and is the whole reason injection still matters: no
delegate can rank the copies it finds.

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
2. Sibling plugin in the SAME install. **Two layouts exist and the rung needs both:**
   - checkout — `"${CLAUDE_PLUGIN_ROOT}"/../*/skills/<name>/SKILL.md`, valid when the root
     is `marketplaces/<mp>/plugins/<plugin>/`, where `..` IS the plugins directory.
   - cache — `"${CLAUDE_PLUGIN_ROOT}"/../../*/*/skills/<name>/SKILL.md`, taking the highest
     version segment. Under a cache install the root is `cache/<mp>/<plugin>/<version>`,
     **three** segments deep, so one `..` reaches the plugin's other VERSIONS and the
     one-level form matches nothing at all — verified: it returns zero hits for
     `sql-best-practices` from an installed laravel root, while the two-level form
     resolves it.

   This rung matters: a cross-plugin token (`sql-best-practices` cited by a Laravel
   worker) resolves here without leaving the install the dispatching plugin came from.
   `taskmaster/scripts/skills-stamp-lint.sh` uses the one-level form and had the same
   defect; it now tries both.
3. `find ~/.claude/plugins/marketplaces \( -path '*/skills/<name>/SKILL.md' -o -path '*/skills/*/<name>/SKILL.md' \) | grep -v '/[^/]*\.bak/' | grep -v '/marketplaces/[^/]*/\.' | sort | head -1`
4. same `find` under `~/.claude/plugins/cache`, keyed on the version field and taking the
   highest: `awk -F/ '{v="0.0.0"; for(i=NF;i>0;i--) if($i ~ /^[0-9]+(\.[0-9]+)+$/){v=$i; break} print v"\t"$0}' | sort -V | tail -1 | cut -f2-`
5. `plugins/*/skills/<name>/SKILL.md` — repo-relative, development only.

The second `-path` in rungs 3–4 is not decoration. Skills may nest one level under a
category (`skills/<category>/<name>/SKILL.md`); 66 such files ship in installed plugins on
the machine this was measured on, and a flat-only glob reports every one of them
`UNRESOLVED` while they sit readable on disk. This marketplace ships none today, so the
case reaches `bestpractices-skill:` tokens never and a card's `Skills to apply` freely.

Filter `.bak` BEFORE deciding to fall through to cache. Testing the unfiltered hit list
means a marketplace holding ONLY a `.bak` copy blocks the cache branch, and the skill
resolves nowhere even though a good cached copy exists. Measured, not theorised: a skill
in exactly that state regressed from resolving to `UNRESOLVED` when the filter was applied
after the fallthrough test instead of before it.

Two details in rungs 3–4 are load-bearing, and both were wrong in the first draft of
this file:

- **`sort` before `head -1` on rung 3.** Raw `find` order is filesystem order. Measured
  here, unsorted `find` returned the `.bak` mirror FIRST for `sql-best-practices` — only
  the exclusion saved it. Without `sort`, which live marketplace wins is unstable across
  machines and across runs on one machine.
- **Rung 4 sorts the VERSION SEGMENT, not the whole path.** `sort -V` on full paths lets
  the marketplace-name segment dominate the comparison, so it is not a version sort at
  all. Given `aa-mp/laravel/0.10.0/…` and `zz-mp/laravel/0.9.0/…`, whole-path `sort -V |
  tail -1` returns **0.9.0**. Extracting the version field first returns 0.10.0. Take that
  field as the last segment matching `^[0-9]+(\.[0-9]+)+$` scanning RIGHT TO LEFT, not as
  a fixed `$(NF-3)`: for the nested `skills/<category>/<name>/SKILL.md` layout this file
  defends two paragraphs above, `NF-3` is the literal string `skills`. The fenced awk does
  the right-to-left scan; the prose used to say `$(NF-3)` and disagreed with it.

The second `grep -v` drops OTHER RUNTIMES' mirrors: a marketplace may ship
`<mp>/.agents/skills/<name>/`, `.roo`, `.kiro`, `.junie` beside its real
`<mp>/plugins/<p>/skills/<name>/`. They are not `.bak`, and a dot sorts BEFORE a letter, so
without this they win `head -1` outright — measured on `caveman`, where four such mirrors
sorted ahead of the real copy.

When rung 3 yields more than one live copy, the pick was decided by sort order, not by
authority. Report the count; do not present an arbitrary pick as an authoritative one.

Rungs 1–2 are exact; 3–4 are heuristics and are ordered last on purpose. A machine can
carry several marketplaces at once (six on the box this was verified against, one of them
a `.bak`), so a bare `find … | head -1` picks arbitrarily among them — fine as a fallback,
wrong as a first choice. Marketplaces outrank cache because the checkout is what the user
installed; `.bak` is excluded because it is by definition superseded. A name that resolves
nowhere is skipped, never an error — but **name the miss**, or a rubric that silently
shrank reads identically to one that applied in full.

## Resolving the AGENT file (before you can read its frontmatter)

`bestpractices-skill:` lives in the worker's agent definition, so priming needs that file
resolved before any skill is. It has the same several-copies problem and needs its own
three-rung ladder, first hit wins:

1. `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` — worker in THIS plugin.
2. `"${CLAUDE_PLUGIN_ROOT}"/../<plugin>/agents/<name>.md` — cross-plugin, checkout layout.
3. `"${CLAUDE_PLUGIN_ROOT}"/../../<plugin>/*/agents/<name>.md` at the highest version —
   cross-plugin, cache layout.

Skipping this is not cosmetic, because copies genuinely disagree about which skills the
worker even names. Measured on one machine: `ui-ux:ui-ux-reviewer` at cache `0.7.7` still
declares a skill this marketplace has since removed, where the live checkout declares the
current `motion-best-practices`. A dispatcher that lands on the old copy injects a
removed skill's rubric and silently drops the current one, while every status field reads
clean. Resolve the agent file by provenance, exactly as you resolve the skill.

Rung 3 matters for the same arithmetic as the skill ladder's rung 2: a cache root is
`<mp>/<plugin>/<version>`, so one `..` reaches other VERSIONS of the same plugin.

## Self-rescue (delegate side)

A delegate that receives no injected path for a skill self-rescues, by whichever tool it
holds. `Bash`: rungs 3–4 above. `Glob` only: one call with an explicit
`path` of `~/.claude/plugins` and pattern `**/skills/<name>/SKILL.md`, then pick by
discarding `.bak` components, preferring `marketplaces/` over `cache/`, and taking the
highest version among cache hits — a rule it must apply by reading the paths, since it has
no `Bash` to filter with, and Glob's own order has handed back the `.bak` mirror first.

This is a backstop, not the design: it covers direct `Agent` spawns and any dispatch site
that skipped its step, neither of which the orchestrator can reach. A delegate that
rescued anything says so (`dispatched under-primed — self-rescued …`) even when it ends up
holding everything — otherwise the broken caller is never told. One holding nothing, with
no tool to look, opens with `dispatched unprimed — rubric not loaded`.

## Standing

**Agent-graded.** `scripts/validate.sh` gates that every dispatching command *carries* a
priming instruction (`pc_dispatch_priming` in `scripts/lib/plugin-checks.sh`), and
`scripts/smoke/chassis-template-tests.sh` gates that the generated apply-lane and worker
bodies carry theirs. Neither can verify that a given run actually injected the paths —
that remains unmeasurable from inside the repo, and saying so is the point.
