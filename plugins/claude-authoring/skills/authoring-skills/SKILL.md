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
- The body — every line after the closing `---` — is at most 150 lines.

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

## The 150-line ceiling

A body over 150 lines fails the build. There is **no floor** — a skill that
says its piece in 60 lines is finished, not thin:

- Brevity forces prioritization: each line earns its place against the line
  it displaces.
- Link references instead of inlining walls — point to a spec, script, or doc
  path and state only the rule the reader needs right now.
- Over 150 lines means two skills, or a doc belonging elsewhere.

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

## The four laws

Applying sites cite `claude-authoring/skills/authoring-skills/SKILL.md`, "The
four laws", by path — a path citation works without this skill firing.
Derivation: `references/doctrine.md`. Standing: **recorded** — nothing checks
that an applying site cites it; law 4's ratchet is the only partial gate.

- **Proportionality.** Size the ceremony to the blast radius. Counts are
  ceilings, not quotas — pick the smallest N covering the risk; never fill a
  number because it was written down. Local thresholds stay local.
- **Honest limitation.** A gate names what it converts from silent to blocking,
  and what stays prose. State the residual; a hidden one gets trusted.
- **The theater test.** Name what the ceremony catches that nothing else
  catches. No answer means theater — a check that cannot fail included.
- **Admission.** An artifact earns existence by carrying a rule nothing else
  carries. Prefer the smallest artifact that works; delete, don't deprecate.

## Say what has teeth

The taxonomy for the honest-limitation law above. Some rules are checked by a
script, some judged by an agent, most only written down — and a reader cannot
tell which from the sentence. Name a rule's standing where it is stated:

| Standing | Means |
| --- | --- |
| **gate** | a script fails the build — name the script and check |
| **agent-graded** | a reviewer judges it; real variance, still a real check |
| **recorded** | written to an artifact; nothing reads it back |
| **unenforceable** | cannot be checked as stated — say why |

Naming a blind spot is not weakness; calling an agent-graded check a gate is
the over-claim. And a rule that keeps being broken is not under-stated — it is
in the wrong tier, and needs a hook, a script, or a tool the model reaches for
instead of another paragraph.

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
