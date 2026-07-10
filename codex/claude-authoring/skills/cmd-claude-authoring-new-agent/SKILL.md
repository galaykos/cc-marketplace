---
name: cmd-claude-authoring-new-agent
description: "Use when the user asks to scaffold a subagent .md with name/description/tools/model/effort frontmatter and a role-procedure-checklist body."
---

_This skill wraps the `/claude-authoring:new-agent` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Scaffold a new subagent from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the agent name (kebab-case) and a one-line purpose.
   Ask for whichever is missing before writing anything.
2. Ask 2–3 scoping questions before generating:
   - Reviewer or worker? Reviewer (read-only analysis, reports findings) gets
     `tools: Read, Grep, Glob`. Worker (makes changes, runs commands) gets
     `tools: Read, Write, Edit, Bash, Grep, Glob`.
   - What situation should make the main session dispatch this agent, and
     what exactly must it return when done?
   - Target location. Default for any project repo:
     `.claude/agents/<name>.md`. If the repo root contains a
     `.claude-plugin/` directory (plugin/marketplace repo), target
     `plugins/<plugin>/agents/<name>.md` instead — ask which plugin.
3. Write the agent file from this template — all five frontmatter keys are
   required (this marketplace's validator rejects files missing any of name,
   description, model, effort):

   ```markdown
   ---
   name: <name>
   description: Use PROACTIVELY when <dispatch situation> — <what it returns>.
   tools: <list chosen in step 2>
   model: sonnet
   effort: xhigh
   ---
   You are a <role in one sentence — what you are, what you are not>.

   Procedure:
   1. TODO: first concrete step.
   2. TODO: next step — numbered, imperative, no branching prose.
   3. TODO: final step producing the output.

   Checklist before finishing:
   - [ ] TODO: verifiable condition the work must satisfy.
   - [ ] TODO: second condition.

   Defer rule: if <out-of-scope situation>, stop and report back instead of
   acting.

   Output: return <exact shape — e.g. a findings table with file paths, or a
   diff summary>. No preamble, no file dumps.
   ```
4. Print the targeted verification for the file you wrote:

   ```bash
   f=<path>.md
   head -1 "$f" | grep -q '^---$' && echo frontmatter-opener-ok
   awk '/^---$/{c++; next} c==1' "$f" | grep -Ec '^(name|description|tools|model|effort):'   # expect 5
   ```
5. Offer the next step as a selectable choice (AskUserQuestion): "Load the
   authoring-agents skill and flesh out the TODOs now (Recommended)" /
   "Skip — I'll fill the scaffold in myself". On yes, load the skill and
   continue; plain text only when headless. Deeper rules live there — the
   deeper rules — PROACTIVELY phrasing, tool scoping, worker vs reviewer.
