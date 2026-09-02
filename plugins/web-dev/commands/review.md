---
description: Review Next.js, React Native, or Vite code against the matching web-dev stack skill — stack detected from the manifests, every finding pinned to the locked version
argument-hint: [files-or-diff]
---

Review the target in $ARGUMENTS against this plugin's stack rubrics — audit it, do not rewrite it.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

   **Hand up when the scope is not this plugin's alone.** This plugin's surface is
   Next.js app code, React Native screens and native config, and Vite config. If the
   resolved scope contains files outside it and `/code-review:review` is installed, hand
   the WHOLE scope to it and stop. It is the fan-in for overlapping review surfaces and
   loads every matching stack skill in one pass; running the per-stack commands
   separately is what produces the duplicate findings the fan-in exists to prevent, and
   leaves the stacks nobody happened to invoke unreviewed. Deferring is not a smaller
   answer — the aggregator reaches this plugin's rubrics too.

3. Detect every stack in scope and load each matching skill from this plugin. Apply
   every loaded skill across every file in scope, not only the first match — a Next.js
   app built by Vite is two rubrics, not one.

   | Evidence (exact key in `dependencies` or `devDependencies`) | Skill |
   |---|---|
   | `next`, or `next.config.*`, or routes under `app/` / `pages/` | `nextjs-best-practices` |
   | `react-native` or `expo`, or `app.config.*` / `eas.json` | `react-native-best-practices` |
   | `vite` AND a `vite.config.*` at the scan root | `vite-best-practices` |

   Exact keys only: `next-auth` is not `next`, `react-native-web` is not `react-native`.
   Inertia in the manifest with the `laravel` plugin installed → also load its `inertia-best-practices`.
   No row matches → say so in one line and stop; plain JS/TS needs no stack skill and
   `/code-review:review` covers it.

   For an Expo project, ALSO read `react-native-best-practices/references/expo.md` and
   check the four things whose standard remediation has since inverted: from SDK 55
   `newArchEnabled: false` is a silently accepted no-op rather than a fix; `expo install`
   (not `npm install`) is the only correct resolver in a managed project; `expo prebuild
   --clean` overwrites hand-edited files under ios/ and android/, so native changes belong
   in a config plugin; and an EAS Update published against a mismatched `runtimeVersion`
   is never delivered, with no error anywhere. Below SDK 55 the old advice is still right.

   Before reporting, read the project manifests (dependency files and their lockfiles)
   and pin every finding to the installed version — do not flag what that version
   already solves, nor propose an API above it. When unsure of an API or behavior, verify
   against the official docs for the pinned version (https://nextjs.org/docs,
   https://reactnative.dev/docs, https://vite.dev/) rather than answering from memory.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix`. Mark a
   finding `CONFIRMED` only with a traced call path, an executed check, or a
   reproduction; absent the ability to execute, findings stay `PLAUSIBLE` — that is
   acceptable, not a failure. No finding without evidence and a concrete fix; no praise,
   no padding.

   Report every issue you find at this step, including ones you are uncertain about or
   consider low-severity. Do not filter for importance or confidence here — step 5 is
   the filter, and a finding it drops costs less than a real bug silently withheld. The
   `[CONFIRMED|PLAUSIBLE]` tag and the severity are what that filter ranks on.

5. Close with a coverage inventory and a self-refute pass. State `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every critical finding; if a finding does not survive it, drop or downgrade it with a
   note.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only. On an apply
   pick, dispatch the finding list down the static chain web-dev:web-developer if installed → task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.
