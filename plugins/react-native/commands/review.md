---
description: Review react-native code against react-native-best-practices
argument-hint: [files-or-diff]
---
<!-- generated from templates/review-command.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Review the target in $ARGUMENTS against this plugin's rubric — audit it, do not rewrite it.

Before reporting, read package.json and the lockfile for `expo`. If the project is an Expo project, ALSO read the skill's `references/expo.md` and check the four things whose standard remediation has since inverted: from SDK 55 `newArchEnabled: false` is a silently accepted no-op rather than a fix; `expo install` (not `npm install`) is the only correct resolver in a managed project; `expo prebuild --clean` overwrites hand-edited files under ios/ and android/, so native changes belong in a config plugin; and an EAS Update published against a mismatched `runtimeVersion` is never delivered, with no error anywhere. Pin every finding to the installed expo version — each of these is version-conditional, and below SDK 55 the old advice is still right.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

3. Invoke the `react-native-best-practices` skill from this plugin and apply its checklist across the
   scope — cite the skill's rubric, do not restate it here. Before reporting,
   read the project manifests (dependency files and their lockfiles) and pin every
   finding to the installed version — do not flag what that version already solves, nor
   propose an API above it. When unsure of an API or behavior, verify against the
   official docs for the pinned version (https://reactnative.dev/docs) rather than answering from memory.

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
   pick, dispatch the finding list down the static chain web-dev:web-developer if installed → task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

7. **Prime the worker's rubric in that same dispatch.** A worker has no `Skill` tool and
   cannot locate an installed skill from the project CWD, so the `bestpractices-skill:`
   line in its agent frontmatter names a rubric it cannot open — unqualified, it works
   from recalled convention. Read that line from the chain head's agent file and resolve
   each comma-separated token to the FIRST hit of
   `${CLAUDE_PLUGIN_ROOT}/skills/<tok>/SKILL.md` →
   `find ~/.claude/plugins/marketplaces -path '*/skills/<tok>/SKILL.md' | grep -v '\.bak' | head -1` →
   `find ~/.claude/plugins/cache -path '*/skills/<tok>/SKILL.md' | sort -V | tail -1` →
   `plugins/*/skills/<tok>/SKILL.md`, then add one line per hit to the dispatch text:
   `Read <abs-path> before writing; it is the authoritative best-practice source for this
   stack.` A token that resolves nowhere is skipped, never an error — but name it, so a
   missing plugin is visible rather than a rubric that quietly shrank. If the chain head
   declares NO `bestpractices-skill:` at all (`task-runner:task-executor` does not), there
   is nothing in frontmatter to resolve and a fix list is not a task card — inject instead
   the skills THIS review itself loaded to produce the findings, so the applier works to
   the same rubric the findings were judged against. Full
   doctrine, and the discipline preamble that rides the same dispatch:
   `orchestration:delegation-contracts` § Skill priming. Standing: agent-graded — no
   script verifies a dispatch actually carried the paths.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.
