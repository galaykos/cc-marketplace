# Changelog

All notable changes to the craft-layer plugin.

Started at 0.47.0, the release that added the first assertions able to fail a
build that previously passed. Earlier versions have no entries rather than
invented ones — a backfilled history in the file whose job is history is worse
than an honest starting point.

## 0.47.6

### Added
- **`/craft-layer:audit` re-runs its script gates after an "Apply now" pick** —
  divergence, contrast, and the gate suite re-check the changed scope before the
  run reports done; a fix that cannot be gate-checked is named unverified. On
  unboosted runs fixes were previously taken on the fixer's word.

### Fixed
- **Removal fallout (i18n, react):** `rtl-bidi.md` now states its four-rule
  floor as the only shipped base rules rather than deferring to the removed <!-- removed-ok -->
  i18n plugin; the README reuse-map row points at that reference; <!-- removed-ok -->
  `product-packages.md` routes data-grid wiring to the chosen library's docs
  instead of the removed `react-data-grid` skill; a bolded react-verb line in <!-- removed-ok -->
  `vector.md` was reworded so the removed-artifact guard can hold the
  line without a marker.

## 0.47.5

### Fixed
- `motion-tiers/SKILL.md` shipped "Standing **recorded** — the mirror is manual and
  no gate checks the two agree" after this same branch added the gate that checks
  it. `pc_source_of_truth` fails CI when a KB figure in the SKILL is absent from
  `references/tier-budgets.md`. The marker now says what is true: KB figures are
  **gate**, prose agreement is **recorded** — nothing reads meaning. A skill telling
  a model the wrong enforcement tier about itself is the has-teeth defect this
  marketplace publishes a convention against.

## 0.47.4

### Changed
- WCAG SC 2.5.7 was stated in full three times — `physics-motion`,
  `interaction-fx`, and `a11y:a11y-audit`, which owns it. The two craft-layer
  satellites now state the rule in one line and name the owner. Deliberately
  still STATE it rather than only pointing: craft-layer installs standalone, so a
  bare pointer would leave a legal accessibility criterion unreachable.
- `motion-tiers/references/reduced-motion.md` was titled "The reduced-motion gate
  — stated once". That was false: `ui-ux:motion-best-practices` also states it and
  owns the WHY, the CSS kill-switch and the subscription mechanism —
  `motion-tiers/SKILL.md` assigns that mechanism to it by name. Retitled and
  scoped to craft-layer. A file whose job is preventing restatement, claiming a
  uniqueness it did not have, was the sharpest form of its own problem.

## 0.47.3

### Fixed
- `motion-tiers/SKILL.md` told a React reader the Tier-1 reduced-bundle path is
  `animate()` from `motion/mini`. Its own declared SOURCE OF TRUTH,
  `references/tier-budgets.md`, reserves `motion/mini` for **vanilla** element
  tweens and names `LazyMotion` + `m.*` as the React path. Two files, opposite
  advice, one of them labelled the truth. The SKILL now matches the reference.
- `motion-tiers/references/rtl-bidi.md` pointed at `plugins/i18n` for the general <!-- removed-ok -->
  RTL rules and said "do not re-teach them here" — but `craft-suite` does not ship
  i18n, so a craft-suite reader got a pointer to nothing. The file now carries a
  four-rule floor (logical properties, `dir`, which icons mirror, LTR runs inside
  RTL) and defers to i18n when it IS installed.

### Note
- The manual SKILL↔reference mirror that produced the first defect is no longer
  unchecked: `pc_source_of_truth` in `scripts/lib/plugin-checks.sh` now fails any
  SKILL naming a reference as SOURCE OF TRUTH that carries a figure the reference
  lacks. Its honest limit: figures only — prose contradiction, which is what this
  defect actually was, stays agent-graded.

## 0.47.2

### Fixed
- **Eleven severed sentences, shipping since 2026-07-27.** Commit `3c8e6d7`
  ("prose strip — net -76 lines, no capability removed") deleted hard-wrapped
  CONTINUATION lines, which ends a sentence mid-clause. Nine of this plugin's
  files carried the damage on every load since: `scroll-orchestration` lost
  "engine drives it — then pins the contract and the budget", the clause naming
  what the skill decides; `webgl-effects` read "earns the GPU cost and" straight
  into "Three.js:"; `information-design` ended mid-sentence at "Cite the". Each
  sentence is repaired in the strip's own spirit — the author-facing "never
  restate" nagging stays deleted, the reader-facing scope claim is back. The
  commit message's "no capability removed" was false, and no gate here could
  tell a redundant line from the second half of a sentence.
