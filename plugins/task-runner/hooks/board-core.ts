export type Status = 'pending' | 'in_progress' | 'done' | 'parked' | 'blocked' | 'unrecognised'

export type Card = { id: string; title: string; dependsOn: string[]; group: string; status: Status; milestone?: string }

export type IndexModel = {
  slug: string
  specPath: string | null
  marker: 'GOAL' | 'GOAL lean' | 'ULTRA' | null
  cards: Card[]
  milestones: { id: string; title: string }[]
}

const CARD_ROW = /^\s*\|\s*\d\d\s*\|/

const CARD_HEADER = /^\s*\|\s*card\s*\|/i

const MILESTONE = /^###\s+Milestone\s+(\S+)\s+—\s+(.+?)\s*$/

const SPEC = /taskmaster-docs\/specs\/[^\s/]+?\.md/

// `skipped` is closed in hooks/announce.sh, and parked is the only closed status that is not done.
const STATUSES: [RegExp, Status][] = [
  [/^done/, 'done'],
  [/^(parked|skipped)/, 'parked'],
  [/^in[ _-]?progress/, 'in_progress'],
  [/^blocked/, 'blocked'],
  [/^pending/, 'pending'],
]

const cellsOf = (row: string) => row.split('|').map((c) => c.trim())

// The cell hooks/announce.sh and hooks/suggest.ts count, not the header's: the last, or the one before a trailing pipe.
// An empty cell is a card not started; any other word outside the vocabulary (a run wrote `committed <sha>`) is shown, not read as pending.
function statusOf(cells: string[]): Status {
  const s = (cells.at(-1) || cells.at(-2) || '').toLowerCase()
  return s === '' ? 'pending' : (STATUSES.find(([re]) => re.test(s))?.[1] ?? 'unrecognised')
}

export function parseIndex(md: string, slug: string): IndexModel | { error: string } {
  const lines = md.split('\n').filter((l) => !l.startsWith('>'))
  const header = lines.find((l) => CARD_HEADER.test(l))
  if (header === undefined) return { error: 'no card table' }

  const cols = cellsOf(header.toLowerCase())
  const cell = (cells: string[], name: string) => {
    const i = cols.indexOf(name)
    return i === -1 ? '' : (cells[i] ?? '')
  }

  const milestones: { id: string; title: string }[] = []
  const milestoneOf = new Map<string, string>()
  let current: string | null = null
  for (const line of lines) {
    if (line.startsWith('#')) {
      const [, id = '', title = ''] = MILESTONE.exec(line) ?? []
      current = id === '' ? null : id
      if (current !== null) milestones.push({ id, title })
    } else if (current !== null && line.startsWith('Cards:')) {
      for (const id of line.slice('Cards:'.length).split(/[\s,]+/)) if (id) milestoneOf.set(id, current)
    }
  }

  // Every card-shaped row, as hooks/announce.sh and hooks/suggest.ts count them; the header only places the columns.
  const cards = lines
    .filter((l) => CARD_ROW.test(l))
    .map((row): Card => {
      const cells = cellsOf(row)
      const id = cells[1] ?? ''
      return {
        id,
        title: cell(cells, 'title'),
        dependsOn: cell(cells, 'depends-on').match(/\b\d\d\b/g) ?? [],
        group: cell(cells, 'parallel group'),
        status: statusOf(cells),
        milestone: milestoneOf.get(id),
      }
    })
  if (cards.length === 0) return { error: 'no card table' }

  const has = (prefix: string) => lines.some((l) => l.startsWith(prefix))
  const marker = has('Goal: true (boost=off)') ? 'GOAL lean' : has('Goal: true') ? 'GOAL' : has('Ultra: true') ? 'ULTRA' : null

  return { slug, specPath: SPEC.exec(lines.join('\n'))?.[0] ?? null, marker, cards, milestones }
}

