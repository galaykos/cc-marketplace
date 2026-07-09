# Piece 5 — Richer Option Rationale (Design)

- **Date:** 2026-07-09
- **Status:** Draft — pending red-team + user approval
- **Depends on:** Piece 1 (harness), Piece 3 (deep-staging — which deliberately kept a one-line tradeoff and deferred richer rationale HERE), Piece 4 (visual-contract entry format).
- **Scope (touched):** `shadcn-studio` template (`stage.config.ts`, `VariantStage.tsx`, the sample variant configs), `shadcn-studio/skills/deep-staging/SKILL.md`, `shadcn-studio/skills/studio/SKILL.md` (one line), `taskmaster/skills/visual-contract/SKILL.md`. **Not touched:** brainstorm (maxed) unless a net-neutral wording swap is trivial; no question-quality doctrine (out of scope per the scope decision).

## Problem

Staged options carry a single one-line `tradeoff` (Piece 1/3). The survey's "3–4 options + a sentence isn't enough" is only half-fixed: the options are now interactive and multi-state (Pieces 1–3), but the *reasoning* per option is still one sentence. Piece 3's red-team explicitly moved richer rationale here rather than bleed Piece 3's scope.

## Goal

Upgrade each staged option's rationale from one line to **serves / trades / breaks** — who it serves, what it trades away, when it breaks — rendered in the harness, taught in deep-staging, and carried into the binding `## Visual contract` so the depth reaches the spec, not just the screen.

## Non-goals

- Question-quality doctrine (brainstorm/grill already carry it; out of scope per the scope decision).
- Any new skill or design-doc gate. Theming. New dependencies.

## Chosen approach

**1. Template schema (`stage.config.ts`).** Replace `tradeoff: string` on `VariantEntry` with `rationale: { serves: string; trades: string; breaks: string }`. Keep everything else (id, label, lane on StageConfig, Component signature) unchanged.

**2. Harness (`VariantStage.tsx`).** Replace the single-line `CardDescription` tradeoff with a compact three-part rationale block (labeled Serves / Trades / Breaks), styled from the shell — equal fidelity per variant, no per-variant restyle. Keep it terse (one short line each) so three variants stay comparable at a glance.

**3. Sample variant configs (`App.tsx`).** Update the design + dataviz + creative stage configs to supply the three-part rationale for each variant (realistic, specific).

**4. deep-staging doctrine.** Change "each variant carries a one-line `tradeoff`; richer per-option rationale is a later concern" to the serves/trades/breaks format: what each field means, keep each to one line, and the "don't pad" rule (a rationale that can't name a real trade or break is a variant that isn't actually different).

**5. studio + visual-contract.** studio/SKILL.md: update its one "one-line tradeoff" mention to "a three-part serves/trades/breaks rationale". visual-contract/SKILL.md: the entry's "Rationale — the one line for why it won" becomes the three-part rationale so the binding contract records the full reasoning, not a caption.

## Verification plan

Re-run the template proof: `npm ci` + `npm run build` exit 0 (the schema change must update every consumer — the two design variants, the chart variant, and App — or tsc fails, which is the guardrail), dev boot 200 + `/__studio`, the three-part rationale renders per variant. Then validate + version-bump. Confirm no skill still says "one-line tradeoff".

## Versioning

shadcn-studio (template + skills) → `0.2.0 → 0.3.0`. taskmaster (visual-contract edit) → `0.19.0 → 0.20.0`. Bump marketplace metadata version. Both enforced by check-version-bumps.

## Success criteria

**Script-verifiable:** (1) `npm ci` + `npm run build` exit 0 from the committed lockfile (the `VariantState`/config change type-checks across all variants). (2) `validate.sh` passes; deep-staging/studio/visual-contract bodies stay 100–150. (3) shadcn-studio + taskmaster bumped; `check-version-bumps.sh` passes. (4) `grep -ri "one-line tradeoff"` across the touched skills returns nothing.

**Behavioral:** (5) The harness renders Serves/Trades/Breaks per variant on boot. (6) deep-staging teaches the format; visual-contract's entry carries all three fields.

## Open risks

- The schema change ripples to every variant Component config — that is the guardrail (tsc fails if one is missed), not a hazard, but the build must be re-proven.
- Three lines per variant risks visual clutter with three variants side by side; keep each field to a short clause and let the shell style it uniformly.
- brainstorm's design-doc "Staged decisions" still says "one-line rationale" (maxed skill); if not swapped net-neutral, note the minor asymmetry (the binding spec is richer than the design-doc record — acceptable, the spec is authoritative).
