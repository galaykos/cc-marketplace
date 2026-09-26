/* craft-layer — the trigger suite.
 * ---------------------------------------------------------------------------
 * Run ALL THREE of this file, `contrast.mjs` and `divergence.mjs` FROM THE
 * PLUGIN, never a copy — `commands/audit.md` step 4 owns the invocation, and a
 * vendored gate is a snapshot with no freshness signal. From the crafted
 * project's root, with the two dev dependencies installed THERE:
 *
 *     npm i -D @playwright/test @axe-core/playwright && npx playwright install chromium
 *     CRAFT_EXPECT_TITLE='<a string only THIS build serves>' \
 *       BASE_URL=http://localhost:5173 NODE_PATH="$PWD/node_modules" \
 *       npx playwright test --config "$CLAUDE_PLUGIN_ROOT/template/craft-gates/playwright.config.ts"
 *     node "$CLAUDE_PLUGIN_ROOT/template/craft-gates/contrast.mjs"
 *     node "$CLAUDE_PLUGIN_ROOT/template/craft-gates/divergence.mjs"
 *
 * Neither flag is decoration. Playwright has no `--spec` flag, so without
 * `--config` the run scans the PROJECT's testDir and exits 0 having found no
 * craft gate; without `NODE_PATH` this file's own imports resolve from the
 * plugin directory, which has no `node_modules`, and the run dies before the
 * first test.
 * Running only some of the three is the same quiet failure by another route: a
 * gate never run never fails, it just never runs, and silence reads as a pass.
 *
 * WHY THIS EXISTS — read before deleting a check.
 *
 * Craft gates catch defect TYPES: wrong contrast, missing spine slot, absent
 * signature. This file covers defect TRIGGERS instead — the conditions that
 * SURFACE a fault (ODC's term: "the force that surfaced the Fault to create the
 * failure"). A review can improve type coverage indefinitely and never fire a
 * new trigger, which is how whole classes of defect stay structurally
 * invisible however careful the reviewer is.
 *
 * The default trigger set for a visual build is the five below. They are cheap
 * (a few seconds), and each has caught a real defect that every other gate
 * in this plugin missed:
 *
 *   - 200% zoom      → a visually-hidden <caption> keeping its min-content
 *                      width and dragging the page into horizontal overflow.
 *                      Invisible at every normal viewport.
 *   - capture        → a leader label clipped mid-word at its viewBox edge on
 *                      the first screen, behind a clean typecheck, a clean
 *                      lint, measured contrast and a full DOM assertion pass.
 *                      This trigger writes IMAGES, not a verdict: nothing in
 *                      this file can see that class, so something has to open
 *                      them.
 *   - reduced motion → transitions surviving the media query, and the JS,
 *                      canvas, smooth-scroll and video motion a stylesheet
 *                      never shows (GSAP, Motion, Lenis, three.js, Lottie).
 *   - forced colours → content vanishing under Windows High Contrast.
 *   - axe            → the machine-testable ~30% of WCAG, on every commit.
 *
 * ADDING a trigger is the point. When a defect escapes to production, ask what
 * condition would have surfaced it, and add THAT here — not another assertion
 * under a trigger you already run.
 *
 * The `sight:` pair below is the exception that proves that rule: two ordinary
 * assertions, riding triggers this file already fires, that measure the
 * clipping and collision an image shows and a query cannot. They are the half
 * of the capture trigger's defect class a machine CAN judge; the rest still
 * needs an opened image. `fixture-sight.html` and `fixture-sight-clean.html`,
 * in this plugin's `scripts/__tests__/fixtures/`, are the pair that proves they
 * fail for the right reason.
 */