export function counts(m: IndexModel): { total: number; done: number; parked: number; unrecognised: number; inProgress: boolean } {
  const count = (s: Status) => m.cards.filter((c) => c.status === s).length
  return {
    total: m.cards.length,
    done: count('done'),
    parked: count('parked'),
    unrecognised: count('unrecognised'),
    inProgress: m.cards.some((c) => c.status === 'in_progress'),
  }
}

const ARC = ['understand', 'shape', 'decide', 'plan', 'build', 'verify', 'review', 'ship']

export function phaseAt(phase: string): string {
  const k = ARC.indexOf(phase) + 1
  return k === 0 ? phase : `${phase} ${k}/${ARC.length}`
}

export function statusLine(m: IndexModel | null, phase: string, checkMinutes: number | null): string {
  const c = m === null ? null : counts(m)
  const marker = m?.marker ?? null
  return [
    'task-runner',
    phaseAt(phase),
    c === null ? '' : `card ${c.done + (c.inProgress ? 1 : 0)}/${c.total}`,
    c === null || c.parked === 0 ? '' : `${c.parked} parked`,
    c === null || c.unrecognised === 0 ? '' : `${c.unrecognised} unrecognised`,
    marker === null ? '' : marker === 'ULTRA' ? 'ultra' : 'goal',
    checkMinutes === null ? '' : `check running ${checkMinutes}m`,
  ]
    .filter((part) => part !== '')
    .join('  ')
}

export function planLine(phase: string): string | undefined {
  return ARC.slice(0, ARC.indexOf('build')).includes(phase) ? `taskmaster  ${phaseAt(phase)}` : undefined
}

export type Mark = 'yes' | 'skip' | 'exempt'

export type Records = { review: Record<string, Mark>; control: Record<string, Mark> }

type Listed = { name: string; mtimeMs: number }

// The names candor's gate.sh counts, written by rv-observe.sh, review-skip.sh and negative-control.sh; it drops range- ids from reviews only.
const REVIEW = /^rv-(seen|skip|exempt)-(?!range-)(.+)\.json$/

const CONTROL = /^nc-(pass|skip)-(.+)\.json$/

const MARKS: Record<string, Mark> = { seen: 'yes', pass: 'yes', skip: 'skip', exempt: 'exempt' }

const RANK: Mark[] = ['yes', 'skip', 'exempt']

// candor counts any id, so a record written for `--card 1` covers the index's card 01.
export function cardKey(id: string): string {
  return /^\d+$/.test(id) ? id.replace(/^0+(?=\d)/, '') : id
}

// Only records newer than the run's registration count, as `find -newer` reads them there: card ids repeat across runs.
function marksOf(entries: Listed[], names: RegExp, registeredMs: number): Record<string, Mark> {
  const marks: Record<string, Mark> = {}
  for (const { name, mtimeMs } of entries) {
    const [, kind = '', id = ''] = names.exec(name) ?? []
    const mark = MARKS[kind]
    const key = cardKey(id)
    const held = marks[key]
    if (mark !== undefined && mtimeMs > registeredMs && (held === undefined || RANK.indexOf(mark) < RANK.indexOf(held))) marks[key] = mark
  }
  return marks
}

export function recordsOf(rv: Listed[], nc: Listed[], registeredMs: number): Records {
  return { review: marksOf(rv, REVIEW, registeredMs), control: marksOf(nc, CONTROL, registeredMs) }
}

// Only for a running.pid with no deadline line (task-runner before 0.48.0), as in candor's gate.sh.
const BG_PID_TTL_MS = 240 * 60 * 1000

// candor's bg_running(): bg/running.pid holds the gate's PID, the HEAD it tests and the epoch second it ends by.
export function checkPid(text: string, mtimeMs: number, nowMs: number, head: string): string | null {
  const [pid = '', sha = '', deadline = ''] = text.split('\n').map((line) => line.trim())
  const isCurrent = /^\d+$/.test(deadline) ? Math.floor(nowMs / 1000) < Number(deadline) : nowMs - mtimeMs <= BG_PID_TTL_MS
  return isCurrent && /^\d+$/.test(pid) && /^[0-9a-f]{7,}$/.test(sha) && head.startsWith(sha) ? pid : null
}
