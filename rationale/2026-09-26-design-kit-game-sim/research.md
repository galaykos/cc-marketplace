# Research shards — 2026-09-26

Four `ultra-deep-research:researcher` shards, run in parallel, each asked for atomic claims with
a verbatim quote and the URL it opened. Compressed here; tier 1 = primary spec/docs/repo,
2 = author's own published material, 3 = secondary press, 4 = search-snippet only (not opened).
Claims the shards marked UNVERIFIED or NOT_FOUND are listed at the end of each shard because
they are the residual, not because they are less interesting.

## B. Typography for playful / game UI

**Faces acclaimed products actually use**
- Duolingo: headlines in Feather Bold (custom, Fontsmith, 2019 Johnson Banks identity); the app UI in DIN Next Rounded. One expressive display face + one plain rounded UI face. — fontsinuse.com/uses/59497 (t2); monotype.com "duolingo-custom-font-inspired-their-owl-mascot-duo" (t2): letterforms "directly inspired by the curves and shapes of Duo the owl".
- NYT Wordle title: NYT Karnak Condensed 700 (Font Bureau / Matthew Carter). — fontsinuse.com/typefaces/31767/nyt-karnak (t2). Wordle-specific use not confirmed on a primary NYT page.
- Monument Valley → Museo slab: third-party catalog only (t4). Alto's, Threes, Two Dots: nothing primary found.

**Open-licence candidates (OFL / Google Fonts)**
- Fredoka — rounded "bubble" display, variable `wght`; used as a project-wide theme default in a game repo (github.com/zoid-by-izook/test-game/pull/48, t3). Baloo, Chewy, Bungee, Lilita One all OFL. — madegooddesigns.com/best-bubble-fonts (t3)
- Bricolage Grotesque — `opsz` 12–96, `wdth` 75–100, `wght` 200–800: one file for display-to-UI duty (t3, axis ranges from Fontsource/npm listings; fonts.google.com returned an empty page to the fetcher).
- Press Start 2P — "the instant shorthand for retro, 8-bit and indie pixel games" — madegooddesigns.com/best-fonts-for-game-titles, 2026-06-08 (t3).
- Tiny5 — 5-pixel variable family with six axes: Weight, Width, Italic, Roundness, Bleed, Jitter — itch.io/t/6984947 (t3).
- 2024–2026 Google Fonts additions "ship as variable fonts with weight axes at minimum, often with optical-size, width, grade" — madegooddesigns.com/best-new-google-fonts-2026 (t3). Audiowide (rounded techy), Teko (condensed athletic) cited for arcade/sports titles (t3).

**Conventions**
- Tabular numerals for anything that updates: "tabular-nums should be the default for any number that updates (timers, counters, prices, percentages, scores, live data)" — x.com/sorenblank/status/2028520200417706017 (t4); mechanism at loke.dev/blog/css-font-variant-numeric-tabular-nums (t3); game-HUD framing at fontalternatives.com/blog/gaming-fonts-hud-esports-branding (t3). MDN property page confirmed to exist (t1).
- Modular scale: 1.25 "the safer choice for complex UI", 1.333 "most widely used ratio for web" (t4 synthesis); dual scale (1.125–1.2 UI, 1.333–1.5 display) common (t4).
- Two faces the safe default, three the practical maximum "only when each has a clear, distinct job" (t4).
- Game accessibility: contrast ≥ 4.5:1 for text/UI; "where that is not possible, use prominent outlines and shadows to separate them from the background" — gameaccessibilityguidelines.com/provide-high-contrast-between-text-ui-and-background (t2). Readable default size: "use 28px as a minimum rather than a target" (10-foot UI at 1080p) — gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size (t2).
- `font-variation-settings` is animatable (hover, keyframes, scroll timelines); reserve a text track so morphing type does not shift layout (t4). Subsetting "can reduce 90KB to 15KB"; `size-adjust`/`ascent-override` metric-matched fallbacks kill font CLS (t4).

**Generic tells (typography)**
- "The blue-to-purple gradient is the single loudest AI tell in 2026"; "Inter is a genuinely excellent typeface, which is exactly why it became the default"; the fingerprint is "the Inter font, an indigo-to-purple gradient, a row of three rounded feature cards with thin-line icons, weightless headline copy" — 925studios.co/blog/ai-slop-design-tells, 2026-09-23 (t3).

**Unverified / not found:** primary type choices for Monument Valley, Alto's, Threes, Two Dots; a shipped tic-tac-toe type case study; any game-specific "display + UI + mono for score" pairing formula; Google's own rationale for any 2025–26 addition; fonts.google.com specimen pages (fetcher got title-only pages, so every axis claim is t3/t4).