import { test, expect, type Locator, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { mkdirSync, rmSync } from 'node:fs'

const URL = process.env.BASE_URL ?? 'http://localhost:5173'

/* ------------------------------------------------------------ check: identity */
/* WHY THIS EXISTS — a port is not an identity. In a real run `:5173`, the
   default above, was held by an UNRELATED project while the build under test
   served on `:5182`. An unattended `npx playwright test` captured, opened and
   reported ANOTHER APPLICATION'S SCREENSHOTS as this build's — through the one
   step whose entire purpose is looking at what shipped. Nothing flagged it:
   every check in this file passed, truthfully, about the wrong page.

   The identity source is `CRAFT_EXPECT_TITLE` — any string only the build under
   test serves, matched against the page's <title> or its body text. It is
   PASSED IN, not derived: this suite runs inside the target project and has no
   access to the offer contract or to `divergence.mjs`'s path resolution, so it
   cannot look up what this build is supposed to be called.

   Two behaviours, and the difference between them is the whole check:
   - UNSET is `not measured`, never a silent pass — this file's standing
     convention. The run is skipped WITH A LOUD NOTE naming what was not proved,
     because the report otherwise reads exactly like a verified capture.
   - SET AND NOT MATCHING is a FAILURE, not a note. The shots are of the wrong
     application, and no other assertion here can tell. */
const EXPECT_TITLE = process.env.CRAFT_EXPECT_TITLE?.trim()
let identityNoted = false

/** Ask whether the page at BASE_URL is the build under test. Throws when the
    question was asked and answered NO; when the caller gave us nothing to ask
    with, records `not measured` on the result and says so once, loudly. */
async function assertIdentity(page: Page) {
  const seen = await page.evaluate(() => ({
    title: document.title,
    text: (document.body?.innerText ?? '').slice(0, 5000),
  }))
  if (!EXPECT_TITLE) {
    const note =
      `IDENTITY NOT MEASURED — CRAFT_EXPECT_TITLE is unset, so NOTHING here proved` +
      ` that ${URL} is serving this build. The page answering it calls itself` +
      ` ${JSON.stringify(seen.title)}. Ports get reused: any screenshot this run writes` +
      ` may be another application's, and every other result below is about whatever` +
      ` page that is. Re-run with CRAFT_EXPECT_TITLE='<a string only this build serves>'.`
    // On the RESULT, so a report read later carries it too — a console line
    // nobody scrolled back to is how the wrong-app run passed for a whole day.
    test.info().annotations.push({ type: 'not measured', description: note })
    if (!identityNoted) {
      identityNoted = true
      console.log(`\n!!! ${note}\n`)
    }
    return
  }
  expect(`${seen.title}\n${seen.text}`,
    `WRONG APPLICATION at ${URL}: expected ${JSON.stringify(EXPECT_TITLE)} in the page` +
    ` title or body, but the page there calls itself ${JSON.stringify(seen.title)}.` +
    ` Something else is holding this port — check BASE_URL before reading any shot.`)
    .toContain(EXPECT_TITLE)
}

test('identity: BASE_URL serves the build under test', async ({ page }) => {
  await page.goto(URL)
  await assertIdentity(page)
  test.skip(!EXPECT_TITLE, 'not measured: CRAFT_EXPECT_TITLE unset — see the note in the output')
})

/** How the project switches theme. Override if it is not a `.dark` class. */
const setTheme = (page: Page, dark: boolean) =>
  page.evaluate((d) => document.documentElement.classList.toggle('dark', d), dark)

const overflow = (page: Page) =>
  page.evaluate(() => ({
    body: document.body.scrollWidth,
    client: document.documentElement.clientWidth,
    offenders: [...document.querySelectorAll('body *')]
      .filter((el) => {
        if (el.scrollWidth <= document.documentElement.clientWidth) return false
        const ox = el.parentElement ? getComputedStyle(el.parentElement).overflowX : ''
        return !['auto', 'scroll', 'hidden'].includes(ox)   // ignore legit scrollers
      })
      .slice(0, 4)
      .map((el) => `${el.tagName}.${(el.className?.toString() || '').slice(0, 40)}`),
  }))

/* -------------------------------------------------------------- trigger: axe */
for (const mode of ['light', 'dark'] as const) {
  test(`axe: no WCAG 2.2 A/AA violations (${mode})`, async ({ page }) => {
    await page.goto(URL)
    await setTheme(page, mode === 'dark')

    /* `color-contrast` is disabled DELIBERATELY and NARROWLY: axe-core cannot
       parse oklch()/lab() computed values and reports false positives on every
       modern-colour build (dequelabs/axe-core#4007). Contrast is covered by
       `contrast.mjs`, which computes the ratios from the token source and is
       the gate of record. This disables a broken checker, not a check — if
       your build has no contrast gate of its own, DELETE this line instead. */
    const { violations } = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
      .disableRules(['color-contrast'])
      .analyze()

    if (violations.length) {
      console.log(`\n[${mode}] ` + violations.map((v) =>
        `${v.id} (${v.impact}) x${v.nodes.length}: ${v.help}\n    ${v.nodes[0]?.target}`).join('\n'))
    }
    expect(violations.map((v) => v.id)).toEqual([])
  })
}

/* ------------------------------------------------------------ trigger: capture */
/* The one trigger whose output is an IMAGE rather than a verdict. A build once
   passed a clean typecheck, a clean lint, a 107,016-state sweep, measured WCAG
   contrast and a full DOM assertion pass — and then one picture showed a leader
   label reading `£1,200 DAILY CEILING — ABSOLUT`, cut mid-word, on the first
   screen. Every assertion in this file is blind to that: the text exists,
   carries the right string, computes the right colour, and is unreadable.

   This trigger only TAKES the pictures. The gate is not discharged until an
   agent or a human opens them and says what is visible — `commands/audit.md`
   step 5 owns that half, and a shot nobody opened is not a look.

   Two rules about where, both load-bearing:
   - The breakpoints are explicit, and they are NOT the zoom trigger's
     viewports. Those are halved CSS pixels chosen for a WCAG check; they are
     near-useless frames for judging craft.
   - Capture runs in the ORDINARY contexts only — never under zoom, forced
     colours, or the motion preference. Those contexts exist to break the page
     on purpose, and a picture of a deliberately broken page teaches nothing
     about the design that ships. */
const SHOTS_DIR = '.craft-layer/shots'

const BREAKPOINTS = [
  ['phone', 390, 844],
  ['tablet', 768, 1024],
  ['desktop', 1280, 800],
] as const

/** Wait for what a scroll just started — webfonts, lazy images, and the FINITE
    animations the reveals fired — under a hard cap, because an unbounded wait
    on a page that never goes quiet is a hang, not a check. Endless loops are
    never awaited: `animations: 'disabled'` freezes those as the shot is taken. */
async function quiet(page: Page, capMs = 3000) {
  await page.evaluate(async (cap) => {
    const ok = (p: Promise<unknown>) => p.then(() => {}, () => {})
    const work = (async () => {
      await ok(document.fonts.ready)
      await Promise.all([...document.images].filter((i) => !i.complete).map((i) =>
        new Promise<void>((r) => {
          i.addEventListener('load', () => r(), { once: true })
          i.addEventListener('error', () => r(), { once: true })
        })))
      await Promise.all(document.getAnimations()
        .filter((a) => (a.effect?.getComputedTiming().iterations ?? 1) !== Infinity)
        .map((a) => ok(a.finished)))
    })()
    await Promise.race([work, new Promise<void>((r) => setTimeout(r, cap))])
  }, capMs)
}

/** Photograph the page a READER sees, not the one `goto` returns. On a
    scroll-orchestrated build every reveal is still unfired at load, so an
    unsettled shot is a picture of an empty stage. Walk to the bottom, let what
    that started finish, then return to the top so the viewport shot frames the
    first screen. */
async function settle(page: Page) {
  await page.evaluate(async () => {
    const frame = () => new Promise((r) => requestAnimationFrame(() => r(null)))
    const step = Math.max(1, Math.round(window.innerHeight * 0.9))
    for (let y = 0; y < document.body.scrollHeight; y += step) {
      window.scrollTo(0, y)
      await frame()
    }
    window.scrollTo(0, document.body.scrollHeight)
    await frame()
  })
  await quiet(page)
  await page.evaluate(() => window.scrollTo(0, 0))
  await quiet(page)
}

test.describe('capture: the shipped design, at the widths people read it', () => {
  /* Serial so the prune runs ONCE, ahead of every shot in the group: a
     per-worker prune deletes a sibling worker's output mid-run. */
  test.describe.configure({ mode: 'serial' })

  test.beforeAll(() => {
    /* Prune first. Stale shots are worse than no shots — they read as this
       run's evidence, and nothing in the image says which run made it. */
    rmSync(SHOTS_DIR, { recursive: true, force: true })
    mkdirSync(SHOTS_DIR, { recursive: true })
  })

  for (const [label, width, height] of BREAKPOINTS) {
    for (const mode of ['light', 'dark'] as const) {
      test(`capture ${label} ${width}w (${mode})`, async ({ page }) => {
        await page.setViewportSize({ width, height })
        await page.goto(URL)
        /* Identity before the shutter: a wrong-app capture is the failure this
           whole check exists for, so refuse to photograph a page that does not
           answer to CRAFT_EXPECT_TITLE rather than write shots nobody can
           later tell apart from this build's. */
        await assertIdentity(page)
        await setTheme(page, mode === 'dark')
        await settle(page)
        const stem = `${SHOTS_DIR}/${width}-${mode}`
        // The whole composition: rhythm, section shapes, what the scroll reveals.
        await page.screenshot({ path: `${stem}-full.png`, fullPage: true, animations: 'disabled' })
        // The first screen, framed exactly as the reader meets it.
        await page.screenshot({ path: `${stem}-top.png`, animations: 'disabled' })
      })
    }
  }
})

/* ---------------------------------------------- sight: the machine-gradable half */
/* The capture trigger writes images because most of this defect class needs an
   eye. These two assertions are the part that does NOT — and a check a machine
   can run is never left to a judgement.

   MACHINE-GRADED here: text painted outside the box that clips it, and text
   landing on top of other text. Both run at the capture breakpoints, because a
   label that fits at 1280 and is cut at 390 is the ordinary case.

   AGENT-GRADED, in the images above and NOT here: a fixed or sticky layer
   covering the column beneath it (passing over content is what a layer is FOR,
   so these skip fixed/sticky subtrees rather than failing every site with a
   sticky header), truncation that reads as a mistake, and any element whose
   rendered position contradicts where the markup implies it sits. Saying which
   half is which is worth more than a check that pretends to cover both.

   `scripts/__tests__/fixtures/fixture-sight.html` carries three defects — one of
   each machine class plus the agent-graded rail — and `fixture-sight-clean.html`
   beside it is the same page without them. Point BASE_URL at each in turn: the pair is what proves these
   assertions fail for the right reason, and a check that has never failed on
   purpose is not known to work. */
for (const [label, width, height] of BREAKPOINTS) {
  test(`sight: no text is clipped by its container or its viewBox (${label})`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await page.goto(URL)
    await settle(page)
    const clipped = await page.evaluate(() => {
      const out: string[] = []
      const name = (el: Element) => {
        const cls = typeof el.className === 'string' ? el.className : el.getAttribute('class') || ''
        return `${el.tagName.toLowerCase()}${cls ? '.' + cls.trim().split(/\s+/)[0] : ''}`
      }
      const says = (el: Element) => `"${(el.textContent || '').trim().slice(0, 40)}"`

      // SVG text outside its own viewBox. Whatever the frame does not contain
      // is not painted — this is the defect that wrote this file.
      for (const svg of document.querySelectorAll('svg[viewBox]')) {
        if (getComputedStyle(svg).overflowX === 'visible') continue      // nothing clips
        const vb = (svg as SVGSVGElement).viewBox.baseVal
        if (!vb || vb.width <= 0) continue
        for (const t of svg.querySelectorAll('text')) {
          let b: DOMRect
          try { b = t.getBBox() } catch { continue }                     // not rendered
          if (b.width <= 0) continue
          const past = Math.max(
            vb.x - b.x, vb.y - b.y,
            b.x + b.width - (vb.x + vb.width), b.y + b.height - (vb.y + vb.height))
          if (past > 0.5) out.push(`${name(t)} ${says(t)} runs ${past.toFixed(0)}u past its viewBox`)
        }
      }

      // Text bigger than the box that hides its overflow. DECLARED truncation
      // — ellipsis, line-clamp — is a decision and is left alone; the silent
      // cut is the defect.
      for (const el of document.querySelectorAll('body *')) {
        if (el.children.length) continue                                 // leaf text only
        if (!(el.textContent || '').trim()) continue
        const cs = getComputedStyle(el)
        if (cs.display === 'none' || cs.display === 'inline' || cs.visibility === 'hidden') continue
        const clips = (o: string) => o === 'hidden' || o === 'clip'
        if (!clips(cs.overflowX) && !clips(cs.overflowY)) continue
        if (cs.textOverflow === 'ellipsis') continue
        if (cs.getPropertyValue('-webkit-line-clamp') !== 'none') continue
        // VISUALLY HIDDEN is clipped ON PURPOSE — that is the whole technique. Tailwind's
        // `sr-only`, Bootstrap's `.visually-hidden` and every hand-rolled variant collapse
        // the box to ~1px and clip it so the text stays in the accessibility tree and off
        // the screen. Flagging it reports every correctly-built table caption and skip link
        // as a defect, and a gate that fires on correct code is a gate people learn to
        // ignore. Detect the shape rather than a class name: tiny clipped box, or an
        // explicit clip-path/clip that hides everything.
        const tiny = el.clientWidth <= 2 && el.clientHeight <= 2
        const clipHidden =
          cs.clipPath === 'inset(50%)' || /rect\(0(px)?[,\s]/.test(cs.clip || '')
        if (tiny || clipHidden) continue
        if (el.clientWidth <= 0 || el.clientHeight <= 0) continue
        const overX = clips(cs.overflowX) ? el.scrollWidth - el.clientWidth : 0
        const overY = clips(cs.overflowY) ? el.scrollHeight - el.clientHeight : 0
        if (overX > 2 || overY > 2) out.push(`${name(el)} ${says(el)} cut by ${overX}x${overY}px`)
      }
      return out.slice(0, 5)
    })
    expect(clipped, 'text painted outside the box that clips it').toEqual([])
  })

  test(`sight: no text lands on top of other text (${label})`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await page.goto(URL)
    await settle(page)
    const collisions = await page.evaluate(() => {
      const layered = (el: Element) => {
        for (let n: Element | null = el; n && n !== document.body; n = n.parentElement) {
          const p = getComputedStyle(n).position
          if (p === 'fixed' || p === 'sticky') return true
        }
        return false
      }
      const boxes: { el: Element; r: DOMRect; text: string }[] = []
      for (const el of document.querySelectorAll('body *')) {
        if (el.children.length) continue
        const text = (el.textContent || '').trim()
        if (!text) continue
        const cs = getComputedStyle(el)
        if (cs.display === 'none' || cs.visibility === 'hidden' || Number(cs.opacity) < 0.1) continue
        if (layered(el)) continue                     // a layer is MEANT to pass over
        const r = el.getBoundingClientRect()
        if (r.width < 2 || r.height < 2) continue     // visually-hidden text
        boxes.push({ el, r, text })
      }
      const out: string[] = []
      for (let i = 0; i < boxes.length; i++) {
        for (let j = i + 1; j < boxes.length; j++) {
          const a = boxes[i], b = boxes[j]
          if (a.el.contains(b.el) || b.el.contains(a.el)) continue
          const w = Math.min(a.r.right, b.r.right) - Math.max(a.r.left, b.r.left)
          const h = Math.min(a.r.bottom, b.r.bottom) - Math.max(a.r.top, b.r.top)
          if (w <= 0 || h <= 0) continue
          const smaller = Math.min(a.r.width * a.r.height, b.r.width * b.r.height)
          // A clip of a corner is a rounding artefact; a quarter of the smaller
          // box is two things occupying one place.
          if (smaller <= 0 || (w * h) / smaller < 0.25) continue
          out.push(`"${a.text.slice(0, 30)}" over "${b.text.slice(0, 30)}"`)
        }
      }
      return out.slice(0, 5)
    })
    expect(collisions, 'these text boxes are printed on top of each other').toEqual([])
  })
}

