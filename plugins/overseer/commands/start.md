---
description: Start an overseer program — one sentence of product intent, delivered milestone by milestone across sessions and branches
argument-hint: [product-goal] [--hands-off] [--model opus|auto] [--budget-tokens <n>]
disable-model-invocation: true
---

Invoke the `overseer` skill from this plugin and open a program for $ARGUMENTS (if
empty, ask for one sentence naming the product and who it is for, then continue). Strip
trailing `--hands-off`, `--model <tier>` and `--budget-tokens <n>` tokens before using the goal
text; pass the tier to `program.sh init --model` (default `opus`: no seat runs above opus;
`auto`: the user chose to let judgment seats inherit the session model) and the budget to
`program.sh init --budget-tokens` (after it, `dispatch check` refuses every dispatch once this
session has spent that many tokens since the program began; **gate**). Then:

1. Refuse to start when `"${CLAUDE_PLUGIN_ROOT}/scripts/program.sh" status` reports a
   program with milestones — print its board and route to `/overseer:resume` (or to
   `program.sh close` when every milestone is done or parked). Two programs over
   one tree is two roadmaps fighting one working copy. Require a git repository; when
   there is none, ask via AskUserQuestion "Initialise git and commit a baseline now
   (Recommended)" / "Stop" — headless or `--hands-off`: initialise.
2. Run the skill's **Discover** step: the project inventory and
   `"${CLAUDE_PLUGIN_ROOT}/scripts/capability-scan.sh"`, both written to the program dir.
3. Run the skill's **Clarify** step: ONE batched AskUserQuestion round, only for the
   questions the skill's rule admits. Under `--hands-off` or headless, derive each answer
   and record it with `program.sh decision add --assumed …` instead of asking; pass
   `--hands-off --reason "<why nobody can answer>"` to `program.sh init` — a user at the
   keyboard is a reason to ask, not a reason to assume.
4. Write the charter and register the roadmap with
   `"${CLAUDE_PLUGIN_ROOT}/scripts/program.sh" milestone add … --kind <kind> --size <S|M|L|XL>`,
   one call per milestone; the kind is the routing row in `kinds.tsv` (a form that
   collects user data is `form`, never `feature`), the size decides whether the milestone
   is briefed to taskmaster (M and up) or may go to one worker (S). The rigour profile is
   scored from the brief at Deliver step 2, not here, unless the roadmap already shows a
   surface (`--rigour adversarial` on an auth milestone).
5. Enter the skill's **Deliver** loop on the first milestone and keep going: after each
   Finish, `program.sh next` — under `--hands-off` deliver every runnable milestone in this
   session; interactive, ask once per milestone whether to continue now or resume in a
   fresh session. Do not stop after planning, and do not stop after m1 with nobody at the
   keyboard — a roadmap with one branch behind it delivers nothing the user can try.
   Under `--hands-off`, before m1, print this line once for the user to run (a command
   cannot set a goal; headless: `claude -p "/goal …"`), with `<N>` twice the milestone count:
   `/goal "${CLAUDE_PLUGIN_ROOT}/scripts/program.sh" next prints none (run it and show its output at the end of every turn), or stop after <N> turns`.
   The host's `/goal` evaluator starts another turn until that holds, so the program no longer
   stops after m1 when nobody is at the keyboard. Standing: recorded — nothing checks that the
   line was printed or run.
