---
description: Review an LLM/RAG feature for eval coverage, retrieval quality, prompt-injection, grounding, and cost against llm-app
argument-hint: [path-or-diff]
---
<!-- generated from templates/review-command.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Review the target in $ARGUMENTS against this plugin's rubric — audit it, do not rewrite it.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

3. Invoke the `llm-app` skill from this plugin and apply its checklist across the
   scope — cite the skill's rubric, do not restate it here.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix` — the
   locator is `path:line`, or the section/heading for a design-doc review. Mark a
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
   pick, dispatch the finding list down the static chain task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

7. **Prime the worker's rubric in that same dispatch.** A worker has no `Skill` tool. It
   can usually FIND a skill (with `Bash`, or `Glob` given an explicit `path`) but cannot
   rank the copies it finds, so the `bestpractices-skill:` line in its agent frontmatter
   names a rubric it cannot reliably open — unqualified, it works from recalled
   convention. Ranking is your job. The chain head's agent file is
   `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` when the head lives in THIS plugin, else
   `"${CLAUDE_PLUGIN_ROOT}"/../<plugin>/agents/<name>.md` — naming an agent file without
   saying where it is would repeat the exact bug this step exists to fix. Read its
   `bestpractices-skill:` line and resolve each comma-separated token to the FIRST hit of
   `${CLAUDE_PLUGIN_ROOT}/skills/<tok>/SKILL.md` →
   `"${CLAUDE_PLUGIN_ROOT}"/../*/skills/<tok>/SKILL.md` (sibling plugin, YOUR marketplace) →
   `find ~/.claude/plugins/marketplaces \( -path '*/skills/<tok>/SKILL.md' -o -path '*/skills/*/<tok>/SKILL.md' \) | grep -v '/[^/]*\.bak/' | grep -v '/marketplaces/[^/]*/\.' | sort | head -1` →
   the same find under `cache`, keyed on the version SEGMENT and never the whole path:
   `awk -F/ '{v="0.0.0"; for(i=NF;i>0;i--) if($i ~ /^[0-9]+(\.[0-9]+)+$/){v=$i; break} print v"\t"$0}' | sort -V | tail -1 | cut -f2-` →
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