/* ---------------------------------------------------- trigger: reduced motion */
test.describe('prefers-reduced-motion: reduce', () => {
  test.use({ contextOptions: { reducedMotion: 'reduce' } })

  /* "Reduce" means LESS motion, not none. Colour and opacity fades are the
     RECOMMENDED substitute for movement under this preference, so flagging them
     would fail every correctly-built site. What must not survive is MOTION:
     transforms, and animations that move something. */
  test('page renders, and no MOTION survives (fades may)', async ({ page }) => {
    await page.goto(URL)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    const moving = await page.evaluate(() => {
      const MOTION = /transform|translate|rotate|scale|top|left|right|bottom|margin|inset/
      return [...document.querySelectorAll('body *')]
        .filter((el) => {
          const cs = getComputedStyle(el)
          const live = (s: string) => s.split(',').some((d) => parseFloat(d) > 0)
          const movesOnTransition = live(cs.transitionDuration) && MOTION.test(cs.transitionProperty)
          // any running keyframe animation is suspect: we cannot read its tracks here
          const movesOnAnimation = live(cs.animationDuration) && cs.animationName !== 'none'
          return movesOnTransition || movesOnAnimation
        })
        .slice(0, 5)
        .map((el) => `${el.tagName}.${(el.className?.toString() || '').slice(0, 40)}`)
    })
    expect(moving, 'these still MOVE under reduced motion').toEqual([])
  })

  /* WHY THE FOUR TESTS BELOW EXIST. The one above reads computed CSS, and
     GSAP, Motion's JS path, anime.js, Lenis and every canvas runtime write
     nothing a stylesheet shows: a build ignoring the preference in all of them
     passed it. Each test below watches one channel the CSS read cannot, and
     names what moved. `scripts/__tests__/fixtures/fixture-motion-{js,canvas,clean}.html`
     are the controls — the two defective pages must fail here, the clean twin
     (same page, preference honoured) must not.

     What none of them sees, stated so a green is not read as more than it is:
     motion that starts only after an interaction (hover, click, drag, a
     carousel arrow); a scroll container other than the window; a small
     scrubbed element on a page past ~8 viewports, where the 32-stop walk
     stretches its step and may see it at fewer than three stops;
     `top`/`left`/`margin` animated by JS; tweens shorter than ~250ms; visible
     canvases past the first four, or changing under 0.1% of their pixels in 400ms;
     closed shadow roots, and OPEN ones for the transform walk (the video walk and
     the canvas locator pierce them); anything inside an iframe; elements past the
     first 1,500 on screen at a scroll stop; a pause button the video heuristic
     cannot name;
     opacity-only change, which is ALLOWED (see above). Whether the reduced
     state is a GOOD still frame is a judgement, not a sample — that stays with
     the reviewer and the shots. */

  test('JS motion: nothing moves on its own or tracks the scroll', async ({ page }) => {
    await page.addInitScript(recordWaapi)
    await openReduced(page)
    const r = await page.evaluate(sampleMotion, { maxSteps: 32, gapMs: 90, maxEls: 1500 })
    expect.soft(r.waapi,
      'WAAPI (Element.animate — Motion, anime.js waapi, hand-rolled) still MOVES under reduced motion').toEqual([])
    expect.soft(r.selfMoving,
      'these elements MOVE ON THEIR OWN under reduced motion (a JS tween or loop — GSAP, Motion, a marquee)').toEqual([])
    expect.soft(r.scrollTracking,
      'these elements TRACK THE SCROLL under reduced motion (scrub, parallax, scroll-driven)').toEqual([])
  })

  test('canvas: no <canvas> keeps animating', async ({ page }) => {
    await openReduced(page)
    const canvases = page.locator('canvas')          // pierces open shadow roots (<spline-viewer>)
    const total = await canvases.count()
    const moving: string[] = []
    // Visible and at least 16x16 first, THEN the cap: hidden or tiny canvases ahead in the
    // DOM must not use up the four. Short timeouts: a canvas removed mid-run is a note, not a hang.
    const picked: { c: Locator; label: string }[] = []
    for (let i = 0; i < total && picked.length < 4; i++) {
      const c = canvases.nth(i)
      try {
        if (!(await c.isVisible())) continue
        const box = await c.boundingBox({ timeout: 2000 })
        if (!box || box.width < 16 || box.height < 16) continue
        const label = await c.evaluate((el) => {
          const cv = el as HTMLCanvasElement
          return `canvas[${cv.id ? '#' + cv.id : ''}${cv.className ? '.' + String(cv.className).split(' ')[0] : ''}] ${cv.width}x${cv.height}`
        }, undefined, { timeout: 2000 })
        picked.push({ c, label })
      } catch (e) {
        test.info().annotations.push({ type: 'not measured', description: `canvas ${i + 1} of ${total}: ${String(e).split('\n')[0]}` })
      }
    }
    const scratch = await page.context().newPage()   // decode off the page under test: its CSP, its main thread
    try {
      for (const { c, label } of picked) {
        try {
          await c.scrollIntoViewIfNeeded({ timeout: 3000 })
          await page.waitForTimeout(300)             // let an on-screen-only loop wake up
          const shots: string[] = []
          for (let k = 0; k < 3; k++) {
            if (k) await page.waitForTimeout(400)
            shots.push((await c.screenshot({ timeout: 5000 })).toString('base64'))
          }
          const changed = await scratch.evaluate(pixelChange, shots)
          // BOTH gaps must change: one change is a late first frame or a resize settling.
          if (changed.every((f) => f > 0.001)) {
            moving.push(`${label}: ${changed.map((f) => (f * 100).toFixed(1) + '%').join(' then ')} of pixels changed 400ms apart`)
          }
        } catch (e) {
          test.info().annotations.push({ type: 'not measured', description: `${label}: ${String(e).split('\n')[0]}` })
        }
      }
    } finally {
      await scratch.close()
    }
    expect(moving, 'these canvases still ANIMATE under reduced motion — render one settled frame instead').toEqual([])
  })

  test('smooth-scroll: wheel scrolling stays native', async ({ page }) => {
    await openReduced(page)
    const found: string[] = await page.evaluate(() =>
      [document.documentElement, document.body]
        .filter((el) => el && getComputedStyle(el).scrollBehavior === 'smooth')
        .map((el) => `<${el.tagName.toLowerCase()}> computes scroll-behavior: smooth — gate it behind (prefers-reduced-motion: no-preference)`))
    /* Lenis marks its root `lenis` while alive and `lenis-smooth` only while it
       is animating a scroll itself, so the second class after a real wheel is
       the proof — presence alone would fail an instance started with
       smoothWheel off, which is instant. */
    const lenis = await page.evaluate(() => {
      const w = window as unknown as { lenisVersion?: string; __craftSmooth?: boolean }
      const alive = !!(document.querySelector('.lenis, [data-lenis-prevent], [data-lenis-prevent-wheel]') || w.lenisVersion)
      if (alive) {
        w.__craftSmooth = false
        const mark = () => { if (document.querySelector('.lenis-smooth')) w.__craftSmooth = true }
        new MutationObserver(mark).observe(document.documentElement, { attributes: true, attributeFilter: ['class'], subtree: true })
        mark()
      }
      return alive
    })
    if (lenis) {
      const vp = page.viewportSize() ?? { width: 1280, height: 720 }
      await page.mouse.move(vp.width / 2, vp.height / 2)
      await page.mouse.wheel(0, 600)
      await page.waitForTimeout(500)
      if (await page.evaluate(() => (window as unknown as { __craftSmooth?: boolean }).__craftSmooth)) {
        found.push('Lenis smooth-scrolled a wheel event (.lenis-smooth appeared) — do not start Lenis when the preference is reduce')
      }
    }
    expect(found, 'smooth scrolling survives reduced motion').toEqual([])
  })

  test('video: nothing autoplays in a loop without a pause control', async ({ page }) => {
    await openReduced(page)
    const looping = await page.evaluate(async () => {
      // Open shadow roots too: a web-component player keeps its <video> in one.
      const vids: HTMLVideoElement[] = []
      const walk = (root: Document | ShadowRoot) => {
        vids.push(...root.querySelectorAll('video'))
        for (const el of root.querySelectorAll('*')) if (el.shadowRoot) walk(el.shadowRoot)
      }
      walk(document)
      if (!vids.length) return []
      const t0 = vids.map((v) => v.currentTime)
      await new Promise((r) => setTimeout(r, 800))
      // "Display", "Replay" and "Google Play" say play and stop nothing: a bare "play"
      // counts only on a toggle (aria-pressed).
      const named = (el: Element) => {
        const text = `${el.getAttribute('aria-label') ?? ''} ${el.getAttribute('title') ?? ''} ${el.textContent ?? ''}`
        return /\b(pause|stop)\b/i.test(text) || (el.hasAttribute('aria-pressed') && /\bplay\b/i.test(text))
      }
      const ctl = 'button, [role="button"], input[type="button"]'
      const up = (n: Node): Element | ShadowRoot | null =>
        n instanceof ShadowRoot ? n.host : n.parentElement ?? (n.parentNode instanceof ShadowRoot ? n.parentNode : null)
      return vids.flatMap((v, i) => {
        const playing = !v.paused && !v.ended && v.currentTime !== t0[i]
        // WCAG 2.2.2's line is five seconds; a loop or a live stream never ends.
        const long = v.loop || !Number.isFinite(v.duration) || v.duration > 5
        if (!playing || !long || v.controls) return []
        // Climb at most three levels, and never into a box holding another video:
        // a pause button there belongs to its neighbour.
        let scope = up(v)
        for (let k = 0; scope && k < 3; k++, scope = up(scope)) {
          if (scope.querySelectorAll('video').length > 1) break
          if ([...scope.querySelectorAll(ctl)].some(named)) return []
        }
        const root = v.getRootNode() as Document | ShadowRoot
        if (v.id && root.querySelector(`[aria-controls~="${CSS.escape(v.id)}"]`)) return []
        const where = root instanceof ShadowRoot ? ` inside <${root.host.tagName.toLowerCase()}>` : ''
        const src = (v.currentSrc || v.getAttribute('src') || 'stream').split('/').pop()
        return [`video${v.id ? '#' + v.id : ''}${where} (${src}) keeps playing${v.loop ? ' in a loop' : ''} with no controls and no pause button nearby`]
      })
    })
    expect(looping, 'autoplaying video survives reduced motion with no way to stop it').toEqual([])
  })
})

