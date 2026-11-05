# Game plugin control-arm evals, 2026-11-02

Five cases were written on 2026-11-02 at the user's request, each aimed at a fact a model might
recite from memory:

- unity-traps: the Rigidbody renames, Unity 6.6 dictionary serialization, Cinemachine 3;
- blender: the bpy calls Blender 5.x removed;
- meshy: no resubmit after a create whose outcome is unknown.

All five ran through `scripts/run-evals.sh`, which calls `claude plugin eval` with
`--ablation with-without`, `--no-publish` and a per-plugin cost cap. Settings:

- runs: 5 per arm, which the user chose over the default 3;
- CLI 2.1.316 and the CLI's default model;
- judge: the runner's default, haiku.

The machine-written summaries are in `rationale/evals/2026-11-02-*.json`. The runner's HTML
reports and per-run transcripts lived in a temp directory that `run-evals.sh` deletes, so the
reason behind any single run's score is not kept.

Standing: `recorded`. No gate reads these numbers, and CI runs no eval.

## Results

| plugin / case | with | without | Δ | runs | spend |
|---|---|---|---|---|---|
| unity-traps / `dictionary-serialization-66` | **5/5** | **0/5** | **+1.00** | 5 + 5 | \$2.54 for the three unity-traps cases |
| unity-traps / `rigidbody-renames` | 5/5 | 5/5 | 0 | 5 + 5 | (in the \$2.54) |
| unity-traps / `cinemachine-3` | 4/5 | 5/5 | −0.20 | 5 + 5 | (in the \$2.54) |
| blender / `removed-5x-bpy` | 5/5 | 5/5 | 0 | 5 + 5 | \$0.97 |
| meshy / `no-resubmit-unknown-create` | 5/5 | 5/5 | 0 | 5 + 5 | \$1.06 |

Total spend: \$4.57, against the user's cap of \$25 (\$15 + \$5 + \$5).

## What each line means

- **`dictionary-serialization-66` is the one measured effect.** Without the plugin the model
  answered all five runs with the wrapper Unity needed before 6.6 (parallel lists or
  `ISerializationCallbackReceiver`). With it, all five used `[SerializeField] Dictionary<string, int>`.
  The 0/5 against 5/5 split has no overlap. That is a measurement of
  `references/upgrades-6.4-6.6.md`'s dictionary item, not of the skill as a whole.
- **`rigidbody-renames`, `removed-5x-bpy` and `no-resubmit-unknown-create` are regression guards.**
  The control arm passed 5/5 each time. The base model already writes `linearVelocity`/
  `linearDamping`, reads F-curves through a channelbag and builds the compositor as a node group,
  and lists Meshy tasks before re-creating one. These cases cannot show the plugin helping, because
  there is no room above 1.00. They can still catch the plugin breaking a right answer. CLAUDE.md's
  Evals section states this rule, and the 2026-09-15 amendment in
  `rationale/marketplace-endgame-review-2026-09-14.md` found the same.
- **`cinemachine-3`: −0.20 is one failed run in five.** One of five with-plugin runs failed and
  none of the control runs did. The failing run's transcript is gone with the temp directory, so
  its cause is unknown. By CLAUDE.md's rule, five runs cannot separate a regression from a flake:
  the 2026-09-14 "−1.00" in the endgame review did not replicate a day later. Read it as "no
  measured effect, one unexplained with-arm failure", not as the plugin hurting. Re-run before
  acting on it: `RUN_EVALS=1 RUN_EVALS_MAX_COST_USD=5 bash scripts/run-evals.sh unity-traps --case cinemachine-3 --runs 10`.

## What this does and does not show

- It shows the unity-traps 6.6 dictionary fact changes what the model writes on this CLI, model
  and judge, at 5 runs per arm.
- It does not show the other unity-traps references, the blender skill or the meshy skill helping.
  Their cases sit at the ceiling. A useful case for them needs a prompt the base model fails,
  which these did not find.
- It says nothing about the hooks added the same day. They are mechanisms, gated by
  `scripts/smoke/game-checker-hooks-tests.sh`, and no eval measures them.
