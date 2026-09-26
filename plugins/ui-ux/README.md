# ui-ux

UI/UX foundations: per-stack skills for **shadcn/ui** and **Tailwind**, design tokens,
a theming system, motion best practices, a theme builder (shadcn/ReUI/Aceternity,
Tailwind, Astryx, or Bootstrap) with a live colour-preview URL, `/ui-ux:build`, the
WCAG 2.2 AA audit, and the ui-ux-reviewer / ui-ux-engineer / a11y-engineer agents.
Generic CSS3/Grid/Flexbox/Bootstrap skills were removed after baseline tests showed the
model covers them unaided — see rationale/stack-skill-baselines.md.

> **Install `ui-libraries` with this plugin — nothing does it for you.** The
> component-library skills — Material UI, PrimeReact, Astryx, ReUI, Aceternity, and the
> library-agnostic `component-libraries` floor with its per-library map — moved to
> `ui-libraries` on 2026-09-26, when ui-ux reached the marketplace's per-plugin prose cap.
> No plugin here may declare `dependencies` (an update that adds one leaves it uninstalled
> and the plugin fails to load), and the suites that used to bring both were retired the
> same day. So run:
>
> ```bash
> /plugin install ui-libraries@cc-plugins-marketplace
> ```
>
> This plugin's commands and agents name those skills as `ui-libraries:<skill>` and say
> so when it is not installed; `/stack-scan:suggest` prints the same line when it sees
> ui-ux without it.