/** Open BASE_URL and wait for a rendered heading when one comes — not asserting
    it: the CSS test above owns that failure, and five copies of it help nobody. */
async function openReduced(page: Page) {
  await page.goto(URL)
  await page.getByRole('heading', { level: 1 }).first().waitFor({ timeout: 5000 }).catch(() => {})
}

/** Init script: record every Element.animate() from before the first page
    script runs, so a Motion entrance that finished before anyone looked is
    still on the record. `document.getAnimations()` only lists live ones. */
function recordWaapi() {
  const w = window as unknown as { __craftWaapi: Animation[]; __craftWaapiQuiet: WeakSet<Animation> }
  w.__craftWaapi = []
  const quiet = (w.__craftWaapiQuiet = new WeakSet<Animation>())
  const original = Element.prototype.animate
  Element.prototype.animate = function (this: Element, ...args: Parameters<Element['animate']>) {
    const a = original.apply(this, args)
    w.__craftWaapi.push(a)
    return a
  }
  /* Cancelled, or jumped to its end, before 50ms of its active phase had played: nothing
     moved on screen. Read BEFORE the call, marked only if the call succeeds (finish() on an
     endless animation throws and leaves it running). One cancelled after it ran — Motion
     cancels on finish — is not marked. */
  for (const m of ['cancel', 'finish'] as const) {
    const call = Animation.prototype[m]
    Animation.prototype[m] = function (this: Animation) {
      const t = this.currentTime
      const played = typeof t === 'number' ? t - Number(this.effect?.getTiming().delay ?? 0) : t === null ? 0 : Infinity
      call.call(this)
      if (played < 50) quiet.add(this)
    }
  }
}