- **`contrast.mjs` was invoked by nothing.** 183 lines and three test fixtures,
  with zero runnable call sites, while `template/craft-gates/gates.spec.ts`
  disables axe's `color-contrast` rule and names this script "the gate of record"
  in its place. Contrast was graded by nothing on every path. `/craft-layer:audit`
  step 4 now runs it beside `divergence.mjs`, and says why exit 2 is a failure
  rather than a skip.
- **Corrected the recorded call sites of `divergence.mjs`.** Three documents said
  it is invoked by "`/craft-layer:craft` step 7 and `/craft-layer:audit` step 4",
  which reads as two independent call sites. There is one: craft step 7 calls the
  audit COMMAND, and explicitly forbids running its gates itself.

## 0.47.1

### Fixed
- **`utility-palette` passed the exact default swatch written as an arbitrary hex
  class.** `bg-[#6366f1]` scored 238.7° in sRGB against a band calibrated in oklch
  (275–315°, where that same swatch is 277.1°), so the assertion returned PASS —
  while its PASS message affirmatively claimed "no in-band arbitrary hex". A gate
  making a false negative claim, and an inverted tier: it missed what the ui-ux
  **advisory** catches by literal list. Found by an adversarial audit on 2026-08-18.
  A `DEFAULT_SWATCHES` set now catches those nine values by name; the PASS message
  no longer asserts more than it checked; and the in-file limitation that claimed
  "the named-utility path catches an indigo hex literal's swatch" is corrected —
  names are not hexes. Any *other* in-band hex is still seen only where the two
  colour spaces agree, and that residual is now stated accurately.

## 0.47.0

### Added
- **`utility-palette` and `utility-font` assertions** in
  `template/craft-gates/divergence.mjs`. **Standing: gate** — both fail the run
  (exit 1) and both are waivable via `.craft-layer/waivers.json` with a reason,
  the same lane every other assertion here rides.

  **This can turn a build red that was green before**, and that is the point.
  `accent-default-band` decides the category-default hue from CSS custom
  properties only, and `font-anti-corpus` reads the token stylesheet plus its
  siblings. On a Tailwind/JSX build neither the palette nor the type passes
  through either input: the hue arrives as `from-indigo-500 via-purple-500
  to-violet-600` inside a `className`, and the family as
  `import { Inter } from 'next/font/google'`. A violet gradient hero set in Inter,
  over a `src/index.css` whose cleanly derived accent token no element ever
  referenced, cleared both — and the run printed "OK: the build clears the N
  divergence assertion(s) that could be graded".

  `utility-palette` reads named Tailwind colour utilities and arbitrary
  `[#rrggbb]` values out of the class strings `CLASS_RE` already extracts;
  `utility-font` reads `font-[...]`, `next/font/google` specifiers and
  `fonts.googleapis.com` family links against the anti-corpus text
  `loadAntiCorpus()` already returns.

  **If this newly fails your build**, the two honest options are to choose a hue
  and a typeface, or to record in `.craft-layer/waivers.json` why the default is
  the right answer here — a brand that genuinely is violet has been made to
  notice, which is the whole claim.

  The `indigo|violet|purple` family list is **derived from `DEFAULT_BAND`**, not
  chosen by taste: those three sit at ~277.1°/292.7°/303.9° oklch, inside the
  275–315° band, while blue-500 (~259.8°) and fuchsia-500 (~322.1°) fall outside.
  If the band ever moves, re-derive the list from the ramp rather than extending
  it by feel.

### Known limitation (unchanged behaviour, newly measured and stated)
- `toHue()` returns a hue in whichever space the value was written in, and oklch,
  hsl and hex are then all compared against one band. Tailwind's own
  indigo/violet/purple **hexes** read 238.7°/258.3°/270.7° in sRGB — below the
  275° floor — while the same swatches are 277.1°/292.7°/303.9° in oklch. So a
  token written `--accent: #6366f1` escapes `accent-default-band`, and the hex
  path of `utility-palette` fires only where the two readings agree
  (fuchsia/magenta-side values such as `#d946ef` at 292.2°). The named-utility
  path is what catches an indigo swatch in practice. Re-spacing the band or
  converting hex to oklch would change `accent-default-band`'s verdicts for every
  existing build, so this is recorded with its measurement instead of changed
  quietly.
- Neither assertion **ever runs on `/ui-ux:build`**. `divergence.mjs` is invoked
  by `/craft-layer:audit` step 4 and `/craft-layer:craft` step 7 and nowhere else,
  while ui-ux's own `build.md:75` calls itself the most reachable UI entry point
  in this marketplace. Closing this gap closes it on the craft path only.
- They count a hue and a family, not a composition: three equal cards, the ribbon
  on the middle one, and the centred hero stay uncounted.
