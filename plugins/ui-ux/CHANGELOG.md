# Changelog — ui-ux

Consumer-facing changes only. Newest first. Started at 0.18.0, the release that
added this plugin's first PostToolUse hook; earlier versions have no entries
rather than invented ones.

## 0.19.4

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.19.3

### Changed
- Registry and preview hand-offs name design-lab (`/design-lab:preview`, `/design-lab:stage`,
  its `registry-source` MCP); design-preview, shadcn-studio and registry-source merged <!-- removed-ok -->
  into it on 2026-09-02.

## 0.19.2

### Changed
- `motion-best-practices` points Three.js work at craft-layer's `threejs-best-practices`;
  the threejs plugin merged into craft-layer on 2026-09-02. <!-- removed-ok -->

## 0.19.0

### Added
- **a11y merged in.** `/ui-ux:audit` (was `/a11y:audit`), the `a11y-audit` skill, and <!-- removed-ok -->
  the `a11y-engineer` worker ship here; `/ui-ux:review` keeps deferring the deep WCAG
  pass to the audit command, now one plugin over. Nothing in the audit's checklist or
  report format changed.

## 0.18.6

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.18.5

### Fixed
- **"Shipping any motion with no `prefers-reduced-motion` path" is back in
  `motion-best-practices` § Common mistakes**, deleted at `dfe8fcf`. The skill opens
  by arguing this is a hard accessibility rule because vestibular disorders make
  large motion physically harmful, and Common mistakes is the list a reviewer scans
  against a diff — the rule the skill opens with was absent from it. Six craft-layer
  skills cite this file as the owner of the reduced-motion mechanism.
- **Two double-loaded bullets split**: permanent `will-change` vs autoplaying loops,
  and View Transitions feature detection vs the GSAP Club-licence correction (free
  since 3.13). The licence item is a fact correction about the world, invisible
  appended to an unrelated bullet.
- **"(method names, options, version numbers)" restored** to the definition of a
  version-sensitive literal — the test deciding when the model must fetch live.

## 0.18.4

### Changed
- **Every hook entry now declares a `timeout`.** `palette-default.sh` 5s, `preview-guard.sh` 10s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.18.3

### Added
- **`/ui-ux:build` offers its reviewer twin** after returning changed files —
  "Run /ui-ux:review on the result now (Recommended)" / "Skip". A standalone
  build previously shipped self-graded even though the reviewer existed.

### Fixed
- **`shadcn-theming`'s "contrast gates are hard" claim names its standing**:
  agent-graded on the theme path — no script computes ratios there; the only
  mechanical checker is craft-layer's `contrast.mjs` under `/craft-layer:audit`.
- **Ghost-skill pointers removed** (css-grid/flexbox/css3 — removed 2026-08-20,
  still named by the generated engineer's procedure and astryx's defer rule);
  plain CSS is stated as baseline. astryx and shadcn skills no longer route to
  the removed react plugin's skills. <!-- removed-ok -->

## 0.18.1

### Fixed
- **`theming-system`'s opening sentence ended mid-clause** — "…or ship a theme.
  Those" followed by a blank line. Inherited from craft-layer's 2026-07-27 prose
  strip when the skill moved here, and shipped on every load since.
- **`hooks/palette-default.sh` recorded the wrong reach for the gate it stands in
  for.** It said `divergence.mjs` is "invoked only by `/craft-layer:craft` step 7
  and `/craft-layer:audit` step 4" — one call site described as two. The hook's
  own argument for existing is unchanged and still holds.

## 0.18.0

### Added
- **`hooks/palette-default.sh`** — a `PostToolUse` advisory that names the
  indigo/violet/purple category default when it reaches a UI file through Tailwind
  class strings (`bg-indigo-600`, `from-violet-500`) or a literal default swatch
  (`#6366f1`). One nudge per session, never per file.

  **Standing: advisory. It cannot block and will not.** A violet brand is a
  legitimate answer, and the only thing separating "chose it" from "reached for the
  default" is intent, which no script reads. craft-layer's stricter equivalent
  (`utility-palette`) can demand a written waiver because a craft run has a
  contract to record one in; a bare edit has nowhere to record consent, so blocking
  here would punish the legitimate case with no way to say so.

  **Why it exists:** craft-layer's gate runs only inside `/craft-layer:craft` step 7
  and `/craft-layer:audit` step 4. A plain "build me an app" turn runs neither. In a
  measured control/treatment run on 2026-08-17, a Laravel build shipped **23 indigo
  utilities across 5 Blade views** with every gate in this marketplace green,
  because none of them was on that path. ui-ux ships in 10 bundles to craft-layer's
  4, so this is the reach half of a rule craft-layer owns the depth of.

  Silence with `CC_PALETTE=off`, or `CC_REMIND=off` for every advisory nudge here.

  Known gaps, stated in the hook header: it counts a hue, never a composition
  (three equal cards, a ribbon on the middle one, a centred hero are the rest of
  the fingerprint and go undetected); it reads literal class strings only, so a
  palette behind `cn(...)` or a component prop is invisible; the hex list is the
  default swatches **by value**, because reading hue from hex is wrong at this band
  — sRGB puts `#6366f1` at 238.7°, far below the 275–315° those same swatches
  occupy in oklch; and its token cost is unmetered, because `context-budget.sh`
  probes the dynamic channel with a synthetic `Edit` that is not a UI file.

- **`scripts/__tests__/palette-default.test.sh`** — 10 cases. The first is the
  observed Blade regression verbatim: if it stops firing, the hook has lost the
  only failure it is known to catch. Four are silence cases, including hues just
  outside the band (`blue-500`, `fuchsia-500`) — without those the family list
  would be taste rather than a derivation from craft-layer's 275–315° band.