/** One in-page pass: WAAPI, then a stepped scroll walk sampling computed
    transforms three times per stop. Transforms only — layout shift from a lazy
    image moves boxes without being motion, and opacity is the allowed fade. */
async function sampleMotion(o: { maxSteps: number; gapMs: number; maxEls: number }) {
  const frame = () => new Promise((r) => requestAnimationFrame(() => r(null)))
  const wait = (ms: number) => new Promise((r) => setTimeout(r, ms))
  const name = (el: Element | null | undefined) => {
    if (!el) return '(no target)'
    const cls = (typeof el.className === 'string' ? el.className : el.getAttribute('class') || '').trim().split(/\s+/)[0]
    return `${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}${cls ? '.' + cls : ''}`
  }
  const cap = (xs: string[]) => xs.length > 6 ? [...xs.slice(0, 6), `…and ${xs.length - 6} more`] : xs

  // WAAPI: recorded calls plus whatever is live now (new Animation(...) is not a .animate() call).
  const MOTION = /^(transform|translate|rotate|scale|top|left|right|bottom|offsetDistance|offsetPath)$|^margin|^inset/i
  const META = new Set(['offset', 'computedOffset', 'easing', 'composite'])
  const seen = new Set<Animation>()
  const waapi: string[] = []
  const w = window as unknown as { __craftWaapi?: Animation[]; __craftWaapiQuiet?: WeakSet<Animation> }
  const recorded = w.__craftWaapi ?? []
  for (const a of [...recorded, ...document.getAnimations()]) {
    if (seen.has(a)) continue
    seen.add(a)
    if (a instanceof CSSAnimation || a instanceof CSSTransition) continue   // the CSS test's
    const eff = a.effect as KeyframeEffect | null
    if (!eff || typeof eff.getKeyframes !== 'function') continue
    // A feature test on a node never attached, or one removed since, moved nothing on screen.
    if (!eff.target?.isConnected) continue
    // Idle or finished having never played (recordWaapi's quiet set); running again counts.
    if ((a.playState === 'idle' || a.playState === 'finished') && w.__craftWaapiQuiet?.has(a)) continue
    const dur = eff.getComputedTiming().duration
    const scrollLinked = !!a.timeline && !(a.timeline instanceof DocumentTimeline)
    if (!scrollLinked && !(typeof dur === 'number' && dur > 50)) continue
    const kfs = eff.getKeyframes()
    const moved = new Set<string>()
    const vals = new Map<string, Set<string>>()
    const hits = new Map<string, number>()
    for (const k of kfs) {
      for (const [p, v] of Object.entries(k)) {
        if (META.has(p) || !MOTION.test(p)) continue
        if (!vals.has(p)) vals.set(p, new Set())
        vals.get(p)!.add(String(v))
        hits.set(p, (hits.get(p) ?? 0) + 1)
      }
    }
    // One keyframe animates FROM the current value; a property missing from a
    // frame is implicit — both move. Identical values in every frame do not.
    for (const [p, vs] of vals) if (kfs.length === 1 || vs.size > 1 || hits.get(p)! < kfs.length) moved.add(p)
    if (moved.size) {
      waapi.push(`${name(eff.target)}: ${[...moved].join(', ')} over ${scrollLinked ? 'a scroll timeline' : Math.round(dur as number) + 'ms'}${eff.getComputedTiming().iterations === Infinity ? ', looping' : ''}`)
    }
  }

  const snap = () => {
    const out = new Map<Element, string>()
    for (const el of document.querySelectorAll('body *')) {
      if (out.size >= o.maxEls) break
      const r = el.getBoundingClientRect()
      if (r.width <= 0 || r.height <= 0 || r.bottom <= 0 || r.top >= innerHeight || r.right <= 0 || r.left >= innerWidth) continue
      const cs = getComputedStyle(el)
      out.set(el, `${cs.transform}|${cs.translate}|${cs.rotate}|${cs.scale}`)
    }
    return out
  }
  const selfMoving = new Map<Element, string>()
  const track = new Map<Element, string[]>()
  const room = document.documentElement.scrollHeight - innerHeight
  const step = Math.max(Math.round(innerHeight / 4), Math.ceil(room / o.maxSteps))
  const stops = [0]
  for (let y = step; y < room; y += step) stops.push(y)
  if (room > 0 && stops[stops.length - 1] !== room) stops.push(room)
  for (const y of stops.slice(0, o.maxSteps + 1)) {
    // 'instant' overrides a page's `scroll-behavior: smooth`, which would
    // otherwise animate the walk itself and file scroll-linked motion as a tween.
    window.scrollTo({ top: y, behavior: 'instant' })
    await frame(); await frame()
    const a = snap(); await wait(o.gapMs)
    const b = snap(); await wait(o.gapMs)
    const c = snap()
    for (const [el, vc] of c) {
      const va = a.get(el), vb = b.get(el)
      // Changed across BOTH gaps with the page at rest: still moving, not a one-off jump.
      if (va !== undefined && vb !== undefined && va !== vb && vb !== vc && !selfMoving.has(el)) {
        selfMoving.set(el, `${va.split('|')[0]} → ${vc.split('|')[0]}`)
      }
      if (!track.has(el)) track.set(el, [])
      track.get(el)!.push(vc)
    }
  }
  window.scrollTo({ top: 0, behavior: 'instant' })

  /* Tracks the scroll = its settled transform changed at two-plus stops. One
     change is an instant reveal snapping into place, which is what a correct
     reduced path LOOKS like. A one-axis scale is a progress meter filling, not
     the scene moving, and is left alone — as a `transform` matrix or as the
     `scale` property. A one-axis TRANSLATE is not exempt on either path: it is
     also what a scroll-linked parallax or marquee looks like. */
  const meter = (v: string) =>
    /^matrix\((?:[-\d.e]+, 0, 0, 1|1, 0, 0, [-\d.e]+), 0, 0\)\|/.test(v) ||
    /^none\|none\|none\|(?:[-\d.e]+ 1|1 [-\d.e]+|1)$/.test(v)          // `scale: 1 1` computes to "1"
  const PROPS = ['transform', 'translate', 'rotate', 'scale']
  const scrollTracking: string[] = []
  for (const [el, vs] of track) {
    if (selfMoving.has(el)) continue
    let changes = 0
    for (let i = 1; i < vs.length; i++) if (vs[i] !== vs[i - 1]) changes++
    if (changes >= 2 && !vs.every((v) => v.startsWith('none|none|none|none') || meter(v))) {
      const parts = vs.map((v) => v.split('|'))
      const first = parts[0], last = parts[parts.length - 1]
      const moved = PROPS.map((p, k) => [p, k] as const).filter(([, k]) => parts.some((q) => q[k] !== first[k]))
      scrollTracking.push(`${name(el)}: ${changes} ${moved.map(([p]) => p).join('/')} changes across ${vs.length} scroll stops (${moved.map(([p, k]) => `${p} ${first[k]} … ${last[k]}`).join('; ')})`)
    }
  }
  return {
    waapi: cap(waapi),
    selfMoving: cap([...selfMoving].map(([el, d]) => `${name(el)}: ${d}`)),
    scrollTracking: cap(scrollTracking),
  }
}