**Six brief lines the shard derived:** (1) one expressive display face + one plain legible UI face, never the display face at HUD sizes; (2) `tabular-nums` on score/move counters; (3) ≥ 4.5:1 against the sprite art, outline/shadow for labels over illustrated tiles; (4) ~28px floor for primary HUD text, a floor not a target; (5) name the display face — Inter + gradient + all-caps eyebrow is the 2026 tell; (6) candidates: Fredoka (`wght`), Bricolage Grotesque (`wght`/`wdth`/`opsz`), Tiny5 (six axes) or Press Start 2P for a pixel treatment.

## C. Motion — Lottie, Rive, sprite sheets, CSS/WAAPI

**Lottie / dotLottie / Rive, 2025–26**
- dotlottie-web: "three rendering backends — Software (Canvas2D), WebGL2, and WebGPU (experimental)", a "Rust + WASM core" shared with the native players; `.lottie` "bundles multiple animations, themes, state machines, and embedded assets into a single compressed file" — github.com/lottiefiles/dotlottie-web (t1).
- dotLottie gained interactive state machines "in late 2025" — unicornicons.com/blog/lottie-vs-rive-performance (t3).
- Rive web runtime "approximately 200KB gzipped (it includes a WASM binary), compared to lottie-web's ~60KB" — unicornicons.com/learn/rive-vs-lottie (t3; the shard flagged this number cluster as circular, no primary benchmark found).
- Rive's new runtime: "Rive Renderer, Data Binding, Layouts, Scrolling, N-Slicing, Vector Feathering"; data binding "when data changes, your scene updates automatically, and changes made in your scene can be written back" — rive.app/blog/data-binding-supercharged-lists-images-and-artboards (t2).
- LottieFiles: "In 2025, a large portion of the content has moved behind premium plans" — vijaytalksai.com/lottiefiles-review (t3).
- GSAP "is now 100% free including all of the bonus plugins" since May 2025 (Webflow) — css-tricks.com/gsap-is-now-completely-free-even-for-commercial-use (t2). Framer Motion → "Motion", framework-independent — motion.dev/docs/gsap-vs-motion (t3). GSAP for "precise, complex, timeline-orchestrated motion — scroll-driven scenes, sequenced hero animations, SVG morphing"; Motion for component state/enter-exit/gestures — hontran.dev/blog/gsap-vs-framer-motion (t3).

**Sprite sheets**
- `steps()` "breaks an animation into discrete segments rather than running continuously"; shift `background-position` by one frame per step ("six steps and 64 pixels per step … 384px") — blog.teamtreehouse.com/css-sprite-sheet-animations-steps (t3).
- `image-rendering: pixelated` for upscaled small art — kbravh.dev/interactive-pixel-spritesheet-animations-with-css (t3).
- TexturePacker (since 2010) detects frame sequences and exports for PixiJS — codeandweb.com/texturepacker/tutorials/…pixijs (t3); PixiJS AssetPack "supports multi-resolution output with resolutions like @1x and @0.5x" — pixijs.io/assetpack/docs/guide/pipes/texture-packer (t2).

**Juice / game feel**
- "Juice it or lose it" (Jonasson & Purho, May 2012) is the canonical talk; "whatever feels 'about right' in your animation, push it 30% further" — gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design (t3).
- "Juice is something you add on top of a thing that already works, never a load-bearing part" — resprawn.medium.com/when-you-play-a-great-game-it-feels-good (t3).
- Emil Kowalski's review-animations STANDARDS.md (t2, github.com/emilkowalski/skills): "Button press feedback: 100–160ms; Tooltip/popover: 125–200ms; Dropdown/select: 150–250ms; Modal/drawer: 200–500ms"; "UI animations stay under 300ms"; ease-out `cubic-bezier(0.23, 1, 0.32, 1)`; spring bounce 0.1–0.3; "Item stagger delays: 30–80ms"; press scale 0.95–0.98, "never from scale(0)".
- canvas-confetti: "performant confetti animation in the browser", `disableForReducedMotion` — github.com/catdad/canvas-confetti (t1 via search, not re-fetched).

**Accessibility and performance**
- `prefers-reduced-motion`: "Animations such as scaling or panning large objects can be vestibular motion triggers"; Baseline since January 2020 — developer.mozilla.org/…/@media/prefers-reduced-motion, modified 2026-06-10 (t1).
- "'Reduce' means less motion, not a frozen page. Swap large movement for a gentle opacity fade rather than removing all feedback"; WCAG 2.3.3 (AAA) targets large-scale movement — blog.pope.tech/2025/12/08/design-accessible-animation-and-movement (t2).
- "Where you can, stick to changing transforms and opacity"; `will-change` sparingly — web.dev/articles/animations-and-performance (t1).
- Same-document View Transitions cross-browser (Chrome 111+, Safari 18+, Firefox 144+); cross-document not in Firefox stable — brainstormsandraves.com/css/view-transitions-2026 (t3). Scroll-driven animations: Chrome/Edge 115+, Safari 18+, Firefox stable still flagged at 152 (t3).
- SMIL still ships in every engine; spec recommends CSS/WAAPI for new work — css-tricks.com/smil-is-dead-long-live-smil (t3).

