---
name: visual-decisions
description: Use during requirement clarification when a choice is visual or structural — layout variants, user flows, architecture topology, data shapes. Builds throwaway ASCII wireframes, theme-aware HTML mockups from a shipped shell (rendered in the project's own colors when detectable), or example payload tables so the user picks between concrete options instead of imagining them from prose. Asks fidelity consent (full mockups / ASCII only / none) on first use per session.
---

## When to show instead of tell

Reach for a visual the moment describing options costs more words than drawing them:

- Layout or component variants — where things sit, what is emphasized.
- User flows — screens/steps and the transitions between them.
- Architecture topology — services, queues, data direction.
- Data shapes — candidate JSON/table structures for the same real scenario.

Do NOT use visuals for text-native tradeoffs (latency vs. cost, library A vs. B) —
a mockup of a sentence is theater. Those stay as multiple-choice questions.

## Consent gate

Before building the session's FIRST visual artifact, ask via `AskUserQuestion`:

- **Full mockups (Recommended)** — shell-based HTML at the live preview URL.
- **Quick ASCII only** — wireframes/tables in chat; no server, no files, skip HTML/Preview.
- **No mockups** — dormant for the session; visual choices become plain multiple-choice.

The answer holds all session — never re-ask. The gate is lazy: fire only when a
genuinely visual choice exists and a build is imminent, never at task intake.

## The fidelity ladder — climb only as high as the decision requires

1. **ASCII wireframe in chat** — seconds. For structure: placement, column counts.
2. **Shell-based HTML mockup** — minutes, on the preview URL; when spacing,
   hierarchy, density, or motion drives the choice and boxes cannot carry it.
3. **Inline SVG inside a variant slot** — for flows and topology diagrams; complex topology may compile author-time mermaid→inline-SVG when a local mermaid CLI is available, the shipped mockup holding zero runtime includes — otherwise stay on hand SVG/ASCII.

Real-component fidelity beyond the shell: design-preview (existing Vite+React) or
shadcn-studio (greenfield/non-React), when installed. Colour/theme IS the decision →
/ui-ux:theme when installed; non-shadcn greenfield tops out at shell fidelity. Entity/
relation modeling: the `erd` skill. No prototype rung — mockups die at the pick;
validating the ASSEMBLED experience afterwards is the experience-walkthrough skill.

## ASCII wireframes

```
+----------------------------+   +----------------------------+
| Logo    [Search]     (@)   |   | Logo                 (@)   |
+------+---------------------+   +----------------------------+
| Nav  |  Card  Card  Card   |   |  List item ............    |
+------+---------------------+   +----------------------------+
      A: sidebar + grid                 B: topbar + list
```

Label A/B/C at equal detail, one-line tradeoff caption each, pick asked right below.
Full vocabulary — panes, branch/loop arrows, selection/state markers, numbered
callouts, worked A/B examples: `references/ascii-patterns.md`.

## HTML mockups from the shell

Never hand-write mockup HTML. Copy `assets/shell.html` (relative to this skill's
directory) to `taskmaster-docs/mockups/YYYY-MM-DD-<topic>.html` and fill its
SLOTs. Frame/slot markup, per-variant `data-state` blocks, the max-3-variants
rule, the realistic-data discipline, curated starter patterns
(`references/starters/`), and motion-pass conventions all live in
`references/shell-authoring.md` — read it before authoring the first pass.

The shell carries the polish — header, frames, panels, compare modes,
auto-reload, state toggles. Do not restyle it; shell missing or unreadable
(broken plugin cache) is the one case for a hand-built minimal mockup — tell
the user the shell was unavailable.

## Theme tokens: mockups in the project's own look

Map context-scout's `Theme tokens` table into the shell's `SLOT: theme-project`
block as the `--vd-*` variables; un-hide `#vd-theme-toggle` and set
`data-vd-theme="project"` on `<html>` so the user can flip project ↔ baseline. Rules:

- Missing tokens keep baseline defaults; tokens style chrome and accents only —
  content text stays high-contrast neutrals by shell design.
- No scout report? One glob for `globals.css`/`components.json`/Tailwind config,
  read only on hit. Miss or confidence `none`: keep baseline and hidden toggle,
  put "baseline theme" in `SLOT: theme-note` — never pass baseline off as the app's.
- The project theme (`html[data-vd-theme]`) never differs between variants —
  equal application is non-negotiable; the sanctioned per-frame theme-axis
  token presets on `.vd-content` are the one exception (see
  `references/shell-authoring.md`).

## Flows and topology as SVG

Embed inline SVG in a variant content slot: boxes, arrows, labels — nothing animated.
ASCII arrows (`login -> otp -> dashboard`) suffice in chat; SVG when branches grow.

## Click-through flows without a server

When the user must FEEL a navigation flow: every screen is a section in one file;
`<a href="#screen-2">` buttons plus `section:target { display: block }` swap
screens. A clickable prototype, zero JavaScript, works over `file://`.

## Preview: one live URL for the whole session

Always serve — every decision lands in the same tab. One server, one canonical file:

1. On the first visual decision, start `assets/serve.py --port "${PREVIEW_PORT:-8123}"`
   (relative to this skill's directory) in the background, note the PID
   (normalized fallback chain: serve.py → `python3 -m http.server "${PREVIEW_PORT:-8123}" --bind 127.0.0.1 -d taskmaster-docs/mockups` →
   no python3 → `php -S 127.0.0.1:${PREVIEW_PORT:-8123} -t taskmaster-docs/mockups` → `npx serve -l tcp://127.0.0.1:${PREVIEW_PORT:-8123} taskmaster-docs/mockups`).
   Port busy? `lsof -ti :${PREVIEW_PORT:-8123}` — reuse a prior mockup server, else bump.
2. Write each pass to a dated file (ledger trail), copy to `current.html` — the
   user's tab at `http://localhost:${PREVIEW_PORT:-8123}/current.html` sees every pass in place.
3. Auto-reload: SSE push exists only on the serve.py rung; any lower rung
   (`http.server`, `php -S`, `npx serve`) still serves fine — the shell falls
   back to body-compare polling there (server gone → page stays usable either way).

Other flows share this server via per-purpose files (`theme.html`, `walkthrough.html`,
`diagram.html`, `api.html`) — kill only at pipeline end; stale: `lsof -ti :${PREVIEW_PORT:-8123} | xargs kill`. `file://` is the no-runtime fallback.

## Data-shape decisions

Show 2–3 shapes carrying the SAME real scenario, edge case included — which matches intent?

```jsonc
// A: flat            // B: nested
{ "user_id": 7,          { "user": { "id": 7 },
  "total_cents": 124000 }  "total": { "cents": 124000 } }
```

Chat table like this for trivial 2-field shapes; anything larger goes to
side-by-side `.vd-code` frames in `api.html` (differing keys in `<mark>`) — see Data-shape passes in `references/shell-authoring.md`.

## Asking for the pick

- Ask via `AskUserQuestion`: one option per variant letter plus its tradeoff line;
  include "mix of the above" only when a mix is actually mergeable.
- On a mix answer ("A's layout with C's nav"): ONE merged variant, one re-ask —
  at most two passes; decision aid, not design sprint.
- Record the pick as a CLEAR ledger row (source: the mockup file path); quote it in the spec.
- On an ACCEPTED pick (not ASCII-only, not abandoned), save the winning
  variant to `taskmaster-docs/mockups/gallery/YYYY-MM-DD-<slug>.html`
  (collision appends `-2`, `-3` — never overwrite) and append one line —
  date, slug, decision, source spec — to `gallery/INDEX.md`, creating it if
  missing. Format details: `references/shell-authoring.md`.
- Gallery re-offer (opt-in): once THIS decision's fresh variants exist, offer at most ONE matching gallery entry as labeled reference, never a rival, never the option set.

## Anti-patterns

- Styling inside a variant slot — polish lives in the shell, never in variant
  content, EXCEPT the sanctioned theme-axis token presets on `.vd-content`
  (see Theme-axis passes); a hand-decorated favorite is a sales pitch.
- More than 3 variants — choice overload produces "whichever", not a decision.
- Variants differing on several axes — the pick can't be attributed; nothing got decided.
- Building real components "since we're at it" — implementation starts after the cards.
- External assets or frameworks — a networked mockup opens slower than the decision it serves.
- Reusing mockup HTML or the shell as the implementation start — implement from
  the spec; mockups carry none of the codebase's conventions.
