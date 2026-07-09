# Piece 4 — Durable Visual Contract (Design v2)

- **Date:** 2026-07-09
- **Status:** Draft v2 — red-teamed (3 lenses), pending user approval
- **Depends on:** Piece 2 (staged decisions in the design doc) and the existing grill→visual-decisions path (staged picks as CLEAR ledger rows quoted into the spec). Mirrors the `erd` → `## Data Model` binding-contract pattern.
- **Scope (touched):** new `plugins/taskmaster/skills/visual-contract/SKILL.md`; edits to `grill/SKILL.md` (a handoff line, net-neutral), `task-cards/SKILL.md` (merge the binding-contract rule), `spec-redteam/SKILL.md` + `agents/spec-adversary.md` (add a fifth lens *consistently*), `coverage-check/SKILL.md` (cover the contract). All prose, no code.

## What the red-team corrected (v1 → v2)

- **grill IS edited.** `erd` is not description-triggered — grill explicitly invokes it (`grill:84-85`) and grill alone writes the spec (`grill:123`). So visual-contract needs an explicit grill handoff. grill body is 149/150, so the handoff is added **net-neutral** (one line in, one genuinely redundant line out, honest recount).
- **Payload is a structural description, not JSX.** The recorded sources carry no artifact — brainstorm's Staged decisions is `label+rationale+tier` (`brainstorm:114`), visual-decisions records a mockup *path* and mockups "die at the pick" (`visual-decisions:37,141`). So the contract binds label + lane + a **precise structural description** + rationale, reconstructed at spec time. (Capturing live JSX at pick time is a future Piece-2 enhancement, out of scope here.)
- **Both sources.** A direct-grill task has no design doc; its visual picks are CLEAR ledger rows quoted into the spec. visual-contract binds from BOTH the design-doc Staged decisions AND grill's CLEAR visual/creative ledger rows — gated on "any staged/visual CLEAR decision exists," not just the design-doc section.
- **Spec section renamed** `## Visual contract` (not "Staged decisions") to avoid a same-name collision with the design doc's section (different schema).
- **Fifth adversary lens updated consistently** everywhere the count is hardcoded.

## Problem

Survey gap 7: `erd` embeds `## Data Model` as a binding contract (`erd:118`) and task-cards forces persistence cards to conform (`task-cards:64-65`, deviation → re-approval). Visual/creative picks get nothing — they die at the pick, cards have no visual reference, spec-redteam and coverage-check never inspect them, so a UI card can silently drop the chosen layout and nothing flags it.

## Goal

Give staged visual/creative decisions the same durable, enforced contract the data model has: a binding spec section, cards that must conform, an adversary lens that attacks it, coverage that counts it.

## Non-goals

- Re-deciding anything (staging is Pieces 2–3). Capturing live JSX at pick time (a Piece-2 change). Any engine/template code.

## Chosen approach — mirror erd, honestly

**1. New skill `visual-contract` (erd-sibling, grill-invoked).** During spec writing, it collects every staged visual/creative decision from **both** sources (design-doc Staged decisions + grill's CLEAR visual ledger rows) and embeds them as a binding `## Visual contract` spec section. One entry per decision: decision, **lane**, chosen variant (label), a **precise structural description** (placement / data-viz / what varies), and a one-line rationale. Declares the section a **binding contract**: implementation follows it; a deviation mid-card goes back through re-approval, never drift — erd's wording (`erd:118-120`). Real substance to fill 100+ lines honestly: the two-source collection rule, the structural-description format, the reconstruct-from-record method, a worked example, the relation to `## Data Model`, anti-patterns. Fires only when a staged/visual decision exists (backend specs get no section, no nag).

**2. grill handoff (net-neutral edit).** Add one line beside the erd handoff (`grill:84-85`) or in the spec-write step (`grill:123`): "visual/creative picks staged → switch to the `visual-contract` skill to bind them." Remove one genuinely redundant grill line in the same edit to stay ≤150; recount honestly.

**3. task-cards — merge the binding-contract rule (net +1).** Merge the Data Model bullet (`task-cards:64-65`) with the new one: "Cards that touch a binding contract section — `## Data Model` for persistence, `## Visual contract` for visual/creative surfaces — must reference it and conform; deviation → re-approval, not drift." A "staged surface" card = one whose Files/Context implement a UI/content element named in `## Visual contract`. Net +1 line → 148/150 (body is 147, headroom 3).

**4. spec-redteam + spec-adversary — a fifth lens, consistently.** Add **visual/experience coherence** (does every `## Visual contract` entry have a conforming card; is any staged decision self-contradicting or unbuildable-as-described). Flip every hardcoded "four" → "five" in `spec-adversary.md` (:16, :19, :58) + its frontmatter description enumeration (:3), and in `spec-redteam/SKILL.md` (:3 + body). The lens is **no-op when the spec has no `## Visual contract` section** (no nag on backend specs).

**5. coverage-check — cover the contract.** Each `## Visual contract` entry is a coverable item mapped to ≥1 card; reverse-check flags a card that alters a named surface with no backing entry (drift). Add a matrix row-type and staged-decision resolution options (fold into a card · defer the surface with re-approval · accept as covered elsewhere) — the current gate is success-criteria-only.

## Lineage

brainstorm records staged decisions (Piece 2) OR grill stages via visual-decisions → `visual-contract` binds both into the spec's `## Visual contract` (Piece 4) → task-cards enforces → spec-redteam attacks + coverage-check counts. The data-model lineage, one lane over — both entry paths covered.

## Versioning

taskmaster (new skill + four skill edits + agent edit) → `0.18.0 → 0.19.0` (enforced). Bump marketplace metadata version.

## Success criteria

**Script-verifiable:** (1) `visual-contract/SKILL.md` body 100–150; `grill`, `task-cards`, `spec-redteam`, `coverage-check` bodies all ≤150 after edits; `validate.sh` passes. (2) taskmaster bumped; `check-version-bumps.sh` passes. (3) `spec-adversary.md` frontmatter valid; and the lens count is **consistent** (no "four" left in spec-adversary.md or spec-redteam) — a manual check, since validate won't catch it.

**Behavioral:** (4) `visual-contract` binds a `## Visual contract` section from both sources, declared binding with deviation→re-approval. (5) grill hands off to it; task-cards' merged rule covers both contracts. (6) spec-adversary attacks the visual lens (no-op when absent); coverage-check maps each entry to a card with resolution options for gaps.

## Open risks

- grill's net-neutral edit must find one genuinely redundant line; if none exists, grill overflows and the handoff must live elsewhere (e.g. visual-contract self-triggers as a fallback with a weaker guarantee) — verify at edit time.
- The structural-description payload is weaker than live JSX; the durable value is the binding + enforcement, not pixel fidelity. Stated honestly.
- Two binding sections (`## Data Model`, `## Visual contract`) share one merged card rule — keep their coverage correspondences distinct.