/** Fraction of pixels (any channel off by more than 8/255) that changed
    between each consecutive pair of PNG frames. Runs in a scratch page. */
async function pixelChange(shots: string[]) {
  const imgs = await Promise.all(shots.map((b64) =>
    createImageBitmap(new Blob([Uint8Array.from(atob(b64), (ch) => ch.charCodeAt(0))], { type: 'image/png' }))))
  const w = Math.min(...imgs.map((i) => i.width)), h = Math.min(...imgs.map((i) => i.height))
  const px = imgs.map((img) => {
    const g = new OffscreenCanvas(w, h).getContext('2d')!
    g.drawImage(img, 0, 0)
    return g.getImageData(0, 0, w, h).data
  })
  const out: number[] = []
  for (let k = 1; k < px.length; k++) {
    const a = px[k - 1], b = px[k]
    let changed = 0
    for (let i = 0; i < a.length; i += 4) {
      if (Math.abs(a[i] - b[i]) > 8 || Math.abs(a[i + 1] - b[i + 1]) > 8 || Math.abs(a[i + 2] - b[i + 2]) > 8) changed++
    }
    out.push(changed / (w * h))
  }
  return out
}

/* ----------------------------------------------------- trigger: forced colours */
test.describe('forced-colors: active', () => {
  test.use({ contextOptions: { forcedColors: 'active' } })

  test('content survives Windows High Contrast', async ({ page }) => {
    await page.goto(URL)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    const o = await overflow(page)
    expect(o.body, JSON.stringify(o.offenders)).toBeLessThanOrEqual(o.client)
  })
})

