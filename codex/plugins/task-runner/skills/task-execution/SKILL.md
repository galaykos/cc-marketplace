---
name: task-execution
description: "Use when executing defined task cards or an ordered plan with scope control, bounded verification loops, and evidence-based status tracking."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Execute the finite task list

Read the index, current card, applicable project instructions, and each available skill stamped on the card. Keep one inline card in progress, respect dependencies, and treat listed files, acceptance criteria, and exact verification command as the scope. Record unrelated improvements in the backlog. If the card is impossible or its change breaks an unlisted boundary, record evidence and correct the definition before continuing.

Implement, run the exact verification, and diagnose actual failures. Allow at most three failed fix/review cycles per card. At that ceiling record attempts, failing output, and the remaining hypothesis; park or halt the task, optionally obtaining one read-only diagnosis with a permitted specialist. Do not weaken assertions, replace verification with a cheaper check, or suppress failures to obtain a pass.

After a pass, assess whether the check discriminates the intended behavior from its absence. Use an isolated negative control when practical; never remove a working change destructively or disturb user work merely to construct one. Record the control result or the concrete reason a manual/visual check was used. Review the diff for correctness; add UI, architecture, or security review when the changed behavior warrants it. Resolve available reviewer skills from the session catalog. Use a permitted subagent with explicit role instructions or conduct the same review inline, recording which happened. Major findings reenter the same bounded loop; incidental minor improvements go to the backlog.

Parallel execution is optional and requires disjoint file sets, satisfied dependencies, an available subagent tool, and permission under the current session instructions. Use its real schema, inherited model, absolute paths, card text, conventions, available skill paths, scope lock, and return contract. A role name is prompt guidance, not an assumed registered agent type. Workers do not redelegate. After a worker returns, inspect its actual diff against the declared files and rerun verification; a worker's success claim is not evidence. If delegation is unavailable, execute serially inline. Do not create user-owned Codex tasks unless explicitly requested.

Update only the index: pending → in_progress → done or parked(reason); mark dependents blocked-by as necessary. Record deviations, verification command, exit status, and relevant output. Manual checks must say what was observed. Honor an upgraded goal statement as context without widening card scope; legacy boost markers never select imaginary model tiers or bypass user authorization.

Finish by running the project's required integration/full checks and exercising the produced behavior where the suite only checks static structure. Report card/status/verification/evidence, parked reasons, and follow-ups. Do not claim unavailable hook completion gates enforced the run, or claim completion while required checks fail. Use `.codex/cc-marketplace/` for adapted project-state helpers (for example `.codex/cc-marketplace/task-runner/nc` for negative-control records), resolving their scripts from this plugin's installed root; do not write another host's state directory.

## Register stateful verification

For a Git-backed run, register it before implementation: create
`.codex/cc-marketplace/task-runner/active-run.json` with `slug` and, when using an
index, its absolute `index_path`. For each inline card write `scope.json` beside
it with `{"allow":["relative/file/path"]}` from the card's actual Files list.
The scope hook warns on edits outside that list; it does not police shell writes.
Avoid overlapping runs sharing this state directory; execute serially or isolate
tracks in worktrees. Do not overwrite another active run's registration.

After all required checks pass, apply the behavioral-gate skill and record its
actual evidence in the index. Only then write `gate-pass.json` in the state
directory with the current Git `head`, `cards_total`, `cards_done`, and
`cards_parked` counts. The Stop hook checks the HEAD and counts; the evidence
behind a pass remains agent-reviewed. A new commit requires new verification.
If existing `nc/` or `rv/` records are in use, follow their per-card coverage
protocol; do not fabricate reviewer-observation records or erase them to pass.
On a completed or explicitly parked run, remove only its own active registration
and scope file, retaining evidence. If checks fail, retain the registration and
report the failure. Outside Git, record checks in the index and explicitly state
that the HEAD-based Stop check is unavailable.
