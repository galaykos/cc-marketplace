// chromium.mjs — the Playwright Chromium that motion-check.mjs and system-render.mjs drive: the project's own Playwright (or NODE_PATH's), then an explicit browser, its own Chromium, the installed Chrome.
// Misses: Firefox and WebKit; a Playwright installed globally with npm -g (not on Node's resolution path); it never installs or downloads anything.
// Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/chromium.mjs
import { existsSync } from 'node:fs'
import { createRequire } from 'node:module'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

export class Missing extends Error {}
export class Usage extends Error {}

const NAMES = ['playwright', 'playwright-core', '@playwright/test']

export function loadPlaywright(project) {
  const req = createRequire(join(resolve(project), 'package.json'))
  for (const name of NAMES) {
    try {
      const mod = req(name)
      if (mod && mod.chromium) return { pw: mod, name }
    } catch { /* next name */ }
  }
  throw new Missing(`no Playwright resolvable from ${resolve(project)} (tried ${NAMES.join(', ')} there, its parents and NODE_PATH). `
    + 'Add it to the project yourself (npm i -D @playwright/test) or pass --project <a dir that has it>; this script installs nothing.')
}

export async function launchChromium({ project, browser }) {
  const { pw, name } = loadPlaywright(project)
  const exe = browser || process.env.DESIGN_KIT_BROWSER
  const tries = []
  if (exe) tries.push([`--browser/DESIGN_KIT_BROWSER ${exe}`, { executablePath: exe }])
  tries.push([`${name}'s own Chromium`, {}])
  tries.push(['the installed Google Chrome (channel chrome)', { channel: 'chrome' }])
  const errs = []
  for (const [label, opt] of tries) {
    try {
      return { browser: await pw.chromium.launch({ headless: true, ...opt }), via: label, pw }
    } catch (e) {
      errs.push(`${label}: ${String(e && e.message).split('\n')[0]}`)
    }
  }
  throw new Missing(`no Chromium ${name} can launch —\n  ${errs.join('\n  ')}\n`
    + 'Install one yourself (npx playwright install chromium), or point --browser / DESIGN_KIT_BROWSER at a Chromium; this script installs nothing.')
}

export function targetUrl(target) {
  if (/^(https?|file):\/\//i.test(target)) return target
  const [, file, rest] = /^([^?#]*)(.*)$/.exec(target)
  if (!file || !existsSync(file)) throw new Usage(`${target}: no such file, and not an http(s):// or file:// URL`)
  return pathToFileURL(resolve(file)).href + rest
}
