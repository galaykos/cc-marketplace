# Piece 3 — Staging Lanes, Depth & Dataviz (Design v2)

- **Date:** 2026-07-09
- **Status:** Draft v2 — red-teamed (3 lenses), pending user approval
- **Depends on:** Piece 1 (`shadcn-studio` engine + harness) and Piece 2 (brainstorm staging routing), both committed on this branch.
- **Scope (touched files):** new `plugins/shadcn-studio/skills/deep-staging/SKILL.md` + `skills/deep-staging/references/dataviz-cheatsheet.md`; edits to `plugins/shadcn-studio/skills/studio/SKILL.md` (wire + toggle line); extend `template/` (harness, sample variants, deps). **Not touched:** `visual-decisions`, `brainstorm` (Piece 2's routing already reaches here — see wiring), the durable contract (Piece 4), rationale-wording quality (Piece 5).

## Problem

Survey gaps 2–4 — the "3–4 thin options" the user rejected: no creative lane, no dataviz (a host skill, not in this marketplace), and Piece 1 shipped only a minimal `populated↔empty` toggle. The engine renders arbitrary JSX and is lane-agnostic; it has the vehicle but no doctrine for *what to vary and how deep* per kind of decision.

## Goal

Give staged options real substance: formal **lanes** (design / creative / dataviz) as authoring doctrine, a **depth matrix** (exercise the states meaningful to the lane), and a **self-contained dataviz** capability — a staged decision becomes a populated, multi-state, real-interactivity artifact, not one frame with a caption. **Rationale wording stays one-line (Piece 5 owns richer rationale)** — this piece is lanes + states + charts only.

## Non-goals

- Richer per-option rationale wording (serves/trades/breaks) — **Piece 5** (this corrects the Piece-1 note; Piece 3 keeps the one-line `tradeoff`).
- The durable, enforced visual contract into cards (Piece 4).
- Editing visual-decisions or brainstorm. Theming as a decision axis (color stays constant).

## Chosen approach

**1. New skill `deep-staging` (in the shadcn-studio plugin).** Owns lane + depth doctrine; invoked by `studio`'s "Author the variants" step (scoped edit below). Body ~110–135 lines; the dataviz cheat-sheet is **offloaded to `references/dataviz-cheatsheet.md`** (uncounted by validate, mirrors the host dataviz skill's references/ convention) so it neither bloats the 150-line body nor drifts silently.

- **Design lane** — vary layout/placement/density; hold content + theme constant.
- **Creative lane** — hold layout constant; each variant a different concept/content direction, N divergent (main-thread authored, per Piece 2). **Populated state only.**
- **Dataviz lane** — chart-type / encoding / dashboard decisions rendered with the real shadcn `chart` (Recharts). Guidance: **when the host `dataviz` skill is installed it GOVERNS; when absent, `references/dataviz-cheatsheet.md` is the fallback floor** (a deliberately frozen minimal set — form heuristic, encoding discipline, when-not-to-chart — that does NOT track the host skill; staleness is by design, documented).

**2. Depth matrix — single lane per stage, variant owns its states.** One ownership model, stated to kill the harness ambiguity:
- `lane` lives on **StageConfig** (a stage is entirely one lane).
- `VariantStage` derives the toggle set from the stage lane: data lanes (design/dataviz) expose `empty | loading | error | populated`; creative exposes `populated` only (no toggle).
- **Each variant Component renders all states of its lane itself** (consistent with today, where variants self-render `empty`). The harness only routes `state` and gates the toggle set — it does NOT short-circuit loading/error into a generic block. So the shipped sample variants MUST gain `loading` (Skeleton) and `error` branches; a widened `VariantState` union is non-exhaustive (missing states fall through silently, no TS error), so this is a required edit, not automatic.

**3. Template / harness extensions (`template/`).**
- `stage.config.ts`: widen `VariantState` to the four-state union; add `lane: 'design'|'creative'|'dataviz'` to **StageConfig**. Keep the one-line `tradeoff` (no rationale change).
- `VariantStage.tsx`: render the toggle buttons from the stage lane's state set (all four for data lanes; none/populated for creative).
- Edit `VariantA.tsx` + `VariantB.tsx`: add `loading` (Skeleton) and `error` branches so the four-state demo is real.
- Add `src/components/ui/skeleton.tsx` (no new dep) and `src/components/ui/chart.tsx` (shadcn v4 shape — the `--chart-1..5` tokens already exist in `index.css:26-30/60-64/98-102`, so no token work).
- Add **`recharts ^3`** (3.9.x — same React-19 peer as ≥2.15 but drops the `defaultProps` console warnings; identical chart.tsx wiring). Add one **dataviz sample variant** rendering a real chart.

**4. Wire `studio` → `deep-staging` (scoped studio/SKILL.md edit).** `studio`'s "Author the variants" step calls `deep-staging` to pick the lane + depth; update the toggle line (`studio/SKILL.md:72`) from "populated↔empty" to the lane-derived state set. Lane selection (incl. recognizing a chart decision → dataviz lane) happens **inside deep-staging at authoring time**, so a chart decision reaches it through brainstorm's existing "greenfield/non-React" routing row — **brainstorm needs no dataviz row**. Re-check studio's body ≤150 after the edit (currently 114).

## Verification plan

Refresh the lockfile with `npm install recharts@^3 --package-lock-only`, then assert **additive-only** and the native matrix survived (`grep -cE '"(os|cpu)":' package-lock.json` unchanged at its current count). Re-run the Piece-1 proof on the extended template: `npm ci` + `npm run build` exit 0; dev boot 200 + `/__studio`; a **dataviz variant renders a real Recharts chart**; the **four-state toggle** switches live on a data-lane stage. Then validate + version-bump.

## Versioning

shadcn-studio → `0.1.0 → 0.2.0` (enforced). Bump marketplace metadata version.

## Success criteria

**Script-verifiable:** (1) `deep-staging/SKILL.md` body 100–150; `validate.sh` passes; no `/plugin:command` slash form for any non-marketplace tier (host `dataviz` is referenced in prose only — a `/dataviz:…` token would hard-fail `validate.sh:78`). (2) shadcn-studio bumped; `check-version-bumps.sh` passes. (3) `npm ci` + `npm run build` exit 0 from the refreshed lockfile; lockfile os/cpu-gated entry count unchanged (additive-only diff).

**Behavioral / observed:** (4) A data-lane stage boots with a four-state toggle switching live across all shipped variants (including a Recharts chart in the dataviz variant). (5) The skill defines all three lanes (varies / holds-constant) and scopes states per lane (creative = populated only, its toggle suppressed). (6) The dataviz cheat-sheet lives in `references/`; the host `dataviz` skill governs when present, the floor is used only when absent.

## Open risks

- `recharts` pulls a large transitive `d3-*` subtree into the isolated `npm ci`; mitigation posture: pinned lockfile + the studio flow's `--ignore-scripts` consideration. Note the enlarged supply-chain surface.
- The four-state edit touches every variant Component; a new variant that omits a state fails silently (non-exhaustive union) — call this out in deep-staging so authors add all lane states.
- deep-staging + studio must not overlap: **studio = provision/serve/cleanup; deep-staging = what/how-deep to author.** Keep the boundary in both skills' text.
- studio/SKILL.md gains a reference + toggle edit against a 114→≤150 budget — honest recount required post-edit.
