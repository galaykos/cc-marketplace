// scaffold.js — turn a multi-step capture into a runnable local replica.
// For each stage: picks its register form, rewrites the action to the local sequencer
// (/api/step/N), injects a hidden session id, and initializes a local SQLite store with
// sessions + submissions. After this the whole flow is 100% local.
import { readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { load } from 'cheerio'
import Database from 'better-sqlite3'

const SID_TOKEN = '__DFC_SID__'

// Heuristic: the form to drive is the one with the most input fields on that stage.
function pickForm(forms) {
  if (!forms.length) return null
  return [...forms].sort((a, b) => b.fields.length - a.fields.length)[0]
}

function rewriteStep(html, step) {
  const $ = load(html, { decodeEntities: false })
  const target = pickForm(step.forms)
  const fields = []
  if (target) {
    const form = $('form').eq(target.index)
    form.attr('action', `/api/step/${step.index}`)
    form.attr('method', 'post')
    // Carry the session id across stages.
    if (form.find('input[name="__sid"]').length === 0) {
      form.prepend(`<input type="hidden" name="__sid" value="${SID_TOKEN}">`)
    }
    const seen = new Set()
    form.find('input, select, textarea').each((i, el) => {
      const $el = $(el)
      const type = ($el.attr('type') || el.name || 'text').toLowerCase()
      if (type === 'submit' || type === 'button' || $el.attr('name') === '__sid') return
      let name = $el.attr('name') || $el.attr('id')
      if (!name) { name = `field_${i}`; $el.attr('name', name) }
      if (seen.has(name)) return
      seen.add(name)
      fields.push({ name, type, required: $el.attr('required') !== undefined })
    })
  }
  return { html: $.html(), fields, hasForm: !!target }
}

export async function scaffold({ inDir }) {
  const manifest = JSON.parse(await readFile(join(inDir, 'steps.json'), 'utf8'))
  if (!manifest.steps?.length) throw new Error(`No steps in ${join(inDir, 'steps.json')} — run capture first.`)

  const steps = []
  for (const step of manifest.steps) {
    const html = await readFile(join(inDir, step.file), 'utf8')
    const { html: rewritten, fields, hasForm } = rewriteStep(html, step)
    const servedFile = `replica-step-${step.index}.html`
    await writeFile(join(inDir, servedFile), rewritten, 'utf8')
    steps.push({ index: step.index, title: step.title, url: step.url, servedFile, fields, hasForm })
  }

  const db = new Database(join(inDir, 'store.sqlite'))
  db.pragma('journal_mode = WAL')
  db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id           TEXT PRIMARY KEY,
      created_at   TEXT NOT NULL DEFAULT (datetime('now')),
      current_step INTEGER NOT NULL DEFAULT 0,
      status       TEXT NOT NULL DEFAULT 'in_progress'
    );
    CREATE TABLE IF NOT EXISTS submissions (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id  TEXT NOT NULL,
      step        INTEGER NOT NULL,
      created_at  TEXT NOT NULL DEFAULT (datetime('now')),
      payload     TEXT NOT NULL
    );
  `)
  db.close()

  const out = {
    sourceBase: manifest.sourceBase,
    stepCount: steps.length,
    steps,
    store: 'store.sqlite',
    sidToken: SID_TOKEN,
    scaffoldedAt: new Date().toISOString(),
  }
  await writeFile(join(inDir, 'replica.json'), JSON.stringify(out, null, 2), 'utf8')

  console.log(`Scaffolded ${steps.length}-step local replica:`)
  for (const s of steps) {
    console.log(`  step ${s.index}: ${s.servedFile}  ${s.hasForm ? `[${s.fields.map((f) => f.name).join(', ')}]` : '(no form — display only)'}`)
  }
  console.log(`  store: ${join(inDir, 'store.sqlite')} (sessions + submissions)`)
  console.log(`\nNext: dfc serve --in ${inDir}`)
  return out
}
