# design-skills fold — 2026-10-06

**Standing: `recorded`.** A dated record; nothing reads it back. Every rule it names ships
inside a plugin; this file holds only the per-skill provenance, the re-verified facts, the
measurements and the deviations an installer never needs.

Source: [freshtechbro/claudedesignskills](https://github.com/freshtechbro/claudedesignskills) at
commit `1da73feb` (2025-11-19), MIT, © 2025 Claude Skills Project. Its 23 skills were copied with
the LICENSE into the gitignored `taskmaster-docs/upstream/claudedesignskills-1da73feb/` on
2026-10-06; nothing was pasted into a plugin (the overlap check below). Upstream's text is about
eleven months old and often stale, so most of what landed was found while checking it against npm
and the packages' source; the plugin CHANGELOGs credit it as "found while reviewing", and no README
carries a credit line. Released as marketplace 0.122.0: ui-ux 0.30.0, craft-layer 0.57.0,
ui-libraries 0.3.0, skill-router 0.24.0, resilience 0.8.0.

## What was asked

The user (2026-10-05) picked "All folds + our drift": fold every confirmed fact into EXISTING
skills, no new skill or plugin, and fix the marketplace's own stale version stamps. Round 1 decided
the conventional-look line in `/ui-ux:build`, Magic UI and React Bits under Aceternity's body (its
description unchanged) plus router rows, a `jsrepo add` row with `ogl` left unrouted, and the Spline
stamp moved with its weight rows labelled rather than re-measured. Eight assumptions and the
red-team amendments were approved on 2026-10-06. The authoring-skills runner swap was dropped by the
user as outside the ask.

## Every upstream skill → destination or skip reason

