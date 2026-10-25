import type { On } from 'claude-code'
import { judgeInput, parseLabel, systemPrompt } from './coach-core'
const CASES = [
  ['clear', 'Add a --dry-run flag to scripts/remove-plugin.sh that prints the plan without deleting anything'],
  ['clear', 'Write a unit test for textHash that covers an empty string and a multi-byte character'],
  ['unclear', 'can you fix that thing now'],
  ['unclear', 'make it work like the other one does'],
  ['unclear', 'change it back to how it was before'],
]
export function register(on: On) {
  on('prompt.submit', async ($, e, next) => {
    const rows: string[] = []
    for (const [label, text] of CASES) {
      for (let i = 0; i < 2; i++) {
        const started = await $.clock.now()
        const r = await $.model.complete({ model: 'haiku', system: systemPrompt('first', 'unactionable', false, null), prompt: judgeInput({ prompt: text, run: null, turns: [] }), maxTokens: 8, effort: 'low', timeoutMs: 5000 })
        const ms = (await $.clock.now()) - started
        rows.push(JSON.stringify({ label, text, ms, isAnswered: r.isAnswered, reason: r.isAnswered ? null : r.reason, raw: r.isAnswered ? r.text : null, parsed: r.isAnswered ? parseLabel(r.text) : null, usage: r.usage ?? null }))
      }
    }
    await $.fs.write('/tmp/coach-first.crZ3bN/out.jsonl', rows.join('\n') + '\n')
    return next(e)
  }).catch(($, e, next) => next(e))
}