**Unverified / not found:** a primary "Lottie is the wrong tool when…" threshold; Rive licence terms 2025–26; Apple HIG / Material duration tokens (not searched within budget); `linear()` easing and `@starting-style` status (not covered); Phaser 4 conventions.

**Six brief lines the shard derived:** (1) place-in ≤ 300 ms with a strong ease-out or a spring with bounce ≤ 0.3; (2) press feedback 100–160 ms, scale 0.95–0.98; (3) stagger 30–80 ms for the board's reveal; (4) reduced motion = smaller/opacity motion, never a frozen board; (5) animate only `transform`/`opacity`; (6) **for the marks, win line and celebration: inline SVG + CSS/WAAPI is the floor and needs no runtime; Lottie/dotLottie (~60 KB) earns its place only for a hand-authored character celebration; Rive (~200 KB WASM) only if a state machine (idle → placed → win → lose) must be authored by a motion designer rather than in CSS; a raster sprite sheet only for painterly frame-by-frame art that vectors cannot carry.**

## A. Visual design of premium 2D sprite games and board-game UIs

**Awards 2024–26**
- Apple Design Awards 2025: Visuals & Graphics winner Infinity Nikki ("wildly detailed fabrics and beautifully realized lighting"); Delight & Fun winner Balatro ("Innovative card game mixing poker, solitaire, and deck-building"); finalist Neva, "Masterful visual language connecting imagery to emotion" — per-level palette tied to emotion — developer.apple.com/design/awards/2025 (t1).
- IGF 2025 Excellence in Visual Art: Hauntii; finalists Consume Me (Grand Prize + Nuovo), Nine Sols — igf.com/archive-2025 (t1); gamedeveloper.com 2025-03-20 (t2).
- Awwwards games & entertainment listing, viewed 2026-09-26: Lacoste Ace Breaker SOTD + Developer Award 2026-08-03; Cozy Eating Village HM 2026-08-30 "warm, inviting visuals suited to its cozy gaming concept" — awwwards.com/websites/games-entertainment (t2). BAFTA Games artistic achievement, CSS Design Awards, Nintendo web: not searched within budget.

**Sprite conventions**
- Export = one PNG atlas + an XML/JSON sidecar of frame positions, not loose frames; "pixel art doesn't scale very well unless the size is a power of two" — kenney.nl/knowledge-base/game-assets-2d/editing-2d-game-assets (t2).
- Squash & stretch "the very first rule" of Disney's twelve, applied to UI with subtle values; "spring physics … tends to feel a lot more natural" — joshwcomeau.com/animation/squash-and-stretch (t2).
- "Hi-bit" pixel art (retro look without the palette/resolution ceilings): search-snippet only (t4).

**Casual / board-game UI**
- Two Dots: Webby 2018 "Best Visual Design" nomination; single-shape-family clarity — en.wikipedia.org/wiki/Two_Dots_(video_game) (t3).
- Poki's game-page guide (t1, developers.poki.com/guide/your-game-page): "Simplify: hide non-essential UI, and center your action"; "Minimal text: let the visuals do the talking"; "Remove the cursor."
- Monument Valley's named lineage (Japanese prints, minimalist sculpture, Windosill, Fez, Sword & Sworcery): t4 snippet.
- **Not found:** any published critique that compares a "premium" tic-tac-toe with a default one; Dribbble/Mobbin pages did not render for the fetcher. Absence is data: the brief has to define premium itself.

**Playful design systems**
- Duolingo's art style: "three fundamental shapes: the rounded rectangle, the circle, and the rounded triangle"; "minimalistic, playful aesthetic that is quick to produce, clear to understand, and fun to learn with"; "the fewest details needed to get the point across" — blog.duolingo.com/shape-language-duolingos-art-style (t1). The offset-shadow button "lip": t4 lead only.
- Material 3 Expressive (May 2025): "a system of more natural, springy animations meant to bring a moment of delight"; "responsive components and emphasized typography" — blog.google/…/material-3-expressive-android-wearos-launch (t1).

