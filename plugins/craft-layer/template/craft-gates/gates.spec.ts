/* craft-layer — the trigger suite.
 * ---------------------------------------------------------------------------
 * Copy this file and `contrast.mjs` into a crafted project, then:
 *
 *     npm i -D @playwright/test @axe-core/playwright && npx playwright install chromium
 *     BASE_URL=http://localhost:5173 npx playwright test
 *     node scripts/contrast.mjs
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
 * The default trigger set for a visual build is the four below. They are cheap
 * (about two seconds), and each has caught a real defect that every other gate
 * in this plugin missed:
 *
 *   - 200% zoom      → a visually-hidden <caption> keeping its min-content
 *                      width and dragging the page into horizontal overflow.
 *                      Invisible at every normal viewport.
 *   - reduced motion → transitions surviving the media query.
 *   - forced colours → content vanishing under Windows High Contrast.
 *   - axe            → the machine-testable ~30% of WCAG, on every commit.
 *
 * ADDING a trigger is the point. When a defect escapes to production, ask what
 * condition would have surfaced it, and add THAT here — not another assertion
 * under a trigger you already run.
 */
import { test, expect, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

const URL = process.env.BASE_URL ?? 'http://localhost:5173'

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
})

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
