# The collective task force — what shipped, and what is still open

Recorded here rather than in `taskmaster-docs/`, which is gitignored: moving it there
would be deletion wearing the word "archive". This is the residual of the 2026-08-16
work that made the marketplace's artifacts declare their territory and take turns.

**Standing: `recorded`.** Nothing reads this file back. It exists so the next person
does not re-derive the same findings, and so the deferred items are visible as
decisions rather than as omissions.

## What shipped

| Mechanism | Where | Teeth |
|---|---|---|
| Lane declaration (`artifact kind phase owns definite_trigger yields_to`) | `plugins/*/lane.tsv` | `gate` for agents + prompt/Stop-hook plugins; `WARN` for commands and skills |
| Territory collision detection | `pc_lanes_territory` | `gate` |
| A plugin may declare only its own artifacts | `pc_lanes_authority` | `gate` |
| Phase sentinel `.claude/cc-phase.json` | `templates/blocks/phase-guard.md` | `gate` on the READ (`pc_phase_guard`); the honouring is agent-graded |
| Monotonic rank within a phase | `templates/reminder-hook.sh.tmpl` | `gate` — `hook-guard-tests.sh` asserts the same winner in both invocation orders |
| Repo-relevance filter on the tool-fit catalog | `route-prompt.sh` | `gate` — `prompt-route-tests.sh`, both directions |
| Session index matches the repo | `skill-router/hooks/prime.sh` | partially — see item 1 below |

## Open, ranked

1. **Generate `prime.sh`'s stack map from `skill-map.md`.** The map is now correct but
   is still a *second hand-maintained copy* of the manifest matcher, held to the first
   only by a comment. `skill-map.md`'s own header warns that two copies guarantee one
   goes stale. Blocked on a **fifth chassis type**: `scripts/generate.sh:216-221`
   dispatches exactly `stack-review`, `suite-uninstall`, `reminder-hook`,
   `worker-agent` and dies on anything else, so this needs a render function, a
   template, a manifest and a `--check` path. Spec criterion S6 is unmet; S5 is met.

2. **Three smoke harnesses mutate real shipped files and rely on cleanup.** This bit
   the implementation run three separate times, including once where a harness restored
   `route-prompt.sh` from its own backup and silently reverted a completed feature.
   - `scripts/smoke/prompt-route-tests.sh:228` appends a 5th grep to the real
     `plugins/skill-router/hooks/route-prompt.sh`, then restores with `cp`.
   - `scripts/smoke/lanes-tests.sh` plants a malformed row into the real
     `plugins/testing/lane.tsv`.
   - `scripts/smoke/validate-fixtures/role-floors-check.sh:20` writes three fake agent
     files into the real `plugins/debugging/agents/`.

   A killed run, or two overlapping runs, leaves the repo corrupted in a way that then
   fails a gate on a file nobody edited. Worse now than before: once
   `pc_lanes_coverage` gates agents, a leaked `_rf_scratch_*.md` demands a lane row
   that will never exist. **Fix: plant into a copied tree, not the live one.**

3. **`transcript_path` keying for PostToolUse one-shots.** Six hooks key their one-shot
   markers on `session_id`, so a subagent context is deduped by nudges the parent
   already received — and PostToolUse is the only hook channel that reaches subagents
   at all. `plugins/lean/hooks/budget.sh:10-15` discovered, documented and fixed this;
   `plugins/skill-router/hooks/route.sh:16-18` documents the identical hole and did not
   adopt the fix. Gate it (`pc_context_key`) rather than patching six files, because the
   next hook someone writes will make the same choice.

4. **Fan-in visibility for the 33 `review` commands.** 26 are chassis-generated, 7 are
   hand-written. `code-review/commands/review.md:36-39` states it is the fan-in for
   overlapping review surfaces, but the catalog trims descriptions to 85 characters, so
   that clause is invisible at exactly the surface where the choice is made. The lane
   rows now record the deference; the *catalog row* still does not show it.

5. **Stop-gate cross-disarm.** `evidence-gate.sh:67` and `completion-gate.sh:40` both
   `exit 0` unconditionally on `stop_hook_active`, and completion-gate's per-HEAD nudge
   marker sits below that exit, unreachable on a continuation. The fix (each gate bounds
   itself with its own existing marker) is correct under every plausible reading of the
   flag. Deferred only because the *impact* depends on harness semantics no artifact in
   this repo establishes.

6. **Compaction behaviour is unverified**, and two shipped mechanisms now rest on it:
   the rank marker key is `cksum(sid + prompt + phase)` and the sentinel checks
   `session_id`. Nothing here establishes that `SessionStart` fires on compaction or
   that `session_id` survives it — `scripts/context-budget.sh:66` hardcodes
   `"source":"startup"` and is the only place a source value appears in the tree.

7. **Commands and skills from `WARN` to `gate`.** 99 commands and 129 skills have no
   lane row. Deliberately not swept: gating them at once would have forced ~66 plugin
   version bumps in a single change.

8. **Lane rows for chassis-generated artifacts are hand-written.** 21 of 32 agents and
   36 of 99 commands are generated, but their lane rows are typed by hand, so
   `generate.sh --check` cannot prove the two agree — one property split across a
   generator and a hand-edited file, which is the drift the chassis exists to prevent.

9. **`plugin.json` deference claims are still ungated.** Nine plugin descriptions carry
   "Defers X to Y" statements. The lane rows were reconciled against them by hand;
   `pc_handoff_refs` does not read `plugin.json`, so the next edit can diverge silently.

## Two limits worth restating

**Single-voice is not guaranteed** on the prompt channel — monotonic precedence is.
Among hooks eligible on a given turn the best rank always speaks, in either invocation
order; a worse-ranked sibling that reads before its better-ranked peer claims will also
print. Buying exactly-one-line needs a settle window, which costs latency on every
prompt. The bound is one line per eligible hook.

**Measured-free is not free.** The turn-taking machinery emits no stdout, so
`context-budget.sh` scores it at zero. But widening the charter gate to symptom phrasing
means the ~2.6k-token catalog now fires in incident sessions that previously paid
nothing, and the instrument cannot see that: it measures one fixed making-verb prompt in
an empty `mktemp -d` sandbox. The catalog filter (item: shipped) claws back far more
than the widening costs on a real repo, but neither number is what the gate reports.
