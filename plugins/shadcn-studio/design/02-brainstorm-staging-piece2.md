# Piece 2 — Brainstorm Always-On Staging Doctrine (Design v2)

- **Date:** 2026-07-09
- **Status:** Draft v2 — red-teamed (3 lenses), pending user approval
- **Depends on:** Piece 1 (`shadcn-studio`, committed on this branch) for the greenfield interactive tier; `design-preview` for the host-app interactive tier. Both are **optional installs** — the doctrine degrades when either is absent (below).
- **Scope:** Edit `plugins/taskmaster/skills/brainstorm/SKILL.md` ONLY. Not touched: `visual-decisions` (150-line ceiling — used as a rendering backend, its consent gate reconciled by prose, never edited), the engine (Piece 1), formal lanes/depth/dataviz (Piece 3), any durable machine-enforced contract (Piece 4).

## Problem

Gaps 1–2 from the survey: brainstorm makes visuals conditional (`SKILL.md:50` "when genuinely visual"), and the path it delegates to (`visual-decisions`) opens a consent gate whose third option is "No mockups → dormant for the session" (`visual-decisions:24`) — a **session-wide existence skip**. Creative/concept options have no rendered home at all. The design doc has no section for staged decisions, and the self-review never checks staging happened.

## Goal

Make staging a **standing, per-decision part of the brainstorm dialogue** for any idea with a confirmed UI or creative surface. Staging means: **a rendered artifact where the chosen fidelity permits, and ALWAYS a recorded staged decision** (label + one-line rationale) in the design doc. Consent chooses **fidelity per decision**; it never makes staging **session-dormant**. Cover both **design** (layout/placement) and **creative** (concept/content) options.

## Non-goals

- The interactive engine (Piece 1). Formal design/creative/**dataviz** lanes + depth (Piece 3). A durable machine/agent-enforced visual contract into cards (Piece 4) — Piece 2 records into the **design doc** only, prose-enforced.
- A single cross-tier "live URL" that accretes picks — that is the URL-unification Piece 1 explicitly deferred. Each tier renders at its own surface and dies at the pick; **accretion lives in the design doc**, not a live surface.
- Editing `visual-decisions` or `approaches`.

## Chosen approach — the brainstorm SKILL.md edits

**1. Brainstorm OWNS one session fidelity consent (this resolves the core conflict).**
On the first staged decision, brainstorm runs its OWN `AskUserQuestion` with the fidelity tiers and **no dormant/none option** (floor = describe-only, which still records a decision). It then uses `visual-decisions` purely as a **rendering backend** for the shell tier — it does **not** delegate the consent DECISION. Because both skills are prose read by one agent, brainstorm treats its answered staging consent as `visual-decisions`' already-answered first-use gate: map shell→"Full mockups", ASCII→"Quick ASCII only", **never re-fire that gate, never surface "No mockups"**, and keep describe-only inside brainstorm so it never enters visual-decisions. No edit to visual-decisions required.

**2. Three trigger states (reconciles "always-on" with "don't nag backend ideas").**
Keyed on context-scout's **Visual surface** sentinel (always present; literal `None` for backend):
- Surface confirmed **≠ None** → staging is **mandatory** (floor = recorded describe-only, no skip).
- Surface **unknown** (scout absent/uncertain) → a **skippable offer**, distinct from the no-skip floor.
- Surface **= None** (backend) → **no staging**.

**3. Auto-route fidelity by host + decision KIND (consent may downgrade).**

| Decision kind & situation | Tier |
|---|---|
| Design, runnable Vite+React host | `design-preview` (`/design-preview:preview`) |
| Design, greenfield/non-React, interactivity matters | `shadcn-studio` (`/shadcn-studio:stage`) |
| Design, structure/density/flow only | visual-decisions shell (as backend) |
| Design, trivial layout | ASCII wireframe |
| **Creative/concept** | interactive tier **only** (`shadcn-studio`/`design-preview`), else **describe-only** |

Creative **never** routes to the visual-decisions shell (it bans text-native options) or ASCII (structural). **Interactive tier unavailable** (plugin not installed) → drop to the next lower design fidelity, or describe-only for creative, **and tell the user which fidelity was lost**. Degradation defers to visual-decisions' own fidelity ladder — one source of truth, not a restated tool list.

**4. Creative generation — NOT opinion-round.**
`approaches:opinion-round` is a fixed engineering-persona panel that converges to one pick; it is the wrong tool for divergent concept ideation. Creative concept variants are **main-thread-authored** as N divergent directions, rendered side-by-side at the interactive tier (or enumerated at describe-only). The `opinion-lens` reuse stays strictly for **design/architecture shape** deliberation (its blessed use), unchanged.

**5. Sequencing (respects one-question-at-a-time).**
The first visual/creative question triggers the single fidelity-consent question (once per session). Thereafter each question stages exactly **one** decision's options; the design doc accretes only accepted picks. Never render a surface that poses several decisions at once — that is a firehose in visual form.

**6. Design-doc + self-review.**
- Add a **required** "Staged decisions" section to the design doc, populated whenever Visual surface ≠ None (each entry: label + one-line rationale + tier/URL if rendered, or "describe-only").
- Add a self-review **prompt** (not a machine gate): "did every visual and creative decision get staged and recorded?" Honest framing: this is model self-review like the rest of brainstorm's self-review; a real enforced gate is Piece 4.

## Line-budget plan (hard constraint, honest numbers)

brainstorm body = **118** lines, ceiling 150 → **32 headroom**. Honest measure of the edits ≈ **net +28** (staging section incl. 5-row table ~23, creative/sequencing ~3, doc/self-review ~2), landing ~**146** with only ~4 durable lines left. To buy real headroom: **collapse the Anti-patterns list** (`SKILL.md:110-121`), which largely restates rules already stated inline (first-idea-as-design, code-mid-brainstorm, doc-after-code) — frees ~6–8 lines without weakening any rule, landing ~**138–140**. Do NOT trim the rationale prose (cutting the "why" is what makes doctrine skippable), and never spill into visual-decisions.

## Versioning

Editing taskmaster → bump `plugins/taskmaster/.claude-plugin/plugin.json` `0.17.0 → 0.18.0` (enforced by `check-version-bumps.sh`). Bump marketplace metadata version separately (not enforced by that script).

## Success criteria

**Script-verifiable:**
1. `brainstorm/SKILL.md` body ≤150 lines; `scripts/validate.sh` passes; `visual-decisions/SKILL.md` byte-for-byte unchanged (`git diff` empty).
2. `plugins/taskmaster` version bumped; `scripts/check-version-bumps.sh` passes.

**Behavioral expectations (prose doctrine, not machine-gated):**
3. A brainstorm of a surface-confirmed UI idea reaches the staging step with no dormant/skip option; visual-decisions' own gate is not independently fired (brainstorm's consent stands in for it).
4. A backend idea (Visual surface = None) is not pushed into staging; an unknown surface gets a skippable offer.
5. A creative decision on a non-interactive host degrades to describe-only (a recorded decision), never to a shell that would refuse it.
6. The written design doc has a populated "Staged decisions" section when Visual surface ≠ None.

## Open risks (residual)

- Both interactive plugins are optional; the degrade path is designed in (state the lost fidelity), but a user without either gets shell/ASCII/describe only.
- Enforcement is prose (consent wording + required doc section + self-review prompt). A silent skip is only caught by the model reviewing itself — a real gate waits for Piece 4.
- Budget lands ~138–140 after the Anti-patterns collapse; the next brainstorm edit must re-audit against 150.
