// serve.js — run the local multi-step replica on localhost.
import { createApp } from './app.js'
import { join } from 'node:path'

export async function serve({ inDir, port }) {
  const { app, manifest, stepCount } = createApp({ inDir })
  app.listen(port, () => {
    console.log(`\n${stepCount}-step demo flow live: http://localhost:${port}/`)
    console.log(`Store:           http://localhost:${port}/admin/submissions`)
    console.log(`Agent — describe flow:  GET  http://localhost:${port}/api/flow`)
    console.log(`Agent — start session:  POST http://localhost:${port}/api/session`)
    console.log(`Agent — submit a step:  POST http://localhost:${port}/api/session/:sid/step/:n`)
    console.log(`Source captured: ${manifest.sourceBase || '(local)'}`)
    console.log(`\nSubmissions write to ${join(inDir, manifest.store)} — never the origin. Ctrl+C to stop.`)
  })
}
