// app.js — the local replica server as an express app factory.
// Sequences a multi-step flow and exposes an agentic session API so a prompt/agent can drive
// every stage deterministically. All state lives in the local SQLite store; nothing leaves.
import express from 'express'
import Database from 'better-sqlite3'
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'

export function createApp({ inDir }) {
  const manifestPath = join(inDir, 'replica.json')
  if (!existsSync(manifestPath)) {
    throw new Error(`No replica.json in "${inDir}". Run: dfc scaffold --in ${inDir}`)
  }
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const steps = manifest.steps
  const pages = new Map(steps.map((s) => [s.index, readFileSync(join(inDir, s.servedFile), 'utf8')]))
  const db = new Database(join(inDir, manifest.store))
  db.pragma('journal_mode = WAL')

  const q = {
    createSession: db.prepare('INSERT INTO sessions (id, current_step, status) VALUES (?, 0, ?)'),
    getSession: db.prepare('SELECT * FROM sessions WHERE id = ?'),
    setStep: db.prepare('UPDATE sessions SET current_step = ?, status = ? WHERE id = ?'),
    insertSub: db.prepare('INSERT INTO submissions (session_id, step, payload) VALUES (?, ?, ?)'),
    subsForSession: db.prepare('SELECT step, created_at, payload FROM submissions WHERE session_id = ? ORDER BY step'),
    allSubs: db.prepare('SELECT id, session_id, step, created_at, payload FROM submissions ORDER BY id DESC'),
  }

  const stepCount = steps.length
  const newSession = () => { const id = randomUUID(); q.createSession.run(id, 'in_progress'); return id }

  // Core state machine, shared by the browser flow and the JSON API.
  function submitStep(sid, n, payload) {
    const s = q.getSession.get(sid)
    if (!s) return { error: 'unknown session', code: 404 }
    if (s.status === 'complete') return { error: 'session already complete', code: 409 }
    if (n !== s.current_step) return { error: `out of order: expected step ${s.current_step}, got ${n}`, code: 409 }
    const clean = { ...payload }; delete clean.__sid
    q.insertSub.run(sid, n, JSON.stringify(clean))
    const next = n + 1
    if (next < stepCount) { q.setStep.run(next, 'in_progress', sid); return { ok: true, done: false, nextStep: next } }
    q.setStep.run(next, 'complete', sid)
    return { ok: true, done: true, nextStep: null }
  }

  const app = express()
  app.use(express.urlencoded({ extended: true }))
  app.use(express.json())

  // ---- Browser flow ----
  app.get('/', (_req, res) => res.redirect(`/step/0?sid=${newSession()}`))

  app.get('/step/:n', (req, res) => {
    const n = Number(req.params.n)
    const sid = req.query.sid
    if (!sid) return res.redirect('/')
    if (!pages.has(n)) return res.redirect(`/done?sid=${sid}`)
    const step = steps.find((s) => s.index === n)
    let html = pages.get(n).replaceAll(manifest.sidToken, esc(sid))
    if (!step.hasForm) {
      // Display-only stage: give the flow a way forward.
      html += `<div style="font:16px system-ui;max-width:40rem;margin:1rem auto;padding:0 1rem">
        <a href="/api/advance/${n}?sid=${esc(sid)}">Continue →</a></div>`
    }
    res.type('html').send(html)
  })

  app.post('/api/step/:n', (req, res) => {
    const r = submitStep(req.body.__sid, Number(req.params.n), req.body || {})
    if (r.error) return res.status(r.code).type('html').send(errPage(r.error))
    res.redirect(r.done ? `/done?sid=${req.body.__sid}` : `/step/${r.nextStep}?sid=${req.body.__sid}`)
  })

  app.get('/api/advance/:n', (req, res) => {
    const r = submitStep(req.query.sid, Number(req.params.n), {})
    if (r.error) return res.status(r.code).type('html').send(errPage(r.error))
    res.redirect(r.done ? `/done?sid=${req.query.sid}` : `/step/${r.nextStep}?sid=${req.query.sid}`)
  })

  app.get('/done', (req, res) => {
    const sid = req.query.sid
    const subs = q.subsForSession.all(sid)
    res.type('html').send(`<!doctype html><meta charset="utf-8"><title>Done</title>
      <div style="font:16px/1.5 system-ui;max-width:44rem;margin:3rem auto;padding:0 1rem">
        <h1>Flow complete ✅</h1>
        <p>Session <code>${esc(sid)}</code> — ${subs.length}/${stepCount} stage(s) stored in <code>${manifest.store}</code>. Nothing sent to <code>${esc(manifest.sourceBase || '')}</code>.</p>
        ${subs.map((s) => `<h3>Step ${s.step}</h3><pre style="background:#f4f4f5;padding:.75rem;border-radius:8px;overflow:auto">${esc(s.payload)}</pre>`).join('')}
        <p><a href="/">↺ run the flow again</a></p>
      </div>`)
  })

  // ---- Agentic JSON API ----
  app.get('/api/flow', (_req, res) => res.json({
    sourceBase: manifest.sourceBase,
    stepCount,
    steps: steps.map((s) => ({ index: s.index, title: s.title, hasForm: s.hasForm, fields: s.fields, submit: `/api/session/:sid/step/${s.index}` })),
  }))

  app.post('/api/session', (_req, res) => res.json({ sid: newSession(), currentStep: 0, stepCount }))

  app.get('/api/session/:sid', (req, res) => {
    const s = q.getSession.get(req.params.sid)
    if (!s) return res.status(404).json({ error: 'unknown session' })
    res.json({
      sid: s.id, status: s.status, currentStep: s.current_step, stepCount,
      submissions: q.subsForSession.all(s.id).map((x) => ({ step: x.step, payload: JSON.parse(x.payload) })),
    })
  })

  app.post('/api/session/:sid/step/:n', (req, res) => {
    const r = submitStep(req.params.sid, Number(req.params.n), req.body || {})
    if (r.error) return res.status(r.code).json({ error: r.error })
    res.json({ ok: true, step: Number(req.params.n), done: r.done, nextStep: r.nextStep, progress: `${(r.nextStep ?? stepCount)}/${stepCount}` })
  })

  app.get('/api/submissions', (_req, res) => res.json(
    q.allSubs.all().map((r) => ({ id: r.id, session_id: r.session_id, step: r.step, created_at: r.created_at, payload: JSON.parse(r.payload) }))
  ))

  app.get('/admin/submissions', (_req, res) => {
    const rows = q.allSubs.all()
    res.type('html').send(`<!doctype html><meta charset="utf-8"><title>Submissions</title>
      <div style="font:14px/1.5 system-ui;max-width:64rem;margin:2rem auto;padding:0 1rem">
        <h1>Local store (${rows.length})</h1><p><code>${join(inDir, manifest.store)}</code></p>
        <table border="1" cellpadding="6" style="border-collapse:collapse;width:100%">
          <tr><th>#</th><th>session</th><th>step</th><th>at</th><th>payload</th></tr>
          ${rows.map((r) => `<tr><td>${r.id}</td><td><code>${esc(r.session_id.slice(0, 8))}</code></td><td>${r.step}</td><td>${r.created_at}</td><td><pre style="margin:0">${esc(r.payload)}</pre></td></tr>`).join('')}
        </table></div>`)
  })

  return { app, db, manifest, steps, stepCount }
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
const errPage = (msg) => `<!doctype html><meta charset="utf-8"><div style="font:16px system-ui;max-width:40rem;margin:3rem auto;padding:0 1rem"><h1>Cannot advance</h1><p>${esc(msg)}</p><p><a href="/">restart</a></p></div>`
