---
description: Start any coding work here. Picks quick (done inline), spec (questions and a spec first) or program (milestone by milestone). Prints why and the steps ahead, then starts. `--explain` prints the route only. Not for work that already has cards.
argument-hint: [what you want done] [--explain] [--lane quick|spec|program]
---

Start work on $ARGUMENTS in one of three lanes, or hand it to the command that owns it,
and show which and the steps ahead before anything runs.

1. Take the flags out of $ARGUMENTS; the rest is the ask. `--explain` prints the route
   and stops. `--lane quick|spec|program` sets the lane; any other value: print the three
   valid ones and stop. If the ask is empty, ask for a one-line request first (headless:
   print the argument hint and stop).

2. Invoke the `coding-entry` skill from this plugin and triage the ask with its rule,
   § The triage line — the order of its checks included. Cite it; do not restate it. Read
   the manifests (`composer.json`, `package.json`, a compose file, `components.json`,
   `.github/workflows/`, whether `migrations/` or `tests/` exist): a few file reads, no
   network, no subagents. Map its result:

   | triage result | lane | steps |
   |---|---|---|
   | `trivial` | quick | 1. load the house rules, prime stack skills · 2. make the change here · 3. verify before calling it done (`work-verification`): run the check, show its output |
   | `needs a spec` | spec | 1. `/taskmaster:task <ask>` · 2. `/task-runner:run` · 3. `/git-workflow:finish` |
   | `needs a spec` for a bug, error or failing test (the risk clause fired) | spec | 1. `/debugging:debug <ask>` — reproduce, find the root cause · 2. `/taskmaster:task` with the diagnosis · 3. `/task-runner:run` · 4. `/git-workflow:finish` |
   | `already spec'd` | spec | 1. `/task-runner:run` · 2. `/git-workflow:finish` |
   | the idea row (`/taskmaster:brainstorm`) | spec | 1. `/taskmaster:brainstorm <ask>` · 2. `/taskmaster:task` with its design doc · 3. `/task-runner:run` · 4. `/git-workflow:finish` |
   | the whole-product row | program | 1. `/overseer:start <ask>`, typed by the user (without overseer: the `needs a spec` steps) |
   | any other ownership row | handed to that command | 1. that command with the ask |

   Residual: `/taskmaster:brainstorm` hands off to `/taskmaster:task`, not to overseer. With
   `--lane`, take that lane's steps (quick: the `trivial` row; spec: `needs a spec`). A
   step whose plugin is not installed is printed with `(not installed)`, never dropped.

3. Print one block before anything runs. It replaces `coding-entry`'s `triage:` or
   `route:` line; the rest of that skill's Output shape follows it in the same block —
   `stack:`, `loaded:`, `primed:`, `budget:` on quick, `stack:` and
   `budget: 0 files, handed off` on every other lane:

       lane: spec — questions and a spec first, then the build
       why: changes how passwords are checked: auth work always gets a spec
       steps:
         1. /taskmaster:task <ask>
         2. /task-runner:run
         3. /git-workflow:finish
       stack: laravel 11 · inertia · react 18
       budget: 0 files, handed off

   The lane words: quick — "done here, now"; spec — "questions and a spec first, then the
   build"; program — "a product built milestone by milestone"; a handover reads
   `lane: handed to /ui-ux:build — it owns this kind of work`. `why:` is one plain line;
   when the risk clause fired it names the risk (auth, stored data, money, a migration, an
   effect that cannot be undone). An override says so and keeps the triage's reading:
   `lane: quick — set by --lane (the triage said spec: changes how passwords are checked)`.
   **`--explain` prints the `lane:`, `why:` and `steps:` lines and stops:** nothing loaded
   but `coding-entry`, nothing written, no step started.

4. Act on the lane.
   - **quick:** take versions from `stack-scan`'s `installed-versions` skill
     when that plugin is installed, else from the manifests; say which.
     <!-- The one line a with/without eval may change: keep it until the quick lane is measured passing as often without the five skills. -->
     Load the five always-relevant skills named in `coding-entry`, and prime the stack-matched ones per `coding-entry/references/skill-map.md`.
     Name every signal whose plugin is not installed. Then write the phase file with
     taskmaster's writer —
     `bash "${CLAUDE_PLUGIN_ROOT}/../taskmaster/scripts/phase-sentinel.sh" write build --owner code-architecture:work --session "<this session id>"`;
     when that path does not exist (an installed plugin sits at
     `<marketplace>/<plugin>/<version>/`), run the newest installed copy,
     `find ~/.claude/plugins/cache -path '*/taskmaster/*/scripts/phase-sentinel.sh' | sort -V | tail -1`;
     when that finds nothing, write
     `{"phase":"build","owner":"code-architecture:work","session_id":"<this session id>","started_at":"<ISO-8601 UTC>"}`
     to `.claude/cc-phase.json` at the repo root (`git rev-parse --show-toplevel`; outside
     git, the project directory). Do the work, reading a primed path when the work reaches
     that surface; verify it; then clear the file (`phase-sentinel.sh clear`, else delete
     it). No other lane writes it: the receiving commands write their own.
   - **spec, and a handover:** load and prime nothing — the receiving command loads its
     own. Run step 1 now; the printed block was the preview. Each later step is offered by
     the one before it. Headless: print step 1 exactly and stop.
   - **program:** print step 1 for the user to type and stop; `/overseer:start` runs only
     when typed. Without overseer, act as spec.

Standing: agent-graded — no script checks the lane picked or that the risk clause was
honoured; the printed block makes both visible and arguable in the transcript.
