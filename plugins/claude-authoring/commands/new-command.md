---
description: Scaffold a slash-command .md — description/argument-hint frontmatter, numbered $ARGUMENTS-driven body.
argument-hint: [command-name] [what-it-does]
---

Scaffold a new slash command from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the command name (kebab-case, no leading slash) and a
   one-line purpose. Ask for whichever is missing before writing anything.
2. Ask 2–3 scoping questions before generating:
   - Does it invoke a skill from the same plugin? A command is usually a thin
     entry point over a skill — name the skill it should load, or say none.
   - Does it end by doing work, or by reporting only? If it may edit the repo,
     it should offer the action as an AskUserQuestion choice (with a headless
     "report only" fallback), not act unprompted.
   - Target location. If the repo root has a `.claude-plugin/` directory
     (plugin/marketplace repo), target `plugins/<plugin>/commands/<name>.md` —
     ask which plugin. Otherwise `.claude/commands/<name>.md`.
3. Write the command file from this template — the validator requires a
   terminated frontmatter block containing `description:` (argument-hint is
   optional but recommended when the command takes input):

   ```markdown
   ---
   description: <one line: what the command does when invoked>
   argument-hint: [<expected-args>]
   ---

   <One line naming the skill this loads, if any, and the goal.> Respond to
   $ARGUMENTS with:

   1. TODO: first concrete step — imperative, no branching prose.
   2. TODO: next step.
   3. TODO: final step producing the output.

   4. When the result maps to real repo work, ask via AskUserQuestion:
      "<do it now> (Recommended)" / "<report only>". Headless: report only.
   ```
4. Print the targeted verification for the file you wrote:

   ```bash
   f=<path>.md
   head -1 "$f" | grep -q '^---$' && echo frontmatter-opener-ok
   awk '/^---$/{c++; next} c==1' "$f" | grep -q '^description:' && echo description-ok
   ```
5. Offer the next step as a selectable choice (AskUserQuestion): "Load the
   authoring-commands skill and flesh out the TODOs now (Recommended)" /
   "Skip — I'll fill the scaffold in myself". On yes, load the skill and
   continue; plain text only when headless. Deeper rules — thin-entry-point
   discipline, $ARGUMENTS handling, headless fallbacks — live there.
