// drive.js — agentic walker. Boots the replica in-process and drives the multi-step flow
// end to end through the same JSON API an agent would use: describe -> start session ->
// submit each stage in order -> report progress. Field values come from --data (JSON keyed by
// step index) or are auto-generated from each field's name/type.
import { createApp } from './app.js'
import { once } from 'node:events'
import { readFileSync } from 'node:fs'

function fakeValue(field, step) {
  const t = (field.type || '').toLowerCase()
  const n = (field.name || '').toLowerCase()
  if (t === 'email' || n.includes('email')) return `user${step}@demo.local`
  if (t === 'password' || n.includes('pass')) return `Passw0rd!${step}`
  if (t === 'tel' || n.includes('phone') || n.includes('tel')) return `555000${1000 + step}`
  if (t === 'number' || n.includes('age')) return String(21 + step)
  if (t === 'date') return '2000-01-01'
  if (t === 'checkbox') return 'on'
  if (n.includes('user')) return `user${step}`
  if (n.includes('name')) return `Demo User ${step}`
  return `val_${field.name}`
}

export async function drive({ inDir, dataFile = null }) {
  const data = dataFile ? JSON.parse(readFileSync(dataFile, 'utf8')) : null
  const { app, db } = createApp({ inDir })
  const server = app.listen(0)
  await once(server, 'listening')
  const base = `http://localhost:${server.address().port}`

  let failures = 0
  try {
    const flow = await (await fetch(`${base}/api/flow`)).json()
    console.log(`Driving ${flow.stepCount}-step flow from ${flow.sourceBase || '(local)'}\n`)

    const { sid } = await (await fetch(`${base}/api/session`, { method: 'POST' })).json()
    console.log(`session ${sid}`)

    for (const step of flow.steps) {
      const provided = data ? (data[step.index] ?? data[String(step.index)]) : null
      const payload = provided ?? Object.fromEntries((step.fields || []).map((f) => [f.name, fakeValue(f, step.index)]))
      const r = await (await fetch(`${base}/api/session/${sid}/step/${step.index}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload),
      })).json()
      if (r.error) { console.error(`  step ${step.index} FAILED: ${r.error}`); failures++; break }
      const sent = Object.keys(payload).join(', ')
      console.log(`  step ${step.index} ok [${sent}] → ${r.done ? 'DONE' : 'next ' + r.nextStep} (${r.progress})`)
    }

    const final = await (await fetch(`${base}/api/session/${sid}`)).json()
    console.log(`\nfinal: status=${final.status}, ${final.submissions.length}/${final.stepCount} stage(s) stored locally`)
    if (final.status !== 'complete') failures++
  } finally {
    server.close()
    db.close()
  }
  if (failures) process.exitCode = 1
  return { ok: failures === 0 }
}
