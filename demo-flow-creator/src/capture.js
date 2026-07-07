// capture.js — headed, multi-step capture of a live flow.
// A REAL browser window opens. You clear any challenge yourself and walk through EACH stage
// of the flow; the tool snapshots each stage in the SAME browser session (so cookies/state
// carry across steps, exactly like a real multi-stage registration). Nothing here defeats a
// bot check — the human passes the gate; the tool only reads the rendered DOM afterward.
import { chromium } from 'playwright'
import { mkdir, writeFile, readFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { createInterface } from 'node:readline'

// One reader for the whole interactive session. Queues lines and signals EOF as null so the
// loop works for a live TTY, piped input, and stream close alike (a fresh readline per prompt
// drops buffered lines and can hang on EOF).
function lineReader() {
  const rl = createInterface({ input: process.stdin })
  const queued = []
  let closed = false
  let waiter = null
  rl.on('line', (l) => { if (waiter) { const w = waiter; waiter = null; w(l) } else queued.push(l) })
  rl.on('close', () => { closed = true; if (waiter) { const w = waiter; waiter = null; w(null) } })
  return {
    next: () => new Promise((res) => {
      if (queued.length) return res(queued.shift())
      if (closed) return res(null)
      waiter = res
    }),
    close: () => rl.close(),
  }
}

// Runs in the page. Serializes the hydrated DOM, inlines same-origin stylesheets,
// and extracts a flow map of the forms present.
function pageExtractor() {
  const abs = (u) => { try { return new URL(u, location.href).href } catch { return u } }

  const inlineStyles = async () => {
    const links = [...document.querySelectorAll('link[rel~="stylesheet"][href]')]
    for (const link of links) {
      try {
        const href = abs(link.getAttribute('href'))
        if (new URL(href).origin !== location.origin) continue
        const css = await fetch(href).then((r) => (r.ok ? r.text() : ''))
        if (!css) continue
        const style = document.createElement('style')
        style.setAttribute('data-inlined-from', href)
        style.textContent = css
        link.replaceWith(style)
      } catch { /* best effort */ }
    }
  }

  const absolutizeAssets = () => {
    for (const el of document.querySelectorAll('[src]')) {
      const v = el.getAttribute('src'); if (v) el.setAttribute('src', abs(v))
    }
    for (const el of document.querySelectorAll('link[href]')) {
      const v = el.getAttribute('href'); if (v) el.setAttribute('href', abs(v))
    }
    if (!document.querySelector('base')) {
      const base = document.createElement('base'); base.href = location.href
      document.head?.prepend(base)
    }
  }

  const forms = [...document.querySelectorAll('form')].map((form, i) => ({
    index: i,
    id: form.id || null,
    action: abs(form.getAttribute('action') || location.href),
    method: (form.getAttribute('method') || 'get').toLowerCase(),
    fields: [...form.querySelectorAll('input, select, textarea')]
      .filter((el) => el.type !== 'submit' && el.type !== 'button')
      .map((el) => ({
        tag: el.tagName.toLowerCase(),
        name: el.getAttribute('name') || el.getAttribute('id') || null,
        type: el.getAttribute('type') || (el.tagName.toLowerCase() === 'textarea' ? 'textarea' : 'text'),
        required: el.hasAttribute('required'),
        placeholder: el.getAttribute('placeholder') || null,
      })),
  }))

  return (async () => {
    await inlineStyles()
    absolutizeAssets()
    return {
      url: location.href,
      title: document.title,
      forms,
      html: '<!doctype html>\n' + document.documentElement.outerHTML,
    }
  })()
}

async function loadManifest(outDir) {
  const p = join(outDir, 'steps.json')
  if (existsSync(p)) return JSON.parse(await readFile(p, 'utf8'))
  return { sourceBase: null, capturedAt: new Date().toISOString(), steps: [] }
}

async function snapshot(page, outDir, manifest) {
  const result = await page.evaluate(pageExtractor)
  const index = manifest.steps.length
  const file = `step-${index}.html`
  const { html, ...meta } = result
  await writeFile(join(outDir, file), html, 'utf8')
  await page.screenshot({ path: join(outDir, `step-${index}.png`), fullPage: true }).catch(() => {})
  if (!manifest.sourceBase) { try { manifest.sourceBase = new URL(meta.url).origin } catch { /* */ } }
  manifest.steps.push({ index, file, ...meta })
  console.log(`  captured step ${index}: ${meta.title || meta.url} (${meta.forms.length} form(s))`)
  return manifest
}

export async function capture({ url, outDir, waitMs = null, headless = false, append = false }) {
  await mkdir(outDir, { recursive: true })
  const manifest = append ? await loadManifest(outDir) : { sourceBase: null, capturedAt: new Date().toISOString(), steps: [] }

  const nonInteractive = waitMs !== null
  console.log(`\nOpening ${headless ? 'headless' : 'a real'} browser at: ${url}`)
  if (nonInteractive) {
    console.log('Non-interactive mode: for gate-free pages only. No challenge is bypassed.\n')
  } else {
    console.log('Headed window. You clear any gate. There is no headless bypass here.\n')
  }

  const browser = await chromium.launch({ headless })
  const context = await browser.newContext({ viewport: null })
  const page = await context.newPage()
  await page.goto(url, { waitUntil: 'domcontentloaded' }).catch(() => {})

  if (nonInteractive) {
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {})
    if (waitMs > 0) await page.waitForTimeout(waitMs)
    await snapshot(page, outDir, manifest)
  } else {
    console.log('Walk the flow ONE STAGE AT A TIME in the browser window:')
    console.log('  - Clear any anti-bot challenge yourself (you pass it as a human).')
    console.log('  - Reach a stage you want to replicate, then press ENTER here to capture it.')
    console.log("  - Advance to the next stage and capture again. Type 'd' + ENTER when done.\n")
    // Same session throughout: navigation/cookies persist across every captured step.
    const reader = lineReader()
    for (;;) {
      process.stdout.write(`Capture step ${manifest.steps.length}? [ENTER = capture, d = done] `)
      const answer = await reader.next()
      if (answer === null || answer.trim().toLowerCase() === 'd') break // d or EOF
      await snapshot(page, outDir, manifest)
      console.log('  → advance the browser to the next stage, then capture again (or d to finish).')
    }
    reader.close()
  }

  await browser.close()
  manifest.capturedAt = new Date().toISOString()
  await writeFile(join(outDir, 'steps.json'), JSON.stringify(manifest, null, 2), 'utf8')

  const withForms = manifest.steps.filter((s) => s.forms.length).length
  console.log(`\nCaptured ${manifest.steps.length} step(s), ${withForms} with a form → ${join(outDir, 'steps.json')}`)
  if (manifest.steps.length === 0) {
    console.log('No steps captured. Re-run and capture at least one stage.')
  } else {
    console.log(`Next: dfc scaffold --in ${outDir}`)
  }
  return manifest
}