/* ------------------------------------------------- trigger: keyboard traversal */
/* An app-craft floor, and a measurable one: a grid of interactive cells must be
   ONE tab stop with arrow keys inside, not one stop per cell. A 5x9 board is 45
   stops standing between a keyboard user and the rest of the page. This exact
   check would have caught a real regression in a craft-layer demo build. */
test('no interactive grid floods the tab order', async ({ page }) => {
  await page.goto(URL)
  const r = await page.evaluate(() => {
    const vis = (el: Element) => (el as HTMLElement).offsetParent !== null
    const all = [...document.querySelectorAll<HTMLElement>('a[href],button,input,select,textarea,[tabindex]')]
      .filter((el) => vis(el) && el.tabIndex >= 0)
    const worst = [...document.querySelectorAll('table, [role="grid"], [role="listbox"]')]
      .map((g) => ({
        grid: g.tagName + (g.getAttribute('role') ? `[${g.getAttribute('role')}]` : ''),
        stops: [...g.querySelectorAll<HTMLElement>('button,a[href],input,[tabindex]')]
          .filter((el) => vis(el) && el.tabIndex >= 0).length,
      }))
      .sort((a, b) => b.stops - a.stops)[0]
    return { total: all.length, worst: worst ?? null }
  })
  // A grid contributing more than a handful of stops is not using roving tabindex.
  expect(r.worst?.stops ?? 0,
    `grid ${r.worst?.grid} contributes ${r.worst?.stops} tab stops of ${r.total} on the page`)
    .toBeLessThanOrEqual(8)
})

/* --------------------------------------------------------------- trigger: zoom */
/* 200% browser zoom halves the CSS-pixel viewport, which WCAG 1.4.4 requires
   content to survive. This is the cheapest high-yield trigger there is, and the
   one most often never run. */
for (const [label, w, h] of [
  ['desktop @200%', 640, 512],
  ['tablet @200%', 384, 512],
  ['phone @200%', 195, 422],
] as const) {
  test(`no horizontal overflow at ${label}`, async ({ page }) => {
    await page.setViewportSize({ width: w, height: h })
    await page.goto(URL)
    const o = await overflow(page)
    expect(o.body, `overflow ${o.body}>${o.client}: ${JSON.stringify(o.offenders)}`)
      .toBeLessThanOrEqual(o.client)
  })
}