Registry libraries (shadcn, [ReUI](https://reui.io/docs),
[Aceternity](https://ui.aceternity.com/components)) get docs-first treatment:
they have no npm version to pin against, so component APIs are verified on the
live docs page, never from memory. The skills split roles cleanly — shadcn/ReUI
for app UI, Aceternity for motion-heavy marketing pages, one primitive set per
project, everything themed through the same CSS-variable tokens.

The UI layer is library-agnostic on purpose: the skills detect the library the
project already has from its manifest and build in that one. A library without
a sibling skill is governed by `ui-libraries:component-libraries` plus its docs URL,
never by a second library installed beside it.

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
2. Generates up to 3 candidate token sets (light + dark, contrast-checked by
   `scripts/contrast.mjs` — see below, and that claim is now a run, not a promise)
   and serves them at the shared preview URL `http://localhost:${PREVIEW_PORT:-8123}/theme.html` —
   swatch grid plus real component mockups (buttons, card, alert, badges,
   chart strip), light and dark side by side.
3. You pick per round (one axis at a time: hue → warmth → radius); the page
   auto-reloads on every regeneration — same URL the whole session.
4. On acceptance it shows the diff against your existing `globals.css` and
   applies only after a yes.

Colours are judged rendered on components, not as variable names — a `primary`
that looks great as a swatch can fail hard as a button.

## Contents

- **Skills**: shadcn-best-practices, shadcn-theming, tailwind-best-practices,
  design-tokens, theming-system, motion-best-practices, a11y-audit (the WCAG 2.2 AA
  checklist, so accessibility rules apply while writing markup, not only under the
  audit command)
- **Agents**: ui-ux-reviewer, ui-ux-engineer, a11y-engineer (applies an audit's fix
  list, preferring native semantics over ARIA patches, each change tagged with its
  WCAG criterion). The reviewer and the engineer preload `a11y-audit` through the host's
  `skills:` frontmatter, which costs about 1.8k tokens per spawn, so its rules are in
  context even when nothing injects a Read path. They flag or apply those rules in the
  same pass and leave `/ui-ux:audit` for a full audit.
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
    `CC_PALETTE=off`, or `CC_REMIND=off` for every reminder hook in this marketplace.

  It exists because craft-layer's stricter equivalent (`utility-palette`, a gate
  with a waiver lane) is invoked by `/craft-layer:audit` only — a `/craft-layer:craft`
  run reaches it because craft's own step 7 calls that command, so one call site, not
  two. A plain "build me an app" turn runs neither: in a measured run on 2026-08-17 a
  Laravel build shipped 23 indigo utilities across 5 Blade views with every gate
  green. This is the reach half of a rule craft-layer owns the depth of; the hook's
  own header carries the derivation.

## The contrast checker

`scripts/contrast.mjs` measures every ink/accent/status/chart pairing in a token
block against its WCAG 2 threshold — exit 0 clean, exit 1 with the failing pairings
listed, exit 2 when it resolved no token at all:

```bash
cd <project root> && node "${CLAUDE_PLUGIN_ROOT}/scripts/contrast.mjs"
CRAFT_TOKEN_SOURCE=path/to/tokens.css node "${CLAUDE_PLUGIN_ROOT}/scripts/contrast.mjs"
```

`/ui-ux:theme` runs it on the accepted token set before it offers the diff;
`/ui-ux:audit` runs it whenever a token source exists and folds each FAIL in as an
SC 1.4.3 / 1.4.11 violation.

**It is a byte-identical twin of `plugins/craft-layer/template/craft-gates/contrast.mjs`**,
held in step by `pc_twin_files` in `scripts/lib/plugin-checks.sh` (**gate** — it
checks SAMENESS, not correctness; two identically wrong copies pass). craft-layer
owns the original and needs ui-ux, never the reverse, so before this copy
existed a ui-ux install without craft-layer reached no
contrast checker at all while three documents promised one.

**Two honest limits.** It parses `oklch()` values under `:root` and `.dark` only:
a Tailwind v3 HSL-triplet theme, a Bootstrap Sass target, or hex tokens resolve
nothing and exit 2, which is reported as *not measured*, never as a pass. And it
grades the TOKEN BLOCK, not the rendered page — text over an image, a gradient, or
a colour written straight into a class string is outside what it can see.

## Evals

`evals/` holds two cases, and they are not the same kind of thing:

```bash
claude plugin eval ./plugins/ui-ux --ablation with-without --runs 5 \
  --no-publish --trust-plugin
```

No `--allow-tools` grant is needed (both declare `Read, Glob, Grep, Skill`, none
gated) and no `--scaffold`. `--max-cost-usd 0` load-checks the suite for free, which
is what `scripts/eval-cases.sh` does in CI; nothing runs a model there.

- **`a11y-older-criteria`** has headroom: a checkout form whose easy defects are
  already fixed, leaving SC 1.3.5 (`autocomplete` tokens) and SC 4.1.3 (a live region
  that must already be in the DOM before the message arrives). The control arm is
  expected to call it clean.
- **`design-tokens-control`** is a **removal measurement**, and by CLAUDE.md's own
  ceiling rule a case whose control passes can never show a skill helping. That is
  what it is for. `rationale/stack-skill-baselines.md` recorded the css3 control
  producing a token scale unaided, and the 2026-09-22 panel proposed deleting
  `design-tokens` on that neighbouring evidence. **`design-tokens` is removed only if
  the measured delta is zero** — and the two paragraphs and the motion-source rule the
  control did NOT produce have already moved into `theming-system`, so the removal
  would lose nothing. Until the run happens the skill stays.

Neither delta is measured. State the run count and the vote spread with a number or
do not state the number.

## Pairs well with

- **taskmaster** — its visual-decisions skill uses the same always-live mockup
  pattern for layout/flow choices
- **A live component registry** — the stack skills here read component APIs from a
  registry MCP rather than from memory: shadcn's own server (`npx shadcn@latest mcp init --client claude`)
  and ReUI's hosted one (`https://mcp.reui.io`, one-time browser sign-in). Neither is
  shipped by this marketplace; `/stack-scan:suggest` prints the install line when the
  manifests show the stack. <!-- removed-ok --> (design-studio, retired 2026-09-14,
  used to declare them.)
- **web-dev** — component-logic review (React and Vue 3) alongside the visual layer
