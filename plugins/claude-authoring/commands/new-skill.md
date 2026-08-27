---
description: Scaffold a SKILL.md — trigger-rich description, 200-line body cap.
argument-hint: [skill-name] [purpose]
---

Scaffold a new skill from $ARGUMENTS. Steps:

1. Parse $ARGUMENTS for the skill name (kebab-case) and a one-line purpose.
   Ask for whichever is missing before writing anything.
2. **Before writing a line**, check the proposal against
   `rationale/measured-zero-shapes.md` — four shapes that were MEASURED at zero
   delta and removed from this marketplace: per-version idiom maps, canonical-
   doctrine checklists, style-rule catalogues, framework restatement. If the
   proposal matches one, the burden is not "argue it is different"; it is to name
   what a blind control would MISS, specifically enough to seed a fixture — and
   that answer comes BEFORE the scaffold exists, because a refuter applied to a
   sunk cost approves. The name gate (`pc_removed_refs`) blocks the removed NAMES
   and cannot see a new proposal wearing the same shape — which is how two of
   them reached a backlog in 2026-08.
3. Ask 2–3 scoping questions before generating:
   - Which trigger phrases or situations should fire this skill? Collect the
     literal words a user would type ("when I say X", "when editing Y files").
   - What single capability does it deliver, and what near-miss requests
     should it explicitly NOT cover?
   - Target location. Default for any project repo:
     `.claude/skills/<name>/SKILL.md`. If the repo root contains a
     `.claude-plugin/` directory (plugin/marketplace repo), target
     `plugins/<plugin>/skills/<name>/SKILL.md` instead — ask which plugin.
4. Create the directory and write SKILL.md from this template, replacing
   every TODO with real content gathered above:

   ```markdown
   ---
   name: <name>            # must equal the directory name exactly
   description: Use when <trigger phrases from step 3> — <what it delivers>.
   ---

   ## Rules

   - TODO: the non-negotiable rules, one per line, imperative voice.

   ## Examples

   TODO: one worked before/after example per rule that needs one.

   ## Anti-patterns

   - TODO: the tempting-but-wrong moves this skill exists to prevent.
   ```

   Line-budget guidance: inside this marketplace the validator caps the body
   (every line after the closing `---`) at 200 lines. There is no minimum —
   stop when the rules are stated. If a section still needs depth, add real
   guidance — more rules, worked examples, edge cases, verification — never
   filler prose or blank-line padding. Project skills created elsewhere have
   no such budget and may be shorter; keep them as tight as the content
   allows.
5. Print the targeted verification for the file you wrote:

   ```bash
   f=<path>/SKILL.md
   head -1 "$f" | grep -q '^---$' && echo frontmatter-opener-ok
   awk '/^---$/{c++; next} c==1' "$f" | grep -Eq '^(name|description):' && echo frontmatter-keys-ok
   awk '/^---$/{c++; next} c>=2' "$f" | wc -l   # marketplace ceiling: 150, no floor
   ```
6. Offer the next step as a selectable choice (AskUserQuestion): "Load the
   authoring-skills skill and flesh out the TODOs now (Recommended)" /
   "Skip — I'll fill the scaffold in myself". On yes, load the skill and
   continue; plain text only when headless. Deeper rules live there —
   description writing, scoping, and budget techniques.
7. Before the skill ships, remind about the baseline: run the target scenario
   WITHOUT the skill and record the failure it exists to fix. Claude Code's
   built-in `skill-creator` skill ships that loop as working code — paired
   with-skill and baseline subagents, a blind comparator, a grader — so run the
   host's loop rather than improvising one; the marketplace's own doctrine for it
   is authoring-skills' `references/behavioral-testing.md`. A skill with no
   baseline failure restates what the model already does. <!-- host-ok -->
