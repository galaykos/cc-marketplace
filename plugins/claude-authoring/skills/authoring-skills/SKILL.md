---
name: authoring-skills
description: Use when writing or editing a SKILL.md — trigger-rich descriptions, line budgets, one-capability scoping, validator frontmatter rules.
---

## Anatomy

One skill is one directory holding one file:

    plugins/<plugin>/skills/<skill-name>/SKILL.md

YAML frontmatter between dash-fence lines, then the body — the instructions
loaded when the skill fires:

    ---
    name: <skill-name>
    description: Use when <trigger> — <what it delivers>.
    ---
    <body>

`scripts/validate.sh` enforces: line 1 is exactly `---` with a closing `---`;
`name:` present and equal to the directory name; `description:` present; and the
body within the budget below. Measure it before committing:

    awk '/^---$/{c++; next} c>=2' SKILL.md | wc -l   # and | wc -c

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
- Trigger conditions ONLY, never a workflow recap — a description that
  summarizes steps makes the model follow the summary and skip the body.
  It answers "should I load this now?", not "what does this do?".
- A skill that never fires is dead weight: it costs registry space and
  reader attention while delivering nothing. Write the description for the
  dispatcher, then test it: given the target request, would THIS line win
  against every other installed skill?
- Baseline a NEW behavioral skill: run the scenario WITHOUT it and record the
  failure — none means the skill restates what the model already does. Loop in
  `references/behavioral-testing.md` (RUNNER: the host `skill-creator`, not
  ours). <!-- host-ok --> Check `rationale/measured-zero-shapes.md` first — four
  shapes measured at zero. Standing: **recorded** — no script runs the baseline.

## Activation fields — measured, not assumed

`paths:` fires on an EDIT to a matching file — not a read, not mere existence —
and on a PLUGIN skill it does NOT drop the description from the listing, so it
buys reach, never budget. `disable-model-invocation: true` does drop it, at the
cost of the skill's only automatic channel: right for a command's implementation,
wrong for a prompt-shaped trigger. Measured on 2.1.237, with the meter's own
error: `references/activation-fields.md`.

## One capability per skill

Scope a skill to a single capability with a single trigger.

- The test: state what the skill does in one sentence without "and". If you
  cannot, it is two skills.
- Split when the body needs headings for unrelated behaviors: a reader who came
  for section A and never needs section B is two skills fighting one trigger.

## The body budget — three measures, no floor

A body fails the build over **200 lines, 14,000 bytes, or 300 characters on one
line**. The last two were added after a skill sat at a frozen 154 lines for 20
commits while its bytes grew 31%: content stops adding lines and starts jamming
them. Lines and bytes were raised from 150/10,000 on 2026-08-27 because the
ceiling had become a target — 24 of 116 bodies sat at EXACTLY 150. The
line-length measure was deliberately NOT raised: jamming is the symptom, and
relaxing the symptom check would have hidden the evidence. Pressure now sits in
`pc_budget_crowding`, a ratchet at the new ceiling (**gate**). There is **no floor** — 60 lines that say their piece is finished, not
thin. Over any measure means two skills, or a `references/` file: point to a
path and state only the rule the reader needs right now.

## Body structure

Order the body the way a reader under time pressure consumes it:

1. Rules first — the imperatives the skill exists to enforce.
2. Examples second — one concrete good/bad pair beats three qualifications.
3. Anti-patterns last — failure modes with names, so reviews can cite them.

Style:

- Imperative voice, no filler: "Start with", "Split when" — never "it is
  recommended that"; no intro restating the title, no closing summary.
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
- Never auto-run the next step silently; the offer IS the consent gate, and one
  offer per moment — a completion that spawns three questions is a quiz.

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
the over-claim. A rule that keeps being broken is in the wrong tier — it needs
a hook, script, or tool, not another paragraph. Real cases: a "never write
component APIs from memory" line broken three times in one session by the model
that had it loaded; a design axis chosen every run and checked by no assertion.

Model-tier scoping applies the same honesty to WHO needs a rule: procedure that
compensates weaker models over-constrains stronger ones. Mark **All models** vs
**Compensation (worker-tier)**, give every procedure skill a skip-clause —
`references/model-tier-scoping.md`; agent MODEL minimums are role-floors.

## Common failures

- Vague descriptions. "Helps with testing" gives the dispatcher nothing to match
  on. Name the trigger: "Use when writing pytest fixtures — …".
- Overlapping skills. Two descriptions that both plausibly match one request
  fire unpredictably — merge, or sharpen until requests partition cleanly.
- Restating general knowledge. The model knows what a unit test is; spend lines
  only on what is local — conventions, thresholds, paths, commands.
- Body before description. Author the trigger first — no sharp "Use when …"
  means the capability is not yet a skill.
