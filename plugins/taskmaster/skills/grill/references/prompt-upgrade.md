# Prompt-upgrade — sharpen the raw prompt at activation

At grill activation, before the interrogation begins, derive an **improved task
statement** from the user's raw prompt. A raw ask is almost always underspecified;
upgrading it up front gives every downstream phase (grill rounds, the spec, the
cards) the sharpest possible starting point — and it is the one improvement that
lands even on a hands-off run where no user is present to clarify.

This step is **mode-agnostic**: it runs the same in an interactive run and a
hands-off one. It records nothing mode-specific — the goal-mode ledger recording is
owned by the `ultra-goal` skill, not here.

## Procedure

1. **Derive.** Read the raw prompt and write a tighter restatement that:
   - sharpens the goal into a concrete outcome (who, what changes, where);
   - names what a better prompt would have specified — the constraints, scope
     boundaries, and success shape the raw ask left implicit;
   - surfaces implied constraints already true in this repo (gates, versions,
     conventions the change must respect).
2. **Show it with the first ledger print.** Print the upgraded statement together
   with the first ambiguity-ledger table so the user sees, from round one, the
   statement the interrogation is actually working from. In an interactive run this
   is itself a cheap confirmation prompt; a wrong sharpening gets corrected early.
3. **Embed it in the spec header.** When the spec is written, carry the upgraded
   statement into its header (raw prompt + upgraded statement, as a pair) so the
   frozen spec records what was actually built toward, not just the raw words.

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
improved task statement from any raw prompt at run start. Every fix must pass
validate.sh, check-version-bumps.sh, generate.sh --check, and the CI smoke suites.*

Notice what the upgrade added and what it did not. It **added**: the concrete
surface (which file kinds count as prompt-content), the precise defect shape (a
safeguard present on one path, absent/contradictory on another), a priority order,
and the enforcement gates every fix must clear. It did **not** invent new goals —
"fix skip bugs", "check usage", "don't skip research", and "improve self-prompting"
are all still exactly the user's asks, only made concrete and testable.
