// Smoke test: multi-step scaffold -> agentic API -> order enforcement -> browser flow -> drive.
// No external network, no browser — runs on the shipped 2-step example/ fixture. `npm test`.
import { cp, rm, mkdir } from 'node:fs/promises'
import { existsSync, readFileSync } from 'node:fs'
import { once } from 'node:events'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const work = join(root, '.bt-smoke')
let failures = 0
const check = (name, cond) => { console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}`); if (!cond) failures++ }

async function main() {
  await rm(work, { recursive: true, force: true })
  await mkdir(work, { recursive: true })
  for (const f of ['steps.json', 'step-0.html', 'step-1.html']) await cp(join(root, 'example', f), join(work, f))

  // ---- scaffold ----
  const { scaffold } = await import('../src/scaffold.js')
  const manifest = await scaffold({ inDir: work })
  check('scaffold sees 2 steps', manifest.stepCount === 2)
  check('step-0 fields = email,password', manifest.steps[0].fields.map((f) => f.name).join() === 'email,password')
  check('step-1 fields = username,fullname,age', manifest.steps[1].fields.map((f) => f.name).join() === 'username,fullname,age')
  check('both replica files written', existsSync(join(work, 'replica-step-0.html')) && existsSync(join(work, 'replica-step-1.html')))
  const r0 = readFileSync(join(work, 'replica-step-0.html'), 'utf8')
  check('step-0 action -> /api/step/0', r0.includes('action="/api/step/0"'))
  check('step-0 has hidden __sid', r0.includes('name="__sid"'))
  check('store.sqlite created', existsSync(join(work, 'store.sqlite')))

  // ---- boot app ----
  const { createApp } = await import('../src/app.js')
  const { app, db } = createApp({ inDir: work })
  const server = app.listen(0)
  await once(server, 'listening')
  const base = `http://localhost:${server.address().port}`
  const jpost = (p, body) => fetch(base + p, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body || {}) })

  try {
    // ---- agentic API ----
    const flow = await (await fetch(base + '/api/flow')).json()
    check('GET /api/flow describes 2 steps', flow.stepCount === 2 && flow.steps.length === 2)

    const { sid } = await (await jpost('/api/session')).json()
    check('POST /api/session returns sid', typeof sid === 'string' && sid.length > 0)

    // order enforcement: step 1 before step 0 must fail
    const outOfOrder = await jpost(`/api/session/${sid}/step/1`, { username: 'x' })
    check('out-of-order step rejected (409)', outOfOrder.status === 409)

    const s0 = await (await jpost(`/api/session/${sid}/step/0`, { email: 'a@demo.local', password: 'pw' })).json()
    check('step 0 accepted -> nextStep 1', s0.ok && s0.done === false && s0.nextStep === 1)
    const s1 = await (await jpost(`/api/session/${sid}/step/1`, { username: 'ada', fullname: 'Ada L', age: '30' })).json()
    check('step 1 accepted -> done', s1.ok && s1.done === true)

    const st = await (await fetch(`${base}/api/session/${sid}`)).json()
    check('session complete, 2 submissions', st.status === 'complete' && st.submissions.length === 2)
    check('step-0 payload round-trips', st.submissions[0].payload.email === 'a@demo.local')
    check('step-1 payload round-trips', st.submissions[1].payload.username === 'ada')

    // double-submit after complete rejected
    const dup = await jpost(`/api/session/${sid}/step/0`, { email: 'x' })
    check('submit after complete rejected (409)', dup.status === 409)

    // ---- browser flow (redirects) ----
    const start = await fetch(base + '/', { redirect: 'manual' })
    const loc = start.headers.get('location') || ''
    const bsid = new URL('http://x' + loc).searchParams.get('sid')
    check('GET / redirects to /step/0 with sid', loc.startsWith('/step/0') && !!bsid)

    const form = (p, body) => fetch(base + p, { method: 'POST', redirect: 'manual', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body })
    const b0 = await form('/api/step/0', `__sid=${bsid}&email=b@demo.local&password=pw`)
    check('browser step 0 -> redirect /step/1', (b0.headers.get('location') || '').startsWith('/step/1'))
    const b1 = await form('/api/step/1', `__sid=${bsid}&username=bob&fullname=Bob&age=40`)
    check('browser step 1 -> redirect /done', (b1.headers.get('location') || '').startsWith('/done'))
    const done = await (await fetch(`${base}/done?sid=${bsid}`)).text()
    check('/done shows completion', done.includes('Flow complete'))
  } finally {
    server.close(); db.close()
  }

  // ---- drive walker (its own in-process server) ----
  const { drive } = await import('../src/drive.js')
  const driven = await drive({ inDir: work })
  check('drive walks full flow to complete', driven.ok === true)

  await rm(work, { recursive: true, force: true })
  console.log(`\n${failures === 0 ? 'PASS' : 'FAIL'} — ${failures} failure(s)`)
  process.exit(failures === 0 ? 0 : 1)
}

main().catch((e) => { console.error(e); process.exit(1) })
