# ui-ux

UI/UX best practices with per-stack skills — shadcn/ui, ReUI, Aceternity UI,
Astryx (Meta's agent-ready design system), Material UI, and Tailwind — and a
library-agnostic `component-libraries` skill for every other React or Vue component
library (Base UI, Radix, Reka UI, React Aria, Ark, Mantine, Chakra, Ant Design,
HeroUI, PrimeVue, Vuetify…)
with a per-library map of signals, theme channels and docs — plus a theme builder
(shadcn/ReUI/Aceternity, Tailwind, Astryx, or Bootstrap) with a live colour-preview URL
and a ui-ux-reviewer agent. Generic CSS3/Grid/Flexbox/Bootstrap skills were
removed after baseline tests showed the model covers them unaided — see
rationale/stack-skill-baselines.md.

Registry libraries (shadcn, [ReUI](https://reui.io/docs),
[Aceternity](https://ui.aceternity.com/components)) get docs-first treatment:
they have no npm version to pin against, so component APIs are verified on the
live docs page, never from memory. The skills split roles cleanly — shadcn/ReUI
for app UI, Aceternity for motion-heavy marketing pages, one primitive set per
project, everything themed through the same CSS-variable tokens.

The UI layer is library-agnostic on purpose: the skills detect the library the
project already has from its manifest and build in that one. A library without
a sibling skill is governed by `component-libraries` plus its docs URL, never
by a second library installed beside it.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install ui-ux@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/ui-ux:theme [brand-color-vibe-or-reference]` | Create or restyle a UI colour theme — shadcn/ReUI/Aceternity, Tailwind, Astryx (`defineTheme()`), or Bootstrap — with a live preview URL |
| `/ui-ux:build [what-to-build]` | Build or restyle a UI component/layout via the ui-ux-engineer worker, applying the stack best-practice and token skills |
| `/ui-ux:audit [files-or-diff]` | Audit UI code against WCAG 2.2 AA — semantic structure, contrast, keyboard, focus, forms, ARIA — one line per violation with fix, blockers first, a manual-test list at the end, and the `a11y-engineer` worker offered to apply the fixes |

## Theme builder example

```bash
/ui-ux:theme deep teal, calm SaaS dashboard vibe
```

What happens:

1. Reads `components.json`, the current `globals.css`, and the Tailwind major
   version from the lockfile — v4 gets oklch tokens, v3 gets HSL triplets.
2. Generates up to 3 candidate token sets (light + dark, contrast-checked) and
   serves them at the shared preview URL `http://localhost:${PREVIEW_PORT:-8123}/theme.html` —
   swatch grid plus real component mockups (buttons, card, alert, badges,
   chart strip), light and dark side by side.
3. You pick per round (one axis at a time: hue → warmth → radius); the page
   auto-reloads on every regeneration — same URL the whole session.
4. On acceptance it shows the diff against your existing `globals.css` and
   applies only after a yes.

Colours are judged rendered on components, not as variable names — a `primary`
that looks great as a swatch can fail hard as a button.

## Contents

- **Skills**: shadcn-best-practices, shadcn-theming, reui-best-practices,
  aceternity-best-practices, astryx-best-practices, mui-best-practices,
  component-libraries (the library-agnostic floor plus `references/library-map.md`),
  tailwind-best-practices, design-tokens, theming-system, motion-best-practices, a11y-audit (the WCAG 2.2 AA
  checklist, so accessibility rules apply while writing markup, not only under the
  audit command)
- **Agents**: ui-ux-reviewer, ui-ux-engineer, a11y-engineer (applies an audit's fix
  list, preferring native semantics over ARIA patches, each change tagged with its
  WCAG criterion)
- **Hooks**, and they are not the same tier:
  - `preview-guard` (PreToolUse on `Artifact`) — **gate, with a human in it.** It
    returns `permissionDecision: "ask"`, which stops the tool call until you answer:
    every time for a strongly visual artifact, once per session for a weak signal.
    It never decides for you, but calling it advisory was wrong — an ask blocks.
  - `palette-default` (PostToolUse on a written UI file) — **advisory.** It names the
    indigo/violet/purple category default when it arrives through Tailwind class
    strings or a literal default swatch, once per session, and never blocks. A violet
    brand is a legitimate answer; the only thing separating "chose it" from "reached
    for the default" is intent, which no script reads. Silence it with
    `CC_PALETTE=off`, or `CC_REMIND=off` for every advisory in this marketplace.

  It exists because craft-layer's stricter equivalent (`utility-palette`, a gate
  with a waiver lane) is invoked by `/craft-layer:audit` only — a `/craft-layer:craft`
  run reaches it because craft's own step 7 calls that command, so one call site, not
  two. A plain "build me an app" turn runs neither: in a measured run on 2026-08-17 a
  Laravel build shipped 23 indigo utilities across 5 Blade views with every gate
  green. This is the reach half of a rule craft-layer owns the depth of; the hook's
  own header carries the derivation.

## Pairs well with

- **taskmaster** — its visual-decisions skill uses the same always-live mockup
  pattern for layout/flow choices
- **A live component registry** — the stack skills here read component APIs from a
  registry MCP rather than from memory: shadcn's own server (`npx shadcn@latest mcp init`)
  and ReUI's hosted one (`https://mcp.reui.io`, one-time browser sign-in). Neither is
  shipped by this marketplace; `/stack-scan:suggest` prints the install line when the
  manifests show the stack. <!-- removed-ok --> (design-studio, retired 2026-09-14,
  used to declare them.)
- **web-dev** — component-logic review (React and Vue 3) alongside the visual layer
