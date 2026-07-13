---
description: Review Inertia.js code against inertia-best-practices
argument-hint: [files-or-diff]
---
<!-- generated from templates/review-command.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Review the target in $ARGUMENTS against this plugin's rubric — audit it, do not rewrite it.

Pin every finding to the installed `inertiajs/inertia-laravel` and `@inertiajs/*` versions — do not suggest v2 APIs (deferred props, polling, prefetching, merge props) on a v1 install. Match the idiom to the installed adapter (`@inertiajs/vue3`, `@inertiajs/react`, or `@inertiajs/svelte`) — never Vue examples for a React codebase or vice versa.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

3. Invoke the `inertia-best-practices` skill from this plugin and apply its checklist across the
   scope — cite the skill's rubric, do not restate it here. Before reporting,
   read the project manifests (dependency files and their lockfiles) and pin every
   finding to the installed version — do not flag what that version already solves, nor
   propose an API above it. When unsure of an API or behavior, verify against the
   official docs for the pinned version (https://inertiajs.com) rather than answering from memory.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix`. Mark a
   finding `CONFIRMED` only with a traced call path, an executed check, or a
   reproduction; absent the ability to execute, findings stay `PLAUSIBLE` — that is
   acceptable, not a failure. No finding without evidence and a concrete fix; no praise,
   no padding.

5. Close with a coverage inventory and a self-refute pass. State `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every critical finding; if a finding does not survive it, drop or downgrade it with a
   note.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only. On an apply
   pick, dispatch the finding list down the static chain web-developer → task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.
