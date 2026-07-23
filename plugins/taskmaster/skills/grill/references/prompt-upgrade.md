# Prompt-upgrade — sharpen the raw prompt once the scout lands

At grill activation, after the context-scout report is folded into the ledger and
before the interrogation rounds begin, derive an **improved task statement** from
the raw prompt plus that report. A raw ask is almost always underspecified;
upgrading it up front gives every downstream phase (grill rounds, the spec, the
cards) the sharpest possible starting point — and it is the one improvement that
lands even on a hands-off run where no user is present to clarify.

This step is **mode-agnostic**: it runs the same in an interactive run and a
hands-off one. It records nothing mode-specific — the goal-mode ledger recording is
owned by the `ultra` skill's Goal mode, not here.

## Procedure

1. **Investigate first.** The derivation waits for the context-scout report —
   never author the statement from the raw words alone. The report, not memory,
   is where "what currently exists" comes from.
2. **Derive.** Read the raw prompt and the scout report, and write a tighter
   restatement that grounds three facets:
   - **why the task is wanted** — the concrete outcome the raw ask is after
     (who, what changes, where);
   - **what currently exists** — the relevant code, patterns, and hard
     constraints (gates, versions, conventions) the scout report established;
   - **how the current state is lacking** relative to that outcome — synthesized
     by the deriver from the two facets above; the scout stays facts-only and
     never opines.
   In doing so, name what a better prompt would have specified — the constraints,
   scope boundaries, and success shape the raw ask left implicit.
3. **Show it with the first ledger print.** Print the upgraded statement together
   with the first ambiguity-ledger table so the user sees, from round one, the
   statement the interrogation is actually working from. In an interactive run this
   is itself a cheap confirmation prompt; a wrong sharpening gets corrected early.
4. **Embed it in the spec header.** When the spec is written, carry the pair into
   its header under the exact labels `**Raw prompt:**` and `**Upgraded statement:**`
   — these labels are parse anchors for downstream steps (task-cards copies the
   statement into `00-INDEX.md` from the second label; spec red-teaming's
   statement-fidelity sub-check compares the two) — so the frozen spec records
   what was actually built toward, not just the raw words.

## Special inputs

- **Brainstorm design doc.** When grill's input is an approved brainstorm design
  doc rather than a raw prompt, degrade to a light confirmation: restate the
  doc's goal as the upgraded statement (same sinks, same labels). The approved
  doc already encodes the triple; do not force a full re-derivation of an
  already-shaped document.
- **Resume.** A statement already recorded (in the resume ledger header or the
  goal ledger) is REUSED on resume — never silently re-derived. If none was
  recorded before the interruption, re-run grill Step 0; re-scout is allowed in
  exactly this case.

## Quality bar

An upgrade must add **constraints and success-shape**, not synonyms. Rewording the
same vagueness in fancier words is not an upgrade — it is noise. A good upgrade is
one a reader could hand to a fresh implementer with materially less room to build
the wrong thing than the raw prompt left. If the sharpened statement would not
change what gets built versus the raw ask, you have not upgraded it.

## The scope rule — sharpen, never reinterpret

The upgraded statement **never overrides what the user actually asked**. It
sharpens; it does not reinterpret scope. It may make the goal concrete, name
implied constraints, and expose the success shape — it may **not** add capabilities
the user did not request, drop ones they did, or swap the objective for a
"better" one you preferred. When sharpening would require a scope decision the raw
prompt does not settle, that is a question for the interrogation (or an ASSUMED row
with a named default), not a silent rewrite. The raw prompt remains the authority
on *what*; the upgrade only clarifies it.

## Worked example

**Raw prompt:** "Go over the marketplace, fix any bugs that will result in AI
skipping tasks, or not checking where the code is used, skipping research, we want
ultra-deep-research to be good" — plus a mid-run addition: "improve self prompting …
to improve ultra-goal or other tasks."

**Upgraded statement:** *In the cc-marketplace repo, find and fix defects in plugin
prompt-content (SKILL.md, references, agents, commands, hooks, templates) where a
safeguard against (a) silently skipping tasks/steps, (b) changing a symbol without
checking its call sites, or (c) answering from memory instead of fetching, exists on
one execution path but is absent, contradictory, or unenforceable on another —
prioritizing ultra-deep-research's refutation/verification teeth. Additionally, give
the taskmaster pipeline a prompt-upgrade step that derives exactly this kind of
improved task statement from any raw prompt plus the scout's findings. Every fix must pass
validate.sh, check-version-bumps.sh, generate.sh --check, and the CI smoke suites.*

Notice what the upgrade added and what it did not. It **added**: the concrete
surface (which file kinds count as prompt-content), the precise defect shape (a
safeguard present on one path, absent/contradictory on another), a priority order,
and the enforcement gates every fix must clear — the kind of facts a scout report
supplies. It did **not** invent new goals — "fix skip bugs", "check usage", "don't
skip research", and "improve self-prompting" are all still exactly the user's asks,
only made concrete and testable.
