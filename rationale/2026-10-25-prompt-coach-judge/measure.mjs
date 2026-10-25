// Judge-quality measurement for prompt-coach: the real coach-core.ts prompts, run through `claude -p`.
// Usage: node24 measure.mjs <path to coach-core.ts> <runs> > results.jsonl
import { execFileSync } from 'node:child_process'
import { mkdtempSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

const [core, runsArg = '3'] = process.argv.slice(2)
const { judgeInput, parseLabel, parseVerdict, shouldHold, systemPrompt, isEligible } = await import(pathToFileURL(core).href)
const runs = Number(runsArg)
const cwd = mkdtempSync(join(tmpdir(), 'coach-judge-'))

const u = text => ({ role: 'user', text })
const a = text => ({ role: 'assistant', text })

// label: what the coach's own rubric asks for. clear = actionable as written or through <turns>.
const CASES = [
  { id: 'c01', label: 'clear', prompt: 'Add a --dry-run flag to scripts/remove-plugin.sh that prints the plan without deleting anything', turns: [] },
  { id: 'c02', label: 'clear', prompt: 'Rename parseIndex in plugins/task-runner/hooks/board-core.ts to parseCardIndex and update every caller', turns: [] },
  { id: 'c03', label: 'clear', prompt: 'Why does npm test fail with ERR_MODULE_NOT_FOUND in packages/api after the upgrade to Node 24?', turns: [] },
  { id: 'c04', label: 'clear', prompt: 'Write a unit test for textHash that covers an empty string and a string with a multi-byte character', turns: [] },
  { id: 'c05', label: 'clear', prompt: 'yes, update the README too', turns: [u('Add a --verbose flag to the CLI in src/cli.ts'), a('Done: --verbose now prints each step. Should I also document the flag in the README?')] },
  { id: 'c06', label: 'clear', prompt: 'go with option 2 then', turns: [u('How should we paginate the orders endpoint?'), a('Two options: 1) offset/limit, simple but slow on deep pages; 2) cursor on created_at,id, stable under inserts. Which do you prefer?')] },
  { id: 'c07', label: 'clear', prompt: 'Refactor the OrderController store method so validation lives in a FormRequest class', turns: [] },
  { id: 'c08', label: 'clear', prompt: 'List every TODO comment under src/ and group them by file', turns: [] },
  { id: 'c09', label: 'clear', prompt: 'do the same for the other two', turns: [u('Add an index on orders.customer_id in a new migration'), a('Added migration 2026_10_25_add_customer_id_index_to_orders. The invoices and payments tables also have an unindexed customer_id.')] },
  { id: 'c10', label: 'clear', prompt: 'Bump the vite dependency to the latest 8.x and fix whatever breaks in vite.config.ts', turns: [] },
  { id: 'c11', label: 'clear', prompt: 'Explain what the stateRoot function in cc-kit.ts returns outside a git repository', turns: [] },
  { id: 'c12', label: 'clear', prompt: 'that looks right, commit it with a short message', turns: [u('Fix the off-by-one in paginate() in src/lib/page.ts'), a('Fixed: the last page now includes its final item; the test in page.test.ts passes. Want me to commit?')] },
  { id: 'u01', label: 'unclear', prompt: 'can you fix that thing now', turns: [] },
  { id: 'u02', label: 'unclear', prompt: 'make it work like the other one does', turns: [] },
  { id: 'u03', label: 'unclear', prompt: 'do the same for the rest of them please', turns: [] },
  { id: 'u04', label: 'unclear', prompt: 'change it back to how it was before', turns: [] },
  { id: 'u05', label: 'unclear', prompt: 'apply the fix we talked about yesterday', turns: [] },
  { id: 'u06', label: 'unclear', prompt: 'the bug is back, sort it out', turns: [] },
  { id: 'u07', label: 'unclear', prompt: 'use the better approach for this one', turns: [u('Show me the current folder structure'), a('Here is the tree of src/: components/, lib/, pages/, styles/.')] },
  { id: 'u08', label: 'unclear', prompt: 'ok now the other thing', turns: [u('Format src/lib with prettier'), a('Formatted 12 files in src/lib.')] },
  { id: 'u09', label: 'unclear', prompt: 'hmm not quite, try again but different', turns: [] },
  { id: 'x01', label: 'conflict', prompt: 'Add a deleted_at column to the users table with a new migration', turns: [u('For this whole task, do not touch the database schema: no migrations.'), a('Understood, I will keep the schema as it is.')] },
  { id: 'x02', label: 'conflict', prompt: 'Install lodash and use it for the deep merge in config.ts', turns: [u('Do not add any new dependencies to this project.'), a('Noted: no new dependencies.')] },
  { id: 'x03', label: 'conflict', prompt: 'Push the branch to origin and open the PR now', turns: [u('Never push anything without asking me first; I review every diff locally.'), a('Understood: I will not push without asking.')] },
]

function ask(model, system, prompt) {
  const out = execFileSync('claude', ['-p', prompt, '--model', model, '--setting-sources', 'project', '--strict-mcp-config',
    '--disable-slash-commands', '--tools', '', '--system-prompt', system, '--output-format', 'json'],
  { cwd, input: '', encoding: 'utf8', timeout: 120_000, maxBuffer: 16 * 1024 * 1024 })
  const d = JSON.parse(out)
  return { text: String(d.result ?? ''), cost: Number(d.total_cost_usd ?? 0), ms: Number(d.duration_api_ms ?? 0) }
}

for (let run = 1; run <= runs; run++) {
  for (const c of CASES) {
    const eligible = isEligible({ text: c.prompt, origin: 'composer', attachments: 0, passed: [], muted: false })
    const input = judgeInput({ prompt: c.prompt, run: null, turns: c.turns })
    const first = ask('haiku', systemPrompt('first', 'unactionable', false, null), input)
    const label = parseLabel(first.text)
    let standby = null
    let verdict = null
    if (label !== 'clear') {
      standby = ask('sonnet', systemPrompt('standby', 'unactionable', false, null), input)
      verdict = parseVerdict(standby.text, c.prompt)
    }
    const held = verdict !== null && shouldHold(verdict)
    process.stdout.write(JSON.stringify({
      run, id: c.id, label: c.label, eligible, first: label, firstRaw: first.text.slice(0, 40),
      verdict: verdict && { verdict: verdict.verdict, kind: verdict.kind, confidence: verdict.confidence },
      standbyParsed: standby === null ? null : verdict !== null, held,
      cost: first.cost + (standby?.cost ?? 0),
    }) + '\n')
  }
}