| upstream | went to | or skipped because |
|---|---|---|
| `motion-framer` | ui-ux `motion-best-practices` SKILL and `references/motion.md` (motion 14 stamps, `steps` as an import, `scroll()`'s timeline binding); craft-layer `framework-bindings.md` stamp; ui-ux `registries.md` motion hazard | — its tutorial content is what the skill already carries |
| `animated-component-libraries` (Magic UI, React Bits) | ui-ux `registries.md` rows and jsrepo section, `motion.md` counter section, `/ui-ux:build` step 3; ui-libraries `aceternity-best-practices` body and two `library-map.md` rows; skill-router's command rows | — its component catalogues; props are read from the registry item, never listed |
| `gsap-scrolltrigger` | ui-ux `references/gsap.md` (five ScrollTrigger traps); ScrollSmoother → craft-layer `scroll-orchestration` | — the rest is covered by `gsap.md` |
| `animejs` | ui-ux `references/animejs.md` (4.2 easing imports, 4.4.0 breaking changes, free text splitting); `motion.md`'s Motion+ section; craft-layer `text-reveals.md` | — |
| `threejs-webgl` | craft-layer `threejs-best-practices` (`THREE.Timer`, `PCFSoftShadowMap`) and new `references/compressed-gltf.md` | — renderer and scene basics already there |
| `react-three-fiber` | `threejs-best-practices` (React minor cap, `invalidate()`, Text3D); `webgl-effects/references/effect-pipeline.md` (postprocessing's bound) | — its `framer-motion-3d` usage is the deprecated package `motion.md` now names |
| `web3d-integration-patterns` | the demand-frameloop rule above; `framer-motion-3d`'s deprecation in `motion.md` | an integration meta-skill over libraries `motion-best-practices`, `scroll-orchestration` and `threejs-best-practices` already own |
| `lottie-animations` | craft-layer `motion-tiers`: `tier-budgets.md` tier-5 row, `vector.md` runtime section, `hosted-runtimes.md` CSP | — |
| `rive-interactive` | the same three `motion-tiers` references (WASM and font CDNs, `useOffscreenRenderer`, `isTouchScrollEnabled`, Events, renamed packages) | — |
| `spline-interactive` | `hosted-runtimes.md`: 2.0.71 read note, 2.0.58 rows labelled | — weight not re-measured (user, round 1) |
| `lightweight-3d-effects` | vanilla-tilt → `interaction-fx/references/pointer-patterns.md`; Vanta → `hosted-runtimes.md` | Zdog: last release 2022 |
| `locomotive-scroll` | Locomotive 5 → `scroll-orchestration/references/lenis-substrate.md`; skill-router's content row | not as a skill: Lenis and native scroll-driven animation own the job |
| `barba-js` | `page-transitions/references/framework-seams.md` route-swapper section; the page-transitions SKILL clause; `craft-reviewer`'s row | not as a skill: Swup is preferred and native cross-document transitions come first |
| `scroll-reveal-libraries` (AOS) | `motion-tiers/references/gotchas.md`; `craft-reviewer` and `/craft-layer:audit` unowned-motion lists | not as a skill: AOS is a trap to grade, not a path to teach |
| `modern-web-design` | its stale `getCLS` usage prompted resilience `performance-tuning`'s web-vitals sentence | generic trends; it recommends looks craft-layer's sameness fingerprint lists as defaults to avoid |
| `react-spring-physics` | — | not as a skill: popmotion is dead; react-spring is kept only where a project already uses it. `@react-spring/three` (10.1.2) appears only as a `framer-motion-3d` replacement and in the demand-rendering rule |
| `skill-creator` | — | Apache-2.0, conflicts with the `authoring-skills` project skill |
| `babylonjs-engine`, `playcanvas-engine`, `aframe-webxr`, `pixijs-2d` | — | second engines; no web-app builder need |
| `blender-web-pipeline`, `substance-3d-texturing` | — | desktop tools; the glTF encode step lives in `compressed-gltf.md` |

## Re-verified facts, with source and date

Every fact below was read on 2026-10-06. Version, date, deprecation and peer-range facts were
re-run for this record the same day with `npm view <pkg> version`, `npm view <pkg> time --json`,
`npm view <pkg> deprecated` and `npm view <pkg> peerDependencies`; facts marked *source* were read
from the package tarball or the vendor page by the fold and were not re-read for this record.

- **motion** 14.0.0, published 2026-10-02 (13.0.0: 2026-08-05); `framer-motion` 14.0.0;
  `framer-motion-3d` last 12.4.13 (2025-03-11), deprecated on npm. *Source:* motion's CHANGELOG and
  the 14.0.0 tarballs — 14.0.0 removes only internal APIs 13.5.1 restored for framer-motion 13.0–13.4;
  `threeEffect` from `motion/three`; `MotionConfig` never reaches a `useSpring` value. motion.dev
  refused the connection that day.
- **gsap** 3.15.0; 3.13.0 published 2025-04-30. *Source:* gsap.com/resources/st-mistakes/ and the
  ScrollTrigger and ScrollSmoother docs.
- **animejs** 4.5.0; 4.4.0 published 2026-04-29, 4.2.0 2025-09-29, 4.1.0 2025-07-23. *Source:* the
  4.4.0 and 4.5.0 code — a `stagger` `use` callback still receives a number; `accessible` split option
  read, not screen-reader tested.
- **Registries:** shadcn 4.21.2; `cobe` 2.0.1 against Magic UI Globe's `^0.6.4`; jsrepo 3.8.1.
  *Source:* the registry items through `view` and `add --dry-run`, React Bits' README (200+ components)
  and licence (MIT + Commons Clause), 77 of 78 Magic UI ui items naming no target, jsrepo's package
  (`jsrepo.config.ts`, "No path was provided").
- **three** 0.186.1, `@react-three/fiber` 9.8.1 (peers `react >=19 <19.4`; 9.5.0 `>=19 <19.3`, 9.4.0
  `^19.0.0`), `@react-three/drei` 10.7.9 (peers `react ^19`), `three-stdlib` 2.36.1,
  `@react-three/postprocessing` 3.1.3 (peers `react ^19.0.0`), `@gltf-transform/cli` 4.5.1.
  *Source:* three's `Clock` deprecation (r183), the soft shadow filter's removal (r182 WebGL, r186
  WebGPU), DRACOLoader and KTX2Loader decoder resolution (r185), `detectSupportAsync` (r181), the
  three GLTFLoader errors, drei's gstatic Draco path, Text3D's `height` and TextGeometry's `depth`
  (r173), gltf-transform's `--compress`, `--texture-compress` and `--texture-size` defaults.
- **postprocessing** 6.39.5 peers `three >=0.168.0 <0.187.0`; 6.39.0 `< 0.184.0`; 6.38.0 `< 0.182.0`.
- **Vector runtimes:** `@lottiefiles/dotlottie-web` 0.80.0, `@lottiefiles/dotlottie-wc` 0.9.28,
  `@dotlottie/player-component` deprecated ("superceded by @lottiefiles/dotlottie-wc"), `lottie-web`
  5.13.0, `lottie-react` 3.1.2 (3.0.0: 2026-08-15), `@rive-app/canvas` 2.44.0, `@rive-app/react-canvas`
  and `react-webgl2` 4.36.0, `@rive-app/react-webgl` last 4.27.3, `rive-react` last 4.24.0
  (2025-11-10). *Measured by the fold:* dotLottie ≈ 33 KB JS gzipped plus ≈ 480 KB WASM as jsDelivr
  served it, `lottie-web` ≈ 76 KB, Rive ≈ 820 KB `rive.wasm` (`webgl2` ≈ 925 KB); `@rive-app/canvas`
  2.39.1 `rive.js` 95,915 B against `lottie.min.js` 76,136 B (gzip -9). *Source:* Rive's web parameters
  page and 2.44 types.
- **Spline:** `@splinetool/runtime` and `@splinetool/viewer` 2.0.71 (2026-10-05; 2.0.58 was
  2026-09-25, 2.0.1 2026-08-20), `@splinetool/react-spline` 4.1.0. **Vanta** 0.5.24 (2022-09-16).
- **Scroll and transitions:** `locomotive-scroll` 5.0.1 (5.0.0 and 5.0.1 2026-01-15) depends on
  `lenis` 1.3.17 exactly; `lenis` 1.3.26. `swup` 4.10.0, `@swup/a11y-plugin` 5.2.1, `@swup/head-plugin`
  2.3.1, `@barba/core` 2.10.3 (2024-08-12), `@barba/prefetch` 2.2.0, `@barba/head` E404.
- **AOS** `latest` 2.3.4 (2018-10-03), `next` 3.0.0-beta.6 (2018-10-03). **vanilla-tilt** 1.8.1.
  *Source:* each package's stylesheet and script.
- **web-vitals** 6.2.3; 3.0.0 2022-08-24, 4.0.0 2024-05-13, 5.0.0 2025-05-07. Re-read from the
  tarballs for this record: `getCLS` present in 3.0.0's `dist` and absent from 4.0.0 on, `onFID`
  present through 4.0.0 and absent from 5.0.0 on. web.dev: INP became a Core Web Vital on March 12,
  2024, replacing FID.

Dropped because it did not re-verify: the anime.js 4.4.0 release notes' statement about what a
`stagger` `use` callback receives. The shipped 4.4.0 and 4.5.0 code passes a number, so the
reference states the code and notes that the release notes disagree.

## Deviations from the spec, kept

- **Text3D, inverted to the source.** The spec said drei's `<Text3D height>` is ignored on r173+.
  The source shows drei passes `height` to three-stdlib's TextGeometry as depth, so `height` works
  there and a `depth` prop does nothing; it is three's own TextGeometry that ignores `height` since
  r173. The compressed-glTF facts overflowed into the new `references/compressed-gltf.md` to keep the
  SKILL body within its budget.
- **`jsrepo.config.ts`, not `jsrepo.json`.** jsrepo 3.x reads only the TypeScript config; the JSON
  file is the 2.x format, so the reference names both.
- **Two clauses outside the planned files:** the page-transitions SKILL's no-new-dependency line now
  allows a route swapper, and `craft-reviewer`'s page-transitions row checks the route-swapper section.
- **skill-router:** the README's library and registry-install lines updated; a `locomotive-scroll`
  content route added; the command row also keys on a `https://reactbits.dev/r/` URL, React Bits'
  jsrepo form. No glob row: neither registry targets a fixed install directory.

## Staleness gaps, recorded and not built

The three gaps are in `scripts/check-doc-staleness.sh`'s "does NOT catch" header and in
`.claude/skills/digest-refresh/SKILL.md`: `--live` runs only by hand while CI runs the age check
alone (motion 14 went unseen until a hand run); `npm:` is the only stamp tail read, so a
`composer:`/Packagist major surfaces only through the age warning; a versioned docs URL is HEADed,
never probed for the next version. digest-refresh's objection to a cron is narrowed to one that
re-stamps; the recorded proposal is a detect-only scheduled `--live` run. The working brief,
`taskmaster-docs/briefs/2026-10-05-staleness-detection-gaps.md`, is gitignored.

## Sizes

Markdown bytes under `skills/`, every `.md` counted (`find <dir> -type f -name '*.md' -exec cat {} +
| wc -c`), before at `8adb66da`, after on this commit's tree:

| plugin | before | after | the corpus gate's own count (generated files skipped) |
|---|---|---|---|
| craft-layer | 597,558 | 617,112 | 590,461 → 610,015 |
| ui-ux | 142,894 | 151,367 | 137,675 → 146,148 |

ui-ux stays under the 160,000-byte cap on either count. craft-layer was already the one plugin over
it, so `pc_plugin_corpus` cannot see its growth; that cost was accepted in the spec.

## The overlap check

No 8-word run in any line this branch added under `plugins/` occurs in the upstream copy. Method:
every file in the copy except the `.zip` and `.pyc` files, plus the contents of the 22 skill `.zip`
archives extracted to a scratch directory (402 files, 250,818 distinct runs), lower-cased and split
on whitespace, code fences included; against every `+` line of `git diff origin/master -- plugins/`
plus the one untracked file, `compressed-gltf.md`, read both line by line and with each block of
consecutive added lines joined, so a run wrapped across two lines is also caught. Run on 2026-10-06
after the CHANGELOG entries were written:

```
upstream files=402 grams=250818 | added lines=551 in 82 runs, untracked files=1
hits=0
```

A second pass with punctuation stripped from every word (194,571 runs) also found 0. Control: the
first 12-word line of upstream's `gsap-scrolltrigger/SKILL.md`, fed through the same matcher, shared
43 runs with the copy. Residual: a paraphrase, or a copy that changes one word in every eight, passes.

## What stays unmeasured

No eval with a control arm measures whether any folded fact changes what the model writes, builds
or installs. The skill-router routes are the only gated part (`route.test.sh`); every reference is
recorded, and the reviewer, audit, Aceternity and web-vitals rules are agent-graded. Not recorded
here: the install-alone proof of each bumped plugin, run after this commit.
