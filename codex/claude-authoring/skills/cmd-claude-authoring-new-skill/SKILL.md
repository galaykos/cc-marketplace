---
name: cmd-claude-authoring-new-skill
description: "Use when the user asks to scaffold a SKILL.md with a trigger-rich description and a body inside the 100–150 line budget."
---

_This skill wraps the `/claude-authoring:new-skill` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Scaffold a new skill from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the skill name (kebab-case) and a one-line purpose.
   Ask for whichever is missing before writing anything.
2. Ask 2–3 scoping questions before generating:
   - Which trigger phrases or situations should fire this skill? Collect the
     literal words a user would type ("when I say X", "when editing Y files").
   - What single capability does it deliver, and what near-miss requests
     should it explicitly NOT cover?
   - Target location. Default for any project repo:
     `.claude/skills/<name>/SKILL.md`. If the repo root contains a
     `.claude-plugin/` directory (plugin/marketplace repo), target
     `plugins/<plugin>/skills/<name>/SKILL.md` instead — ask which plugin.
3. Create the directory and write SKILL.md from this template, replacing
   every TODO with real content gathered above:

   ```markdown
   ---
   name: <name>            # must equal the directory name exactly
   description: Use when <trigger phrases from step 2> — <what it delivers>.
   ---

   ## Rules

   - TODO: the non-negotiable rules, one per line, imperative voice.

   ## Examples

   TODO: one worked before/after example per rule that needs one.

   ## Anti-patterns

   - TODO: the tempting-but-wrong moves this skill exists to prevent.
   ```

   Line-budget guidance: inside this marketplace the validator requires the
   body (every line after the closing `---`) to be 100–150 lines. Reach the
   window by expanding the three sections with real guidance — more rules,
   more worked examples, edge cases, a verification section — never with
   filler prose or blank-line padding. Project skills created elsewhere have
   no such budget and may be shorter; keep them as tight as the content
   allows.
4. Print the targeted verification for the file you wrote:

   ```bash
   f=<path>/SKILL.md
   head -1 "$f" | grep -q '^---$' && echo frontmatter-opener-ok
   awk '/^---$/{c++; next} c==1' "$f" | grep -Eq '^(name|description):' && echo frontmatter-keys-ok
   awk '/^---$/{c++; next} c>=2' "$f" | wc -l   # marketplace target: 100–150
   ```
5. Offer the next step as a selectable choice (AskUserQuestion): "Load the
   authoring-skills skill and flesh out the TODOs now (Recommended)" /
   "Skip — I'll fill the scaffold in myself". On yes, load the skill and
   continue; plain text only when headless. Deeper rules live there — the
   deeper rules — description writing, scoping, and budget techniques.
