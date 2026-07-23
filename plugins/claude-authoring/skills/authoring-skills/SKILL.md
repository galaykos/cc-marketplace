---
name: authoring-skills
description: Use when writing or editing a SKILL.md — trigger-rich descriptions, line budgets, one-capability scoping, validator frontmatter rules.
---

## Anatomy

One skill is one directory holding one file:

    plugins/<plugin>/skills/<skill-name>/SKILL.md

The file opens with YAML frontmatter delimited by dash-fence lines, then a
body — the instructions loaded when the skill fires:

    ---
    name: <skill-name>
    description: Use when <trigger> — <what it delivers>.
    ---
    <body>

This marketplace's validator (scripts/validate.sh) enforces, for every
skills/<name>/SKILL.md:

- Line 1 is exactly `---` and a closing `---` terminates the frontmatter.
- `name:` is present and equals the skill's directory name exactly.
- `description:` is present.
- The body — every line after the closing `---` — is 100 to 150 lines.

Count the body before you commit:

    awk '/^---$/{c++; next} c>=2' SKILL.md | wc -l

## The description is the trigger

The body is only ever read AFTER the skill fires; whether it fires at all is
decided by the description alone. Treat the description as a routing rule,
not a summary.

- Start with "Use when …" and name the concrete situations: the file types,
  the actions, the phrases a user would actually type.
- Follow with an em dash and what the skill delivers, so the dispatcher can
  weigh it against neighbors: "Use when X — does Y."
- Include trigger vocabulary verbatim. If users say "review my diff", the
  words "review" and "diff" belong in the description, not synonyms.
- A skill that never fires is dead weight: it costs registry space and
  reader attention while delivering nothing. Write the description for the
  dispatcher, then test it: given the target request, would THIS line win
  against every other installed skill?

## One capability per skill

Scope a skill to a single capability with a single trigger.

- The test: state what the skill does in one sentence without "and". If you
  cannot, it is two skills.
- Split when the body needs headings for unrelated behaviors — if a reader
  who came for section A never needs section B, they are two skills
  fighting over one trigger.
- Splitting also sharpens descriptions: two narrow triggers each beat one
  vague umbrella trigger.

## The 100–150 line budget

This marketplace rejects bodies under 100 or over 150 lines. The budget is
a feature, not a ceiling to resent:

- Brevity forces prioritization. Each line must earn its place against the
  line it displaces.
- Link references instead of inlining walls: point to a spec file, script,
  or doc path and state only the rule the reader needs right now.
- Under 100 lines usually means the skill restates the obvious or is too
  thin to be a skill at all; over 150 means it is two skills or a doc that
  belongs elsewhere with a pointer here.

## Body structure

Order the body the way a reader under time pressure consumes it:

1. Rules first — the imperatives the skill exists to enforce.
2. Examples second — one concrete good/bad pair beats three paragraphs of
   qualification.
3. Anti-patterns last — failure modes with names, so reviews can cite them.

Style:

- Imperative voice throughout: "Start with", "Split when" — never "it is
  recommended that".
- No filler: no introduction restating the title, no closing summary, no
  hedging boilerplate.
- Headings carry the skeleton; a reader skimming only headings should still
  reconstruct the skill's argument.
- Show commands and paths as literal, copyable text, not prose descriptions
  of them.

## Handoff offers, not homework

When a skill or command finishes and a logical next step exists as another
command (run the cards, apply the fixes, review the diff):

- OFFER it as a selectable choice (AskUserQuestion): "Run X now
  (Recommended)" / "Skip — I'll run it later". The user picks; nobody types.
- Print the bare command as text ONLY in headless runs where selection UI
  is unavailable — and print it exactly, copy-paste ready.
- Never auto-run the next step silently; the offer IS the consent gate.
- One offer per handoff moment — a completion that spawns three questions
  is a quiz, not a handoff.

## Common failures

- Vague descriptions. "Helps with testing" gives the dispatcher nothing to
  match on. Name the trigger: "Use when writing pytest fixtures — …".
- Overlapping skills. Two skills whose descriptions both plausibly match
  the same request fire unpredictably. Merge them, or sharpen both
  descriptions until requests partition cleanly between them.
- Restating general knowledge. The model already knows what a unit test is;
  a body explaining it wastes budget. Spend lines only on what is local:
  this repo's conventions, thresholds, paths, and commands.
- Name/directory drift. Renaming the directory without updating `name:` (or
  vice versa) fails validation — they must match exactly.
- Body written before description. Author the trigger first; if you cannot
  write a sharp "Use when …", the capability is not yet a skill.