**Generic tells (visual)**
- "The purple-to-cyan gradient. Glassmorphism with a neon glow. Six identical cards in a row, each with an icon, a heading, and two lines of text."; "A bounce on every hover." — smoothui.dev/blog/ai-design-slop, 2026-06-24 (t2).

**Five brief lines the shard derived:** (1) a named minimal shape vocabulary for marks and board; (2) a named placement "juice" mechanism (squash-stretch, spring, offset-shadow lip) rather than a default transition; (3) the asset pipeline stated (atlas + sidecar, or inline SVG); (4) storefront discipline — strip chrome, centre the 3×3, nothing generic bleeding in; (5) an explicit rejection list of the SaaS/AI tells.

## D. Graphic-design conventions, effects and colour, 2025–26

**Trends**
- Glassmorphism survives as small chrome (sticky header on `backdrop-filter`), not full surfaces; bento grids default for feature sections at "6 to 9 tiles" — theplusaddons.com/blog/web-design-trends-2026 (t3). `backdrop-filter` "computationally expensive … 15 to 30 percent FPS drops" — dev.to/studiomeyer_io (t3; number uncorroborated).
- Apple Liquid Glass (WWDC 2025, iOS 26): "a shift away from the extreme flatness that dominated the last decade" — hyperpixel.co.uk (t3).
- Claymorphism "settled into a comfortable niche: onboarding flows, kids' apps, fintech with a friendly face" and "can still pass contrast checks when the fill color is chosen well" (t4). Neo-brutalism in commercial use adds "saturated colour, generous type and working affordances" (t4).
- Kinetic type "fights screen readers, fights search crawlers, and adds layout shift" — stays demo-reel; heavy Spline heroes "800kB to 2MB before users see anything", confined to agency portfolios — dev.to/studiomeyer_io (t3).
- Pantone 2026: Cloud Dancer 11-4201, "a diaphanous white with atmospheric qualities", companion palettes = neutral base + selective vivid accents — pantone.com/articles/color-of-the-year/color-of-the-year-2026-color-palettes (t1). WGSN/Coloro: Transformative Teal (t4).

**Colour for two players**
- "Blue and orange are distinguishable by all common types of color blindness"; red/green "appear as brownish-yellow to users with deuteranopia and protanopia"; never colour alone — pair with shape, label or pattern — colorcontrast.org/color-blind-colors (t3).
- APCA: "Large/thick elements do not need brute-force contrast levels"; "Lc 45 - The minimum for larger, heavier text (36px normal weight or 24px bold)"; "The WCAG 4.5:1 ratio can be functionally unreadable when a color is near black" — git.apcacontrast.com/documentation/APCAeasyIntro (t1). WCAG 3 / APCA "still a draft" — ruitina.com/apca-accessible-colour-contrast (t2).
- **A specimen of the fabricated-statistic pattern:** "OKLCH usage in production at 18 percent, rising 1.4 points per month", attributed to State of CSS 2025, does not appear on 2025.stateofcss.com/en-US/features (t1 for the absence). Do not quote it.

**Effects**
- SVG `feTurbulence` grain "300 bytes instead of a 200KB JPEG texture image" (t3); keep `feGaussianBlur` `stdDeviation` low for glows; "some browsers still rasterize heavy filters inefficiently" — theyellowflashlight.com/svg-filters-branding (t3). The ">4 chained primitives → 60fps to 12fps on iPhone SE" figure was not on the fetched page (t4).

**Generic tells (root cause and list)**
- Tailwind's co-founder, August 2025: apologised for "making every button in Tailwind UI use `bg-indigo-500` five years ago, because now every AI-generated interface on earth is purple" — dev.to/alanwest/why-every-ai-built-website-looks-the-same (t3).
- "the four horsemen of the apocalypse": pill badge, all-caps kicker, icon-studded card, purple gradient (t4). Emoji as icons (t4). "It's like an insecure designer. The agents are very insecure." — 5–8 competing type sizes, kicker labels, "two-pixel color swipes on card edges", gradient text; the fix is "Human curation through deletion" — finance.biggo.com/news/02e3364420ca66dc (t3).

**Not found:** an Awwwards annual trend editorial; It's Nice That / Codrops / Smashing round-ups opened directly; a primary OKLCH/`color-mix()` adoption number; any acclaimed casual game's documented colour system.

**Six brief lines the shard derived:** (1) X and O distinguishable by silhouette and weight, not hue alone; (2) blue/orange is the best-attested colour-blind-safe pair; (3) size the contrast rule to the element — large marks may sit at APCA Lc 45, HUD text at the text rule; (4) restraint on material effects — a narrow low-blur inner glow on the active cell, no full-surface glass or filter chains; (5) reject the tell-set by name; (6) calm neutral base, one or two saturated accents.
